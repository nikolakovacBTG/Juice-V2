## JuiceLedger — centralized delta-ledger for the Juice System.
##
## Owns the per-target metadata dictionary that tracks each node's natural
## (base) property values and all per-source deltas currently applied to it.
## Every domain node (_JuiceControl_, _Juice2D_, _Juice3D_) writes through this
## class instead of writing directly to the target — ensuring that multiple
## concurrent Juice sources are always summed correctly.

# ============================================================================
# WHAT: Typed static ledger API extracted from JuiceBase.
# WHY:  Raw Dictionary-in-metadata with no type safety or isolation was
#       untestable and fragile. A static class with a documented API is
#       testable in isolation and enforces a single write path.
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Know about domains, effects, or recipes.
#           Does not inherit from Node — pure static utility.
# ============================================================================
#
# LEDGER SCHEMA (stored as Node metadata under KEY):
#   {
#     "base":   { "position": Vector2, "rotation": float, ... }
#     "deltas": { "position": { source_id: delta, ... }, ... }
#   }
# ============================================================================

class_name JuiceLedger

# --- Private storage key ---
const KEY := &"juice_active_ledger"

# =============================================================================
# PUBLIC API
# =============================================================================

## Returns the zero value appropriate for the type of [param value].
## Used to create a starting accumulator before summing deltas dynamically.
static func zero_for(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT: return 0.0
	if typeof(value) == TYPE_VECTOR2: return Vector2.ZERO
	if typeof(value) == TYPE_VECTOR3: return Vector3.ZERO
	if typeof(value) == TYPE_COLOR: return Color.WHITE
	return null


## Ensures the ledger exists on [param target] and that each property in
## [param props] has its base value recorded from the current node state.
## Prevents duplicate instantiations of the ledger while ensuring all requested properties are tracked before animation begins. Safe to call every frame.
static func ensure(target: Node, props: Array[String]) -> Dictionary:
	var ledger: Dictionary
	if not target.has_meta(KEY):
		ledger = {"base": {}, "deltas": {}}
		target.set_meta(KEY, ledger)
	else:
		ledger = target.get_meta(KEY)

	for prop in props:
		if not ledger["base"].has(prop):
			ledger["base"][prop] = target.get(prop)
	return ledger


## Detects whether [param target] was moved externally (e.g. by a layout engine)
## and adjusts the ledger base accordingly so subsequent animation reads are correct.
## Ensures that external movement (like layout engines or game logic) doesn't cause the juice animation to snap back to an outdated origin. Container positions are handled with special idle-only logic to avoid axis corruption.
static func sync_base_if_moved(target: Node, props: Array[String]) -> void:
	if not target.has_meta(KEY): return
	var ledger: Dictionary = target.get_meta(KEY)

	for prop in props:
		if not ledger["base"].has(prop): continue
		var base_val: Variant = ledger["base"][prop]
		var total_delta: Variant = zero_for(base_val)
		if ledger["deltas"].has(prop):
			for delta_val: Variant in ledger["deltas"][prop].values():
				if typeof(total_delta) == TYPE_COLOR and typeof(delta_val) == TYPE_COLOR:
					var c_tot := total_delta as Color
					var c_del := delta_val as Color
					total_delta = Color(c_tot.r * c_del.r, c_tot.g * c_del.g, c_tot.b * c_del.b, c_tot.a * c_del.a)
				else:
					total_delta += delta_val

		var expected_val: Variant = base_val
		if typeof(total_delta) == TYPE_COLOR:
			var base_col := base_val as Color
			var tot_col := total_delta as Color
			expected_val = Color(base_col.r * tot_col.r, base_col.g * tot_col.g, base_col.b * tot_col.b, base_col.a * tot_col.a)
		else:
			expected_val = base_val + total_delta

		var current_val: Variant = target.get(prop)

		# If the node is a Control in a Container, the layout engine applies absolute positions.
		var is_container_position := false
		if prop == "position" and target is Control:
			var parent := target.get_parent()
			if parent is Container and not (target as Control).top_level:
				is_container_position = true

		var displaced := false
		var offset: Variant = zero_for(base_val)

		if typeof(current_val) == TYPE_FLOAT:
			if not is_equal_approx(current_val as float, expected_val as float):
				displaced = true
				offset = (current_val as float) - (expected_val as float)
		elif typeof(current_val) == TYPE_VECTOR2:
			if not (current_val as Vector2).is_equal_approx(expected_val as Vector2):
				if is_container_position:
					# The Container re-sorts children to their natural positions.
					# When Juice is IDLE (total_delta == 0): current_val IS the true natural
					# Container position — update the base so subsequent animations start from the
					# correct spot. This handles HBox re-sorting after resize, visibility change, etc.
					# When Juice is ACTIVE (total_delta != 0): Juice intentionally displaced the node.
					# The mismatch is expected — do NOT update the base. Subtracting total_delta
					# is unsafe because Containers only manage one axis (HBox → X, VBox → Y),
					# so subtracting a 2D delta corrupts the unmanaged axis.
					var is_idle: bool = (total_delta as Vector2).is_equal_approx(Vector2.ZERO)
					if is_idle:
						ledger["base"][prop] = current_val
					continue
				else:
					var test_offset: Vector2 = (current_val as Vector2) - (expected_val as Vector2)
					if abs(test_offset.x) > 0.0001 or abs(test_offset.y) > 0.0001:
						displaced = true
						offset = test_offset
		elif typeof(current_val) == TYPE_VECTOR3:
			if not (current_val as Vector3).is_equal_approx(expected_val as Vector3):
				displaced = true
				offset = (current_val as Vector3) - (expected_val as Vector3)
		elif typeof(current_val) == TYPE_COLOR:
			pass # External drift on modulate not tracked yet

		if displaced:
			ledger["base"][prop] += offset


## Registers [param delta] for [param prop] from [param source] on [param target].
## Allows multiple effects (e.g. hover and click) to independently contribute to the same property without overwriting each other. Re-registering from the same source replaces the previous value.
static func register_delta(target: Node, source: Node, prop: String, delta: Variant) -> void:
	if not target.has_meta(KEY): return
	var ledger: Dictionary = target.get_meta(KEY)
	if not ledger["deltas"].has(prop):
		ledger["deltas"][prop] = {}
	var source_id := source.get_instance_id()
	ledger["deltas"][prop][source_id] = delta


## Returns the summed total delta for [param prop] across all registered sources.
## Aggregates all active effect contributions so the domain node can perform a single combined write per frame. Colors are multiplied (modulate factors); all other types are added.
static func get_total(target: Node, prop: String, zero_val: Variant) -> Variant:
	if not target.has_meta(KEY): return zero_val
	var ledger: Dictionary = target.get_meta(KEY)
	if not ledger["deltas"].has(prop): return zero_val
	var total: Variant = zero_val
	for delta_val: Variant in ledger["deltas"][prop].values():
		if typeof(total) == TYPE_COLOR and typeof(delta_val) == TYPE_COLOR:
			var c_tot := total as Color
			var c_del := delta_val as Color
			total = Color(c_tot.r * c_del.r, c_tot.g * c_del.g, c_tot.b * c_del.b, c_tot.a * c_del.a)
		else:
			total += delta_val
	return total


## Returns the recorded natural (base) value for [param prop].
## Safely retrieves the unmodified property value, falling back to the current value if the ledger hasn't captured it yet.
static func get_base(target: Node, prop: String, fallback: Variant) -> Variant:
	if not target.has_meta(KEY): return fallback
	var ledger: Dictionary = target.get_meta(KEY)
	return ledger["base"].get(prop, fallback)


## Overwrites the stored base value for [param prop] with [param value].
## Use only when the persisted base is known-stale — for example, when an
## editor-preview init fires and the ledger was saved before a @tool node
## (e.g. TileMapLayer) had finished its own deferred initialization.
## Never call this during runtime animation.
static func force_base(target: Node, prop: String, value: Variant) -> void:
	if not target.has_meta(KEY):
		return
	var ledger: Dictionary = target.get_meta(KEY)
	if ledger["base"].has(prop):
		ledger["base"][prop] = value


## Returns the full "base" snapshot dictionary for [param target].
## Effect SELF-capture methods use this to read the true natural state
## instead of a dirty target.property that includes active animation.
## Returns [code]{}[/code] when no ledger exists — effects fall back to
## target.property safely.
static func get_base_dict(target: Node) -> Dictionary:
	if target == null or not target.has_meta(KEY):
		return {}
	var ledger: Dictionary = target.get_meta(KEY)
	return ledger.get("base", {})


## Removes all deltas registered by [param source] from [param target]'s ledger.
## If [param permanently] is [code]true[/code] and no other sources remain,
## restores all base values and removes the ledger metadata entirely.
static func cleanup_source(target: Node, source: Node, permanently: bool = true) -> void:
	if not target.has_meta(KEY): return
	var ledger: Dictionary = target.get_meta(KEY)
	var source_id := source.get_instance_id()

	var any_remaining := false
	for prop: String in ledger["deltas"].keys():
		var sources: Dictionary = ledger["deltas"][prop]
		sources.erase(source_id)
		if not sources.is_empty():
			any_remaining = true

	if permanently and not any_remaining:
		for prop: String in ledger["base"].keys():
			# Skip synthetic keys (e.g. "_appearance_factor") that are used for
			# Ledger-based tracking but don't correspond to real Node properties.
			if prop.begins_with("_"):
				continue
			target.set(prop, ledger["base"][prop])
		target.remove_meta(KEY)


## Immediately writes the combined value for tracked properties to the target node.
## Additive properties (position, rotation, scale): [code]base + Σdeltas[/code].
## Multiplicative properties (self_modulate, modulate): [code]base × Πfactors[/code].
## Called after stop() or from [_temporarily_undo_visual] when no active
## _process loop will perform the next write.
## [param props] restricts which properties are written. If empty, all tracked
## properties are flushed.
## All REMAINING sources (e.g. an active hover) are preserved.
static func flush(target: Node, props: Array[String] = []) -> void:
	if not target.has_meta(KEY): return
	var ledger: Dictionary = target.get_meta(KEY)
	var keys: Array = props if not props.is_empty() else ledger["base"].keys()
	for prop: String in keys:
		# Skip synthetic keys (e.g. "_appearance_factor") — not real Node properties.
		if prop.begins_with("_"): continue
		var base_val: Variant = ledger["base"].get(prop)
		if base_val == null: continue
		var total_delta: Variant = zero_for(base_val)
		var delta_sources: Dictionary = ledger["deltas"].get(prop, {})
		for delta_val: Variant in delta_sources.values():
			if typeof(total_delta) == TYPE_COLOR and typeof(delta_val) == TYPE_COLOR:
				var c_tot := total_delta as Color
				var c_del := delta_val as Color
				total_delta = Color(c_tot.r * c_del.r, c_tot.g * c_del.g, c_tot.b * c_del.b, c_tot.a * c_del.a)
			else:
				total_delta += delta_val
		# Color properties use multiplicative accumulation (base × Πfactors).
		# All other types use additive accumulation (base + Σdeltas).
		if typeof(base_val) == TYPE_COLOR:
			var b := base_val as Color
			var t := total_delta as Color
			target.set(prop, Color(b.r * t.r, b.g * t.g, b.b * t.b, b.a * t.a))
		else:
			target.set(prop, base_val + total_delta)


## Returns [code]true[/code] if [param target] has an active ledger.
## Quickly checks if a target is currently under Juice control without allocating.
static func has_ledger(target: Node) -> bool:
	return target != null and target.has_meta(KEY)
