## Appearance3DJuiceComp.gd
## ============================================================================
## WHAT: Unified appearance effect for 3D nodes. One enum selects from tint,
##       overbright, outline, blend mode, fade, grayscale, dissolve, and
##       3D-exclusive material properties (emission, roughness, metallic, grow,
##       rim, clearcoat, refraction).
## WHY:  Artists think "change how this looks." One component covers all
##       per-node visual effects, hiding domain-specific rendering details
##       (StandardMaterial3D, ShaderMaterial, next_pass) behind a dropdown.
## SYSTEM: Juicing System (addons/juice/) — Appearance Family (3D Domain)
## DOES NOT: CanvasItem effects — use Appearance2D / AppearanceControl.
## DOES NOT: Custom shader uniforms — use ShaderPropertyJuiceComp.
## DOES NOT: Screen-space overlays — use ScreenOverlayJuiceComp.
## ============================================================================
##
## ARCHITECTURE:
## - Top-level enum (appearance_effect) selects the active effect.
## - Effect-specific parameters shown/hidden via _get_property_list().
## - Optional Flicker group provides temporal modulation on ANY effect.
## - progress=0.0 → base state, progress=1.0 → effect fully applied.
##
## EFFECTS (shared with 2D/Control):
## - TINT: Animate albedo_color from color_from to color_to.
## - OVERBRIGHT: Emission energy for HDR bloom/glow.
## - OUTLINE: Inverted Hull technique (next_pass material, cull front, grow).
## - FADE: Animate material transparency.
## - GRAYSCALE: Shader-based desaturation (next_pass grayscale_3d.gdshader).
## - DISSOLVE: Shader-based noise dissolve (material_override dissolve_3d.gdshader).
## - COLOR_OVERLAY: Shader-based flat color mix (next_pass overlay_3d.gdshader).
##
## LAYERS (optional modifiers on any effect):
## - Flicker: Temporal modulation (random or curve-driven).
## - Blending Mode: BaseMaterial3D compositing mode during animation.
##
## 3D-EXCLUSIVE EFFECTS:
## - EMISSION: Animate emission color.
## - ROUGHNESS: Animate surface roughness.
## - METALLIC: Animate metallic appearance.
## - GROW: Animate vertex displacement along normals.
## - RIM: Animate rim lighting intensity.
## - CLEARCOAT: Animate clearcoat intensity.
## - REFRACTION: Animate refraction scale.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase3D.svg")
class_name Appearance3DJuiceComp
extends JuiceCompBase


# =============================================================================
# ENUMS
# =============================================================================

## Which appearance effect to apply
enum AppearanceEffect {
	TINT,          ## Animate albedo_color (lerp from/to)
	OVERBRIGHT,    ## Emission energy for HDR bloom/glow
	OUTLINE,       ## Inverted Hull technique (next_pass grow + cull front)
	FADE,          ## Animate material transparency
	GRAYSCALE,     ## Shader-based desaturation (next_pass)
	DISSOLVE,      ## Shader-based noise dissolve (material_override)
	COLOR_OVERLAY, ## Shader-based flat color mix (next_pass)
	EMISSION,      ## Animate emission color
	ROUGHNESS,     ## Animate surface roughness
	METALLIC,      ## Animate metallic appearance
	GROW,          ## Animate vertex displacement along normals
	RIM,           ## Animate rim lighting intensity
	CLEARCOAT,     ## Animate clearcoat intensity
	REFRACTION,    ## Animate refraction scale
}

