## Animates visual appearance properties (tint, fade, overbright, outline) of [Node2D] targets.
## ============================================================================
## WHAT: Animates visual appearance properties of Node2D targets.
##       Modulate effects (TINT, FADE, OVERBRIGHT) contribute a multiplicative
##       _modulate_factor; Juice2D accumulates all factors and writes once.
##       OUTLINE installs a ShaderMaterial on target.material (separate slot).
## WHY: Correct V1 stackable architecture — effects do not write to target
##      directly; the domain node owns the single write per channel per frame.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Handle Control or Node3D targets — use AppearanceControl/3DJuiceEffect.
## DOES NOT: Animate position/rotation/scale — use Transform2DJuiceEffect.
## ============================================================================
#
# SHADER PARAMETER NAMES:
#   outline_2d:  outline_color (Color), outline_width (float)
#
# FLICKER: Optional temporal modulation applied on top of animation progress.
#   RANDOM uses FastNoiseLite. CUSTOM uses a Curve. hard_flicker = binary on/off.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase2D.svg")
class_name Appearance2DJuiceEffect
extends Juice2DAppearanceEffect


# =============================================================================
# ENUMS
# =============================================================================

enum AppearanceEffect {
	TINT,       ## Multiply modulate with a color overlay
	FADE,       ## Animate modulate alpha to a target value
	OVERBRIGHT, ## Boost brightness above 1.0 via modulate
	OUTLINE,    ## Add colored outline via outline_2d.gdshader
}

enum FlickerMode {
	NONE,   ## No flicker — progress passes through unmodified
	RANDOM, ## FastNoiseLite-driven flicker
	CUSTOM, ## Curve-driven flicker pattern
}


# =============================================================================
# CONFIGURATION
# =============================================================================

var effect_type: int = AppearanceEffect.FADE:
	set(value):
		effect_type = value
		notify_property_list_changed()

## Color to tint toward at peak progress (TINT). Multiplied with natural modulate.
var tint_color: Color = Color(1.0, 0.4, 0.4, 1.0)
## How strongly to blend toward tint_color at progress=1.0 (TINT).
var tint_blend: float = 1.0
## Target alpha at progress=1.0 (FADE). Natural alpha restored at progress=0.
var fade_target_alpha: float = 0.0
## Modulate multiplier at peak (OVERBRIGHT). 2.0 = double brightness.
var overbright_strength: float = 2.0
## Outline stroke color (OUTLINE).
var outline_color: Color = Color.WHITE
## Outline pixel width at full effect (OUTLINE).
var outline_width: float = 2.0

## Temporal modulation applied on top of animation progress.
var flicker_mode: int = FlickerMode.NONE:
	set(value):
		flicker_mode = value
		notify_property_list_changed()
## Minimum flicker multiplier (0.0 = fully off at flicker minimum).
var flicker_min: float = 0.0
## Maximum flicker multiplier (1.0 = no dimming at flicker maximum).
var flicker_max: float = 1.0
## Binary on/off flicker instead of smooth. Threshold = (min+max)/2.
var hard_flicker: bool = false
## Flicker cycles per second (RANDOM mode).
var flicker_rate: float = 10.0
## Curve for flicker pattern (CUSTOM mode). X=phase [0,1], Y=multiplier.
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
		"hint_string": "Tint,Fade,Overbright,Outline",
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

# Only needed for OUTLINE (which installs a ShaderMaterial on target.material).
# Modulate effects (TINT/FADE/OVERBRIGHT) use _modulate_factor from the intermediate.
var _natural_material: Material = null
var _has_natural: bool = false
var _active_material: Material = null  # Material we installed — tracked so restore doesn't clobber user materials.
var _tick_delta: float = 0.0
var _flicker_time: float = 0.0
var _flicker_noise: FastNoiseLite = null


# =============================================================================
# TICK OVERRIDE
# =============================================================================

