## Base class for all Juice effects that animate arbitrary named properties
## via the Juice Ledger's delta-accumulation system.
##
## Extend this class to create effects that animate any Godot property
## (e.g. [code]modulate[/code], [code]visible[/code], [code]custom_minimum_size[/code]).
## Subclasses override [method _compute_property_value] to provide per-frame values.

# ============================================================================
# WHAT: Base for Property-family effects. Manages per-frame Ledger registration
#       for an array of PropertyTarget sub-resources.
# WHY:  Transform effects are hard-coded into domain nodes because they require
#       axis-aware math (pivot compensation, container hold). Property effects
#       target user-defined property paths — they must discover and register
#       their targets dynamically at animation start.
#       Writing through the Ledger (register_delta / register_hold) guarantees
#       that concurrent property effects on the same target node stack correctly,
#       each with its own unique source ID (the Resource's instance ID).
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Know the specific property type or interpolation math — subclasses provide that.
#           Does not know about from/to capture — that is InterpolatePropertyTarget.
#           Does not handle transform properties (position, rotation, scale) — domain nodes own those.
# ============================================================================

@tool
class_name PropertyJuiceEffectBase
extends JuiceEffectBase


# =============================================================================
# CONFIGURATION
# =============================================================================

## Properties to animate. Each entry declares one named property on the target node.
## Multiple entries animate multiple properties simultaneously within one effect.
var property_targets: Array[PropertyTarget] = []

## When true, the subclass takes full ownership of _get_property_list().
## Noise / Shake bases set this so they can place noise/shake settings before
## the Property Targets array. The default layout (Effect header + timing + targets)
## is emitted only when this is false.
var _subclass_owns_prop_layout: bool = false


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

