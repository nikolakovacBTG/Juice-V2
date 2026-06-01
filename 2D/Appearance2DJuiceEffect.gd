## Animates visual appearance properties (tint, fade, overbright, outline) of [Node2D] targets.
##
## Modulate effects (TINT, FADE, OVERBRIGHT) are stackable. OUTLINE installs
## a ShaderMaterial on the target.

# ============================================================================
# WHAT: Animates visual appearance properties of Node2D targets.
# WHY: Maintains stackable invariant — effects do not write to target
#      directly; the domain node owns the single write per channel per frame.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Handle Control or Node3D targets — use AppearanceControl/3DJuiceEffect.
# DOES NOT: Animate position/rotation/scale — use Transform2DJuiceEffect.
# ============================================================================
#
# SHADER PARAMETER NAMES:
#   outline_2d:  outline_color (Color), outline_width (float)
#
# FLICKER: Optional temporal modulation applied on top of animation progress.
#   RANDOM uses FastNoiseLite. CUSTOM uses a Curve. hard_flicker = binary on/off.
# ============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBase2D.svg")
class_name Appearance2DJuiceEffect
extends Juice2DAppearanceEffect


# =============================================================================
# ENUMS
# =============================================================================

enum AppearanceReference {
	CUSTOM, ## Use explicit From/To values
	SELF, ## Capture from target at animation start
}

enum CaptureAt {
	TRIGGER, ## Capture when animation starts
	READY, ## Capture when node enters tree
	IN_EDITOR, ## Capture immediately in editor
}

enum AppearanceEffect {
	TINT, ## Multiply modulate with a color overlay
	FADE, ## Animate modulate alpha to a target value
	OVERBRIGHT, ## Boost brightness above 1.0 via modulate
	OUTLINE, ## Add colored outline via outline_2d.gdshader
}

enum FlickerMode {
	NONE, ## No flicker — progress passes through unmodified
	RANDOM, ## FastNoiseLite-driven flicker
	CUSTOM, ## Curve-driven flicker pattern
}

enum OutlineFlickerTarget {
	WIDTH, ## Flicker modulates outline width
	COLOR_ALPHA, ## Flicker modulates outline color alpha
	COLOR, ## Flicker lerps between outline_color and flicker_color_to
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Which appearance effect to apply (Tint, Fade, Overbright, Outline).
var effect_type: int = AppearanceEffect.TINT:
	set(value):
		effect_type = value
		notify_property_list_changed()

# From/To reference infrastructure
## Where From values come from: Custom (explicit) or Self (captured from target).
var from_reference: int = AppearanceReference.SELF:
	set(value):
		from_reference = value
		notify_property_list_changed()
## Where To values come from: Custom (explicit) or Self (captured from target).
var to_reference: int = AppearanceReference.CUSTOM:
	set(value):
		to_reference = value
		notify_property_list_changed()

## When to capture From values (when from_reference == SELF).
var from_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		from_capture_at = value
		notify_property_list_changed()
## When to capture To values (when to_reference == SELF).
var to_capture_at: int = CaptureAt.TRIGGER:
	set(value):
		to_capture_at = value
		notify_property_list_changed()

# Per-effect From/To fields
## From tint color at progress=0 (TINT).
var from_tint_color: Color = Color.WHITE
## From tint blend strength 0=none, 1=full at progress=0 (TINT).
var from_tint_blend: float = 0.0
## To tint color at progress=1 (TINT).
var tint_color: Color = Color(1.0, 0.4, 0.4, 1.0)
## To tint blend strength 0=none, 1=full at progress=1 (TINT).
var tint_blend: float = 1.0

## From alpha at progress=0 (FADE).
var from_alpha: float = 1.0
## To alpha at progress=1 (FADE).
var fade_target_alpha: float = 0.0

## From brightness at progress=0 (OVERBRIGHT).
var from_brightness: float = 1.0
## To brightness at progress=1 (OVERBRIGHT).
var overbright_strength: float = 2.0

## Outline color (OUTLINE).
var outline_color: Color = Color.WHITE
## From outline width at progress=0 (OUTLINE).
var from_width: float = 0.0
## To outline width at progress=1 (OUTLINE).
var outline_width: float = 2.0

## Flicker mode: None, Random (noise-driven), or Custom (curve-driven).
var flicker_mode: int = FlickerMode.NONE:
	set(value):
		flicker_mode = value
		notify_property_list_changed()
## Minimum flicker multiplier (when flicker is at low point).
var flicker_min: float = 0.0
## Maximum flicker multiplier (when flicker is at high point).
var flicker_max: float = 1.0
## When true, flicker snaps between min/max instead of smooth interpolation.
var hard_flicker: bool = false
## Flicker speed in cycles per second (RANDOM mode).
var flicker_rate: float = 10.0
## Curve for flicker pattern (CUSTOM mode). X=phase [0,1], Y=multiplier.
var flicker_curve: Curve

## Which aspect of OUTLINE is modulated by flicker. Only shown when effect_type == OUTLINE and flicker_mode != NONE.
var outline_flicker_target: int = OutlineFlickerTarget.WIDTH:
	set(value):
		outline_flicker_target = value
		notify_property_list_changed()
## Secondary color for OUTLINE COLOR flicker mode. Outline lerps between outline_color and this.
var flicker_color_to: Color = Color.BLACK


func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Step 1: Effect GROUP (main selector + base timing) ---
	props.append({"name": "Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "effect_type", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Tint,Fade,Overbright,Outline",
		"usage": PROPERTY_USAGE_DEFAULT})
	props.append_array(_get_effect_base_properties())