## Store delta before super.tick() so _apply_effect() can advance flicker time.
func tick(delta: float, target: Node) -> TickResult:
	_tick_delta = delta
	return super.tick(delta, target)


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _on_animate_start(target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return

	# Modulate effects contribute a factor; OUTLINE owns target.material directly.
	_contributes_modulate = (effect_type != AppearanceEffect.OUTLINE)

	_flicker_time = 0.0
	_setup_flicker_noise()

	if effect_type == AppearanceEffect.OUTLINE:
		if not _has_natural:
			_natural_material = n2d.material
			_has_natural = true
		var mat := _create_shader_material("res://addons/Juice_V1/Shaders/outline_2d.gdshader")
		if mat:
			mat.set_shader_parameter("outline_color", outline_color)
			mat.set_shader_parameter("outline_width", 0.0)
			_install_material(n2d, mat)

	if debug_enabled:
		print("[Appearance2D] Start: %s, flicker=%s" % [
			AppearanceEffect.keys()[effect_type],
			FlickerMode.keys()[flicker_mode]])


func _apply_effect(progress: float, target: Node) -> void:
	_advance_flicker_time()
	var p := _get_effective_progress(progress)

	if target == null:
		return

	match effect_type:
		AppearanceEffect.TINT:
			# Set multiplicative factor; domain node writes target.modulate = base * factor.
			_modulate_factor = lerp(Color.WHITE, tint_color, tint_blend * p)
			_modulate_factor.a = 1.0  # TINT does not alter alpha channel

		AppearanceEffect.FADE:
			# Alpha factor 1.0→fade_target_alpha; domain multiplies against base alpha.
			_modulate_factor = Color(1.0, 1.0, 1.0, lerpf(1.0, fade_target_alpha, p))

		AppearanceEffect.OVERBRIGHT:
			# RGB boost > 1.0 via modulate; domain node writes with HDR-capable color.
			var boost := lerpf(1.0, overbright_strength, p)
			_modulate_factor = Color(boost, boost, boost, 1.0)

		AppearanceEffect.OUTLINE:
			# Direct-write to target.material (separate slot — no modulate conflict).
			var mat := _active_material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("outline_width", outline_width * p)


func _on_animate_out_complete(_target: Node) -> void:
	# Progress is back at 0 — natural state is effectively restored by _apply_effect.
	# Materials remain installed until stop() calls _restore_to_natural().
	pass


func _restore_to_natural(target: Node) -> void:
	# Reset modulate factor — domain node stops writing once factor is WHITE.
	_modulate_factor = Color.WHITE
	_contributes_modulate = false

	# OUTLINE: restore target.material to what it was before animation.
	if _active_material != null:
		var n2d := target as Node2D
		if n2d != null and _has_natural:
			n2d.material = _natural_material
		_active_material = null

	_has_natural = false
	_flicker_time = 0.0

	if debug_enabled:
		print("[Appearance2D] Restored natural state.")


func _invalidate_base_cache() -> void:
	_has_natural = false
	_active_material = null


func _temporarily_undo_visual(target: Node) -> void:
	# Modulate is owned by domain node — nothing to undo here for TINT/FADE/OVERBRIGHT.
	# OUTLINE: temporarily restore natural material.
	if _active_material != null and _has_natural:
		var n2d := target as Node2D
		if n2d != null:
			n2d.material = _natural_material


func _temporarily_reapply_visual(target: Node) -> void:
	# OUTLINE: re-install working material.
	if _active_material != null:
		var n2d := target as Node2D
		if n2d != null:
			n2d.material = _active_material
	# Update _modulate_factor so domain node has current value on next write.
	_apply_effect(_animation_progress, target)


func _get_interrupt_identity() -> Variant:
	# Two Appearance2D effects of the same type on the same target interrupt each other.
	return [get_script(), effect_type]


# =============================================================================
# FLICKER SYSTEM
# =============================================================================

## Returns effective progress after flicker modulation is applied.
func _get_effective_progress(progress: float) -> float:
	if flicker_mode == FlickerMode.NONE or progress <= 0.0:
		return progress

	var multiplier: float = 1.0
	match flicker_mode:
		FlickerMode.RANDOM:
			if _flicker_noise != null:
				# get_noise_1d returns -1..1; normalize to 0..1 for lerp.
				var raw := (_flicker_noise.get_noise_1d(_flicker_time * flicker_rate) + 1.0) * 0.5
				multiplier = lerpf(flicker_min, flicker_max, raw)
		FlickerMode.CUSTOM:
			if flicker_curve != null:
				var phase := fmod(_flicker_time * flicker_rate, 1.0)
				multiplier = lerpf(flicker_min, flicker_max, flicker_curve.sample(phase))

	if hard_flicker:
		var threshold := (flicker_min + flicker_max) * 0.5
		multiplier = 1.0 if multiplier >= threshold else 0.0

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
		push_warning("[Appearance2D] Shader not found: %s" % shader_path)
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _install_material(n2d: Node2D, mat: Material) -> void:
	_active_material = mat
	n2d.material = mat


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if flicker_mode == FlickerMode.CUSTOM and flicker_curve == null:
		warnings.append("Flicker mode is Custom but no flicker_curve is assigned. Flicker will not apply.")
	if flicker_min > flicker_max:
		warnings.append("flicker_min is greater than flicker_max — flicker behavior undefined.")
	return warnings
