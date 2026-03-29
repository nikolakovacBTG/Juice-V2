## AppearanceControlJuiceEffect.gd
## ============================================================================
## WHAT: Animates visual appearance properties of Control (UI) node targets.
##       Supports modulate-based effects (TINT, FADE, OVERBRIGHT) and
##       shader-based effects (OUTLINE, GRAYSCALE, BLEND_MODE, DISSOLVE).
## WHY: Control domain equivalent of Appearance2DJuiceEffect. Centralizes
##      UI appearance animation in one V1 Resource effect.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Handle Node2D or Node3D targets — use Appearance2D/3DJuiceEffect.
## DOES NOT: Animate position/rotation/scale — use TransformControlJuiceEffect.
## ============================================================================
#
# WRITE PATTERN: Controlled deviation — writes directly to target.modulate
#   and target.material. Control inherits CanvasItem so modulate and material
#   work identically to Node2D. Multiple Appearance effects on the same target
#   will fight on color — documented limitation.
#
# SHADER PARAMETER NAMES (same shaders as 2D domain — reused for Control):
#   outline_2d:    outline_color (Color), outline_width (float)
#   grayscale_2d:  amount (float)
#   dissolve_2d:   dissolve_texture (Texture2D), edge_color (Color),
#                  edge_width (float), threshold (float)
#
# FLICKER: Duplicated per-domain per design doc (no shared intermediate base).
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseControl.svg")
class_name AppearanceControlJuiceEffect
extends JuiceControlEffectBase


# =============================================================================
# ENUMS
# =============================================================================

enum AppearanceEffect {
	TINT,       ## Multiply modulate with a color overlay
	FADE,       ## Animate modulate alpha to a target value
	OVERBRIGHT, ## Boost brightness above 1.0 via modulate
	OUTLINE,    ## Add colored outline via outline_2d.gdshader
	BLEND_MODE, ## Change CanvasItem blend mode (CanvasItemMaterial)
	GRAYSCALE,  ## Desaturate via grayscale_2d.gdshader
	DISSOLVE,   ## Dissolve out via dissolve_2d.gdshader noise threshold
}

enum FlickerMode {
	NONE,
	RANDOM,
	CUSTOM,
}


# =============================================================================
# CONFIGURATION
# =============================================================================

var effect_type: int = AppearanceEffect.FADE:
	set(value):
		effect_type = value
		notify_property_list_changed()