	# --- Step 2: Effect-specific subgroup — Flicker ---
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
		# Outline-specific flicker target (only when OUTLINE + flicker enabled)
		if effect_type == AppearanceEffect.OUTLINE:
			props.append({"name": "outline_flicker_target", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Width,Color Alpha,Color",
				"usage": PROPERTY_USAGE_DEFAULT})
			if outline_flicker_target == OutlineFlickerTarget.COLOR:
				props.append({"name": "flicker_color_to", "type": TYPE_COLOR,
					"usage": PROPERTY_USAGE_DEFAULT})

	# --- Step 3: From GROUP ---
	props.append({"name": "From", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	if effect_type == AppearanceEffect.OUTLINE:
		# OUTLINE From is always CUSTOM (width only, no reference selector)
		props.append({"name": "from_width", "type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,20.0,0.5,or_greater",
			"usage": PROPERTY_USAGE_DEFAULT})
	else:
		props.append({"name": "from_reference", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Custom,Self",
			"usage": PROPERTY_USAGE_DEFAULT})
		if from_reference == AppearanceReference.CUSTOM:
			match effect_type:
				AppearanceEffect.TINT:
					props.append({"name": "from_tint_color", "type": TYPE_COLOR,
						"usage": PROPERTY_USAGE_DEFAULT})
					props.append({"name": "from_tint_blend", "type": TYPE_FLOAT,
						"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
						"usage": PROPERTY_USAGE_DEFAULT})
				AppearanceEffect.FADE:
					props.append({"name": "from_alpha", "type": TYPE_FLOAT,
						"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01",
						"usage": PROPERTY_USAGE_DEFAULT})
				AppearanceEffect.OVERBRIGHT:
					props.append({"name": "from_brightness", "type": TYPE_FLOAT,
						"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,5.0,0.1,or_greater",
						"usage": PROPERTY_USAGE_DEFAULT})
		elif from_reference == AppearanceReference.SELF:
			# Capture property directly under From when SELF selected
			props.append({"name": "from_capture_at", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Trigger,Ready,In Editor",
				"usage": PROPERTY_USAGE_DEFAULT})

	# --- Step 4: To GROUP ---
	props.append({"name": "To", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "to_reference", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Custom,Self",
		"usage": PROPERTY_USAGE_DEFAULT})
	if to_reference == AppearanceReference.CUSTOM:
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
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,5.0,0.1,or_greater",
					"usage": PROPERTY_USAGE_DEFAULT})
			AppearanceEffect.OUTLINE:
				props.append({"name": "outline_color", "type": TYPE_COLOR,
					"usage": PROPERTY_USAGE_DEFAULT})
				props.append({"name": "outline_width", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,10.0,0.1,or_greater",
					"usage": PROPERTY_USAGE_DEFAULT})
	elif to_reference == AppearanceReference.SELF:
		# Capture property directly under To when SELF selected
		props.append({"name": "to_capture_at", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Trigger,Ready,In Editor",
			"usage": PROPERTY_USAGE_DEFAULT})

