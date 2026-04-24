## A shareable collection of [JuiceEffectBase] resources.
##
## Recipes are the preset unit — drop a [code].tres[/code] onto a Juice node
## and get a complete visual behavior. Effects fire simultaneously unless
## linked via [member JuiceEffectBase.chain_to] references.

# ============================================================================
# WHAT: A shareable, savable collection of JuiceEffectBase resources.
# WHY: Recipes are the "preset" unit — drop a .tres onto a Juice node and get
#      a complete visual behavior. Marketplace-ready, copy-pasteable, reusable.
# SYSTEM: Juice System (addons/Juice_V1/)
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
	var original_chains: Array[Array] = []
	for effect in valid_effects:
		original_chains.append(effect.chain_to.duplicate())
		clones.append(effect.duplicate(true) as JuiceEffectBase)

	# Remap chain_to array references using the saved originals (not deep-copied refs)
	for i in clones.size():
		var remapped_array: Array[JuiceEffectBase] = []
		for original_chain in original_chains[i]:
			if original_chain == null:
				continue
			var chain_idx := valid_effects.find(original_chain)
			if chain_idx >= 0 and chain_idx < clones.size():
				remapped_array.append(clones[chain_idx])
		clones[i].chain_to = remapped_array

	return clones


## Get the indices of all "root" effects (those not chained FROM another effect).
## These are the entry points — they fire first when the recipe is triggered.
func get_root_effect_indices() -> Array[int]:
	var chained_targets: Array[JuiceEffectBase] = []
	for effect in effects:
		if effect != null:
			chained_targets.append_array(effect.chain_to)

	var roots: Array[int] = []
	for i in effects.size():
		if effects[i] != null and effects[i] not in chained_targets:
			roots.append(i)
	return roots


## Get total preview duration (longest chain path).
## Walks the chain_to graph recursively, summing durations along each path
## and subtracting chained_preroll overlap. Returns the longest path found.
## NOTE: Editor Transport port can rely on this returning accurate chain totals.
func get_total_preview_duration() -> float:
	if effects.is_empty():
		return 0.0
	var roots := get_root_effect_indices()
	if roots.is_empty():
		# All effects are chained to something — fall back to max individual
		var max_dur := 0.0
		for effect in effects:
			if effect != null:
				max_dur = maxf(max_dur, effect.get_total_preview_duration())
		return max_dur
	var longest := 0.0
	for root_idx in roots:
		longest = maxf(longest, _walk_chain_duration(effects[root_idx]))
	return longest


# Recursively compute the total duration of an effect plus its longest
# chained descendant path, accounting for chained_preroll overlap.
func _walk_chain_duration(effect: JuiceEffectBase) -> float:
	if effect == null:
		return 0.0
	var own := effect.get_total_preview_duration()
	if effect.chain_to.is_empty():
		return own
	var max_chained := 0.0
	for chained in effect.chain_to:
		if chained == null:
			continue
		var chained_dur := _walk_chain_duration(chained)
		# Preroll means the chained effect starts early — subtract that overlap
		var overlap := effect.chained_preroll if effect.chained_preroll > 0.0 else 0.0
		max_chained = maxf(max_chained, chained_dur - overlap)
	return own + max_chained
