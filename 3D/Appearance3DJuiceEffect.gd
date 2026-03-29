## Appearance3DJuiceEffect.gd
## ============================================================================
## WHAT: Animates visual appearance properties of Node3D targets.
##       Supports material-based effects (TINT, FADE, OVERBRIGHT, EMISSION,
##       ROUGHNESS, METALLIC) and shader-based effects (GRAYSCALE, DISSOLVE).
## WHY: 3D domain equivalent of Appearance2DJuiceEffect.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Handle Control or Node2D targets — use AppearanceControl/2DJuiceEffect.
## DOES NOT: Animate position/rotation/scale — use Transform3DJuiceEffect.
## ============================================================================
#
# WRITE PATTERN: Controlled deviation. Node3D has no .modulate shortcut.
#   Finds the first MeshInstance3D child (or self if target is MeshInstance3D)
#   and manipulates its surface override material.
#
# MATERIAL STRATEGY:
#   - TINT/FADE/OVERBRIGHT/EMISSION/ROUGHNESS/METALLIC:
#       Duplicate surface material as StandardMaterial3D, animate properties.
#   - GRAYSCALE/DISSOLVE:
#       Install ShaderMaterial on surface override slot.
#   On _restore_to_natural(): original surface override is reinstated.
#
# SHADER PARAMETER NAMES (verified against shader files):
#   grayscale_3d:  amount (float)
#   dissolve_3d:   dissolve_texture (Texture2D), edge_color (Color),
#                  edge_width (float), threshold (float)
#
# FLICKER: Duplicated per-domain per design doc (no shared intermediate base).
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Appearance3DJuiceEffect
extends Juice3DEffectBase


# =============================================================================
# ENUMS
# =============================================================================

enum AppearanceEffect {
	TINT,       ## Blend albedo toward a tint color
	FADE,       ## Animate material alpha (enables transparency automatically)
	OVERBRIGHT, ## Boost emission to simulate an overbright flash
	EMISSION,   ## Animate emission color and energy
	ROUGHNESS,  ## Animate surface roughness (0=mirror, 1=matte)
	METALLIC,   ## Animate surface metallic value (0=dielectric, 1=metal)
	GRAYSCALE,  ## Desaturate via grayscale_3d.gdshader
	DISSOLVE,   ## Dissolve out via dissolve_3d.gdshader noise threshold
}

enum FlickerMode {
	NONE,
	RANDOM,
	CUSTOM,
}


# =============================================================================
# CONFIGURATION
# =============================================================================

var effect_type: int = AppearanceEffect.TINT:
	set(value):
		effect_type = value
		notify_property_list_changed()

## Surface index on MeshInstance3D to target (0 = first surface).
var mesh_surface_index: int = 0

## Tint color blended into albedo at peak (TINT).
var tint_color: Color = Color(1.0, 0.4, 0.4, 1.0)
## Tint blend strength 0=none, 1=full (TINT).
var tint_blend: float = 1.0
## Target alpha at progress=1.0 (FADE). Enables TRANSPARENCY_ALPHA automatically.
var fade_target_alpha: float = 0.0
## Emission color for overbright/emission flash (OVERBRIGHT/EMISSION).
var emission_color: Color = Color(1.0, 0.8, 0.2, 1.0)
## Emission energy multiplier at peak (OVERBRIGHT/EMISSION).
var emission_energy: float = 2.0
## Target roughness at progress=1.0 (ROUGHNESS).
var roughness_target: float = 0.0
## Target metallic at progress=1.0 (METALLIC).
var metallic_target: float = 1.0
## Desaturation at peak 0.0=color, 1.0=gray (GRAYSCALE).
var grayscale_amount: float = 1.0
## Noise texture for dissolve. Auto-created if null (DISSOLVE).
var dissolve_texture: NoiseTexture2D
## Edge glow color at dissolve boundary (DISSOLVE).
var dissolve_edge_color: Color = Color(1.0, 0.5, 0.0, 1.0)
## Edge band width in noise space (DISSOLVE).
var dissolve_edge_width: float = 0.05

var flicker_mode: int = FlickerMode.NONE:
	set(value):
		flicker_mode = value
		notify_property_list_changed()
var flicker_min: float = 0.0
var flicker_max: float = 1.0
var hard_flicker: bool = false
var flicker_rate: float = 10.0
var flicker_curve: Curve


