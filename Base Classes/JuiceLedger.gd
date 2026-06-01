## JuiceLedger — centralized delta-ledger for the Juice System.
##
## Owns the per-target in-memory dictionary that tracks each node's natural
## (base) property values and all per-source deltas currently applied to it.
## Every domain node (_JuiceControl_, _Juice2D_, _Juice3D_) writes through this
## class instead of writing directly to the target — ensuring that multiple
## concurrent Juice sources are always summed correctly.

# ============================================================================
# WHAT: Typed static ledger API for the Juice System.
# WHY:  Ledger state is session-transient — it must not survive scene saves.
#       A static Dictionary keyed by instance ID keeps all ledger data in
#       process memory only, never in the Godot serialization pipeline.
#       Node metadata is part of Godot's serialization path and caused stale
#       base values to be baked into .tscn files, corrupting animation origins.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Know about domains, effects, or recipes.
#           Does not inherit from Node — pure static utility.
# ============================================================================
#
# LEDGER SCHEMA (one entry per active target, keyed by get_instance_id()):
#   {
#     "base":   { "position": Vector2, "rotation": float, ... }
#     "deltas": { "position": { source_id: delta, ... }, ... }
#   }
# ============================================================================

class_name JuiceLedger

# In-memory store: keyed by target.get_instance_id().
# Never serialized. Created in ensure(), erased in cleanup_source() or via
# the tree_exiting auto-erase connected in ensure().
static var _store: Dictionary = {}

# =============================================================================
# PUBLIC API
# =============================================================================

