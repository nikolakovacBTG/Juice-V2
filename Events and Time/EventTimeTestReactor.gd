## EventTimeTestReactor.gd
## ============================================================================
## WHAT: Test helper that reacts to CallMethodJuiceUtility and SignalEmitJuiceUtility.
## WHY: Provides visual/debug verification that control flow comps fire correctly.
##      Triggers all child JuiceCompBase comps when react() is called or when
##      a sibling SignalEmitJuiceUtility emits juice_signal.
## SYSTEM: Juicing System — Test Infrastructure
## DOES NOT: Provide any game functionality. Test-only script.
## ============================================================================
##
## AUTO-CONNECT:
##   In _ready(), this script walks up the ancestor chain and searches each
##   ancestor's children for SignalEmitJuiceUtility nodes. Stops at the first
##   ancestor level where at least one is found. This means the reactor can
##   be nested inside a container (e.g. ReactorRect) while the SignalEmit
##   is a sibling of that container — no manual signal wiring needed.
##
## USAGE:
## - Attach to any test node (ColorRect, Sprite2D, MeshInstance3D, etc.)
## - Add child JuiceCompBase comps for visual feedback (scale, color, etc.)
## - CallMethodJuiceUtility calls react() on this node
## - SignalEmitJuiceUtility auto-connects via sibling discovery
## ============================================================================

@tool
extends Node

@export var debug_enabled: bool = true

func _ready() -> void:
	if debug_enabled:
		print("[%s] _ready() running (tool=%s)" % [name, Engine.is_editor_hint()])
	# Auto-discover and connect to any SignalEmitJuiceUtility in the ancestor chain.
	# Searches parent, grandparent, etc. children so the reactor doesn't need to
	# be a direct sibling of the SignalEmit comp. This covers scene layouts where
	# the reactor is nested inside a container (e.g. ReactorRect) while the
	# SignalEmit is a sibling of that container.
	# Uses type-safe discovery (is operator) per project standards.
	var search_node := get_parent()
	while search_node != null:
		var found_any := false
		for child in search_node.get_children():
			if child is SignalEmitJuiceUtility:
				if not child.juice_signal.is_connected(on_juice_signal):
					child.juice_signal.connect(on_juice_signal)
					found_any = true
					if debug_enabled:
						print("[%s] Auto-connected to %s.juice_signal" % [name, child.name])
		if found_any:
			break
		search_node = search_node.get_parent()


## Called by CallMethodJuiceUtility — triggers all child juice comps.
func react() -> void:
	if debug_enabled:
		print("[%s] react() called!" % name)
	_trigger_children()


## Called by SignalEmitJuiceUtility's juice_signal — triggers all child juice comps.
func on_juice_signal(payload: Variant) -> void:
	if debug_enabled:
		print("[%s] juice_signal received! Payload: %s" % [name, payload])
	_trigger_children()


## Trigger nearby JuiceCompBase instances (visual feedback).
## Searches own children first, then parent's children (siblings) as fallback.
## This handles both layouts: juice comps as children of this node, or as siblings
## under the same parent container (e.g. ReactorRect).
func _trigger_children() -> void:
	var triggered := false
	# First: own children
	for child in get_children():
		if child is JuiceCompBase:
			child.animate_in()
			triggered = true
			if debug_enabled:
				print("[%s] Triggered child: %s" % [name, child.name])
	# Fallback: siblings (parent's children)
	if not triggered and get_parent():
		for sibling in get_parent().get_children():
			if sibling != self and sibling is JuiceCompBase:
				sibling.animate_in()
				triggered = true
				if debug_enabled:
					print("[%s] Triggered sibling: %s" % [name, sibling.name])
	if not triggered and debug_enabled:
		push_warning("[%s] No JuiceCompBase children or siblings found to trigger" % name)
