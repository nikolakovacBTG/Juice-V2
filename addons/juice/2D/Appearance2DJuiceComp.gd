## Appearance2DJuiceComp.gd
## ============================================================================
## WHAT: Unified appearance effect for Node2D / CanvasItem nodes. One enum
##       selects from tint, overbright, outline, blend mode, fade, grayscale,
##       and dissolve effects — each with its own minimal parameter set.
## WHY:  Artists think "change how this looks." One component covers all
##       per-node visual effects, hiding domain-specific rendering details
##       (modulate, shaders, CanvasItemMaterial) behind a simple dropdown.
## SYSTEM: Juicing System (addons/juice/) — Appearance Family (2D Domain)
## DOES NOT: 3D material properties — use Appearance3DJuiceComp.
## DOES NOT: Custom shader uniforms — use ShaderPropertyJuiceComp.
## DOES NOT: Screen-space overlays — use ScreenOverlayJuiceComp.
## ============================================================================
##
## ARCHITECTURE:
## - Top-level enum (appearance_effect) selects the active effect.
## - Effect-specific parameters shown/hidden via _get_property_list().
## - Optional Flicker group provides temporal modulation on ANY effect.
## - progress=0.0 → base state, progress=1.0 → effect fully applied.
## - Flicker multiplies the base progress for rapid oscillation.
##
## EFFECTS:
## - TINT: Lerp modulate from color_from to color_to.
## - OVERBRIGHT: Modulate > 1.0 for HDR bloom/glow.
## - OUTLINE: Shader-based edge detection (uses outline_2d.gdshader).
## - BLEND_MODE: Apply CanvasItemMaterial blend mode, fade via alpha.
## - FADE: Animate modulate.a from base to target alpha.
## - GRAYSCALE: Shader-based desaturation (uses grayscale_2d.gdshader).
## - DISSOLVE: Shader-based noise dissolve (uses dissolve_2d.gdshader).
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase2D.svg")
class_name Appearance2DJuiceComp
extends JuiceCompBase


# =============================================================================
# ENUMS
# =============================================================================

## Which appearance effect to apply
enum AppearanceEffect {
	TINT,        ## Animate modulate color (lerp from/to)
	OVERBRIGHT,  ## Modulate > 1.0 for HDR bloom/glow
	OUTLINE,     ## Shader-based edge detection outline
	BLEND_MODE,  ## CanvasItemMaterial compositing blend mode
	FADE,        ## Animate modulate alpha
	GRAYSCALE,   ## Shader-based desaturation
	DISSOLVE,    ## Shader-based noise dissolve
}

## Compositing blend mode targets for BLEND_MODE effect
enum TargetBlendMode {
	ADD,           ## CanvasItemMaterial.BLEND_MODE_ADD
	SUB,           ## CanvasItemMaterial.BLEND_MODE_SUB
	MUL,           ## CanvasItemMaterial.BLEND_MODE_MUL
	PREMULT_ALPHA, ## CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
}

## Flicker temporal modulation modes
enum FlickerMode {
	RANDOM, ## Random value between min/max each interval
	CUSTOM, ## Sample a user-drawn Curve over time
}


# =============================================================================
# ALWAYS-VISIBLE EXPORTS
# =============================================================================

@export_group("Effect")

## Which appearance effect is active. Controls which parameters are shown.
@export var appearance_effect: AppearanceEffect = AppearanceEffect.TINT:
	set(value):
		appearance_effect = value
		notify_property_list_changed()


# =============================================================================
# BACKING VARIABLES — shown/hidden by _get_property_list per effect
# =============================================================================

# --- TINT ---
var color_from: Color = Color.WHITE
var color_to: Color = Color.RED
var animate_alpha: bool = false
var affect_children: bool = true

# --- OVERBRIGHT ---
var overbright_intensity: float = 2.0
var overbright_color: Color = Color.WHITE

# --- OUTLINE ---
var outline_color: Color = Color.YELLOW
var outline_width: float = 3.0

# --- BLEND_MODE ---
var target_blend_mode: int = TargetBlendMode.ADD

# --- FADE ---
var fade_target_alpha: float = 0.0

# --- GRAYSCALE ---
var grayscale_strength: float = 1.0

# --- DISSOLVE ---
var dissolve_texture: NoiseTexture2D = null
var dissolve_edge_color: Color = Color(1.0, 0.5, 0.0, 1.0)
var dissolve_edge_width: float = 0.05

# --- FLICKER (temporal modulation layer) ---
var use_flicker: bool = false:
	set(value):
		use_flicker = value
		notify_property_list_changed()
