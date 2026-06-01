## Manages the animation lifecycle for a single JuiceBase node.
##
## Single class with a mode enum — PREVIEW and RUNTIME differ only in
## what happens on stop() and teardown(). Extends Node so _process runs
## natively in the scene tree and queue_free() handles cleanup automatically.
## The orchestrator is added as a child of its managed domain node.

# ============================================================================
# WHAT: Lifecycle container for one JuiceBase node's animation session.
# WHY:  Decouples lifecycle management from PreviewDirector (which manages lists
#       of nodes) and from JuiceBase (which owns the tick loop and ledger writes).
#       Extends Node (not Object) so _process runs natively and queue_free()
#       provides automatic scene-tree cleanup — no manual deferred freeing needed.
# SYSTEM: Juice V2 Editor (addons/Juice_V2/Editor/)
# DOES NOT: Permanently remove ledger entries on stop —
#           only cleanup_source(permanent=false) fires in _exit_tree. Domain nodes handle
#           permanent cleanup in NOTIFICATION_PREDELETE until Phase 5C-full removes them.
# ============================================================================

@tool
class_name JuiceOrchestrator
extends Node


# =============================================================================
# ENUMS
# =============================================================================

## Operating mode for this orchestrator instance.
## PREVIEW: editor-only playback — teardown() frees the orchestrator.
## RUNTIME: in-game playback — stop() keeps the orchestrator alive for reset().
enum Mode {
	PREVIEW,
	RUNTIME,
}


# =============================================================================
# INTERNAL STATE
# =============================================================================

# The JuiceBase node this orchestrator manages.
var _node: JuiceBase = null

# Recipe being played. Stored for Phase 5 when orchestrator owns cloning.
var _recipe: JuiceRecipe = null

# Target node (what gets animated). Stored for Phase 5 ledger registration.
var _target: Node = null

# Current mode — determines stop() and teardown() behavior.
var _mode: Mode = Mode.PREVIEW

# Debug flag — mirrors the managed node's debug_enabled by default.
var debug_enabled: bool = false

# Effect arrays for the active animation session.
# JuiceBase._runtime_effects and ._active_effect_indices are computed properties that
# delegate reads and writes here — all existing JuiceBase callers need no changes.
var runtime_effects: Array[JuiceEffectBase] = []
var active_effect_indices: Array[int] = []


# =============================================================================
# LIFECYCLE
# =============================================================================

# Drives one animation frame per scene-tree tick for both modes.
# STACK: full tick body inlined — arrays are local fields on this orch.
# SEQUENCER: calls _seq_process_tick() directly on the node (no tick() indirection).
func _process(delta: float) -> void:
	if not _is_node_valid():
		return

	# SEQUENCER: call the sequencer tick body directly.
	if _node.mode == JuiceBase.Mode.SEQUENCER:
		if _node._is_playing:
			_node._seq_process_tick(delta)
		return

	# No animation active — safe no-op every frame.
	if not _node._is_playing:
		return

	# Superseded guard: if this orchestrator has been replaced (e.g., PREVIEW orch
	# took over after director.select()), the node routes all array reads/writes
	# through the newer orch. Running here would call _on_all_effects_completed()
	# on our empty active_effect_indices, aborting any animation the newer orch drives.
	if _node._runtime_orchestrator != self:
		return

	# --- Node-level start_delay: hold before starting effects ---
	if _node._in_node_start_delay:
		_node._node_delay_elapsed += delta
		if _node._node_delay_elapsed < _node.start_delay:
			# Write base state every frame to beat Container re-sorts
			_node._post_tick_write()
			return
		_node._in_node_start_delay = false
		_node._start_effects(_node._pending_play_in)
		# Fall through to normal tick if effects started this frame

	# --- Iteration delay ---
	if _node._in_loop_delay:
		_node._loop_delay_elapsed += delta
		if _node._loop_delay_elapsed < _node.loop_delay:
			return
		_node._in_loop_delay = false
		_node._start_effects(true)
		return

	# --- Pre-tick: domain-specific external-move detection ---
	_node._pre_tick()

	# --- Tick all active effects ---
	var all_done := true
	var newly_completed: Array[int] = []

	for idx in active_effect_indices:
		if idx < 0 or idx >= runtime_effects.size():
			continue
		var effect := runtime_effects[idx]
		if effect == null or not effect.is_playing():
			continue

		all_done = false
		var result := effect.tick(delta, _node._target_node)
		if result == JuiceEffectBase.TickResult.COMPLETED:
			newly_completed.append(idx)
		elif result == JuiceEffectBase.TickResult.RESTART_REVERSED:
			# REVERSE_EASED accumulation: direction already flipped — restart easing from 0
			effect.start(_node._target_node, true, false, _node)

	# --- Chained preroll: start chained effects early for overlap ---
	for idx in active_effect_indices:
		if idx < 0 or idx >= runtime_effects.size():
			continue
		var effect := runtime_effects[idx]
		if effect == null or not effect.is_playing():
			continue
		if effect.chain_to.is_empty() or effect.chained_preroll <= 0.0:
			continue
		if effect._chained_preroll_triggered:
			continue
		if effect._get_time_to_completion() <= effect.chained_preroll:
			for chained_effect in effect.chain_to:
				var chain_idx := runtime_effects.find(chained_effect)
				if chain_idx >= 0 and chain_idx not in active_effect_indices:
					var chained := runtime_effects[chain_idx]
					if chained != null:
						var play_in := effect._animation_progress >= 0.5
						chained.start(_node._target_node, play_in, false, _node)
						active_effect_indices.append(chain_idx)
			effect._chained_preroll_triggered = true
			JuiceLogger.log_info(_node, _node._get_domain_tag(),
					"Chained preroll: effect %d \u2192 %d effects (%.2fs early)" % [
					idx, effect.chain_to.size(), effect.chained_preroll],
					debug_enabled)

	# --- Post-tick: domain-specific aggregation + write once ---
	_node._post_tick_write()

	# --- Handle completions ---
	for idx in newly_completed:
		_node._on_effect_completed(idx)

	# --- Check if ALL effects are done ---
	if all_done and not newly_completed.is_empty():
		_node._on_all_effects_completed()
	elif all_done and active_effect_indices.is_empty():
		_node._on_all_effects_completed()

	# Re-check: are ALL effects truly done?
	var any_playing := false
	for idx in active_effect_indices:
		if idx >= 0 and idx < runtime_effects.size():
			var eff := runtime_effects[idx]
			if eff != null and eff.is_playing():
				any_playing = true
				break

	if not any_playing and not _node._in_loop_delay:
		_node._on_all_effects_completed()



