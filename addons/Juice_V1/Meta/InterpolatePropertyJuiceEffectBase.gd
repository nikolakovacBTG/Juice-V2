## Interpolates arbitrary node properties from a FROM value to a TO value.
##
## Each InterpolatePropertyTarget entry specifies its own node, property,
## capture modes, and typed from/to values. Continuous types use lerp/slerp.
## Discrete types (bool, String, Object, etc.) flip at a designer-set threshold.

# =============================================================================
# WHAT: Drives a list of arbitrary properties from configurable From to To
#       values using the JuiceEffectBase animate_in/out envelope for easing.
# WHY:  Provides a domain-agnostic generic From/To interpolation effect for the Property family.
#       Any exported property on any node can be tweened: energy, modulate:a,
#       shader_parameter paths, custom vars — all via set_indexed().
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Use domain delta aggregation — writes via set_indexed() directly.
# DOES NOT: Sustain. set_indexed() is a persistent write — last value at
#           progress=1.0 holds without ticking. Animate_out reverses if enabled.
# NOTE: lerp() is polymorphic in GDScript 4 for float/Vector2/Vector3/Color.
#       int is special-cased: lerpf(from, to, t) cast back to int.
# =============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceBaseProperty.svg")
class_name PropertyInterpolateJuiceEffectBase
extends PropertyJuiceEffectBase


# =============================================================================
# CONFIGURATION
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Tell the base class which resource type to use for the typed array hint.
# Required to support strongly-typed property inspector rendering for different concrete effects.
func _get_target_resource_type() -> String:
	return "InterpolatePropertyTarget"


# No additional properties beyond the base Effect group + Property Targets.
# Full layout is inherited from PropertyJuiceEffectBase._get_property_list().


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Log what is being restored before delegating to the base class lifecycle.
func _restore_to_natural(target: Node) -> void:
	for entry: InterpolatePropertyTarget in property_targets:
		if entry == null or not entry.is_configured():
			continue
		JuiceLogger.log_info(self, _get_domain_tag(),
				"restore_to_natural: resetting path='%s' to natural" % entry.property_path,
				debug_enabled)
	super._restore_to_natural(target)


## Interpolate does not need frame-by-frame sustain — set_indexed() writes
## are persistent. The last write at progress=1.0 holds naturally.
func _needs_sustain() -> bool:
	return false


## Captures dynamic ON_TRIGGER From/To values at the exact moment of playback, ensuring accurate start points when interrupted or chained.
func _on_animate_start(target: Node) -> void:
	# Capture base values (restore target) and resolve nodes.
	super._on_animate_start(target)
	# Capture ON_TRIGGER from/to values from the current property state.
	for entry: InterpolatePropertyTarget in property_targets:
		if entry != null and entry.is_configured():
			entry.capture_runtime_values()
	# Log each entry individually — the from/to capture is the critical diagnostic.
	# A wrong captured value at this point (ON_TRIGGER mode) explains any wrong output.
	for entry: InterpolatePropertyTarget in property_targets:
		if entry == null or not entry.is_configured():
			continue
		JuiceLogger.log_capture(self, _get_domain_tag(), "interpolate_target",
			{"path": entry.property_path, "from": entry.get_from(),
			"to": entry.get_to()}, debug_enabled)


## Iterates over the target entries and performs polymorphic interpolation (lerp), mapping 0-1 progress to property values directly on the engine target.
func _apply_effect(progress: float, _target: Node) -> void:
	for entry: InterpolatePropertyTarget in property_targets:
		if entry == null or not entry.is_configured():
			continue
		if not is_instance_valid(entry._resolved_node):
			JuiceLogger.warn(self, _get_domain_tag(),
					"resolved_node invalid for path '%s' — effect skipped" % entry.property_path,
					debug_enabled)
			continue
		var value: Variant = _compute_lerp(entry, progress)
		if value == null:
			continue
		entry._resolved_node.set_indexed(entry.property_path, value)
		# Per-entry log: from, to, and computed value make divergence immediately visible.
		JuiceLogger.log_delta(self, _get_domain_tag(), progress,
				{"path": entry.property_path, "from": entry.get_from(),
				"to": entry.get_to(), "computed": value},
				entry._resolved_node.name, debug_enabled)


# =============================================================================
# LERP CORE
# =============================================================================

