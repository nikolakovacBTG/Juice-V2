## Animates screen-space deformations via ScreenJuiceUtility.
##
## Drop in any domain recipe on any entity. The effect auto-bootstraps a
## ScreenJuiceUtility at SceneTree.root on first use — no manual setup.

# ============================================================================
# WHAT: Meta effect that writes screen-space deformations to ScreenJuiceUtility.
#       Supports 7 channels: Offset, Rotation, Zoom, Skew, Barrel, Wave, Chromatic.
#       Two animation modes: Deterministic (curve-driven) or Shake (noise-driven,
#       with the curve acting as the amplitude envelope).
# WHY:  Screen effects are authored on entities, not on a camera or global node.
#       Auto-bootstrap means zero configuration — just drop the effect and go.
# SYSTEM: Juice System (addons/Juice_V1/Screen/)
# DOES NOT: Animate the JuiceBase target node — writes to ScreenJuiceUtility only.
# DOES NOT: Preview in editor — ScreenJuiceUtility is runtime-only.
#           Transport preview will be addressed during the Editor Transport port.
#
# SETUP: None. The effect auto-bootstraps ScreenJuiceUtility at runtime.
#        Place ScreenJuiceUtility manually only for custom layer/shader control.
# ============================================================================

@icon("res://addons/Juice_V1/icons/JuiceBaseScreen.svg")
@tool
class_name ScreenJuiceEffect
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which screen property to animate.
enum Channel {
	OFFSET,    ## UV offset — screen push/kick/shake (most common).
	ROTATION,  ## Screen rotation — tilt or spin.
	ZOOM,      ## Screen scale — punch-in / breathe. Positive = zoom in.
	SKEW,      ## UV shear — lean/warp. X = horizontal, Y = vertical.
	BARREL,    ## Radial distortion. Negative = barrel, positive = pincushion.
	WAVE,      ## Scanline sine-wave distortion — underwater/heat shimmer.
	CHROMATIC, ## RGB channel split — glitch, impact, aberration.
}

## Animation mode. Deterministic plays a clean curve-shaped ramp. Shake adds a
## multi-frequency noise oscillator whose amplitude is shaped by the same curve.
enum AnimationMode {
	DETERMINISTIC, ## Smooth curve from 0 → value → 0. Curve controls the shape.
	SHAKE,         ## Chaotic oscillation. Value = max amplitude; curve = envelope.
}