	# Steps 5-9 (Animate In/Out, Chaining, Debug, Resource) handled by base class
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"effect_type": effect_type = value; return true
		&"from_reference": from_reference = value; return true
		&"to_reference": to_reference = value; return true
		&"from_capture_at": from_capture_at = value; return true
		&"to_capture_at": to_capture_at = value; return true
		&"from_tint_color": from_tint_color = value; return true
		&"from_tint_blend": from_tint_blend = value; return true
		&"tint_color": tint_color = value; return true
		&"tint_blend": tint_blend = value; return true
		&"from_alpha": from_alpha = value; return true
		&"fade_target_alpha": fade_target_alpha = value; return true
		&"from_brightness": from_brightness = value; return true
		&"overbright_strength": overbright_strength = value; return true
		&"outline_color": outline_color = value; return true
		&"from_width": from_width = value; return true
		&"outline_width": outline_width = value; return true
		&"flicker_mode": flicker_mode = value; return true
		&"flicker_rate": flicker_rate = value; return true
		&"flicker_min": flicker_min = value; return true
		&"flicker_max": flicker_max = value; return true
		&"hard_flicker": hard_flicker = value; return true
		&"flicker_curve": flicker_curve = value; return true
		&"outline_flicker_target": outline_flicker_target = value; return true
		&"flicker_color_to": flicker_color_to = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"effect_type": return effect_type
		&"from_reference": return from_reference
		&"to_reference": return to_reference
		&"from_capture_at": return from_capture_at
		&"to_capture_at": return to_capture_at
		&"from_tint_color": return from_tint_color
		&"from_tint_blend": return from_tint_blend
		&"tint_color": return tint_color
		&"tint_blend": return tint_blend
		&"from_alpha": return from_alpha
		&"fade_target_alpha": return fade_target_alpha
		&"from_brightness": return from_brightness
		&"overbright_strength": return overbright_strength
		&"outline_color": return outline_color
		&"from_width": return from_width
		&"outline_width": return outline_width
		&"flicker_mode": return flicker_mode
		&"flicker_rate": return flicker_rate
		&"flicker_min": return flicker_min
		&"flicker_max": return flicker_max
		&"hard_flicker": return hard_flicker
		&"flicker_curve": return flicker_curve
		&"outline_flicker_target": return outline_flicker_target
		&"flicker_color_to": return flicker_color_to
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

# Captured reference values for From animation
var _captured_from_tint_color: Color = Color.WHITE
var _captured_from_tint_blend: float = 0.0
var _captured_from_alpha: float = 1.0
var _captured_from_brightness: float = 1.0

# Captured reference values for To animation
var _captured_to_tint_color: Color = Color.WHITE
var _captured_to_tint_blend: float = 0.0
var _captured_to_alpha: float = 1.0
var _captured_to_brightness: float = 1.0

var _has_from_self_snapshot: bool = false
var _has_to_self_snapshot: bool = false

# Only needed for OUTLINE (which installs a ShaderMaterial on target.material).
# Modulate effects (TINT/FADE/OVERBRIGHT) use _modulate_factor from the intermediate.
var _natural_material: Material = null
var _has_natural: bool = false
var _active_material: Material = null # Material we installed — tracked so restore doesn't clobber user materials.
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

func _on_host_ready(target: Node, host: Node) -> void:
	_host_node = host
	var n2d := target as Node2D
	if n2d == null:
		return