# Computes the interpolated value for one entry at the given progress (0.0–1.0).
# Explicit type dispatch — avoids Variant lerp() polymorphism which is too
# implicit and fails silently for integer and vector-int types.
# Returns null if from/to are null or the type is not handled (caller skips write).
func _compute_lerp(entry: InterpolatePropertyTarget, progress: float) -> Variant:
	var from_val: Variant = entry.get_from()
	var to_val:   Variant = entry.get_to()

	if from_val == null or to_val == null:
		return null

	match entry._detected_type:

		# ----- Continuous types: lerp/slerp between from_val and to_val -----

		TYPE_FLOAT:
			# Direct float lerp — the most common case (alpha, progress, uniforms).
			return lerpf(from_val, to_val, progress)

		TYPE_INT:
			# Lerp as float then truncate back to int so integer node properties
			# (e.g. z_index, item count) receive a clean integer on every write.
			return int(lerpf(float(from_val), float(to_val), progress))

		TYPE_VECTOR2:
			return (from_val as Vector2).lerp(to_val, progress)

		TYPE_VECTOR2I:
			# GDScript has no Vector2i.lerp(); promote to float, lerp, truncate.
			var fv := Vector2(from_val.x, from_val.y)
			var tv := Vector2(to_val.x,   to_val.y)
			var r  := fv.lerp(tv, progress)
			return Vector2i(int(r.x), int(r.y))

		TYPE_RECT2:
			# Rect2 has no lerp(); decompose, lerp position and size independently.
			var f := from_val as Rect2
			var t := to_val   as Rect2
			return Rect2(f.position.lerp(t.position, progress),
						 f.size.lerp(t.size, progress))

		TYPE_RECT2I:
			# Same decompose-and-lerp, then truncate back to int components.
			var f := from_val as Rect2i
			var t := to_val   as Rect2i
			var p  := Vector2(f.position.x, f.position.y).lerp(
					  Vector2(t.position.x, t.position.y), progress)
			var s  := Vector2(f.size.x, f.size.y).lerp(
					  Vector2(t.size.x,   t.size.y),   progress)
			return Rect2i(int(p.x), int(p.y), int(s.x), int(s.y))

		TYPE_VECTOR3:
			return (from_val as Vector3).lerp(to_val, progress)

		TYPE_VECTOR3I:
			# Same float-promote pattern as Vector2i.
			var fv := Vector3(from_val.x, from_val.y, from_val.z)
			var tv := Vector3(to_val.x,   to_val.y,   to_val.z)
			var r  := fv.lerp(tv, progress)
			return Vector3i(int(r.x), int(r.y), int(r.z))

		TYPE_VECTOR4:
			# Vector4 has no built-in lerp(); component-wise lerpf.
			var f := from_val as Vector4
			var t := to_val   as Vector4
			return Vector4(
				lerpf(f.x, t.x, progress),
				lerpf(f.y, t.y, progress),
				lerpf(f.z, t.z, progress),
				lerpf(f.w, t.w, progress))

		TYPE_VECTOR4I:
			# Same component-wise pattern, truncated back to int.
			var f := from_val as Vector4i
			var t := to_val   as Vector4i
			return Vector4i(
				int(lerpf(f.x, t.x, progress)),
				int(lerpf(f.y, t.y, progress)),
				int(lerpf(f.z, t.z, progress)),
				int(lerpf(f.w, t.w, progress)))

		TYPE_QUATERNION:
			# slerp() avoids length drift and gimbal lock that lerp+normalize causes.
			return (from_val as Quaternion).slerp(to_val, progress)

		TYPE_AABB:
			# Decompose and lerp position + size extents independently.
			var f := from_val as AABB
			var t := to_val   as AABB
			return AABB(f.position.lerp(t.position, progress),
						f.size.lerp(t.size, progress))

		TYPE_COLOR:
			# Color.lerp() handles all four channels (r, g, b, a) uniformly.
			return (from_val as Color).lerp(to_val, progress)

		# ----- Discrete / threshold-flip types -----
		# At progress >= flip_threshold return to_val; before it return from_val.
		# No interpolation — these types cannot be meaningfully lerped.

		TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME, \
		TYPE_NODE_PATH, TYPE_OBJECT, \
		TYPE_PLANE, TYPE_BASIS, TYPE_PROJECTION:
			return to_val if progress >= entry.flip_threshold else from_val

	# TYPE_NIL or an unhandled type — warn once (first ~frame) to avoid log spam.
	if progress < 0.02:
		JuiceLogger.warn(self, _get_domain_tag(),
				"property '%s' has unhandled type %d — pick a valid property first" \
				% [entry.property_path, entry._detected_type],
				debug_enabled)
	return null
