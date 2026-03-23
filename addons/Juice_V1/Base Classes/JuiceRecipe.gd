## A shareable collection of [JuiceEffectBase] resources.
##
## Recipes are the preset unit — drop a [code].tres[/code] onto a Juice node
## and get a complete visual behavior. Effects fire simultaneously unless
## linked via [member JuiceEffectBase.chain_to] references.

# ============================================================================
# WHAT: A shareable, savable collection of JuiceEffectBase resources.
# WHY: Recipes are the "preset" unit — drop a .tres onto a Juice node and get
#      a complete visual behavior. Marketplace-ready, copy-pasteable, reusable.
# SYSTEM: Juicing System (addons/Juice_V1/)
# DOES NOT: Execute effects — the host node (JuiceControl etc.) does that.
# DOES NOT: Own animation state — effects hold their own state per-instance.
# ============================================================================
#
# USAGE:
# 1. Create a JuiceRecipe resource (.tres)
# 2. Add JuiceEffectBase sub-resources to the effects array
# 3. Assign the recipe to a Juice node's recipe property
# 4. The node clones effects at runtime for independent state
#
# CHAINING:
# Effects in the array can reference each other via chain_to.
# Unchained effects fire simultaneously on trigger.
# Array order is IRRELEVANT for execution — chain pointers define ordering.
# ============================================================================

@tool
class_name JuiceRecipe
extends Resource

# =============================================================================
# CONFIGURATION
# =============================================================================

## The effects that make up this recipe.
## Each effect is a JuiceEffectBase sub-resource with its own timing and config.
## Effects fire simultaneously unless linked via chain_to references.
@export var effects: Array[JuiceEffectBase] = []

# =============================================================================
# PUBLIC API
# =============================================================================

## Create runtime-independent copies of all effects.
## Each host node gets its own cloned set so animation state is independent.
## This is critical when the same recipe .tres is shared across multiple nodes.
func create_runtime_effects() -> Array[JuiceEffectBase]:
	# Filter out null slots — users may leave empty slots in the inspector.
	var valid_effects: Array[JuiceEffectBase] = []
	for effect in effects:
		if effect != null:
			valid_effects.append(effect)

	var clones: Array[JuiceEffectBase] = []
	# Save original chain_to refs BEFORE deep duplicate replaces them with copies
	var original_chains: Array[JuiceEffectBase] = []
	for effect in valid_effects:
		original_chains.append(effect.chain_to)
		clones.append(effect.duplicate(true) as JuiceEffectBase)

	# Remap chain_to references using the saved originals (not deep-copied refs)
	for i in clones.size():
		if original_chains[i] == null:
			clones[i].chain_to = null
			continue
		var chain_idx := valid_effects.find(original_chains[i])
		if chain_idx >= 0 and chain_idx < clones.size():
			clones[i].chain_to = clones[chain_idx]
		else:
			clones[i].chain_to = null  # Broken reference, clear it

	return clones


## Get the indices of all "root" effects (those not chained FROM another effect).
## These are the entry points — they fire first when the recipe is triggered.
func get_root_effect_indices() -> Array[int]:
	var chained_targets: Array[JuiceEffectBase] = []
	for effect in effects:
		if effect != null and effect.chain_to != null:
			chained_targets.append(effect.chain_to)

	var roots: Array[int] = []
	for i in effects.size():
		if effects[i] != null and effects[i] not in chained_targets:
			roots.append(i)
	return roots


## Get total preview duration (longest chain path).
func get_total_preview_duration() -> float:
	if effects.is_empty():
		return 0.0
	# Simple approximation: max of all individual effect durations
	# TODO: Proper chain-walk for accurate total with chaining
	var max_dur := 0.0
	for effect in effects:
		if effect != null:
			max_dur = maxf(max_dur, effect.get_total_preview_duration())
	return max_dur
