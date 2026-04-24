## Routes interaction signals to designated Juice nodes based on trigger behaviors.
## ============================================================================
## WHAT: Stateless signal wiring utilities for JuiceBase.
## WHY:  Extracts the signal-routing algorithm out of JuiceBase so it can be
##       read, modified and tested without wading through 2000 lines of lifecycle
##       code. All methods are pure static functions — zero coupling to JuiceBase.
## SYSTEM: Juice System (addons/Juice_V1/)
## DOES NOT: Hold state, own connections, or touch JuiceBase internals.
## ============================================================================

class_name JuiceTriggerRouter


# =============================================================================
# PUBLIC API
# =============================================================================

## Inspect [param sig_name]'s argument list on [param source] and return the
## correct [Callable] to connect for a MANUAL trigger.
##
## Routing rules:
##  - 0 args       → [param on_momentary]           (one-shot, no args needed)
##  - 1 float arg  → [param on_progress]             (continuous progress drive)
##  - N other args → [param on_momentary].unbind(N)  (strip args, treat as momentary)
##
## This makes MANUAL trigger universally safe — any signal from any source works,
## including [signal SoftTrigger2DJuiceUtility.progress_changed], without crashing.
static func resolve_manual_callable(
	source: Object,
	sig_name: StringName,
	on_momentary: Callable,
	on_progress: Callable,
	debug_label: String = "",
) -> Callable:
	var sig_args: Array = []
	for sig in source.get_signal_list():
		if sig["name"] == sig_name:
			sig_args = sig.get("args", [])
			break

	if not debug_label.is_empty():
		print("[%s] TriggerRouter.resolve_manual_callable: signal='%s' | arg_count=%d | types=%s" % [
			debug_label, sig_name, sig_args.size(),
			sig_args.map(func(a): return type_string(a.get("type", TYPE_NIL)))])

	# Case 1: zero-arg signal → standard momentary trigger
	if sig_args.is_empty():
		if not debug_label.is_empty():
			print("[%s]   → routing to on_momentary (0 args)" % debug_label)
		return on_momentary

	# Case 2: single float arg → drive external progress directly
	if sig_args.size() == 1 and sig_args[0].get("type", -1) == TYPE_FLOAT:
		if not debug_label.is_empty():
			print("[%s]   → routing to on_progress (float arg)" % debug_label)
		return on_progress

	# Case 3: any other signature → strip all args, treat as momentary
	if not debug_label.is_empty():
		print("[%s]   → routing to on_momentary.unbind(%d)" % [debug_label, sig_args.size()])
	return on_momentary.unbind(sig_args.size())


## Connect [signal Node.visibility_changed] on [param source] to [param on_changed].
## Works for both [CanvasItem] and [Node3D] without domain-specific knowledge.
static func connect_visibility(source: Node, on_changed: Callable) -> void:
	if source.has_signal("visibility_changed"):
		if not source.is_connected("visibility_changed", on_changed):
			source.connect("visibility_changed", on_changed)


## Wire a MANUAL trigger signal on [param source] to the correct callable,
## resolved via [method resolve_manual_callable]. No-op if [param sig_name]
## does not exist on [param source].
static func wire_manual(
	source: Node,
	sig_name: StringName,
	on_momentary: Callable,
	on_progress: Callable,
	debug_label: String = "",
) -> void:
	if not source.has_signal(sig_name):
		return
	var target := resolve_manual_callable(source, sig_name, on_momentary, on_progress, debug_label)
	if not source.is_connected(sig_name, target):
		source.connect(sig_name, target)