# Clean up the ledger source when this orchestrator is freed.
# Fires on queue_free() (animation complete, teardown, scene exit) — covers all normal paths.
# Domain nodes retain a PREDELETE fallback for abnormal exits (Phase 5C-full removes it).
func _exit_tree() -> void:
	if _target != null and is_instance_valid(_target) \
			and _node != null and is_instance_valid(_node):
		JuiceLedger.cleanup_source(_target, _node, false)
		JuiceLogger.log_info(self, "Orchestrator",
				"_exit_tree: ledger cleanup for target=%s" % _target.name,
				debug_enabled)


# =============================================================================
# PUBLIC API
# =============================================================================

## Configure this orchestrator for the given node and mode.
## Must be called before any play/stop/teardown calls.
## In Phase 4, stores references only — no cloning, no ledger registration.
func setup(node: JuiceBase, recipe: JuiceRecipe, target: Node, mode: Mode) -> void:
	_node   = node
	_recipe = recipe
	_target = target
	_mode   = mode
	debug_enabled = node.debug_enabled if node != null else false
	JuiceLogger.log_info(self, "Orchestrator",
			"setup() | node=%s | mode=%s" % [
			node.name if node else "null",
			"PREVIEW" if mode == Mode.PREVIEW else "RUNTIME"],
			debug_enabled)


## Full-fidelity play — routes through the trigger pipeline.
## Respects trigger_behaviour, start_delay, and retrigger policies.
## Use this for transport "Play" button (full recipe). Use play_in() for quick preview.
func play() -> void:
	if not _is_node_valid():
		return
	JuiceLogger.log_info(self, "Orchestrator", "play() → %s._handle_trigger(play_in)" % _node.name, debug_enabled)
	_node._handle_trigger({"play_in": true})


## Start the forward (IN) animation on the managed node.
## Delegates to JuiceBase.animate_in() — respects trigger_behaviour.
func play_in() -> void:
	if not _is_node_valid():
		return
	JuiceLogger.log_info(self, "Orchestrator", "play_in() → %s.animate_in()" % _node.name, debug_enabled)
	_node.animate_in()


## Start the reverse (OUT) animation on the managed node.
## Delegates to JuiceBase.animate_out() — respects trigger_behaviour.
func play_out() -> void:
	if not _is_node_valid():
		return
	JuiceLogger.log_info(self, "Orchestrator", "play_out() → %s.animate_out()" % _node.name, debug_enabled)
	_node.animate_out()


## Retrigger the animation without reallocating this orchestrator.
## RUNTIME only: stops the node and immediately restarts animate_in().
## This is the zero-allocation retrigger path — no new() call needed.
func reset() -> void:
	if not _is_node_valid():
		return
	if _mode != Mode.RUNTIME:
		JuiceLogger.warn(self, "Orchestrator",
				"reset() called on PREVIEW orchestrator — use teardown() instead.", debug_enabled)
		return
	JuiceLogger.log_info(self, "Orchestrator",
			"reset() → %s.stop() + animate_in() [zero-alloc retrigger]" % _node.name, debug_enabled)
	_node.stop()
	_node.animate_in()


## Stop the current animation.
## RUNTIME: stops the node, orchestrator stays alive (can reset() or teardown()).
## PREVIEW: stops the node, orchestrator is ready for teardown().
func stop() -> void:
	if not _is_node_valid():
		return
	JuiceLogger.log_info(self, "Orchestrator",
			"stop() → %s.stop() [mode=%s]" % [
			_node.name, "PREVIEW" if _mode == Mode.PREVIEW else "RUNTIME"],
			debug_enabled)
	_node.stop()


## Finalize this orchestrator: stop the node and free this object.
## Must be called for both PREVIEW and RUNTIME modes when the node is
## deselected, the game ends, or the node leaves the scene tree.
## After teardown(), this object is invalid — do not call any other methods.
func teardown() -> void:
	if _is_node_valid():
		JuiceLogger.log_info(self, "Orchestrator",
				"teardown() → %s.stop() + free()" % _node.name, debug_enabled)
		_node.stop()
		# Clear the node's orch reference so it doesn't hold a dangling pointer after free.
		if _node._runtime_orchestrator == self:
			_node._runtime_orchestrator = null
	else:
		JuiceLogger.log_info(self, "Orchestrator", "teardown() — node invalid, freeing anyway", debug_enabled)
	_node   = null
	_recipe = null
	_target = null
	# queue_free() is safe here: as a Node child, Godot handles scene-tree removal
	# cleanly. Callers can check is_instance_valid() in the same frame after teardown.
	queue_free()



# =============================================================================
# HELPERS
# =============================================================================

# Returns true if the managed node is still valid.
# Guards all delegation methods against freed or exited nodes.
func _is_node_valid() -> bool:
	return _node != null and is_instance_valid(_node)