## Compositing blend mode for the optional Blending Mode layer
enum TargetBlendMode {
	ADD,  ## BaseMaterial3D.BLEND_MODE_ADD
	SUB,  ## BaseMaterial3D.BLEND_MODE_SUB
	MUL,  ## BaseMaterial3D.BLEND_MODE_MUL
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

## Which child GeometryInstance3D to affect (leave empty to auto-search)
@export_node_path("GeometryInstance3D") var geometry_path: NodePath


# =============================================================================
# BACKING VARIABLES — shown/hidden by _get_property_list per effect
# =============================================================================

# --- TINT (albedo_color) ---
var color_from: Color = Color.WHITE
var color_to: Color = Color.RED

# --- OVERBRIGHT ---
var overbright_intensity: float = 2.0
var overbright_color: Color = Color.WHITE

# --- OUTLINE (Inverted Hull) ---
var outline_color: Color = Color.YELLOW
var outline_width: float = 0.02
var auto_create_outline: bool = true

# --- FADE ---
var fade_target_alpha: float = 0.0

# --- GRAYSCALE ---
var grayscale_strength: float = 1.0

# --- DISSOLVE ---
var dissolve_texture: NoiseTexture2D = null
var dissolve_edge_color: Color = Color(1.0, 0.5, 0.0, 1.0)
var dissolve_edge_width: float = 0.05

# --- COLOR_OVERLAY ---
var overlay_color: Color = Color.RED

# --- BLENDING MODE (optional compositing layer) ---
var use_blend_mode: bool = false:
	set(value):
		use_blend_mode = value
		notify_property_list_changed()
var target_blend_mode: int = TargetBlendMode.ADD

# --- EMISSION (color) ---
var emission_color_target: Color = Color.WHITE

# --- Numeric material properties (ROUGHNESS, METALLIC, GROW, RIM, CLEARCOAT, REFRACTION) ---
var float_offset: float = 1.0

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
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.001,0.1,0.001,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "auto_create_outline", "type": TYPE_BOOL,
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

		AppearanceEffect.COLOR_OVERLAY:
			props.append({"name": "overlay_color", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})

		AppearanceEffect.EMISSION:
			props.append({"name": "emission_color_target", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})

		AppearanceEffect.ROUGHNESS, AppearanceEffect.METALLIC, \
		AppearanceEffect.GROW, AppearanceEffect.RIM, \
		AppearanceEffect.CLEARCOAT, AppearanceEffect.REFRACTION:
			props.append({"name": "float_offset", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "-2.0,2.0,0.01,or_greater,or_less",
				"usage": PROPERTY_USAGE_DEFAULT})