var flicker_mode: int = FlickerMode.RANDOM:
	set(value):
		flicker_mode = value
		notify_property_list_changed()
var hard_flicker: bool = false
var flicker_rate: float = 10.0
var flicker_min: float = 0.0
var flicker_max: float = 1.0
var flicker_curve: Curve = null


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Effect-specific parameters ---
	match appearance_effect:
		AppearanceEffect.TINT:
			props.append({"name": "color_from", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "color_to", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "animate_alpha", "type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "affect_children", "type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT})

		AppearanceEffect.OVERBRIGHT:
			props.append({"name": "overbright_intensity", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "1.0,10.0,0.1,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "overbright_color", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})

		AppearanceEffect.OUTLINE:
			props.append({"name": "outline_color", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "outline_width", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.5,20.0,0.5",
				"usage": PROPERTY_USAGE_DEFAULT})

		AppearanceEffect.BLEND_MODE:
			props.append({"name": "target_blend_mode", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Add,Sub,Mul,Premult Alpha",
				"usage": PROPERTY_USAGE_DEFAULT})

		AppearanceEffect.FADE:
			props.append({"name": "fade_target_alpha", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})

		AppearanceEffect.GRAYSCALE:
			props.append({"name": "grayscale_strength", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})

		AppearanceEffect.DISSOLVE:
			props.append({"name": "dissolve_texture", "type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "NoiseTexture2D",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "dissolve_edge_color", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "dissolve_edge_width", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,0.5,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})

	# --- Flicker group ---
	props.append({"name": "Flicker", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "use_flicker", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	if use_flicker:
		props.append({"name": "flicker_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Random,Custom",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "hard_flicker", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "flicker_rate", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,60.0,0.1,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
		match flicker_mode:
			FlickerMode.RANDOM:
				props.append({"name": "flicker_min", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
					"usage": PROPERTY_USAGE_DEFAULT})
				props.append({"name": "flicker_max", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
					"usage": PROPERTY_USAGE_DEFAULT})
			FlickerMode.CUSTOM:
				props.append({"name": "flicker_curve", "type": TYPE_OBJECT,
					"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Curve",
					"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(prop: StringName, value: Variant) -> bool:
	match prop:
		# TINT
		&"color_from": color_from = value; return true
		&"color_to": color_to = value; return true
		&"animate_alpha": animate_alpha = value; return true
		&"affect_children": affect_children = value; return true
		# OVERBRIGHT
		&"overbright_intensity": overbright_intensity = value; return true
		&"overbright_color": overbright_color = value; return true
		# OUTLINE
		&"outline_color": outline_color = value; return true
		&"outline_width": outline_width = value; return true
		# BLEND_MODE
		&"target_blend_mode": target_blend_mode = value; return true
		# FADE
		&"fade_target_alpha": fade_target_alpha = value; return true
		# GRAYSCALE
		&"grayscale_strength": grayscale_strength = value; return true
		# DISSOLVE
		&"dissolve_texture": dissolve_texture = value; return true
		&"dissolve_edge_color": dissolve_edge_color = value; return true
		&"dissolve_edge_width": dissolve_edge_width = value; return true
		# FLICKER
		&"use_flicker": use_flicker = value; return true
		&"flicker_mode": flicker_mode = value; return true
		&"hard_flicker": hard_flicker = value; return true
		&"flicker_rate": flicker_rate = value; return true
		&"flicker_min": flicker_min = value; return true
		&"flicker_max": flicker_max = value; return true
		&"flicker_curve": flicker_curve = value; return true
	return false


func _get(prop: StringName) -> Variant:
	match prop:
		# TINT
		&"color_from": return color_from
		&"color_to": return color_to
		&"animate_alpha": return animate_alpha
		&"affect_children": return affect_children
		# OVERBRIGHT
		&"overbright_intensity": return overbright_intensity
		&"overbright_color": return overbright_color
		# OUTLINE
		&"outline_color": return outline_color
		&"outline_width": return outline_width
		# BLEND_MODE
		&"target_blend_mode": return target_blend_mode
		# FADE
		&"fade_target_alpha": return fade_target_alpha
		# GRAYSCALE
		&"grayscale_strength": return grayscale_strength
		# DISSOLVE
		&"dissolve_texture": return dissolve_texture
		&"dissolve_edge_color": return dissolve_edge_color
		&"dissolve_edge_width": return dissolve_edge_width
		# FLICKER
		&"use_flicker": return use_flicker
		&"flicker_mode": return flicker_mode
		&"hard_flicker": return hard_flicker
		&"flicker_rate": return flicker_rate
		&"flicker_min": return flicker_min
		&"flicker_max": return flicker_max
		&"flicker_curve": return flicker_curve
	return null


# =============================================================================
# INTERNAL STATE (transient — never serialized)
# =============================================================================

# Shared
var _base_color: Color = Color.WHITE
var _base_alpha: float = 1.0
var _has_base_captured: bool = false

# Shader effects (OUTLINE, GRAYSCALE, DISSOLVE)
var _shader_material: ShaderMaterial = null
var _original_material: Material = null
var _owns_shader_material: bool = false

# Outline shader reference (preloaded once)
static var _outline_shader: Shader = null
static var _grayscale_shader: Shader = null
static var _dissolve_shader: Shader = null

# BLEND_MODE
var _canvas_item_material: CanvasItemMaterial = null
var _original_canvas_material: Material = null
var _original_blend_mode: int = -1
var _blend_mode_base_alpha: float = 1.0

# Flicker
var _flicker_time: float = 0.0
var _flicker_multiplier: float = 1.0

# Track last delta for flicker (updated in _process)
var _last_delta: float = 0.0


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


func _process(delta: float) -> void:
	_last_delta = delta
	super._process(delta)


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

func _invalidate_base_cache() -> void:
	_has_base_captured = false
	_shader_material = null
	_canvas_item_material = null
	_owns_shader_material = false


func _on_animate_start() -> void:
	if not _has_base_captured:
		_capture_base_state()

	# Set up shader/material if this effect needs one
	match appearance_effect:
		AppearanceEffect.OUTLINE:
			_setup_outline_shader()
		AppearanceEffect.BLEND_MODE:
			_setup_blend_mode()
		AppearanceEffect.GRAYSCALE:
			_setup_grayscale_shader()
		AppearanceEffect.DISSOLVE:
			_setup_dissolve_shader()

	# Reset flicker time for fresh start
	_flicker_time = 0.0
	_flicker_multiplier = 1.0

	if debug_enabled:
		print("[%s] Appearance2D start: effect=%s, flicker=%s" % [
			name, AppearanceEffect.keys()[appearance_effect], use_flicker])


func _apply_effect(progress: float) -> void:
	var effective := _get_effective_progress(progress)

	match appearance_effect:
		AppearanceEffect.TINT:
			_apply_tint(effective)
		AppearanceEffect.OVERBRIGHT:
			_apply_overbright(effective)
		AppearanceEffect.OUTLINE:
			_apply_outline(effective)
		AppearanceEffect.BLEND_MODE:
			_apply_blend_mode_effect(effective)
		AppearanceEffect.FADE:
			_apply_fade(effective)
		AppearanceEffect.GRAYSCALE:
			_apply_grayscale(effective)
		AppearanceEffect.DISSOLVE:
			_apply_dissolve(effective)


func _on_animate_out_complete() -> void:
	# Snap to base state
	_apply_effect(0.0)

	# Clean up shader/material resources
	match appearance_effect:
		AppearanceEffect.OUTLINE:
			_teardown_shader()
		AppearanceEffect.BLEND_MODE:
			_teardown_blend_mode()
		AppearanceEffect.GRAYSCALE:
			_teardown_shader()
		AppearanceEffect.DISSOLVE:
			_teardown_shader()

	if debug_enabled:
		print("[%s] Appearance2D complete, restored to base state" % name)


# =============================================================================
# FLICKER — TEMPORAL MODULATION
# =============================================================================

## Compute effective progress by applying flicker modulation.
## Without flicker, returns progress unchanged.
## With flicker, multiplies progress by a rapid oscillation value (0–1).
func _get_effective_progress(progress: float) -> float:
	if not use_flicker:
		return progress

	_flicker_time += _last_delta

	var multiplier: float = 1.0
	match flicker_mode:
		FlickerMode.RANDOM:
			# Generate new random value each interval (1 / flicker_rate seconds)
			var interval := 1.0 / maxf(flicker_rate, 0.01)
			if _flicker_time >= interval:
				_flicker_time = fmod(_flicker_time, interval)
				_flicker_multiplier = randf_range(flicker_min, flicker_max)
			multiplier = _flicker_multiplier

		FlickerMode.CUSTOM:
			if flicker_curve:
				var t := fmod(_flicker_time * flicker_rate, 1.0)
				multiplier = flicker_curve.sample(t)
			else:
				multiplier = 1.0

	# hard_flicker clamps to binary 0 or 1 — solves Godot's lack of
	# constant/step interpolation on Curve resources
	if hard_flicker:
		multiplier = 1.0 if multiplier >= 0.5 else 0.0

	return progress * multiplier


# =============================================================================
# EFFECT IMPLEMENTATIONS
# =============================================================================

# --- TINT ---

func _apply_tint(progress: float) -> void:
	var result := color_from.lerp(color_to, progress)
	if not animate_alpha:
		result.a = _base_color.a
	_set_modulate(result)


# --- OVERBRIGHT ---

func _apply_overbright(progress: float) -> void:
	# Lerp modulate from base toward overbright_color * intensity.
	# At progress=0 → base_color. At progress=1 → overbright.
	var intensity := lerpf(1.0, overbright_intensity, progress)
	var result := Color(
		_base_color.r * overbright_color.r * intensity,
		_base_color.g * overbright_color.g * intensity,
		_base_color.b * overbright_color.b * intensity,
		_base_color.a
	)
	_set_modulate(result)


# --- OUTLINE ---

func _apply_outline(progress: float) -> void:
	if not _shader_material:
		return
	_shader_material.set_shader_parameter("outline_width", outline_width * progress)
	# Update color live so inspector changes take effect during animation
	_shader_material.set_shader_parameter("outline_color", outline_color)


# --- BLEND_MODE ---

func _apply_blend_mode_effect(progress: float) -> void:
	# Blend modes are discrete — we fade the effect via alpha
	if not _target_node is CanvasItem:
		return
	var canvas := _target_node as CanvasItem
	canvas.modulate.a = lerpf(_blend_mode_base_alpha, _blend_mode_base_alpha, 1.0) * progress
	# At progress=0, alpha=0 makes the blend invisible. At progress=1, full effect.
	# Actually: we want the node visible, just blend-mode-faded.
	# The approach: alpha at base when progress=0, alpha at base when progress=1,
	# but the blend mode itself is the effect.
	# Simpler: just keep alpha at base. The visual change IS the blend mode being active.
	# Fade the blend mode influence by lerping alpha from 0 → base_alpha.
	canvas.modulate.a = _blend_mode_base_alpha * progress


# --- FADE ---

func _apply_fade(progress: float) -> void:
	if not _target_node is CanvasItem:
		return
	var canvas := _target_node as CanvasItem
	var new_alpha := lerpf(_base_alpha, fade_target_alpha, progress)
	var mod := canvas.modulate
	mod.a = new_alpha
	canvas.modulate = mod


# --- GRAYSCALE ---

func _apply_grayscale(progress: float) -> void:
	if not _shader_material:
		return
	_shader_material.set_shader_parameter("amount", grayscale_strength * progress)


# --- DISSOLVE ---

func _apply_dissolve(progress: float) -> void:
	if not _shader_material:
		return
	_shader_material.set_shader_parameter("threshold", progress)
	# Update edge parameters live for inspector tweaking
	_shader_material.set_shader_parameter("edge_color", dissolve_edge_color)
	_shader_material.set_shader_parameter("edge_width", dissolve_edge_width)


# =============================================================================
# BASE STATE CAPTURE
# =============================================================================

func _capture_base_state() -> void:
	if _has_base_captured:
		return

	if _target_node is CanvasItem:
		var canvas := _target_node as CanvasItem
		_base_color = canvas.modulate
		_base_alpha = canvas.modulate.a
	else:
		_base_color = Color.WHITE
		_base_alpha = 1.0
		if debug_enabled:
			push_warning("[%s] Target '%s' is not a CanvasItem" % [
				name, str(_target_node.name) if _target_node else "null"])

	_has_base_captured = true

	if debug_enabled:
		print("[%s] Captured base: color=%s, alpha=%.2f" % [name, _base_color, _base_alpha])


# =============================================================================
# MODULATE HELPERS
# =============================================================================

## Write color to modulate or self_modulate based on affect_children setting
func _set_modulate(color: Color) -> void:
	if not _target_node is CanvasItem:
		return
	var canvas := _target_node as CanvasItem
	if affect_children:
		canvas.modulate = color
	else:
		canvas.self_modulate = color


# =============================================================================
# SHADER SETUP / TEARDOWN
# =============================================================================

## Load a shader from the Juice addon's Shaders folder (cached statically)
func _get_outline_shader() -> Shader:
	if _outline_shader == null:
		_outline_shader = load("res://addons/juice/Shaders/outline_2d.gdshader")
	return _outline_shader


func _get_grayscale_shader() -> Shader:
	if _grayscale_shader == null:
		_grayscale_shader = load("res://addons/juice/Shaders/grayscale_2d.gdshader")
	return _grayscale_shader


func _get_dissolve_shader() -> Shader:
	if _dissolve_shader == null:
		_dissolve_shader = load("res://addons/juice/Shaders/dissolve_2d.gdshader")
	return _dissolve_shader


func _setup_outline_shader() -> void:
	if _shader_material:
		return
	if not _target_node is CanvasItem:
		return

	var canvas := _target_node as CanvasItem
	_original_material = canvas.material

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _get_outline_shader()
	_shader_material.set_shader_parameter("outline_width", 0.0)
	_shader_material.set_shader_parameter("outline_color", outline_color)
	canvas.material = _shader_material
	_owns_shader_material = true

	if debug_enabled:
		print("[%s] Outline shader applied to '%s'" % [name, canvas.name])


func _setup_grayscale_shader() -> void:
	if _shader_material:
		return
	if not _target_node is CanvasItem:
		return

	var canvas := _target_node as CanvasItem
	_original_material = canvas.material

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _get_grayscale_shader()
	_shader_material.set_shader_parameter("amount", 0.0)
	canvas.material = _shader_material
	_owns_shader_material = true

	if debug_enabled:
		print("[%s] Grayscale shader applied to '%s'" % [name, canvas.name])


func _setup_dissolve_shader() -> void:
	if _shader_material:
		return
	if not _target_node is CanvasItem:
		return

	var canvas := _target_node as CanvasItem
	_original_material = canvas.material

	# Auto-create noise texture if user didn't provide one
	var noise_tex := dissolve_texture
	if noise_tex == null:
		noise_tex = NoiseTexture2D.new()
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.05
		noise_tex.noise = noise

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _get_dissolve_shader()
	_shader_material.set_shader_parameter("threshold", 0.0)
	_shader_material.set_shader_parameter("dissolve_noise", noise_tex)
	_shader_material.set_shader_parameter("edge_color", dissolve_edge_color)
	_shader_material.set_shader_parameter("edge_width", dissolve_edge_width)
	canvas.material = _shader_material
	_owns_shader_material = true

	if debug_enabled:
		print("[%s] Dissolve shader applied to '%s'" % [name, canvas.name])


func _teardown_shader() -> void:
	if not _target_node is CanvasItem:
		return

	var canvas := _target_node as CanvasItem

	# Restore original material (or clear if we created one from scratch)
	if _owns_shader_material:
		canvas.material = _original_material
		_owns_shader_material = false

	_shader_material = null
	_original_material = null

	if debug_enabled:
		print("[%s] Shader material removed, original restored" % name)


# =============================================================================
# BLEND MODE SETUP / TEARDOWN
# =============================================================================

func _setup_blend_mode() -> void:
	if not _target_node is CanvasItem:
		return

	var canvas := _target_node as CanvasItem
	_blend_mode_base_alpha = canvas.modulate.a

	# Save original material for restoration
	_original_canvas_material = canvas.material

	# Create CanvasItemMaterial with target blend mode
	_canvas_item_material = CanvasItemMaterial.new()
	match target_blend_mode:
		TargetBlendMode.ADD:
			_canvas_item_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		TargetBlendMode.SUB:
			_canvas_item_material.blend_mode = CanvasItemMaterial.BLEND_MODE_SUB
		TargetBlendMode.MUL:
			_canvas_item_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		TargetBlendMode.PREMULT_ALPHA:
			_canvas_item_material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA

	canvas.material = _canvas_item_material
	# Start with alpha=0 so the blend effect fades in
	canvas.modulate.a = 0.0

	if debug_enabled:
		print("[%s] Blend mode %s applied to '%s'" % [
			name, TargetBlendMode.keys()[target_blend_mode], canvas.name])


func _teardown_blend_mode() -> void:
	if not _target_node is CanvasItem:
		return

	var canvas := _target_node as CanvasItem

	# Restore original material
	canvas.material = _original_canvas_material
	_original_canvas_material = null
	_canvas_item_material = null

	# Restore original alpha
	var mod := canvas.modulate
	mod.a = _blend_mode_base_alpha
	canvas.modulate = mod

	if debug_enabled:
		print("[%s] Blend mode removed, original restored" % name)


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()

	if parent and not parent is CanvasItem:
		warnings.append("Target must be a CanvasItem (Node2D, Sprite2D, etc.). Use Appearance3DJuiceComp for 3D nodes.")

	# Warn about shader effects on non-simple nodes
	if appearance_effect in [AppearanceEffect.GRAYSCALE, AppearanceEffect.DISSOLVE]:
		if parent and parent is CanvasItem and parent.material != null:
			warnings.append("Target already has a material. %s will temporarily replace it during animation." % AppearanceEffect.keys()[appearance_effect])

	if appearance_effect == AppearanceEffect.TINT:
		if color_from == color_to:
			warnings.append("color_from and color_to are identical — animation will have no visible effect.")

	return warnings