	if from_reference == AppearanceReference.SELF and from_capture_at == CaptureAt.READY:
		_perform_from_capture(n2d)

	if to_reference == AppearanceReference.SELF and to_capture_at == CaptureAt.READY:
		_perform_to_capture(n2d)


# Orchestrates startup: flags modulate contribution or shader ownership, captures
# From/To references, and initializes flicker. OUTLINE installs a ShaderMaterial on
# target.material directly. TINT/FADE/OVERBRIGHT set _modulate_factor, which Juice2D
# writes to modulate (not self_modulate — Node2D has no self_modulate).
func _on_animate_start(target: Node) -> void:
	var n2d := target as Node2D
	if n2d == null:
		return

	# Modulate effects contribute a factor; OUTLINE owns target.material directly.
	_contributes_modulate = (effect_type != AppearanceEffect.OUTLINE)

	# Capture From/To references based on capture_at setting
	if from_reference == AppearanceReference.SELF and (from_capture_at == CaptureAt.TRIGGER or from_capture_at == CaptureAt.IN_EDITOR):
		_perform_from_capture(n2d)

	if to_reference == AppearanceReference.SELF and (to_capture_at == CaptureAt.TRIGGER or to_capture_at == CaptureAt.IN_EDITOR):
		_perform_to_capture(n2d)

	_flicker_time = 0.0
	_setup_flicker_noise()

	if effect_type == AppearanceEffect.OUTLINE:
		if not _has_natural:
			_natural_material = n2d.material
			_has_natural = true
		var mat := _create_shader_material("res://addons/Juice_V2/Shaders/outline_2d.gdshader")
		if mat:
			mat.set_shader_parameter("outline_color", outline_color)
			mat.set_shader_parameter("outline_width", 0.0)
			_install_material(n2d, mat)

	JuiceLogger.log_info(self, _get_domain_tag(),
			"animate_start: effect=%s from_ref=%s(%s) to_ref=%s(%s) flicker=%s" % [
			AppearanceEffect.keys()[effect_type],
			AppearanceReference.keys()[from_reference],
			CaptureAt.keys()[from_capture_at] if from_reference == AppearanceReference.SELF else "n/a",
			AppearanceReference.keys()[to_reference],
			CaptureAt.keys()[to_capture_at] if to_reference == AppearanceReference.SELF else "n/a",
			FlickerMode.keys()[flicker_mode]],
			debug_enabled)
	match effect_type:
		AppearanceEffect.TINT:
			JuiceLogger.log_capture(self, _get_domain_tag(), "appearance_from",
				{"tint_color": _captured_from_tint_color, "tint_blend": _captured_from_tint_blend}, debug_enabled)
			JuiceLogger.log_capture(self, _get_domain_tag(), "appearance_to",
				{"tint_color": _captured_to_tint_color, "tint_blend": _captured_to_tint_blend}, debug_enabled)
		AppearanceEffect.FADE:
			JuiceLogger.log_capture(self, _get_domain_tag(), "appearance_from",
				{"alpha": _captured_from_alpha}, debug_enabled)
			JuiceLogger.log_capture(self, _get_domain_tag(), "appearance_to",
				{"alpha": _captured_to_alpha}, debug_enabled)
		AppearanceEffect.OVERBRIGHT:
			JuiceLogger.log_capture(self, _get_domain_tag(), "appearance_from",
				{"brightness": _captured_from_brightness}, debug_enabled)
			JuiceLogger.log_capture(self, _get_domain_tag(), "appearance_to",
				{"brightness": _captured_to_brightness}, debug_enabled)
		AppearanceEffect.OUTLINE:
			JuiceLogger.log_capture(self, _get_domain_tag(), "appearance_from",
				{"from_width": from_width}, debug_enabled)
			JuiceLogger.log_capture(self, _get_domain_tag(), "appearance_to",
				{"outline_width": outline_width, "outline_color": outline_color}, debug_enabled)


func _apply_effect(progress: float, target: Node) -> void:
	_advance_flicker_time()
	var f := _compute_flicker_multiplier()

