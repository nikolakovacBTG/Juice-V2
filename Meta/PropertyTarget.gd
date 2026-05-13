## Binds an animation to a specific named property on the target node.
##
## Add one PropertyTarget per property you want to animate.
## Multiple PropertyTargets on one effect animate multiple properties simultaneously.

# ============================================================================
# WHAT: Thin resource that pairs a property name with a ledger registration call.
# WHY:  "Which property to animate" must be declared before the first tick so
#       the Ledger can capture the natural base value before any deltas land.
#       Separating the target declaration (PropertyTarget) from interpolation math
#       (InterpolatePropertyTarget) allows base classes to handle registration
#       uniformly without duplicating the ledger plumbing in every concrete effect.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Know how to compute from/to values or interpolation math — that is
#            the responsibility of concrete sub-resources (InterpolatePropertyTarget).
#            Does not hold animation state — stateless resource, safe to share.
# ============================================================================

@tool
class_name PropertyTarget
extends Resource

# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Target")

## The property name to animate (e.g. [code]"modulate"[/code],
## [code]"custom_minimum_size"[/code], [code]"visible"[/code]).
## Supports Godot property paths (e.g. [code]"position:x"[/code] for a single axis).
@export var property_path: String = ""

# =============================================================================
# PUBLIC API
# =============================================================================

## Registers [param property_path] in the Juice Ledger for [param host],
## recording its current value as the natural base before any deltas are applied.
## Must be called in [method _on_animate_start] before the first
## [method JuiceLedger.register_delta] or [method JuiceLedger.register_hold] call.
func capture_base(host: Node) -> void:
	if property_path.is_empty() or host == null:
		return
	JuiceLedger.ensure(host, [property_path])
