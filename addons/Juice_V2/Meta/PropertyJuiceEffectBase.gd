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
#           Does not know about from/to capture — that is InterpolatePropertyTarget (Phase 6.2).
#           Does not handle transform properties (position, rotation, scale) — domain nodes own those.
# ============================================================================

@tool
class_name PropertyJuiceEffectBase
extends JuiceEffectBase

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Properties")

## Properties to animate. Each entry declares one named property on the target node.
## Multiple entries animate multiple properties simultaneously within one effect.
@export var property_targets: Array[PropertyTarget] = []


# =============================================================================
# LIFECYCLE
# =============================================================================

# Called when animation starts (either direction). Registers all declared
# property paths in the Ledger so base values are captured before any deltas land.
func _on_animate_start(target: Node) -> void:
	for pt in property_targets:
		if pt != null:
			pt.capture_base(target)


# Removes this effect's Ledger contributions without restoring base values.
# permanently=false means the Ledger entry and other sources' contributions
# remain intact — only THIS effect's deltas are erased.
# The domain node's own cleanup_source (called on _exit_tree or full stop)
# handles the complete Ledger teardown for the node's own transform contributions.
func _restore_to_natural(target: Node) -> void:
	JuiceLedger.cleanup_source(target, self, false)

# =============================================================================
# PUBLIC API
# =============================================================================

## Override to compute the [b]desired absolute property value[/b] for [param prop]
## at [param progress]. Return what you want the property to equal — the base
## class converts this into whatever the Ledger needs (delta, factor, or hold).
##
## [b]Additive types[/b] (float, int, Vector*, Quaternion): return the
## target value. The base class subtracts [param base_val] and registers the
## delta so the Ledger sums concurrent sources correctly.
##
## [b]Color[/b]: return the target Color. The base class computes a
## multiplicative factor ([code]desired / base[/code]) so the Ledger's
## multiplicative-accumulation path writes the correct tinted result.
##
## [b]Decomposed types[/b] (Rect2, Rect2i, AABB): return the target value.
## The base class decomposes into position/size deltas for the Ledger.
##
## [b]Hold/flip types[/b] (bool, String, StringName, NodePath, Object,
## Plane, Basis, Projection): return the absolute target value. The Ledger
## writes the most-recently-registered active source's value each frame.
##
## [param base_val] is the natural (pre-Juice) value from the Ledger.
## Read it to produce a meaningful target value without stale drift.
func _compute_property_value(_progress: float, _prop: String, base_val: Variant, _target: Node) -> Variant:
	return base_val  # Default: no-op. Subclass MUST override.

# =============================================================================
# CORE LOGIC
# =============================================================================

# Drives per-frame Ledger registration for all declared property targets.
# Subclass _compute_property_value() returns the ABSOLUTE desired value;
# this method converts it into the Ledger's required form per type:
#   • Hold/flip types  → register_hold (absolute value, newest wins)
#   • Color            → register_delta (multiplicative factor: desired / base)
#   • Rect2 / AABB     → register_delta (decomposed position+size offsets)
#   • All other types  → register_delta (desired - base additive delta)
func _apply_effect(progress: float, target: Node) -> void:
	for pt in property_targets:
		if pt == null or pt.property_path.is_empty():
			continue

		var base_val: Variant = JuiceLedger.get_base(target, pt.property_path, null)
		if base_val == null:
			# Ledger not primed — capture_base() should have run in _on_animate_start,
			# but guard gracefully against edge cases (e.g. target changed mid-animation).
			continue

		# Subclass returns the absolute desired value.
		var desired: Variant = _compute_property_value(progress, pt.property_path, base_val, target)

		match typeof(base_val):

			TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME, \
			TYPE_NODE_PATH, TYPE_OBJECT, \
			TYPE_PLANE, TYPE_BASIS, TYPE_PROJECTION:
				# Hold/flip: newest active source's absolute value wins.
				JuiceLedger.register_hold(target, self, pt.property_path, desired)

			TYPE_COLOR:
				# Multiplicative: flush() writes base * Π(factors), so register
				# the ratio (desired / base) as the factor for this source.
				# EPS prevents division by zero on zero-channel bases.
				const EPS := 0.0001
				var b := base_val as Color
				var d := desired as Color
				JuiceLedger.register_delta(target, self, pt.property_path,
						Color(d.r / max(b.r, EPS), d.g / max(b.g, EPS),
							  d.b / max(b.b, EPS), d.a / max(b.a, EPS)))

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
				JuiceLedger.register_delta(target, self, pt.property_path, desired - base_val)


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if property_targets.is_empty():
		warnings.append("No Property Targets defined — this effect will not animate any properties.")
	for pt in property_targets:
		if pt != null and pt.property_path.is_empty():
			warnings.append("A PropertyTarget has an empty Property Path and will be skipped.")
	return warnings