	if target == null:
		JuiceLogger.warn(self, _get_domain_tag(),
			"_apply_effect: target is null — skipping", debug_enabled)
		return

	var from_val: Variant
	var to_val: Variant
	match effect_type:
		AppearanceEffect.TINT:
			from_val = _resolve_from_tint(target)
			to_val = _resolve_to_tint(target)
			_modulate_factor = (from_val as Color).lerp(to_val, progress * f)
			_modulate_factor.a = 1.0 # TINT does not alter alpha channel

		AppearanceEffect.FADE:
			from_val = _resolve_from_alpha(target)
			to_val = _resolve_to_alpha(target)
			_modulate_factor = Color(1.0, 1.0, 1.0, lerpf(from_val, to_val, progress * f))

		AppearanceEffect.OVERBRIGHT:
			from_val = _resolve_from_brightness(target)
			to_val = _resolve_to_brightness(target)
			var boost := lerpf(from_val, to_val, progress * f)
			_modulate_factor = Color(boost, boost, boost, 1.0)

		AppearanceEffect.OUTLINE:
			# Direct-write to target.material (separate slot — no modulate conflict).
			var mat := _active_material as ShaderMaterial
			if mat:
				var width := lerpf(from_width, outline_width, progress)
				match outline_flicker_target:
					OutlineFlickerTarget.WIDTH:
						mat.set_shader_parameter("outline_width", width * f)
						mat.set_shader_parameter("outline_color", outline_color)
					OutlineFlickerTarget.COLOR_ALPHA:
						mat.set_shader_parameter("outline_width", width)
						mat.set_shader_parameter("outline_color",
							Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * f))
					OutlineFlickerTarget.COLOR:
						mat.set_shader_parameter("outline_width", width)
						mat.set_shader_parameter("outline_color", outline_color.lerp(flicker_color_to, 1.0 - f))
				JuiceLogger.log_shader(self, _get_domain_tag(),
						"outline_width", mat.get_shader_parameter("outline_width"),
						"rid=%s" % mat.get_rid(), debug_enabled)
	JuiceLogger.log_delta(self, _get_domain_tag(), progress,
			{"f(flicker)": f, "from": from_val, "to": to_val, "modulate": _modulate_factor},
			target.name, debug_enabled)


func _on_animate_out_complete(_target: Node) -> void:
	# Progress is back at 0 — natural state is effectively restored by _apply_effect.
	# Materials remain installed until stop() calls _restore_to_natural().
	pass


func _restore_to_natural(target: Node) -> void:
	var had_outline := _active_material != null
	JuiceLogger.log_info(self, _get_domain_tag(),
			"restore_to_natural: clearing modulate=%s had_outline=%s" % [
			_modulate_factor, had_outline], debug_enabled)

	# Reset modulate factor — domain node stops writing once factor is WHITE.
	_modulate_factor = Color.WHITE
	_contributes_modulate = false

	# OUTLINE: restore target.material to what it was before animation.
	if had_outline:
		var n2d := target as Node2D
		if n2d != null and _has_natural:
			n2d.material = _natural_material
		_active_material = null

	_has_natural = false
	_flicker_time = 0.0


func _invalidate_base_cache() -> void:
	_has_natural = false
	_active_material = null
	_has_from_self_snapshot = false
	_has_to_self_snapshot = false


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