## Returns the additive identity for [param value]'s type, used as the accumulator
## seed before summing deltas in [method flush] and [method get_total].
## Returns [code]null[/code] for non-additive types — decomposed types
## (Rect2, Rect2i, AABB) and hold/flip types (bool, String, StringName, NodePath,
## Object, Plane, Basis, Projection). [method flush] inspects [code]typeof(base_val)[/code]
## to route these types to their correct accumulation path.
static func zero_for(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT: return 0.0
		TYPE_VECTOR2:         return Vector2.ZERO
		TYPE_VECTOR2I:        return Vector2i.ZERO
		TYPE_VECTOR3:         return Vector3.ZERO
		TYPE_VECTOR3I:        return Vector3i.ZERO
		TYPE_VECTOR4:         return Vector4.ZERO
		TYPE_VECTOR4I:        return Vector4i.ZERO
		# Quaternion uses component-wise + as additive identity (0,0,0,0).
		# Single-effect delta: base + (computed - base) = computed.
		# Stacking two Quaternion effects produces a non-unit result
		# (expected limitation — slerp composition requires multiplicative model).
		TYPE_QUATERNION:      return Quaternion(0.0, 0.0, 0.0, 0.0)
		TYPE_COLOR:           return Color.WHITE
		# All other types (Rect2, Rect2i, AABB, bool, String, NodePath, Plane, etc.)
		# return null. flush() routes null to decomposed or hold accumulation paths.
		_: return null


## Ensures the ledger exists for [param target] and that each property in
## [param props] has its base value recorded from the current node state.
## Prevents duplicate instantiations of the ledger while ensuring all requested properties are tracked before animation begins. Safe to call every frame.
static func ensure(target: Node, props: Array[String]) -> Dictionary:
	var id := target.get_instance_id()
	if not _store.has(id):
		var ledger: Dictionary = {"base": {}, "deltas": {}}
		_store[id] = ledger
		# Auto-erase when target leaves the tree. Covers the case where the
		# target is freed before the Juice node's _exit_tree fires.
		# CONNECT_ONE_SHOT auto-disconnects after the signal fires once.
		target.tree_exiting.connect(func(): _store.erase(id), CONNECT_ONE_SHOT)
	var ledger: Dictionary = _store[id]
	for prop in props:
		if not ledger["base"].has(prop):
			# get_indexed() handles colon sub-paths ("modulate:a", "material:shader_parameter/x")
			# that Object.get() cannot resolve. Top-level props work identically.
			ledger["base"][prop] = target.get_indexed(prop)
	return ledger


## Detects whether [param target] was moved externally (e.g. by a layout engine)
## and adjusts the ledger base accordingly so subsequent animation reads are correct.
## Ensures that external movement (like layout engines or game logic) doesn't cause the juice animation to snap back to an outdated origin. Container positions are handled with special idle-only logic to avoid axis corruption.
static func sync_base_if_moved(target: Node, props: Array[String]) -> void:
	var id := target.get_instance_id()
	if not _store.has(id): return
	var ledger: Dictionary = _store[id]

	for prop in props:
		if not ledger["base"].has(prop): continue
		var base_val: Variant = ledger["base"][prop]
		var total_delta: Variant = zero_for(base_val)
		# Decomposed and hold types (null from zero_for) do not support drift
		# detection yet — PropertyTarget captures base before animation starts.
		if total_delta == null: continue
		if ledger["deltas"].has(prop):
			# Hoist type check outside loop — the delta type never changes mid-iteration.
			# Key-iteration avoids the per-call Array allocation of .values().
			var delta_dict: Dictionary = ledger["deltas"][prop]
			if typeof(total_delta) == TYPE_COLOR:
				for source_id in delta_dict:
					var c_tot := total_delta as Color
					var c_del := delta_dict[source_id] as Color
					total_delta = Color(c_tot.r * c_del.r, c_tot.g * c_del.g, c_tot.b * c_del.b, c_tot.a * c_del.a)
			else:
				for source_id in delta_dict:
					total_delta += delta_dict[source_id]

		var expected_val: Variant = base_val
		if typeof(total_delta) == TYPE_COLOR:
			var base_col := base_val as Color
			var tot_col := total_delta as Color
			expected_val = Color(base_col.r * tot_col.r, base_col.g * tot_col.g, base_col.b * tot_col.b, base_col.a * tot_col.a)
		else:
			expected_val = base_val + total_delta

		# get_indexed() required for sub-path props ("modulate:a", etc.).
		var current_val: Variant = target.get_indexed(prop)

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
## Allows multiple effects (e.g. hover and click) to independently contribute to
## the same property without overwriting each other.
## Re-registering from the same source replaces the previous value.
## [param source] may be a Node or a Resource — any Object with [method get_instance_id].
static func register_delta(target: Node, source: Object, prop: String, delta: Variant) -> void:
	var id := target.get_instance_id()
	if not _store.has(id): return
	var ledger: Dictionary = _store[id]
	if not ledger["deltas"].has(prop):
		ledger["deltas"][prop] = {}
	var source_id := source.get_instance_id()
	ledger["deltas"][prop][source_id] = delta


## Registers [param value] as the desired hold state for [param prop] from
## [param source] on [param target]. Used for discrete and flip-type properties
## (bool, String, StringName, NodePath, Object, Plane, Basis, Projection) that
## cannot be additively stacked.
## [method flush] writes the most-recently-registered active source's value each
## frame. When that source ends via [method cleanup_source], the previously
## registered source's value is automatically restored — no manual bookkeeping needed.
## Internally stored in the same deltas dict as register_delta; flush() routes
## to the correct path by inspecting typeof(base_val).
## [param source] may be a Node or a Resource — any Object with [method get_instance_id].
static func register_hold(target: Node, source: Object, prop: String, value: Variant) -> void:
	var id := target.get_instance_id()
	if not _store.has(id): return
	var ledger: Dictionary = _store[id]
	if not ledger["deltas"].has(prop):
		ledger["deltas"][prop] = {}
	var source_id := source.get_instance_id()
	ledger["deltas"][prop][source_id] = value


## Returns the summed total delta for [param prop] across all registered sources.
## Aggregates all active effect contributions so the domain node can perform a single combined write per frame. Colors are multiplied (modulate factors); all other types are added.
static func get_total(target: Node, prop: String, zero_val: Variant) -> Variant:
	if not _store.has(target.get_instance_id()): return zero_val
	var ledger: Dictionary = _store[target.get_instance_id()]
	if not ledger["deltas"].has(prop): return zero_val
	var total: Variant = zero_val
	# Hoist type check outside loop — the delta type never changes mid-iteration.
	# Key-iteration avoids the per-call Array allocation of .values().
	var delta_dict: Dictionary = ledger["deltas"][prop]
	if typeof(total) == TYPE_COLOR:
		for source_id in delta_dict:
			var c_tot := total as Color
			var c_del := delta_dict[source_id] as Color
			total = Color(c_tot.r * c_del.r, c_tot.g * c_del.g, c_tot.b * c_del.b, c_tot.a * c_del.a)
	else:
		for source_id in delta_dict:
			total += delta_dict[source_id]
	return total


## Returns the recorded natural (base) value for [param prop].
## Safely retrieves the unmodified property value, falling back to the current value if the ledger hasn't captured it yet.
static func get_base(target: Node, prop: String, fallback: Variant) -> Variant:
	if not _store.has(target.get_instance_id()): return fallback
	var ledger: Dictionary = _store[target.get_instance_id()]
	return ledger["base"].get(prop, fallback)


## Overwrites the stored base value for [param prop] with [param value].
## Use to correct a base that was seeded with a placeholder before the true
## natural value was available — for example, when appearance state is lazily
## resolved after the working material is established.
## Never call this during active animation.
static func force_base(target: Node, prop: String, value: Variant) -> void:
	if not _store.has(target.get_instance_id()):
		return
	var ledger: Dictionary = _store[target.get_instance_id()]
	if ledger["base"].has(prop):
		ledger["base"][prop] = value


## Returns the full "base" snapshot dictionary for [param target].
## Effect SELF-capture methods use this to read the true natural state
## instead of a dirty target.property that includes active animation.
## Returns [code]{}[/code] when no ledger exists — effects fall back to
## target.property safely.
static func get_base_dict(target: Node) -> Dictionary:
	if target == null or not _store.has(target.get_instance_id()):
		return {}
	var ledger: Dictionary = _store[target.get_instance_id()]
	return ledger.get("base", {})


## Removes all deltas registered by [param source] from [param target]'s ledger.
## If [param permanently] is [code]true[/code] and no other sources remain,
## restores all base values and removes the ledger entry entirely.
## [param source] may be a Node or a Resource — any Object with [method get_instance_id].
static func cleanup_source(target: Node, source: Object, permanently: bool = true) -> void:
	var id := target.get_instance_id()
	if not _store.has(id): return
	var ledger: Dictionary = _store[id]
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
			# set_indexed() required for sub-path props ("modulate:a", etc.).
			target.set_indexed(prop, ledger["base"][prop])
		_store.erase(id)


## Immediately writes the combined value for all tracked (or specified) properties
## to the target node, using one of three accumulation strategies per type:
## [b]Additive[/b] (float, int, Vector2/2i/3/3i/4/4i, Quaternion): [code]base + Σdeltas[/code].
## [b]Multiplicative[/b] (Color): [code]base × Πfactors[/code].
## [b]Decomposed[/b] (Rect2, Rect2i, AABB): component-wise position + size sums.
## [b]Hold[/b] (bool, String, StringName, NodePath, Object, Plane, Basis, Projection):
## last-insertion-order active source wins; reverts to base when no holds remain.
## Called from [method _post_tick_write] every frame, and from
## [method _temporarily_undo_visual] / [method _temporarily_reapply_visual].
## [param props] restricts which properties are flushed. Empty = flush all tracked.
## All REMAINING sources (e.g. an active hover) are preserved.
static func flush(target: Node, props: Array[String] = []) -> void:
	if not _store.has(target.get_instance_id()): return
	var ledger: Dictionary = _store[target.get_instance_id()]
	var keys: Array = props if not props.is_empty() else ledger["base"].keys()
	for prop: String in keys:
		# Skip synthetic keys (e.g. "_appearance_factor") — not real Node properties.
		if prop.begins_with("_"): continue
		var base_val: Variant = ledger["base"].get(prop)
		if base_val == null: continue
		var delta_sources: Dictionary = ledger["deltas"].get(prop, {})
		var total_delta: Variant = zero_for(base_val)

		# --- Additive path: float, int, Vector2/2i/3/3i/4/4i, Quaternion ---
		# --- Multiplicative path: Color ---
		# zero_for() returns a non-null accumulator for these types.
		if total_delta != null:
			# Hoist type check outside loop — delta type never changes mid-iteration.
			# Key-iteration avoids the per-call Array allocation of .values().
			if typeof(total_delta) == TYPE_COLOR:
				for source_id in delta_sources:
					var c_tot := total_delta as Color
					var c_del := delta_sources[source_id] as Color
					total_delta = Color(c_tot.r * c_del.r, c_tot.g * c_del.g, c_tot.b * c_del.b, c_tot.a * c_del.a)
				var b := base_val as Color
				var t := total_delta as Color
				# set_indexed() required for sub-path props ("modulate:a", etc.).
				target.set_indexed(prop, Color(b.r * t.r, b.g * t.g, b.b * t.b, b.a * t.a))
			else:
				for source_id in delta_sources:
					total_delta += delta_sources[source_id]
				target.set_indexed(prop, base_val + total_delta)
			continue

		# --- Non-additive types: zero_for() returned null ---
		# Route by base_val type to the correct accumulation strategy.
		match typeof(base_val):
			# Decomposed continuous: Rect2/Rect2i/AABB have no GDScript + operator.
			# Component channels (position, size) are summed independently,
			# preserving additive stacking semantics across concurrent effects.
			TYPE_RECT2:
				var base_r := base_val as Rect2
				var dp := Vector2.ZERO
				var ds := Vector2.ZERO
				for source_id in delta_sources:
					var d := delta_sources[source_id] as Rect2
					dp += d.position
					ds += d.size
				target.set_indexed(prop, Rect2(base_r.position + dp, base_r.size + ds))
			TYPE_RECT2I:
				var base_ri := base_val as Rect2i
				var dpi := Vector2i.ZERO
				var dsi := Vector2i.ZERO
				for source_id in delta_sources:
					var d := delta_sources[source_id] as Rect2i
					dpi += d.position
					dsi += d.size
				target.set_indexed(prop, Rect2i(base_ri.position + dpi, base_ri.size + dsi))
			TYPE_AABB:
				var base_a := base_val as AABB
				var dp3 := Vector3.ZERO
				var ds3 := Vector3.ZERO
				for source_id in delta_sources:
					var d := delta_sources[source_id] as AABB
					dp3 += d.position
					ds3 += d.size
				target.set_indexed(prop, AABB(base_a.position + dp3, base_a.size + ds3))
			# Hold / flip-discrete: bool, String, StringName, NodePath, Object,
			# Plane, Basis, Projection. No arithmetic.
			# GDScript Dictionaries preserve insertion order — the last key iterated
			# is the most recently registered (newest) hold. When the newest ends
			# via cleanup_source(), the previous source's value automatically becomes last.
			_:
				if delta_sources.is_empty():
					target.set_indexed(prop, base_val)
				else:
					var last_hold: Variant = base_val
					for source_id in delta_sources:
						last_hold = delta_sources[source_id]
					target.set_indexed(prop, last_hold)


## Returns [code]true[/code] if [param target] has an active ledger.
## Quickly checks if a target is currently under Juice control without allocating.
static func has_ledger(target: Node) -> bool:
	return target != null and _store.has(target.get_instance_id())


## Returns the number of active ledger entries. For test verification only.
static func _store_entry_count() -> int:
	return _store.size()
