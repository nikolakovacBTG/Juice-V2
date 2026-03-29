## Appearance3DJuiceEffect.gd
## ============================================================================
## WHAT: Animates visual appearance properties of Node3D targets.
##       Modulate-equivalent effects (TINT, FADE, OVERBRIGHT) contribute
##       multiplicative albedo/alpha factors; Juice3D owns one working material
##       and writes once per frame.
## WHY: Correct V1 stackable architecture — effects do not write to the mesh
##      material directly; the domain node (Juice3D) owns the working material
##      and the single write per frame. Multiple stacked effects stack cleanly.
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Handle Control or Node2D targets — use AppearanceControl/2DJuiceEffect.
## DOES NOT: Animate position/rotation/scale — use Transform3DJuiceEffect.
## DOES NOT: Manage MeshInstance3D or surface materials — Juice3D does that.
## ============================================================================
#
# OVERBRIGHT NOTE: Uses albedo_color with RGB > 1.0 (HDR-compatible path).
#   Works correctly with Godot's forward+ renderer + HDR enabled.
#
# FLICKER: Optional temporal modulation applied on top of animation progress.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBase3D.svg")
class_name Appearance3DJuiceEffect
extends Juice3DAppearanceEffect


# =============================================================================
# ENUMS
# =============================================================================

enum AppearanceEffect {
	TINT,       ## Blend albedo toward a tint color (multiplicative factor)
	FADE,       ## Animate alpha via albedo_color.a (multiplicative factor)
	OVERBRIGHT, ## Boost RGB albedo above 1.0 for HDR overbright effect
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

## Tint color blended into albedo at peak (TINT).
var tint_color: Color = Color(1.0, 0.4, 0.4, 1.0)
## Tint blend strength 0=none, 1=full (TINT).
var tint_blend: float = 1.0
## Target alpha factor at progress=1.0 (FADE). 0.0 = fully transparent.
var fade_target_alpha: float = 0.0
## RGB albedo multiplier at peak (OVERBRIGHT). 2.0 = double brightness.
var overbright_strength: float = 2.0

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
		"hint_string": "Tint,Fade,Overbright",
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

# No mesh/material state here — Juice3D domain node owns the working material.
# This effect only computes _albedo_factor and _alpha_factor for the domain to use.
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
	# All TINT/FADE/OVERBRIGHT effects contribute albedo/alpha factors.
	# The domain node (Juice3D) owns the working material and writes albedo_color.
	_contributes_appearance = true

	_flicker_time = 0.0
	_setup_flicker_noise()

	if debug_enabled:
		print("[Appearance3D] Start: %s" % AppearanceEffect.keys()[effect_type])


func _apply_effect(progress: float, _target: Node) -> void:
	_advance_flicker_time()
	var p := _get_effective_progress(progress)

	match effect_type:
		AppearanceEffect.TINT:
			# Set multiplicative factor; domain node writes albedo_color = natural * factor.
			_albedo_factor = lerp(Color.WHITE, tint_color, tint_blend * p)
			_albedo_factor.a = 1.0  # TINT does not alter alpha channel
			_alpha_factor = 1.0

		AppearanceEffect.FADE:
			# Alpha factor 1.0→fade_target_alpha; domain multiplies against natural alpha.
			_albedo_factor = Color.WHITE
			_alpha_factor = lerpf(1.0, fade_target_alpha, p)

		AppearanceEffect.OVERBRIGHT:
			# RGB albedo boost > 1.0; works with HDR forward+ renderer.
			var boost := lerpf(1.0, overbright_strength, p)
			_albedo_factor = Color(boost, boost, boost, 1.0)
			_alpha_factor = 1.0


func _on_animate_out_complete(_target: Node) -> void:
	pass


func _restore_to_natural(_target: Node) -> void:
	# Reset appearance factors — domain node stops modifying material once factors are identity.
	_clear_appearance()
	_contributes_appearance = false
	_flicker_time = 0.0


func _invalidate_base_cache() -> void:
	_clear_appearance()
	_contributes_appearance = false


func _temporarily_undo_visual(_target: Node) -> void:
	# Appearance is managed by domain node (Juice3D._temporarily_undo_visual).
	# Effect has nothing to undo here — domain restores natural material.
	pass


func _temporarily_reapply_visual(target: Node) -> void:
	# Update factors so domain node has current values on next write.
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
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if flicker_mode == FlickerMode.CUSTOM and flicker_curve == null:
		warnings.append("Flicker mode is Custom but no flicker_curve is assigned. Flicker will not apply.")
	if flicker_min > flicker_max:
		warnings.append("flicker_min is greater than flicker_max.")
	return warnings