	# --- Blending Mode group (optional compositing layer) ---
	props.append({"name": "Blending Mode", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "use_blend_mode", "type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT})

	if use_blend_mode:
		props.append({"name": "target_blend_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Add,Sub,Mul",
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
		# OVERBRIGHT
		&"overbright_intensity": overbright_intensity = value; return true
		&"overbright_color": overbright_color = value; return true
		# OUTLINE
		&"outline_color": outline_color = value; return true
		&"outline_width": outline_width = value; return true
		&"auto_create_outline": auto_create_outline = value; return true
		# FADE
		&"fade_target_alpha": fade_target_alpha = value; return true
		# GRAYSCALE
		&"grayscale_strength": grayscale_strength = value; return true
		# DISSOLVE
		&"dissolve_texture": dissolve_texture = value; return true
		&"dissolve_edge_color": dissolve_edge_color = value; return true
		&"dissolve_edge_width": dissolve_edge_width = value; return true
		# COLOR_OVERLAY
		&"overlay_color": overlay_color = value; return true
		# BLENDING MODE LAYER
		&"use_blend_mode": use_blend_mode = value; return true
		&"target_blend_mode": target_blend_mode = value; return true
		# EMISSION
		&"emission_color_target": emission_color_target = value; return true
		# Numeric
		&"float_offset": float_offset = value; return true
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
		# OVERBRIGHT
		&"overbright_intensity": return overbright_intensity
		&"overbright_color": return overbright_color
		# OUTLINE
		&"outline_color": return outline_color
		&"outline_width": return outline_width
		&"auto_create_outline": return auto_create_outline
		# FADE
		&"fade_target_alpha": return fade_target_alpha
		# GRAYSCALE
		&"grayscale_strength": return grayscale_strength
		# DISSOLVE
		&"dissolve_texture": return dissolve_texture
		&"dissolve_edge_color": return dissolve_edge_color
		&"dissolve_edge_width": return dissolve_edge_width
		# COLOR_OVERLAY
		&"overlay_color": return overlay_color
		# BLENDING MODE LAYER
		&"use_blend_mode": return use_blend_mode
		&"target_blend_mode": return target_blend_mode
		# EMISSION
		&"emission_color_target": return emission_color_target
		# Numeric
		&"float_offset": return float_offset
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

# Material references
var _target_material: StandardMaterial3D = null
var _geometry_instance: GeometryInstance3D = null
var _has_base_captured: bool = false
var _is_material_duplicated: bool = false

# Base values for various effects
var _base_albedo: Color = Color.WHITE
var _base_emission: Color = Color.BLACK
var _base_emission_energy: float = 1.0
var _base_float_value: float = 0.0
var _base_alpha: float = 1.0

# OUTLINE (Inverted Hull)
var _outline_material: StandardMaterial3D = null
var _main_material: Material = null
var _created_outline_material: bool = false
var _outline_is_setup: bool = false

# GRAYSCALE (next_pass shader)
var _grayscale_shader_material: ShaderMaterial = null
var _original_next_pass: Material = null
var _grayscale_is_setup: bool = false

# DISSOLVE (material_override shader)
var _dissolve_shader_material: ShaderMaterial = null
var _original_material_override: Material = null
var _dissolve_is_setup: bool = false

# COLOR_OVERLAY (next_pass shader)
var _overlay_shader_material: ShaderMaterial = null
var _overlay_original_next_pass: Material = null
var _overlay_is_setup: bool = false

# Blending Mode layer
var _original_blend_mode: int = -1
var _original_transparency: int = -1
var _blend_mode_is_setup: bool = false

# Shader references (preloaded once)
static var _grayscale_shader: Shader = null
static var _dissolve_shader: Shader = null
static var _overlay_shader: Shader = null

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
	_target_material = null
	_geometry_instance = null
	_is_material_duplicated = false
	_outline_material = null
	_main_material = null
	_created_outline_material = false
	_outline_is_setup = false
	_grayscale_shader_material = null
	_grayscale_is_setup = false
	_dissolve_shader_material = null
	_dissolve_is_setup = false
	_overlay_shader_material = null
	_overlay_is_setup = false
	_blend_mode_is_setup = false


func _on_animate_start() -> void:
	# Find geometry and material for effects that need StandardMaterial3D
	if _needs_standard_material() and not _target_material:
		_find_and_prepare_material()
		if not _target_material:
			if debug_enabled:
				push_warning("[%s] No StandardMaterial3D found on target '%s'" % [
					name, str(_target_node.name) if _target_node else "null"])
			return

	# Capture base values
	if not _has_base_captured:
		_capture_base_state()

	# Set up specialized resources per effect
	match appearance_effect:
		AppearanceEffect.OUTLINE:
			_setup_outline()
		AppearanceEffect.FADE:
			_setup_fade()
		AppearanceEffect.GRAYSCALE:
			_setup_grayscale()
		AppearanceEffect.DISSOLVE:
			_setup_dissolve()
		AppearanceEffect.COLOR_OVERLAY:
			_setup_overlay()

	# Set up optional blending mode layer
	if use_blend_mode:
		_setup_blend_mode_layer()

	# Reset flicker time
	_flicker_time = 0.0
	_flicker_multiplier = 1.0

	if debug_enabled:
		print("[%s] Appearance3D start: effect=%s, flicker=%s" % [
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
		AppearanceEffect.FADE:
			_apply_fade(effective)
		AppearanceEffect.GRAYSCALE:
			_apply_grayscale(effective)
		AppearanceEffect.DISSOLVE:
			_apply_dissolve(effective)
		AppearanceEffect.COLOR_OVERLAY:
			_apply_color_overlay(effective)
		AppearanceEffect.EMISSION:
			_apply_emission(effective)
		AppearanceEffect.ROUGHNESS:
			_apply_float_property("roughness", effective, true)
		AppearanceEffect.METALLIC:
			_apply_float_property("metallic", effective, true)
		AppearanceEffect.GROW:
			_apply_grow(effective)
		AppearanceEffect.RIM:
			_apply_float_property("rim", effective, true)
		AppearanceEffect.CLEARCOAT:
			_apply_float_property("clearcoat", effective, true)
		AppearanceEffect.REFRACTION:
			_apply_float_property("refraction_scale", effective, false)


func _on_animate_out_complete() -> void:
	# Snap to base state
	_apply_effect(0.0)

	# Clean up resources
	match appearance_effect:
		AppearanceEffect.OUTLINE:
			_teardown_outline()
		AppearanceEffect.FADE:
			_teardown_fade()
		AppearanceEffect.GRAYSCALE:
			_teardown_grayscale()
		AppearanceEffect.DISSOLVE:
			_teardown_dissolve()
		AppearanceEffect.COLOR_OVERLAY:
			_teardown_overlay()

	# Clean up optional blending mode layer
	if _blend_mode_is_setup:
		_teardown_blend_mode_layer()

	if debug_enabled:
		print("[%s] Appearance3D complete, restored to base state" % name)


# =============================================================================
# FLICKER — TEMPORAL MODULATION
# =============================================================================

## Compute effective progress by applying flicker modulation.
func _get_effective_progress(progress: float) -> float:
	if not use_flicker:
		return progress

	_flicker_time += _last_delta

	var multiplier: float = 1.0
	match flicker_mode:
		FlickerMode.RANDOM:
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

	if hard_flicker:
		multiplier = 1.0 if multiplier >= 0.5 else 0.0

	return progress * multiplier


# =============================================================================
# EFFECT IMPLEMENTATIONS
# =============================================================================

# --- TINT (albedo_color) ---

func _apply_tint(progress: float) -> void:
	if not _target_material:
		return
	_target_material.albedo_color = color_from.lerp(color_to, progress)


# --- OVERBRIGHT (emission energy) ---

func _apply_overbright(progress: float) -> void:
	if not _target_material:
		return
	if not _target_material.emission_enabled:
		_target_material.emission_enabled = true
	_target_material.emission = overbright_color
	_target_material.emission_energy_multiplier = lerpf(0.0, overbright_intensity, progress)


# --- OUTLINE (Inverted Hull) ---

func _apply_outline(progress: float) -> void:
	if not _outline_material:
		return
	_outline_material.grow_amount = outline_width * progress
	_outline_material.albedo_color = outline_color


# --- FADE ---

func _apply_fade(progress: float) -> void:
	if not _target_material:
		return
	var new_alpha := lerpf(_base_alpha, fade_target_alpha, progress)
	_target_material.albedo_color.a = new_alpha


# --- GRAYSCALE (next_pass shader) ---

func _apply_grayscale(progress: float) -> void:
	if not _grayscale_shader_material:
		return
	_grayscale_shader_material.set_shader_parameter("amount", grayscale_strength * progress)


# --- DISSOLVE (material_override shader) ---

func _apply_dissolve(progress: float) -> void:
	if not _dissolve_shader_material:
		return
	_dissolve_shader_material.set_shader_parameter("threshold", progress)
	_dissolve_shader_material.set_shader_parameter("edge_color", dissolve_edge_color)
	_dissolve_shader_material.set_shader_parameter("edge_width", dissolve_edge_width)


# --- COLOR_OVERLAY (next_pass shader) ---

func _apply_color_overlay(progress: float) -> void:
	if not _overlay_shader_material:
		return
	_overlay_shader_material.set_shader_parameter("amount", progress)
	# Update overlay color live for inspector tweaking
	_overlay_shader_material.set_shader_parameter("overlay_color", overlay_color)


# --- EMISSION (color) ---

func _apply_emission(progress: float) -> void:
	if not _target_material:
		return
	if not _target_material.emission_enabled:
		_target_material.emission_enabled = true
	_target_material.emission = _base_emission.lerp(emission_color_target, progress)


# --- FLOAT PROPERTIES (ROUGHNESS, METALLIC, RIM, CLEARCOAT, REFRACTION) ---

func _apply_float_property(prop_name: String, progress: float, clamped: bool) -> void:
	if not _target_material:
		return
	var new_val: float = _base_float_value + (float_offset * progress)
	if clamped:
		new_val = clampf(new_val, 0.0, 1.0)
	_target_material.set(prop_name, new_val)


# --- GROW ---

func _apply_grow(progress: float) -> void:
	if not _target_material:
		return
	if not _target_material.grow:
		_target_material.grow = true
	_target_material.grow_amount = _base_float_value + (float_offset * progress)


# =============================================================================
# HELPERS
# =============================================================================

## Whether this effect needs a StandardMaterial3D on the geometry
func _needs_standard_material() -> bool:
	return appearance_effect in [
		AppearanceEffect.TINT, AppearanceEffect.OVERBRIGHT,
		AppearanceEffect.FADE,
		AppearanceEffect.EMISSION, AppearanceEffect.ROUGHNESS,
		AppearanceEffect.METALLIC, AppearanceEffect.GROW,
		AppearanceEffect.RIM, AppearanceEffect.CLEARCOAT,
		AppearanceEffect.REFRACTION,
	]


# =============================================================================
# BASE STATE CAPTURE
# =============================================================================

func _capture_base_state() -> void:
	if _has_base_captured:
		return

	if _target_material:
		_base_albedo = _target_material.albedo_color
		_base_alpha = _target_material.albedo_color.a
		_base_emission = _target_material.emission if _target_material.emission_enabled else Color.BLACK
		_base_emission_energy = _target_material.emission_energy_multiplier

		# Capture the numeric base value for the selected effect
		match appearance_effect:
			AppearanceEffect.ROUGHNESS:
				_base_float_value = _target_material.roughness
			AppearanceEffect.METALLIC:
				_base_float_value = _target_material.metallic
			AppearanceEffect.GROW:
				_base_float_value = _target_material.grow_amount if _target_material.grow else 0.0
			AppearanceEffect.RIM:
				_base_float_value = _target_material.rim if _target_material.rim_enabled else 0.0
			AppearanceEffect.CLEARCOAT:
				_base_float_value = _target_material.clearcoat if _target_material.clearcoat_enabled else 0.0
			AppearanceEffect.REFRACTION:
				_base_float_value = _target_material.refraction_scale if _target_material.refraction_enabled else 0.0

	_has_base_captured = true

	if debug_enabled:
		print("[%s] Captured base: albedo=%s, alpha=%.2f, emission=%s" % [
			name, _base_albedo, _base_alpha, _base_emission])


# =============================================================================
# MATERIAL FINDING
# =============================================================================

## Find and prepare the StandardMaterial3D on the target
func _find_and_prepare_material() -> void:
	_geometry_instance = _find_geometry_instance()
	if not _geometry_instance:
		return

	# Check material_override first
	if _geometry_instance.material_override is StandardMaterial3D:
		_target_material = _ensure_material_unique(
			_geometry_instance.material_override as StandardMaterial3D)
		_geometry_instance.material_override = _target_material
		return

	# For MeshInstance3D, check surface materials
	if _geometry_instance is MeshInstance3D:
		var mesh_inst := _geometry_instance as MeshInstance3D
		if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
			var surface_mat := mesh_inst.get_active_material(0)
			if surface_mat is StandardMaterial3D:
				_target_material = _ensure_material_unique(surface_mat as StandardMaterial3D)
				mesh_inst.material_override = _target_material
				return

	# Fallback: Create a new StandardMaterial3D
	var new_mat := StandardMaterial3D.new()
	_geometry_instance.material_override = new_mat
	_target_material = new_mat
	_is_material_duplicated = true

	if debug_enabled:
		print("[%s] Created new StandardMaterial3D for '%s'" % [name, _geometry_instance.name])


## Find a GeometryInstance3D for 3D nodes
func _find_geometry_instance() -> GeometryInstance3D:
	if not _target_node:
		return null

	# First try the explicit path
	if not geometry_path.is_empty():
		var node := get_node_or_null(geometry_path)
		if node is GeometryInstance3D:
			return node as GeometryInstance3D

	# If target IS a GeometryInstance3D, use it directly
	if _target_node is GeometryInstance3D:
		return _target_node as GeometryInstance3D

	# Search children for first GeometryInstance3D
	for child in _target_node.get_children():
		if child is GeometryInstance3D:
			return child as GeometryInstance3D

	if debug_enabled:
		push_warning("[%s] No GeometryInstance3D found for appearance effect" % name)
	return null


## Ensure the material is unique to avoid affecting other nodes
func _ensure_material_unique(mat: StandardMaterial3D) -> StandardMaterial3D:
	if mat.resource_local_to_scene:
		return mat

	var unique_mat := mat.duplicate() as StandardMaterial3D
	unique_mat.resource_local_to_scene = true
	_is_material_duplicated = true

	if debug_enabled:
		print("[%s] Duplicated shared StandardMaterial3D" % name)

	return unique_mat


# =============================================================================
# OUTLINE SETUP / TEARDOWN (Inverted Hull — 3D-specific)
# =============================================================================

func _setup_outline() -> void:
	if _outline_is_setup:
		return

	_geometry_instance = _find_geometry_instance()
	if not _geometry_instance:
		if debug_enabled:
			push_warning("[%s] No GeometryInstance3D found for outline" % name)
		return

	# Get the main material
	_main_material = _get_main_material()
	if not _main_material:
		if debug_enabled:
			push_warning("[%s] No main material found on '%s'" % [name, _geometry_instance.name])
		return

	# Check for existing Next Pass material
	if _main_material.next_pass is StandardMaterial3D:
		_outline_material = _main_material.next_pass as StandardMaterial3D
	elif auto_create_outline:
		_outline_material = _create_outline_material()
		_main_material.next_pass = _outline_material
		_created_outline_material = true
	else:
		if debug_enabled:
			push_warning("[%s] No Next Pass material and auto_create_outline is false" % name)
		return

	# Start with grow at 0 (invisible outline)
	_outline_material.grow_amount = 0.0
	_outline_is_setup = true

	if debug_enabled:
		print("[%s] Outline (Inverted Hull) set up on '%s'" % [name, _geometry_instance.name])


func _teardown_outline() -> void:
	if _created_outline_material and _main_material:
		_main_material.next_pass = null
		_created_outline_material = false
	_outline_material = null
	_outline_is_setup = false

	if debug_enabled:
		print("[%s] Outline teardown complete" % name)


## Get the main material from the geometry instance (duplicates if shared)
func _get_main_material() -> Material:
	if _geometry_instance.material_override:
		if not _geometry_instance.material_override.resource_local_to_scene:
			var unique := _geometry_instance.material_override.duplicate()
			unique.resource_local_to_scene = true
			_geometry_instance.material_override = unique
		return _geometry_instance.material_override

	if _geometry_instance is MeshInstance3D:
		var mesh_inst := _geometry_instance as MeshInstance3D
		if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
			var surface_mat := mesh_inst.get_active_material(0)
			if surface_mat:
				var unique := surface_mat.duplicate()
				unique.resource_local_to_scene = true
				mesh_inst.material_override = unique
				return unique

	# Fallback: Create a basic material
	var new_mat := StandardMaterial3D.new()
	new_mat.resource_local_to_scene = true
	_geometry_instance.material_override = new_mat
	return new_mat


## Create the outline material with proper settings for Inverted Hull technique
func _create_outline_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_local_to_scene = true
	mat.albedo_color = outline_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.grow = true
	mat.grow_amount = 0.0
	mat.no_depth_test = false
	return mat


# =============================================================================
# BLENDING MODE LAYER SETUP / TEARDOWN (3D)
# =============================================================================

## Apply a BaseMaterial3D blend mode to the target material.
## This is a LAYER — it modifies how the mesh composites with the scene,
## independent of which appearance effect is active.
func _setup_blend_mode_layer() -> void:
	if _blend_mode_is_setup:
		return
	if not _target_material:
		# Need a material for this layer — try to find one
		if not _geometry_instance:
			_geometry_instance = _find_geometry_instance()
		if _geometry_instance:
			_find_and_prepare_material()
		if not _target_material:
			if debug_enabled:
				push_warning("[%s] No StandardMaterial3D for blending mode layer" % name)
			return

	_original_blend_mode = _target_material.blend_mode

	# Set the blend mode
	match target_blend_mode:
		TargetBlendMode.ADD:
			_target_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		TargetBlendMode.SUB:
			_target_material.blend_mode = BaseMaterial3D.BLEND_MODE_SUB
		TargetBlendMode.MUL:
			_target_material.blend_mode = BaseMaterial3D.BLEND_MODE_MUL

	_blend_mode_is_setup = true

	if debug_enabled:
		print("[%s] Blending mode layer %s applied" % [name, TargetBlendMode.keys()[target_blend_mode]])


func _teardown_blend_mode_layer() -> void:
	if not _target_material:
		return

	if _original_blend_mode >= 0:
		_target_material.blend_mode = _original_blend_mode
	_original_blend_mode = -1
	_blend_mode_is_setup = false

	if debug_enabled:
		print("[%s] Blending mode layer restored" % name)


# =============================================================================
# FADE SETUP / TEARDOWN (3D — needs transparency enabled)
# =============================================================================

func _setup_fade() -> void:
	if not _target_material:
		return

	_original_transparency = _target_material.transparency
	if _target_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		_target_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	if debug_enabled:
		print("[%s] Fade: transparency enabled on material" % name)


func _teardown_fade() -> void:
	if not _target_material:
		return

	if _original_transparency >= 0:
		_target_material.transparency = _original_transparency
		_original_transparency = -1
	_target_material.albedo_color.a = _base_alpha

	if debug_enabled:
		print("[%s] Fade: transparency restored" % name)


# =============================================================================
# GRAYSCALE SETUP / TEARDOWN (next_pass shader — 3D)
# =============================================================================

func _get_grayscale_shader() -> Shader:
	if _grayscale_shader == null:
		_grayscale_shader = load("res://addons/juice/Shaders/grayscale_3d.gdshader")
	return _grayscale_shader


func _setup_grayscale() -> void:
	if _grayscale_is_setup:
		return

	_geometry_instance = _find_geometry_instance()
	if not _geometry_instance:
		return

	# Get main material for next_pass
	_main_material = _get_main_material()
	if not _main_material:
		return

	# Save original next_pass
	_original_next_pass = _main_material.next_pass

	# Create grayscale shader as next_pass
	_grayscale_shader_material = ShaderMaterial.new()
	_grayscale_shader_material.shader = _get_grayscale_shader()
	_grayscale_shader_material.set_shader_parameter("amount", 0.0)
	_main_material.next_pass = _grayscale_shader_material
	_grayscale_is_setup = true

	if debug_enabled:
		print("[%s] Grayscale next_pass shader applied to '%s'" % [name, _geometry_instance.name])


func _teardown_grayscale() -> void:
	if _main_material and _grayscale_is_setup:
		_main_material.next_pass = _original_next_pass
		_original_next_pass = null
	_grayscale_shader_material = null
	_grayscale_is_setup = false

	if debug_enabled:
		print("[%s] Grayscale next_pass removed" % name)


# =============================================================================
# DISSOLVE SETUP / TEARDOWN (material_override shader — 3D)
# =============================================================================

func _get_dissolve_shader() -> Shader:
	if _dissolve_shader == null:
		_dissolve_shader = load("res://addons/juice/Shaders/dissolve_3d.gdshader")
	return _dissolve_shader


func _setup_dissolve() -> void:
	if _dissolve_is_setup:
		return

	_geometry_instance = _find_geometry_instance()
	if not _geometry_instance:
		return

	# Save original material_override
	_original_material_override = _geometry_instance.material_override

	# Capture albedo info from existing material for the dissolve shader
	var albedo_color := Color.WHITE
	var albedo_texture: Texture2D = null
	if _original_material_override is StandardMaterial3D:
		var std := _original_material_override as StandardMaterial3D
		albedo_color = std.albedo_color
		albedo_texture = std.albedo_texture
	elif _geometry_instance is MeshInstance3D:
		var mesh_inst := _geometry_instance as MeshInstance3D
		if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
			var surface_mat := mesh_inst.get_active_material(0)
			if surface_mat is StandardMaterial3D:
				var std := surface_mat as StandardMaterial3D
				albedo_color = std.albedo_color
				albedo_texture = std.albedo_texture

	# Auto-create noise texture if user didn't provide one
	var noise_tex := dissolve_texture
	if noise_tex == null:
		noise_tex = NoiseTexture2D.new()
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.05
		noise_tex.noise = noise

	_dissolve_shader_material = ShaderMaterial.new()
	_dissolve_shader_material.shader = _get_dissolve_shader()
	_dissolve_shader_material.set_shader_parameter("threshold", 0.0)
	_dissolve_shader_material.set_shader_parameter("dissolve_noise", noise_tex)
	_dissolve_shader_material.set_shader_parameter("edge_color", dissolve_edge_color)
	_dissolve_shader_material.set_shader_parameter("edge_width", dissolve_edge_width)
	_dissolve_shader_material.set_shader_parameter("albedo_color", albedo_color)
	if albedo_texture:
		_dissolve_shader_material.set_shader_parameter("albedo_texture", albedo_texture)

	_geometry_instance.material_override = _dissolve_shader_material
	_dissolve_is_setup = true

	if debug_enabled:
		print("[%s] Dissolve shader applied as material_override on '%s'" % [
			name, _geometry_instance.name])


func _teardown_dissolve() -> void:
	if _geometry_instance and _dissolve_is_setup:
		_geometry_instance.material_override = _original_material_override
		_original_material_override = null
	_dissolve_shader_material = null
	_dissolve_is_setup = false

	if debug_enabled:
		print("[%s] Dissolve shader removed, original material restored" % name)


# =============================================================================
# COLOR_OVERLAY SETUP / TEARDOWN (next_pass shader — 3D)
# =============================================================================

func _get_overlay_shader() -> Shader:
	if _overlay_shader == null:
		_overlay_shader = load("res://addons/juice/Shaders/overlay_3d.gdshader")
	return _overlay_shader


func _setup_overlay() -> void:
	if _overlay_is_setup:
		return

	_geometry_instance = _find_geometry_instance()
	if not _geometry_instance:
		return

	# Get main material for next_pass
	_main_material = _get_main_material()
	if not _main_material:
		return

	# Save original next_pass
	_overlay_original_next_pass = _main_material.next_pass

	# Create overlay shader as next_pass
	_overlay_shader_material = ShaderMaterial.new()
	_overlay_shader_material.shader = _get_overlay_shader()
	_overlay_shader_material.set_shader_parameter("amount", 0.0)
	_overlay_shader_material.set_shader_parameter("overlay_color", overlay_color)
	_main_material.next_pass = _overlay_shader_material
	_overlay_is_setup = true

	if debug_enabled:
		print("[%s] Color overlay next_pass shader applied to '%s'" % [name, _geometry_instance.name])


func _teardown_overlay() -> void:
	if _main_material and _overlay_is_setup:
		_main_material.next_pass = _overlay_original_next_pass
		_overlay_original_next_pass = null
	_overlay_shader_material = null
	_overlay_is_setup = false

	if debug_enabled:
		print("[%s] Color overlay next_pass removed" % name)


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()

	if parent and not parent is Node3D:
		warnings.append("Target must be a Node3D with a GeometryInstance3D. Use Appearance2D/Control for 2D/UI nodes.")

	if appearance_effect == AppearanceEffect.TINT:
		if color_from == color_to:
			warnings.append("color_from and color_to are identical — animation will have no visible effect.")

	if appearance_effect == AppearanceEffect.DISSOLVE:
		warnings.append("DISSOLVE replaces material_override during animation. Any existing material_override will be temporarily removed.")

	return warnings
