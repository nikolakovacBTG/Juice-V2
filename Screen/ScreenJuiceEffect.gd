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

## Wave displacement direction.
## HORIZONTAL: each row shifts sideways (classic scanline/underwater look).
## VERTICAL:   each column shifts up/down.
## CONCENTRIC: radial ripples expanding from pivot_uv (pond-ripple look).
enum WaveDirection {
	HORIZONTAL,  ## Rows shift in X by sin(y * freq)
	VERTICAL,    ## Columns shift in Y by sin(x * freq)
	CONCENTRIC,  ## Radial ripples from pivot_uv
}

## Chromatic aberration displacement mode.
## UNIFORM_SHIFT:    Equal horizontal R/Blue offset (classic impact smear).
## VIGNETTE_FALLOFF: Horizontal offset scaled by vignette_mask (= 0 at center, 1 at edges).
##                   Simulates realistic lens dispersion at screen periphery.
## NOISE_PER_CHANNEL: R, G, B each get independent 2D noise offsets ("drunken" chromatic warp).
##                   Driven by shake_frequency (speed) and shake_seed (character).
enum ChromaticMode {
	UNIFORM_SHIFT,     ## Horizontal split — same for all pixels
	VIGNETTE_FALLOFF,  ## Horizontal split — fades toward center
	NOISE_PER_CHANNEL, ## Independent R/G/B 2D noise offsets — drunken/warp look
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

## BARREL: Radial distortion strength per axis at peak.
## X = horizontal warp, Y = vertical warp. Negative = barrel, positive = pincushion.
## Decouple X/Y to get anamorphic or asymmetric lens effects. Typical: -0.5 to 0.5 per axis.
var barrel_amount: Vector2 = Vector2(-0.2, -0.2)

## WAVE: Maximum wave amplitude at peak (UV normalized). Typical: 0.005–0.05.
var wave_amplitude: float = 0.015

## WAVE: Number of full sine cycles fitting the screen height. Not animated — static config.
## Higher = tighter/faster ripple. Typical: 5–30.
var wave_frequency: float = 12.0

## WAVE: Which axis the wave displaces. See WaveDirection enum.
var wave_direction: int = WaveDirection.HORIZONTAL

## CHROMATIC: RGB channel separation at peak (UV normalized). Typical: 0.002–0.02.
var chromatic_amount: float = 0.008

## CHROMATIC: Which displacement pattern to use. See ChromaticMode.
var chromatic_mode: int = ChromaticMode.UNIFORM_SHIFT

## PIVOT: UV-space offset from screen center (0.5, 0.5) used as the rotation/zoom/
## skew/barrel transform origin. (0, 0) = center, (-0.5, -0.5) = top-left corner.
## Only meaningful for ROTATION, BARREL, ZOOM, and SKEW channels.
var pivot_offset: Vector2 = Vector2.ZERO

## VIGNETTE: Fades the effect toward the screen center using a radial mask.
## Only meaningful for WAVE and CHROMATIC channels.
## use_vignette: enables the vignette falloff.
## vignette_scale: stretches the ellipse. (1,1) = circle, (2,1) = wide.
## vignette_softness: falloff steepness. Higher = sharper edge. Typical: 0.5–3.0.
var use_vignette:      bool    = false
var vignette_scale:    Vector2 = Vector2.ONE
var vignette_softness: float   = 1.0

# --- Shake-mode parameters (shown only when animation_mode == SHAKE) ---

## SHAKE: Oscillation frequency (cycles per second). Higher = more frantic.
var shake_frequency: float = 8.0

## SHAKE: Seed for the noise field. Different seeds produce different oscillation
## character from the same frequency settings.
var shake_seed: float = 0.0

## SHAKE: Noise algorithm that shapes the oscillator character.
## - Simplex Smooth: organic, flowing tremor (default)
## - Cellular:       twitchy, heartbeat-style glitch
## - Perlin:         classic gradient rumble
## - Value:          chunky, retro blocky shake
var shake_noise_type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


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
			# Vector2: no PROPERTY_HINT_RANGE support in Godot 4 — just usage DEFAULT.
			# X = horizontal warp (typical -0.5..0.5), Y = vertical warp.
			props.append({"name": "barrel_amount", "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.WAVE:
			props.append({"name": "wave_amplitude", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,0.1,0.001,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "wave_frequency", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "1.0,60.0,0.5",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "wave_direction", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Horizontal,Vertical,Concentric",
				"usage": PROPERTY_USAGE_DEFAULT})
			# Vignette: shown inline for channels where it is meaningful.
			props.append({"name": "use_vignette", "type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT})
			if use_vignette:
				props.append({"name": "vignette_scale", "type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_DEFAULT})
				props.append({"name": "vignette_softness", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,5.0,0.1",
					"usage": PROPERTY_USAGE_DEFAULT})
		Channel.CHROMATIC:
			props.append({"name": "chromatic_amount", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,0.05,0.0005,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "chromatic_mode", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Uniform Shift,Vignette Falloff,Noise Per Channel",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "use_vignette", "type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT})
			if use_vignette:
				props.append({"name": "vignette_scale", "type": TYPE_VECTOR2,
					"usage": PROPERTY_USAGE_DEFAULT})
				props.append({"name": "vignette_softness", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,5.0,0.1",
					"usage": PROPERTY_USAGE_DEFAULT})

	# Pivot: visible only for channels that use a transform origin.
	# Wave and Chromatic are full-screen effects — pivot has no meaning for them.
	# Offset is a translation — pivot doesn't apply either.
	var _is_pivotable := (channel == Channel.ROTATION or channel == Channel.ZOOM
		or channel == Channel.SKEW or channel == Channel.BARREL)
	if _is_pivotable:
		props.append({"name": "pivot_offset", "type": TYPE_VECTOR2,
			"hint": PROPERTY_HINT_NONE,
			"usage": PROPERTY_USAGE_DEFAULT})

	# Shake params — only visible in SHAKE mode
	if animation_mode == AnimationMode.SHAKE:
		props.append({"name": "shake_frequency", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.5,30.0,0.5",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "shake_seed", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1000.0,1.0",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "shake_noise_type", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Simplex Smooth:1,Simplex:0,Cellular:2,Perlin:3,Value:5,Value Cubic:6",
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
		&"wave_direction":           wave_direction = value;           return true
		&"chromatic_amount":         chromatic_amount = value;         return true
		&"chromatic_mode":           chromatic_mode = value;           return true
		&"shake_frequency":          shake_frequency = value;          return true
		&"shake_seed":               shake_seed = value;               return true
		&"shake_noise_type":         shake_noise_type = value;         return true
		&"pivot_offset":             pivot_offset = value;             return true
		&"use_vignette":             use_vignette = value;             return true
		&"vignette_scale":           vignette_scale = value;           return true
		&"vignette_softness":        vignette_softness = value;        return true
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
		&"wave_direction":           return wave_direction
		&"chromatic_amount":         return chromatic_amount
		&"chromatic_mode":           return chromatic_mode
		&"shake_frequency":          return shake_frequency
		&"shake_seed":               return shake_seed
		&"shake_noise_type":         return shake_noise_type
		&"pivot_offset":             return pivot_offset
		&"use_vignette":             return use_vignette
		&"vignette_scale":           return vignette_scale
		&"vignette_softness":        return vignette_softness
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Delta-first contribution tracking — what THIS effect has added to the utility this frame.
var _my_offset:    Vector2 = Vector2.ZERO
var _my_rot:       float   = 0.0
var _my_zoom:      float   = 0.0
var _my_skew:      Vector2 = Vector2.ZERO
var _my_barrel:    Vector2 = Vector2.ZERO
var _my_wave:      float   = 0.0
var _my_chromatic: float   = 0.0

# FastNoiseLite instance — created at _on_animate_start for SHAKE mode.
# Stateless query: get_noise_2d(t, offset) is safe to call from multiple
# callers with the same t as there is no internal position/playhead state.
var _shake_noise: FastNoiseLite = null



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


func _needs_sustain() -> bool:
	# SHAKE uses a time-driven noise field — must keep ticking after animate_in
	# so the screen keeps oscillating during hold_at_peak and indefinite waits.
	return animation_mode == AnimationMode.SHAKE


func _on_animate_start(_target: Node) -> void:
	if animation_mode != AnimationMode.SHAKE:
		return
	# (Re-)create noise so seed/type changes take effect mid-session.
	_shake_noise = FastNoiseLite.new()
	_shake_noise.noise_type = shake_noise_type
	_shake_noise.seed      = int(shake_seed)
	_shake_noise.frequency = 1.0  # Rate driven externally via t * shake_frequency


func _on_animate_out_complete(_target: Node) -> void:
	_remove_contribution()


func _restore_to_natural(_target: Node) -> void:
	_remove_contribution()


# =============================================================================
# CHANNEL APPLY METHODS
# =============================================================================

func _apply_offset(util: ScreenJuiceUtility, envelope: float) -> void:
	var uv := _offset_to_uv(screen_offset)
	var desired: Vector2
	if animation_mode == AnimationMode.SHAKE and _shake_noise != null:
		# Sample X and Y at different noise-field offsets — fully decorrelated axes.
		# This fixes the diagonal-only motion of the old single-scalar approach.
		var t := Time.get_ticks_msec() / 1000.0 * shake_frequency
		desired = Vector2(
			uv.x * _shake_noise.get_noise_2d(t, 0.0)   * envelope,
			uv.y * _shake_noise.get_noise_2d(t, 100.0) * envelope)
	else:
		desired = uv * envelope
	var delta   := desired - _my_offset
	util.offset += delta
	_my_offset = desired


func _apply_rotation(util: ScreenJuiceUtility, envelope: float) -> void:
	# Pivot: moves the rotation origin. (0,0) = center, (-0.5,-0.5) = top-left corner.
	util.pivot_uv = Vector2(0.5, 0.5) + pivot_offset
	var desired := deg_to_rad(screen_rotation_degrees) * _sample(envelope, 200.0)
	var delta   := desired - _my_rot
	util.rotation_amount += delta
	_my_rot = desired


func _apply_zoom(util: ScreenJuiceUtility, envelope: float) -> void:
	util.pivot_uv = Vector2(0.5, 0.5) + pivot_offset
	var desired := screen_zoom_offset * _sample(envelope, 300.0)
	var delta   := desired - _my_zoom
	util.zoom_offset += delta
	_my_zoom = desired


func _apply_skew(util: ScreenJuiceUtility, envelope: float) -> void:
	util.pivot_uv = Vector2(0.5, 0.5) + pivot_offset
	var desired := skew_amount * _sample(envelope, 100.0)
	var delta   := desired - _my_skew
	util.skew_offset += delta
	_my_skew = desired


func _apply_barrel(util: ScreenJuiceUtility, envelope: float) -> void:
	util.pivot_uv = Vector2(0.5, 0.5) + pivot_offset
	var desired := barrel_amount * _sample(envelope, 400.0)
	var delta   := desired - _my_barrel
	util.barrel_distortion += delta
	_my_barrel = desired


func _apply_wave(util: ScreenJuiceUtility, envelope: float) -> void:
	# Vignette config: last-write-wins. Shader reads use_vignette to decide whether
	# to apply the vignette mask. Falsy writes are intentional — they match the default state.
	util.use_vignette     = use_vignette
	util.vignette_scale   = vignette_scale
	util.vignette_softness = vignette_softness
	util.wave_direction   = wave_direction  # last-write-wins config
	var desired := wave_amplitude * absf(_sample(envelope, 500.0))  # abs: amplitude, sign via wave
	var delta   := desired - _my_wave
	util.wave_amplitude += delta
	util.wave_frequency  = wave_frequency  # config: last-write-wins
	_my_wave = desired


func _apply_chromatic(util: ScreenJuiceUtility, envelope: float) -> void:
	util.use_vignette     = use_vignette
	util.vignette_scale   = vignette_scale
	util.vignette_softness = vignette_softness
	util.chromatic_mode   = chromatic_mode
	if chromatic_mode == ChromaticMode.NOISE_PER_CHANNEL:
		# Drive the shader's sin oscillator at shake_frequency speed.
		# Time advances monotonically so each frame the shader gets a new input.
		util.chromatic_time = Time.get_ticks_msec() / 1000.0 * shake_frequency
		util.chromatic_seed = shake_seed
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
		# Reset last-write-wins config so stale values don’t affect the next effect.
		util.pivot_uv           = Vector2(0.5, 0.5)
		util.use_vignette       = false
		util.vignette_scale     = Vector2.ONE
		util.vignette_softness  = 1.0
		util.wave_direction     = 0  # back to Horizontal default
		util.chromatic_mode     = 0  # back to Uniform default
		util.chromatic_time     = 0.0
		util.chromatic_seed     = 0.0
	_my_offset    = Vector2.ZERO
	_my_rot       = 0.0
	_my_zoom      = 0.0
	_my_skew      = Vector2.ZERO
	_my_barrel    = Vector2.ZERO
	_my_wave      = 0.0
	_my_chromatic = 0.0


# =============================================================================
# SHAKE OSCILLATOR
# =============================================================================

## Returns the effective multiplier for the current frame.
## DETERMINISTIC: returns envelope (0→1→0 curve value).
## SHAKE: returns envelope × FastNoiseLite sample (decorrelated per channel via seed_offset).
func _sample(envelope: float, seed_offset: float) -> float:
	match animation_mode:
		AnimationMode.DETERMINISTIC:
			return envelope
		AnimationMode.SHAKE:
			if _shake_noise == null:
				return envelope  # Safety: noise not yet initialized
			# t * shake_frequency = oscillation rate in noise-space (≈ cycles/sec).
			# seed_offset selects a different noise-field row per channel.
			var t := Time.get_ticks_msec() / 1000.0 * shake_frequency
			return envelope * _shake_noise.get_noise_2d(t, seed_offset)
		_:
			return envelope


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
