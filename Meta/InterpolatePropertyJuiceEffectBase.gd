## Base for all Interpolate-family property effects.
##
## Overrides [method PropertyJuiceEffectBase._compute_property_value] to perform
## 19-type polymorphic lerp/slerp between a From and To value per target entry.

# ============================================================================
# WHAT: Interpolation logic for arbitrary named properties via the Juice Ledger.
# WHY:  The base class (PropertyJuiceEffectBase) owns Ledger routing — it calls
#       register_delta() for continuous types and register_hold() for discrete
#       types automatically. This class only needs to compute the correct value
#       (a delta for continuous, an absolute value for hold/flip) and return it
#       from _compute_property_value(). No direct node writes happen here.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Write to nodes directly — PropertyJuiceEffectBase routes via JuiceLedger.
#           Does not detect property types — uses typeof(base_val) from the Ledger.
#           Does not support cross-node targeting via node_path (Phase 6.2 scope).
# ============================================================================

@tool
class_name InterpolatePropertyJuiceEffectBase
extends PropertyJuiceEffectBase

# =============================================================================
# CONFIGURATION
# =============================================================================

# property_targets array is inherited from PropertyJuiceEffectBase.
# Elements are typed as PropertyTarget there; we cast to InterpolatePropertyTarget
# in _find_entry() to access get_from() / get_to() / is_configured().

# =============================================================================
# LIFECYCLE
# =============================================================================

func _on_animate_start(target: Node) -> void:
	# Must call super first: registers all property paths in the Ledger so
	# base values are captured before capture_runtime_values() reads them.
	super._on_animate_start(target)
	# Then capture ON_TRIGGER from/to values from the current (base) state.
	for pt in property_targets:
		var entry := pt as InterpolatePropertyTarget
		if entry != null and entry.is_configured():
			entry.capture_runtime_values(target)
			JuiceLogger.log_capture(self, _get_domain_tag(), "interpolate_target",
					{"path": entry.property_path, "from": entry.get_from(),
					"to": entry.get_to()}, debug_enabled)

# =============================================================================
# PUBLIC API
# =============================================================================

## Returns the [b]desired absolute value[/b] for [param prop] at [param progress].
##
## Delegates to [method _compute_lerp] to produce the interpolated value;
## the base class ([PropertyJuiceEffectBase]) handles all Ledger routing
## (Color factor, Rect2/AABB decompose, additive delta, hold/flip).
## Subclass overriders of this method should follow the same convention:
## return what you want the property to equal, not a pre-computed delta.
func _compute_property_value(progress: float, prop: String, base_val: Variant, _target: Node) -> Variant:
	var entry := _find_entry(prop)
	if entry == null or not entry.is_configured():
		return base_val  # No-op: base class registers zero delta.

	var detected_type := typeof(base_val)
	var lerped: Variant = _compute_lerp(entry, progress, detected_type)
	# Return the absolute desired value. PropertyJuiceEffectBase converts it
	# into the correct Ledger form (factor/delta/hold) per type.
	return lerped if lerped != null else base_val


## Whether this effect needs per-frame ticking after animate_in completes.
## Interpolate effects hold their final value without a sustain loop.
func _needs_sustain() -> bool:
	return false


## Tells PropertyJuiceEffectBase which resource subclass to use for the
## property_targets typed array in the inspector.
## Without this override the inspector would offer base PropertyTarget entries,
## hiding InterpolatePropertyTarget's From/To/CaptureMode fields.
func _get_target_resource_type() -> String:
	return "InterpolatePropertyTarget"

# =============================================================================
# CORE LOGIC
# =============================================================================

# Finds the InterpolatePropertyTarget entry for [param prop].
# Returns null if no configured entry matches.
func _find_entry(prop: String) -> InterpolatePropertyTarget:
	for pt in property_targets:
		var entry := pt as InterpolatePropertyTarget
		if entry != null and entry.property_path == prop:
			return entry
	return null


# Computes the interpolated value at [param progress] using [param detected_type]
# to dispatch the correct lerp math. Returns null for unhandled types.
# Discrete types apply threshold-flip logic: return to_val when progress >= flip_threshold.
func _compute_lerp(entry: InterpolatePropertyTarget, progress: float, detected_type: int) -> Variant:
	var from_val: Variant = entry.get_from()
	var to_val:   Variant = entry.get_to()
	if from_val == null or to_val == null:
		return null

	match detected_type:

		# ---- Continuous: lerp/slerp ----

		TYPE_FLOAT:
			return lerpf(from_val, to_val, progress)

		TYPE_INT:
			# Lerp via float, truncate to int — preserves integer node properties.
			return int(lerpf(float(from_val), float(to_val), progress))

		TYPE_VECTOR2:
			return (from_val as Vector2).lerp(to_val, progress)

		TYPE_VECTOR2I:
			var r := Vector2(from_val.x, from_val.y).lerp(Vector2(to_val.x, to_val.y), progress)
			return Vector2i(int(r.x), int(r.y))

		TYPE_RECT2:
			var f := from_val as Rect2; var t := to_val as Rect2
			return Rect2(f.position.lerp(t.position, progress), f.size.lerp(t.size, progress))

		TYPE_RECT2I:
			var f := from_val as Rect2i; var t := to_val as Rect2i
			var p := Vector2(f.position.x, f.position.y).lerp(Vector2(t.position.x, t.position.y), progress)
			var s := Vector2(f.size.x, f.size.y).lerp(Vector2(t.size.x, t.size.y), progress)
			return Rect2i(int(p.x), int(p.y), int(s.x), int(s.y))

		TYPE_VECTOR3:
			return (from_val as Vector3).lerp(to_val, progress)

		TYPE_VECTOR3I:
			var r := Vector3(from_val.x, from_val.y, from_val.z).lerp(
					Vector3(to_val.x, to_val.y, to_val.z), progress)
			return Vector3i(int(r.x), int(r.y), int(r.z))

		TYPE_VECTOR4:
			var f := from_val as Vector4; var t := to_val as Vector4
			return Vector4(lerpf(f.x, t.x, progress), lerpf(f.y, t.y, progress),
						   lerpf(f.z, t.z, progress), lerpf(f.w, t.w, progress))

		TYPE_VECTOR4I:
			var f := from_val as Vector4i; var t := to_val as Vector4i
			return Vector4i(int(lerpf(f.x, t.x, progress)), int(lerpf(f.y, t.y, progress)),
							int(lerpf(f.z, t.z, progress)), int(lerpf(f.w, t.w, progress)))

		TYPE_QUATERNION:
			# slerp avoids length drift and gimbal lock that lerp+normalize causes.
			return (from_val as Quaternion).slerp(to_val, progress)

		TYPE_AABB:
			var f := from_val as AABB; var t := to_val as AABB
			return AABB(f.position.lerp(t.position, progress), f.size.lerp(t.size, progress))

		TYPE_COLOR:
			return (from_val as Color).lerp(to_val, progress)

		# ---- Hold/flip: threshold switch ----
		# No interpolation — these types cannot be meaningfully lerped.

		TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME, \
		TYPE_NODE_PATH, TYPE_OBJECT, \
		TYPE_PLANE, TYPE_BASIS, TYPE_PROJECTION:
			return to_val if progress >= entry.flip_threshold else from_val

	# TYPE_NIL or unhandled type — warn once on first frame.
	if progress < 0.02:
		JuiceLogger.warn(self, _get_domain_tag(),
				"property '%s' has unhandled type %d — set a valid property_path first" \
				% [entry.property_path, detected_type], debug_enabled)
	return null