## Unit for the OFFSET channel.
enum ScreenOffsetUnit {
	UV_NORMALIZED, ## 0.0–1.0 = full screen width/height. Resolution independent.
	PIXELS,        ## Pixels. Converted to UV at apply-time via viewport size.
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Which screen channel to animate.
var channel: int = Channel.OFFSET:
	set(value):
		channel = value
		notify_property_list_changed()

## Animation mode: deterministic curve or chaotic shake with curve envelope.
var animation_mode: int = AnimationMode.DETERMINISTIC:
	set(value):
		animation_mode = value
		notify_property_list_changed()

# --- Channel-specific values (shown/hidden by _get_property_list) ---

## OFFSET: Screen UV displacement at peak (progress=1.0).
var screen_offset: Vector2 = Vector2(0.02, 0.0)

## OFFSET: Unit interpretation for screen_offset.
var offset_unit: int = ScreenOffsetUnit.UV_NORMALIZED:
	set(value):
		offset_unit = value
		notify_property_list_changed()

## ROTATION: Screen rotation at peak (degrees).
var screen_rotation_degrees: float = 2.0

## ZOOM: Screen zoom scale offset at peak. Positive = zoom in.
var screen_zoom_offset: float = 0.05

## SKEW: Horizontal (x) and vertical (y) UV shear at peak.
## Typical range: -0.2 to 0.2. Positive x = lean right.
var skew_amount: Vector2 = Vector2(0.1, 0.0)

## BARREL: Radial distortion strength at peak. Negative = barrel (edges bow outward).
## Positive = pincushion (edges bow inward). Typical range: -0.5 to 0.5.
var barrel_amount: float = -0.2

## WAVE: Maximum wave amplitude at peak (UV normalized). Typical: 0.005–0.05.
var wave_amplitude: float = 0.015

## WAVE: Number of full sine cycles fitting the screen height. Not animated — static config.
## Higher = tighter/faster ripple. Typical: 5–30.
var wave_frequency: float = 12.0

## CHROMATIC: RGB channel separation at peak (UV normalized). Typical: 0.002–0.02.
var chromatic_amount: float = 0.008

# --- Shake-mode parameters (shown only when animation_mode == SHAKE) ---

## SHAKE: Oscillation frequency (cycles per second). Higher = more frantic.
var shake_frequency: float = 8.0

## SHAKE: Seed offset for the noise oscillator. Different seeds give different
## feel from the same settings. Range: 0.0 to 1000.0.
var shake_seed: float = 0.0


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "Screen Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	props.append({"name": "channel", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Offset,Rotation,Zoom,Skew,Barrel,Wave,Chromatic",
		"usage": PROPERTY_USAGE_DEFAULT})

	props.append({"name": "animation_mode", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Deterministic,Shake",
		"usage": PROPERTY_USAGE_DEFAULT})

	# Channel-specific value
	match channel:
		Channel.OFFSET:
			props.append({"name": "screen_offset", "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "offset_unit", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "UV Normalized,Pixels",
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.ROTATION:
			props.append({"name": "screen_rotation_degrees", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-180.0,180.0,0.1,or_less,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.ZOOM:
			props.append({"name": "screen_zoom_offset", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-2.0,2.0,0.01,or_less,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.SKEW:
			props.append({"name": "skew_amount", "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.BARREL:
			props.append({"name": "barrel_amount", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-1.0,1.0,0.005,or_less,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.WAVE:
			props.append({"name": "wave_amplitude", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,0.1,0.001,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "wave_frequency", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "1.0,60.0,0.5",
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.CHROMATIC:
			props.append({"name": "chromatic_amount", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,0.05,0.0005,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})

	# Shake params — only visible in SHAKE mode
	if animation_mode == AnimationMode.SHAKE:
		props.append({"name": "shake_frequency", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.5,30.0,0.5",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "shake_seed", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1000.0,1.0",
			"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"channel":                  channel = value;                  return true
		&"animation_mode":           animation_mode = value;           return true
		&"screen_offset":            screen_offset = value;            return true
		&"offset_unit":              offset_unit = value;              return true
		&"screen_rotation_degrees":  screen_rotation_degrees = value;  return true
		&"screen_zoom_offset":       screen_zoom_offset = value;       return true
		&"skew_amount":              skew_amount = value;              return true
		&"barrel_amount":            barrel_amount = value;            return true
		&"wave_amplitude":           wave_amplitude = value;           return true
		&"wave_frequency":           wave_frequency = value;           return true
		&"chromatic_amount":         chromatic_amount = value;         return true
		&"shake_frequency":          shake_frequency = value;          return true
		&"shake_seed":               shake_seed = value;               return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"channel":                  return channel
		&"animation_mode":           return animation_mode
		&"screen_offset":            return screen_offset
		&"offset_unit":              return offset_unit
		&"screen_rotation_degrees":  return screen_rotation_degrees
		&"screen_zoom_offset":       return screen_zoom_offset
		&"skew_amount":              return skew_amount
		&"barrel_amount":            return barrel_amount
		&"wave_amplitude":           return wave_amplitude
		&"wave_frequency":           return wave_frequency
		&"chromatic_amount":         return chromatic_amount
		&"shake_frequency":          return shake_frequency
		&"shake_seed":               return shake_seed
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Delta-first contribution tracking — what THIS effect has added to the utility this frame.
var _my_offset:    Vector2 = Vector2.ZERO
var _my_rot:       float   = 0.0
var _my_zoom:      float   = 0.0
var _my_skew:      Vector2 = Vector2.ZERO
var _my_barrel:    float   = 0.0
var _my_wave:      float   = 0.0
var _my_chromatic: float   = 0.0



# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _apply_effect(progress: float, _target: Node) -> void:
	var util := _find_or_create_utility()
	if not is_instance_valid(util):
		return

	var envelope := progress  # progress is curve-evaluated by JuiceEffectBase

	match channel:
		Channel.OFFSET:    _apply_offset(util, envelope)
		Channel.ROTATION:  _apply_rotation(util, envelope)
		Channel.ZOOM:      _apply_zoom(util, envelope)
		Channel.SKEW:      _apply_skew(util, envelope)
		Channel.BARREL:    _apply_barrel(util, envelope)
		Channel.WAVE:      _apply_wave(util, envelope)
		Channel.CHROMATIC: _apply_chromatic(util, envelope)


func _on_animate_out_complete(_target: Node) -> void:
	_remove_contribution()


func _restore_to_natural(_target: Node) -> void:
	_remove_contribution()


# =============================================================================
# CHANNEL APPLY METHODS
# =============================================================================

func _apply_offset(util: ScreenJuiceUtility, envelope: float) -> void:
	var uv := _offset_to_uv(screen_offset)
	var desired := uv * _sample(envelope, 0.0)
	var delta   := desired - _my_offset
	util.offset += delta
	_my_offset = desired


func _apply_rotation(util: ScreenJuiceUtility, envelope: float) -> void:
	var desired := deg_to_rad(screen_rotation_degrees) * _sample(envelope, 200.0)
	var delta   := desired - _my_rot
	util.rotation_amount += delta
	_my_rot = desired


func _apply_zoom(util: ScreenJuiceUtility, envelope: float) -> void:
	var desired := screen_zoom_offset * _sample(envelope, 300.0)
	var delta   := desired - _my_zoom
	util.zoom_offset += delta
	_my_zoom = desired


func _apply_skew(util: ScreenJuiceUtility, envelope: float) -> void:
	var desired := skew_amount * _sample(envelope, 100.0)
	var delta   := desired - _my_skew
	util.skew_offset += delta
	_my_skew = desired


func _apply_barrel(util: ScreenJuiceUtility, envelope: float) -> void:
	var desired := barrel_amount * _sample(envelope, 400.0)
	var delta   := desired - _my_barrel
	util.barrel_distortion += delta
	_my_barrel = desired


func _apply_wave(util: ScreenJuiceUtility, envelope: float) -> void:
	var desired := wave_amplitude * absf(_sample(envelope, 500.0))  # abs: amplitude, sign via wave
	var delta   := desired - _my_wave
	util.wave_amplitude += delta
	util.wave_frequency  = wave_frequency  # config: last-write-wins
	_my_wave = desired


func _apply_chromatic(util: ScreenJuiceUtility, envelope: float) -> void:
	var desired := chromatic_amount * absf(_sample(envelope, 600.0))  # abs: separation always positive
	var delta   := desired - _my_chromatic
	util.chromatic_amount += delta
	_my_chromatic = desired


# =============================================================================
# CONTRIBUTION CLEANUP
# =============================================================================

func _remove_contribution() -> void:
	var util := _find_utility()
	if is_instance_valid(util):
		util.offset            -= _my_offset
		util.rotation_amount   -= _my_rot
		util.zoom_offset       -= _my_zoom
		util.skew_offset       -= _my_skew
		util.barrel_distortion -= _my_barrel
		util.wave_amplitude    -= _my_wave
		util.chromatic_amount  -= _my_chromatic
	_my_offset    = Vector2.ZERO
	_my_rot       = 0.0
	_my_zoom      = 0.0
	_my_skew      = Vector2.ZERO
	_my_barrel    = 0.0
	_my_wave      = 0.0
	_my_chromatic = 0.0


# =============================================================================
# SHAKE OSCILLATOR
# =============================================================================

## Returns the effective multiplier for the current frame.
## DETERMINISTIC: returns envelope (0→1→0 curve value).
## SHAKE: returns envelope × multi-frequency noise oscillator.
func _sample(envelope: float, seed_offset: float) -> float:
	match animation_mode:
		AnimationMode.DETERMINISTIC:
			return envelope
		AnimationMode.SHAKE:
			var t := Time.get_ticks_msec() / 1000.0
			return envelope * _noise_sample(t, shake_seed + seed_offset)
		_:
			return envelope


## Multi-frequency sin superposition — cheap chaotic waveform.
## Normalized so |output| ≤ 1.0.
func _noise_sample(t: float, seed: float) -> float:
	return (  sin(t * shake_frequency * 1.00 + seed * 0.00) * 0.50
			+ sin(t * shake_frequency * 2.10 + seed * 1.00) * 0.30
			+ sin(t * shake_frequency * 4.30 + seed * 2.00) * 0.15
			+ sin(t * shake_frequency * 8.70 + seed * 3.00) * 0.05)


# =============================================================================
# UTILITY DISCOVERY + AUTO-BOOTSTRAP
# =============================================================================

## Returns the utility instantly if it already exists.
func _find_utility() -> ScreenJuiceUtility:
	if is_instance_valid(ScreenJuiceUtility.instance):
		return ScreenJuiceUtility.instance
	return null


## Returns the utility, bootstrapping one at SceneTree.root if not present.
## Returns null in editor (would overlay Godot's own UI) or if tree unavailable.
func _find_or_create_utility() -> ScreenJuiceUtility:
	if Engine.is_editor_hint():
		return null
	if is_instance_valid(ScreenJuiceUtility.instance):
		return ScreenJuiceUtility.instance
	return _bootstrap_utility()


## Creates ScreenJuiceUtility + CanvasLayer at SceneTree.root.
## Persists across scene transitions. Only called on first use.
func _bootstrap_utility() -> ScreenJuiceUtility:
	if not is_instance_valid(_host_node):
		push_warning("[ScreenJuiceEffect] Cannot bootstrap — _host_node is null. Is this effect chained without host?")
		return null

	var tree := _host_node.get_tree()
	if not tree:
		return null

	var canvas := CanvasLayer.new()
	canvas.name       = "ScreenJuiceCanvas"
	canvas.layer      = 128
	canvas.follow_viewport_enabled = false
	tree.root.add_child(canvas)

	var util := ScreenJuiceUtility.new()
	util.name          = "ScreenJuiceUtility"
	util.anchor_right  = 1.0
	util.anchor_bottom = 1.0
	util.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	# Assign the shader material
	var mat := ShaderMaterial.new()
	mat.shader = load("res://addons/Juice_V1/Screen/screen_juice.gdshader")
	util.material = mat

	canvas.add_child(util)

	# Force _ready equivalent — static instance may not be set yet
	ScreenJuiceUtility.instance = util
	util._ready()

	if debug_enabled:
		print("[ScreenJuiceEffect] Auto-bootstrapped ScreenJuiceUtility at root")

	return util


# =============================================================================
# HELPERS
# =============================================================================

## Converts screen_offset from the user's chosen unit to UV-normalized.
func _offset_to_uv(px_or_uv: Vector2) -> Vector2:
	if offset_unit == ScreenOffsetUnit.UV_NORMALIZED:
		return px_or_uv
	# PIXELS → UV: divide by viewport size
	if is_instance_valid(_host_node):
		var vp_size := _host_node.get_viewport().get_visible_rect().size
		if vp_size.x > 0.0 and vp_size.y > 0.0:
			return Vector2(px_or_uv.x / vp_size.x, px_or_uv.y / vp_size.y)
	push_warning("[ScreenJuiceEffect] Could not convert pixels to UV — viewport unavailable, using raw value")
	return px_or_uv