func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "effect_type", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Tint,Fade,Overbright,Emission,Roughness,Metallic,Grayscale,Dissolve",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append({"name": "mesh_surface_index", "type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE, "hint_string": "0,8,1",
		"usage": PROPERTY_USAGE_DEFAULT})

	match effect_type:
		AppearanceEffect.TINT:
			props.append({"name": "tint_color", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "tint_blend", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		AppearanceEffect.FADE:
			props.append({"name": "fade_target_alpha", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		AppearanceEffect.OVERBRIGHT, AppearanceEffect.EMISSION:
			props.append({"name": "emission_color", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "emission_energy", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.1,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		AppearanceEffect.ROUGHNESS:
			props.append({"name": "roughness_target", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		AppearanceEffect.METALLIC:
			props.append({"name": "metallic_target", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT})
		AppearanceEffect.GRAYSCALE:
			props.append({"name": "grayscale_amount", "type": TYPE_FLOAT,
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

	props.append_array(_get_effect_base_properties())

	props.append({"name": "Flicker", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP, "hint_string": ""})
	props.append({"name": "flicker_mode", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "None,Random,Custom",
		"usage": PROPERTY_USAGE_DEFAULT})
	if flicker_mode != FlickerMode.NONE:
		props.append({"name": "flicker_min", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "flicker_max", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
			"usage": PROPERTY_USAGE_DEFAULT})
		props.append({"name": "hard_flicker", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})
		if flicker_mode == FlickerMode.RANDOM:
			props.append({"name": "flicker_rate", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,60.0,0.1,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		elif flicker_mode == FlickerMode.CUSTOM:
			props.append({"name": "flicker_curve", "type": TYPE_OBJECT,
				"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Curve",
				"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"effect_type": effect_type = value; return true
		&"mesh_surface_index": mesh_surface_index = value; return true
		&"tint_color": tint_color = value; return true
		&"tint_blend": tint_blend = value; return true
		&"fade_target_alpha": fade_target_alpha = value; return true
		&"emission_color": emission_color = value; return true
		&"emission_energy": emission_energy = value; return true
		&"roughness_target": roughness_target = value; return true
		&"metallic_target": metallic_target = value; return true
		&"grayscale_amount": grayscale_amount = value; return true
		&"dissolve_texture": dissolve_texture = value; return true
		&"dissolve_edge_color": dissolve_edge_color = value; return true
		&"dissolve_edge_width": dissolve_edge_width = value; return true
		&"flicker_mode": flicker_mode = value; return true
		&"flicker_rate": flicker_rate = value; return true
		&"flicker_min": flicker_min = value; return true
		&"flicker_max": flicker_max = value; return true
		&"hard_flicker": hard_flicker = value; return true
		&"flicker_curve": flicker_curve = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"effect_type": return effect_type
		&"mesh_surface_index": return mesh_surface_index
		&"tint_color": return tint_color
		&"tint_blend": return tint_blend
		&"fade_target_alpha": return fade_target_alpha
		&"emission_color": return emission_color
		&"emission_energy": return emission_energy
		&"roughness_target": return roughness_target
		&"metallic_target": return metallic_target
		&"grayscale_amount": return grayscale_amount
		&"dissolve_texture": return dissolve_texture
		&"dissolve_edge_color": return dissolve_edge_color
		&"dissolve_edge_width": return dissolve_edge_width
		&"flicker_mode": return flicker_mode
		&"flicker_rate": return flicker_rate
		&"flicker_min": return flicker_min
		&"flicker_max": return flicker_max
		&"hard_flicker": return hard_flicker
		&"flicker_curve": return flicker_curve
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Captured natural (pre-effect) material values.
var _natural_albedo: Color = Color.WHITE
var _natural_alpha: float = 1.0
var _natural_emission_enabled: bool = false
var _natural_emission_color: Color = Color.BLACK
var _natural_emission_energy: float = 1.0
var _natural_roughness: float = 0.5
var _natural_metallic: float = 0.0
var _natural_surface_material: Material = null  # Original surface override (may be null).
var _has_natural: bool = false

var _working_material: StandardMaterial3D = null  # Duplicated for property animation.
var _active_shader_material: ShaderMaterial = null  # For GRAYSCALE/DISSOLVE.
var _cached_mesh: MeshInstance3D = null
var _auto_dissolve_texture: NoiseTexture2D = null
var _tick_delta: float = 0.0
var _flicker_time: float = 0.0
var _flicker_noise: FastNoiseLite = null


# =============================================================================
# TICK OVERRIDE
# =============================================================================

func tick(delta: float, target: Node) -> TickResult:
	_tick_delta = delta
	return super.tick(delta, target)


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _on_animate_start(target: Node) -> void:
	_cached_mesh = _find_mesh(target)
	if _cached_mesh == null:
		push_warning("[Appearance3D] No MeshInstance3D found on '%s'. Effect will not apply." % target.name)
		return

	if not _has_natural:
		_capture_natural_state(_cached_mesh)
		_has_natural = true

	_flicker_time = 0.0
	_setup_flicker_noise()

	match effect_type:
		AppearanceEffect.TINT, AppearanceEffect.FADE, AppearanceEffect.OVERBRIGHT, \
		AppearanceEffect.EMISSION, AppearanceEffect.ROUGHNESS, AppearanceEffect.METALLIC:
			_setup_working_material(_cached_mesh)
		AppearanceEffect.GRAYSCALE:
			var mat := _create_shader_material("res://addons/Juice_V1/Shaders/grayscale_3d.gdshader")
			if mat:
				mat.set_shader_parameter("amount", 0.0)
				_active_shader_material = mat
				_cached_mesh.set_surface_override_material(mesh_surface_index, mat)
		AppearanceEffect.DISSOLVE:
			var mat := _create_shader_material("res://addons/Juice_V1/Shaders/dissolve_3d.gdshader")
			if mat:
				var tex := dissolve_texture if dissolve_texture != null else _get_or_create_dissolve_texture()
				mat.set_shader_parameter("dissolve_texture", tex)
				mat.set_shader_parameter("edge_color", dissolve_edge_color)
				mat.set_shader_parameter("edge_width", dissolve_edge_width)
				mat.set_shader_parameter("threshold", 0.0)
				_active_shader_material = mat
				_cached_mesh.set_surface_override_material(mesh_surface_index, mat)

	if debug_enabled:
		print("[Appearance3D] Start: %s on mesh: %s" % [
			AppearanceEffect.keys()[effect_type],
			_cached_mesh.name])


func _apply_effect(progress: float, _target: Node) -> void:
	_advance_flicker_time()
	var p := _get_effective_progress(progress)

	if not _has_natural or _cached_mesh == null:
		return

	match effect_type:
		AppearanceEffect.TINT:
			if _working_material:
				var blended := lerp(Color.WHITE, tint_color, tint_blend * p)
				_working_material.albedo_color = Color(
					_natural_albedo.r * blended.r,
					_natural_albedo.g * blended.g,
					_natural_albedo.b * blended.b,
					_natural_albedo.a)

		AppearanceEffect.FADE:
			if _working_material:
				_working_material.albedo_color.a = lerpf(_natural_alpha, fade_target_alpha, p)

		AppearanceEffect.OVERBRIGHT:
			# Simulate overbright: animate emission toward albedo color at high energy.
			if _working_material:
				_working_material.emission_enabled = true
				_working_material.emission = _natural_albedo
				_working_material.emission_energy_multiplier = lerpf(0.0, emission_energy, p)

		AppearanceEffect.EMISSION:
			if _working_material:
				_working_material.emission_enabled = true
				_working_material.emission = emission_color
				_working_material.emission_energy_multiplier = lerpf(0.0, emission_energy, p)

		AppearanceEffect.ROUGHNESS:
			if _working_material:
				_working_material.roughness = lerpf(_natural_roughness, roughness_target, p)

		AppearanceEffect.METALLIC:
			if _working_material:
				_working_material.metallic = lerpf(_natural_metallic, metallic_target, p)

		AppearanceEffect.GRAYSCALE:
			if _active_shader_material:
				_active_shader_material.set_shader_parameter("amount", grayscale_amount * p)

		AppearanceEffect.DISSOLVE:
			if _active_shader_material:
				_active_shader_material.set_shader_parameter("threshold", p)


func _on_animate_out_complete(_target: Node) -> void:
	pass


func _restore_to_natural(target: Node) -> void:
	if not _has_natural:
		return
	var mesh := _cached_mesh if _cached_mesh != null else _find_mesh(target)
	if mesh == null:
		return

	# Reinstate the original surface override (null = mesh uses its own material).
	mesh.set_surface_override_material(mesh_surface_index, _natural_surface_material)
	_working_material = null
	_active_shader_material = null
	_has_natural = false
	_flicker_time = 0.0


func _invalidate_base_cache() -> void:
	_has_natural = false
	_cached_mesh = null
	_working_material = null
	_active_shader_material = null


func _temporarily_undo_visual(_target: Node) -> void:
	if not _has_natural or _cached_mesh == null:
		return
	_cached_mesh.set_surface_override_material(mesh_surface_index, _natural_surface_material)


func _temporarily_reapply_visual(target: Node) -> void:
	if not _has_natural or _cached_mesh == null:
		return
	var mat: Material = _working_material if _working_material != null else _active_shader_material
	if mat != null:
		_cached_mesh.set_surface_override_material(mesh_surface_index, mat)
	_apply_effect(_animation_progress, target)


func _get_interrupt_identity() -> Variant:
	return [get_script(), effect_type]


# =============================================================================
# FLICKER SYSTEM
# =============================================================================

func _get_effective_progress(progress: float) -> float:
	if flicker_mode == FlickerMode.NONE or progress <= 0.0:
		return progress
	var multiplier: float = 1.0
	match flicker_mode:
		FlickerMode.RANDOM:
			if _flicker_noise != null:
				var raw := (_flicker_noise.get_noise_1d(_flicker_time * flicker_rate) + 1.0) * 0.5
				multiplier = lerpf(flicker_min, flicker_max, raw)
		FlickerMode.CUSTOM:
			if flicker_curve != null:
				var phase := fmod(_flicker_time * flicker_rate, 1.0)
				multiplier = lerpf(flicker_min, flicker_max, flicker_curve.sample(phase))
	if hard_flicker:
		multiplier = 1.0 if multiplier >= (flicker_min + flicker_max) * 0.5 else 0.0
	return progress * multiplier


func _advance_flicker_time() -> void:
	if flicker_mode != FlickerMode.NONE:
		_flicker_time += _tick_delta


func _setup_flicker_noise() -> void:
	if flicker_mode == FlickerMode.RANDOM and _flicker_noise == null:
		_flicker_noise = FastNoiseLite.new()
		_flicker_noise.seed = randi()
		_flicker_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH


# =============================================================================
# MESH / MATERIAL HELPERS
# =============================================================================

## Find first MeshInstance3D child, or return target itself if it is one.
func _find_mesh(target: Node) -> MeshInstance3D:
	if target is MeshInstance3D:
		return target as MeshInstance3D
	for child in target.get_children():
		if child is MeshInstance3D:
			return child as MeshInstance3D
	return null


func _capture_natural_state(mesh: MeshInstance3D) -> void:
	_natural_surface_material = mesh.get_surface_override_material(mesh_surface_index)

	# Read material properties for per-property effects.
	var base_mat: Material = _natural_surface_material
	if base_mat == null and mesh.mesh != null and mesh_surface_index < mesh.mesh.get_surface_count():
		base_mat = mesh.mesh.surface_get_material(mesh_surface_index)

	if base_mat is StandardMaterial3D:
		var std := base_mat as StandardMaterial3D
		_natural_albedo = std.albedo_color
		_natural_alpha = std.albedo_color.a
		_natural_emission_enabled = std.emission_enabled
		_natural_emission_color = std.emission
		_natural_emission_energy = std.emission_energy_multiplier
		_natural_roughness = std.roughness
		_natural_metallic = std.metallic
	else:
		# Non-StandardMaterial3D or null: use safe defaults.
		_natural_albedo = Color.WHITE
		_natural_alpha = 1.0
		_natural_roughness = 0.5
		_natural_metallic = 0.0


func _setup_working_material(mesh: MeshInstance3D) -> void:
	# Duplicate existing material or create a fresh StandardMaterial3D.
	var base_mat: Material = _natural_surface_material
	if base_mat == null and mesh.mesh != null and mesh_surface_index < mesh.mesh.get_surface_count():
		base_mat = mesh.mesh.surface_get_material(mesh_surface_index)

	if base_mat is StandardMaterial3D:
		_working_material = (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		var new_mat := StandardMaterial3D.new()
		new_mat.albedo_color = _natural_albedo
		new_mat.roughness = _natural_roughness
		new_mat.metallic = _natural_metallic
		_working_material = new_mat

	# FADE requires transparency to be enabled.
	if effect_type == AppearanceEffect.FADE:
		_working_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	mesh.set_surface_override_material(mesh_surface_index, _working_material)


func _create_shader_material(shader_path: String) -> ShaderMaterial:
	var shader := load(shader_path) as Shader
	if shader == null:
		push_warning("[Appearance3D] Shader not found: %s" % shader_path)
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _get_or_create_dissolve_texture() -> NoiseTexture2D:
	if _auto_dissolve_texture == null:
		_auto_dissolve_texture = NoiseTexture2D.new()
		_auto_dissolve_texture.width = 256
		_auto_dissolve_texture.height = 256
		var noise := FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.5
		_auto_dissolve_texture.noise = noise
	return _auto_dissolve_texture


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if effect_type == AppearanceEffect.DISSOLVE and dissolve_texture == null:
		warnings.append("No dissolve_texture set — a 256x256 NoiseTexture2D will be auto-created at runtime.")
	if flicker_mode == FlickerMode.CUSTOM and flicker_curve == null:
		warnings.append("Flicker mode is Custom but no flicker_curve is assigned. Flicker will not apply.")
	if flicker_min > flicker_max:
		warnings.append("flicker_min is greater than flicker_max.")
	return warnings