# Compute flicker multiplier for output delta (not progress)
func _compute_flicker_multiplier() -> float:
	if flicker_mode == FlickerMode.NONE:
		return 1.0
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

	return multiplier

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
		JuiceLogger.warn(self, _get_domain_tag(),
				"shader not found: %s" % shader_path, debug_enabled)
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _install_material(n2d: Node2D, mat: Material) -> void:
	_active_material = mat
	n2d.material = mat


# =============================================================================
# FROM/TO RESOLVERS
# =============================================================================

# Called during _on_animate_start and _on_host_ready (CaptureAt.READY path).
# Reads directly from n2d.modulate to capture the node's current appearance state.
# Skip-guarded: only captures once per animation cycle to prevent overwrite.
func _perform_from_capture(n2d: Node2D) -> void:
	if _has_from_self_snapshot:
		return
	# Capture TINT references
	_captured_from_tint_color = n2d.modulate
	_captured_from_tint_blend = 0.0 # SELF means no tint at progress=0
	# Capture FADE references
	_captured_from_alpha = n2d.modulate.a
	# Capture OVERBRIGHT references
	var mod := n2d.modulate
	_captured_from_brightness = max(mod.r, max(mod.g, mod.b))
	_has_from_self_snapshot = true

# Perform the actual To reference capture
func _perform_to_capture(n2d: Node2D) -> void:
	if _has_to_self_snapshot:
		return
	# Capture TINT references
	_captured_to_tint_color = n2d.modulate
	_captured_to_tint_blend = 0.0
	# Capture FADE references
	_captured_to_alpha = n2d.modulate.a
	# Capture OVERBRIGHT references
	var mod := n2d.modulate
	_captured_to_brightness = max(mod.r, max(mod.g, mod.b))
	_has_to_self_snapshot = true

# TINT resolvers
func _resolve_from_tint(_n2d: Node2D) -> Color:
	if from_reference == AppearanceReference.SELF:
		return lerp(Color.WHITE, _captured_from_tint_color, _captured_from_tint_blend)
	else: # CUSTOM
		return lerp(Color.WHITE, from_tint_color, from_tint_blend)

func _resolve_to_tint(_n2d: Node2D) -> Color:
	if to_reference == AppearanceReference.SELF:
		return lerp(Color.WHITE, _captured_to_tint_color, _captured_to_tint_blend)
	else: # CUSTOM
		return lerp(Color.WHITE, tint_color, tint_blend)

# FADE resolvers
func _resolve_from_alpha(_n2d: Node2D) -> float:
	if from_reference == AppearanceReference.SELF:
		return _captured_from_alpha
	else: # CUSTOM
		return from_alpha

func _resolve_to_alpha(_n2d: Node2D) -> float:
	if to_reference == AppearanceReference.SELF:
		return _captured_to_alpha
	else: # CUSTOM
		return fade_target_alpha

# OVERBRIGHT resolvers
func _resolve_from_brightness(_n2d: Node2D) -> float:
	if from_reference == AppearanceReference.SELF:
		return _captured_from_brightness
	else: # CUSTOM
		return from_brightness

func _resolve_to_brightness(_n2d: Node2D) -> float:
	if to_reference == AppearanceReference.SELF:
		return _captured_to_brightness
	else: # CUSTOM
		return overbright_strength

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if flicker_mode == FlickerMode.CUSTOM and flicker_curve == null:
		warnings.append("Flicker mode is Custom but no flicker_curve is assigned. Flicker will not apply.")
	if flicker_min > flicker_max:
		warnings.append("flicker_min is greater than flicker_max — flicker behavior undefined.")
	# Add warnings for OUTLINE without proper setup
	if effect_type == AppearanceEffect.OUTLINE and outline_width <= 0.0:
		warnings.append("OUTLINE effect requires outline_width > 0.0 to be visible.")
	return warnings