# Godot automatically merges _get_property_list() entries from every class
# in the hierarchy. PropertyJuiceEffectBase only needs to declare the
# additional properties it introduces (property_targets). JuiceEffectBase's
# own _get_property_list() continues to emit Effect/timing/debug fields.
func _get_property_list() -> Array[Dictionary]:
	if _subclass_owns_prop_layout:
		# Noise/Shake subclass emits everything itself including property_targets.
		# Return nothing here to avoid duplicates.
		return []
	var props: Array[Dictionary] = []
	# --- Property Targets typed array ---
	props.append({"name": "Property Targets", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({
		"name": "property_targets",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:%s" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE,
			_get_target_resource_type()],
		"usage": PROPERTY_USAGE_DEFAULT,
	})
	return props


func _set(property: StringName, value: Variant) -> bool:
	if property == &"property_targets":
		property_targets = value
		return true
	return false


func _get(property: StringName) -> Variant:
	if property == &"property_targets":
		return property_targets
	return null


# =============================================================================
# LIFECYCLE
# =============================================================================

# Called when animation starts. Registers all declared property paths in the
# Ledger so base values are captured before any deltas land.
func _on_animate_start(target: Node) -> void:
	for pt in property_targets:
		if pt != null:
			pt.capture_base(target)


# Removes this effect's Ledger contributions. Called when this specific effect
# ends (not necessarily when the whole animation stops).
# permanent=false: keeps the ledger entry and other sources' contributions intact;
# only THIS effect's deltas are removed. The domain's next flush() writes the
# correct stacked visual automatically.
func _restore_to_natural(target: Node) -> void:
	JuiceLedger.cleanup_source(target, self, false)


# Called before the scene file is saved to prevent Juice offsets being baked in.
# Direct restore_natural() on each entry writes the base value synchronously,
# bypassing the Ledger, because there is no _process() tick running at save time.
func _temporarily_undo_visual(_target: Node) -> void:
	for pt in property_targets:
		if pt != null:
			pt.restore_natural()


# Called immediately after the scene file is saved to restore the live effect.
# Re-registers deltas in the Ledger; the domain's _post_tick_write() flush
# that follows applies them to the node.
func _temporarily_reapply_visual(target: Node) -> void:
	_apply_effect(_animation_progress, target)


# =============================================================================
# PUBLIC API
# =============================================================================

## Override to compute the [b]desired absolute property value[/b] for [param prop]
## at [param progress]. Return what you want the property to equal — the base
## class converts this into whatever the Ledger needs (delta, factor, or hold).
##
## [b]Additive types[/b] (float, int, Vector*, Quaternion, Color): return the
## target value. The base class subtracts [param base_val] and registers the
## delta so the Ledger sums concurrent sources correctly.
## Color deltas are clamped to valid range in [method JuiceLedger.flush].
##
## [b]Decomposed types[/b] (Rect2, Rect2i, AABB): return the target value.
## The base class decomposes into position/size deltas for the Ledger.
##
## [b]Hold/flip types[/b] (bool, String, StringName, NodePath, Object,
## Plane, Basis, Projection): return the absolute target value.
##
## [param base_val] is the natural (pre-Juice) value from the Ledger.
## Read it to produce a meaningful target value without drift.
func _compute_property_value(_progress: float, _prop: String, base_val: Variant, _target: Node) -> Variant:
	return base_val  # Default: no-op. Subclass MUST override.


## Returns the class name string used to type the property_targets array in the inspector.
## Override in subclasses that use a specialised PropertyTarget subclass
## (e.g. [code]"InterpolatePropertyTarget"[/code]).
func _get_target_resource_type() -> String:
	return "PropertyTarget"


## Property effects bypass the sequencer's delta-sum mechanism because they write
## via the Ledger directly. Returning an empty dictionary signals this correctly.
func _get_seq_contribution() -> Dictionary:
	return {}


# =============================================================================
# CORE LOGIC
# =============================================================================

# Drives per-frame Ledger registration for all declared property targets.
# _compute_property_value() returns the ABSOLUTE desired value; this method
# converts it into the Ledger's required form per type:
#   • Hold/flip types  → register_hold (absolute value, newest wins)
#   • Rect2 / AABB     → register_delta (decomposed position+size offsets)
#   • All other types (float, Vector*, Quaternion, Color) → register_delta (desired - base additive delta)
func _apply_effect(progress: float, target: Node) -> void:
	for pt in property_targets:
		if pt == null or pt.property_path.is_empty():
			continue

		var base_val: Variant = JuiceLedger.get_base(target, pt.property_path, null)
		if base_val == null:
			# Ledger not primed — capture_base() should have run in _on_animate_start.
			# Guard gracefully against edge cases (e.g. target changed mid-animation).
			continue

		var desired: Variant = _compute_property_value(progress, pt.property_path, base_val, target)

		match typeof(base_val):

			TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME, \
			TYPE_NODE_PATH, TYPE_OBJECT, \
			TYPE_PLANE, TYPE_BASIS, TYPE_PROJECTION:
				# Hold/flip: newest active source's absolute value wins.
				JuiceLedger.register_hold(target, self, pt.property_path, desired)

			TYPE_RECT2:
				var f := desired as Rect2;  var b := base_val as Rect2
				JuiceLedger.register_delta(target, self, pt.property_path,
						Rect2(f.position - b.position, f.size - b.size))

			TYPE_RECT2I:
				var f := desired as Rect2i; var b := base_val as Rect2i
				JuiceLedger.register_delta(target, self, pt.property_path,
						Rect2i(f.position - b.position, f.size - b.size))

			TYPE_AABB:
				var f := desired as AABB;   var b := base_val as AABB
				JuiceLedger.register_delta(target, self, pt.property_path,
						AABB(f.position - b.position, f.size - b.size))

			_:
				# Generic additive: desired - base gives the offset to stack.
				# Covers float, int, Vector2/2i/3/3i/4/4i, Quaternion, Color.
				JuiceLedger.register_delta(target, self, pt.property_path, desired - base_val)


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if property_targets.is_empty():
		warnings.append("No Property Targets defined — this effect will not animate any properties.")
	for pt in property_targets:
		if pt != null:
			for w in pt.get_target_warnings():
				warnings.append(w)
	return warnings