## Color to tint toward at peak progress (TINT).
var tint_color: Color = Color(1.0, 0.4, 0.4, 1.0)
## Tint blend strength 0=none, 1=full (TINT).
var tint_blend: float = 1.0
## Target alpha at progress=1.0 (FADE).
var fade_target_alpha: float = 0.0
## Modulate multiplier at peak (OVERBRIGHT). 2.0 = double brightness.
var overbright_strength: float = 2.0
## Outline stroke color (OUTLINE).
var outline_color: Color = Color.WHITE
## Outline pixel width at full effect (OUTLINE).
var outline_width: float = 2.0
## Target blend mode (BLEND_MODE). 1=Add, 2=Sub, 3=Mul.
var blend_mode_target: int = CanvasItemMaterial.BLEND_MODE_ADD
## Fade alpha 0->natural alongside blend mode (BLEND_MODE).
var blend_fade_in: bool = true
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
		"hint_string": "Tint,Fade,Overbright,Outline,Blend Mode,Grayscale,Dissolve",
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
		AppearanceEffect.OVERBRIGHT:
			props.append({"name": "overbright_strength", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "1.0,10.0,0.1,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		AppearanceEffect.OUTLINE:
			props.append({"name": "outline_color", "type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "outline_width", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.5,20.0,0.5,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		AppearanceEffect.BLEND_MODE:
			props.append({"name": "blend_mode_target", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Mix,Add,Sub,Mul,Premult Alpha",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "blend_fade_in", "type": TYPE_BOOL,
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
		&"tint_color": tint_color = value; return true
		&"tint_blend": tint_blend = value; return true
		&"fade_target_alpha": fade_target_alpha = value; return true
		&"overbright_strength": overbright_strength = value; return true
		&"outline_color": outline_color = value; return true
		&"outline_width": outline_width = value; return true
		&"blend_mode_target": blend_mode_target = value; return true
		&"blend_fade_in": blend_fade_in = value; return true
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
		&"tint_color": return tint_color
		&"tint_blend": return tint_blend
		&"fade_target_alpha": return fade_target_alpha
		&"overbright_strength": return overbright_strength
		&"outline_color": return outline_color
		&"outline_width": return outline_width
		&"blend_mode_target": return blend_mode_target
		&"blend_fade_in": return blend_fade_in
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

var _natural_modulate: Color = Color.WHITE
var _natural_material: Material = null
var _has_natural: bool = false
var _active_material: Material = null
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
	var ctrl := target as Control
	if ctrl == null:
		return

	if not _has_natural:
		_natural_modulate = ctrl.modulate
		_natural_material = ctrl.material
		_has_natural = true

	_flicker_time = 0.0
	_setup_flicker_noise()

	match effect_type:
		AppearanceEffect.OUTLINE:
			var mat := _create_shader_material("res://addons/Juice_V1/Shaders/outline_2d.gdshader")
			if mat:
				mat.set_shader_parameter("outline_color", outline_color)
				mat.set_shader_parameter("outline_width", 0.0)
				_install_material(ctrl, mat)
		AppearanceEffect.GRAYSCALE:
			var mat := _create_shader_material("res://addons/Juice_V1/Shaders/grayscale_2d.gdshader")
			if mat:
				mat.set_shader_parameter("amount", 0.0)
				_install_material(ctrl, mat)
		AppearanceEffect.DISSOLVE:
			var mat := _create_shader_material("res://addons/Juice_V1/Shaders/dissolve_2d.gdshader")
			if mat:
				var tex := dissolve_texture if dissolve_texture != null else _get_or_create_dissolve_texture()
				mat.set_shader_parameter("dissolve_texture", tex)
				mat.set_shader_parameter("edge_color", dissolve_edge_color)
				mat.set_shader_parameter("edge_width", dissolve_edge_width)
				mat.set_shader_parameter("threshold", 0.0)
				_install_material(ctrl, mat)
		AppearanceEffect.BLEND_MODE:
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = blend_mode_target as CanvasItemMaterial.BlendMode
			_install_material(ctrl, mat)

	if debug_enabled:
		print("[AppearanceControl] Start: %s, flicker=%s" % [
			AppearanceEffect.keys()[effect_type],
			FlickerMode.keys()[flicker_mode]])


func _apply_effect(progress: float, target: Node) -> void:
	_advance_flicker_time()
	var p := _get_effective_progress(progress)

	var ctrl := target as Control
	if ctrl == null or not _has_natural:
		return

	match effect_type:
		AppearanceEffect.TINT:
			var blended := lerp(Color.WHITE, tint_color, tint_blend * p)
			ctrl.modulate = Color(
				_natural_modulate.r * blended.r,
				_natural_modulate.g * blended.g,
				_natural_modulate.b * blended.b,
				_natural_modulate.a)

		AppearanceEffect.FADE:
			var new_mod := _natural_modulate
			new_mod.a = lerpf(_natural_modulate.a, fade_target_alpha, p)
			ctrl.modulate = new_mod

		AppearanceEffect.OVERBRIGHT:
			var boost := lerpf(1.0, overbright_strength, p)
			ctrl.modulate = Color(
				_natural_modulate.r * boost,
				_natural_modulate.g * boost,
				_natural_modulate.b * boost,
				_natural_modulate.a)

		AppearanceEffect.OUTLINE:
			var mat := _active_material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("outline_width", outline_width * p)

		AppearanceEffect.BLEND_MODE:
			if blend_fade_in:
				var new_mod := _natural_modulate
				new_mod.a = lerpf(0.0, _natural_modulate.a, p)
				ctrl.modulate = new_mod

		AppearanceEffect.GRAYSCALE:
			var mat := _active_material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("amount", grayscale_amount * p)

		AppearanceEffect.DISSOLVE:
			var mat := _active_material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("threshold", p)


func _on_animate_out_complete(_target: Node) -> void:
	pass


func _restore_to_natural(target: Node) -> void:
	if not _has_natural:
		return
	var ctrl := target as Control
	if ctrl == null:
		return
	ctrl.modulate = _natural_modulate
	if _active_material != null:
		ctrl.material = _natural_material
		_active_material = null
	_has_natural = false
	_flicker_time = 0.0


func _invalidate_base_cache() -> void:
	_has_natural = false
	_active_material = null


func _temporarily_undo_visual(target: Node) -> void:
	if not _has_natural:
		return
	var ctrl := target as Control
	if ctrl == null:
		return
	ctrl.modulate = _natural_modulate
	if _active_material != null:
		ctrl.material = _natural_material


func _temporarily_reapply_visual(target: Node) -> void:
	if not _has_natural:
		return
	var ctrl := target as Control
	if ctrl != null and _active_material != null:
		ctrl.material = _active_material
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
# SHADER / MATERIAL HELPERS
# =============================================================================

func _create_shader_material(shader_path: String) -> ShaderMaterial:
	var shader := load(shader_path) as Shader
	if shader == null:
		push_warning("[AppearanceControl] Shader not found: %s" % shader_path)
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _install_material(ctrl: Control, mat: Material) -> void:
	_active_material = mat
	ctrl.material = mat


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
