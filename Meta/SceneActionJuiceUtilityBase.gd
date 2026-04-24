## Scene management utility for designers.
##
## Handles scene switching, overlaying, reloading, and quitting with
## integrated transition effects. Domain-agnostic — no visual output.

# ============================================================================
# WHAT: Meta utility that triggers scene management actions when an animation
#       starts. Spawns an ephemeral orchestrator on scene root that handles
#       the full lifecycle independently.
# WHY:  Allows designers to build complete game flow purely in the inspector.
#       As a Resource in the recipe stack, it participates in chaining,
#       start_delay, and sequencing without custom scripting.
# SYSTEM: Juice System (addons/Juice_V1/Meta/)
# DOES NOT: Produce any visual effect — control/flow only.
# DOES NOT: Hold scene tree references persistently — NodePaths resolved at trigger.
# DOES NOT: Survive scene destruction — the orchestrator does that.
#
# TIMING ARCHITECTURE:
#   Animate In  = Cover transition   (screen hides)
#   hold_at_peak = Covered pause     (async loading, dramatic pause)
#   Animate Out = Reveal transition  (screen shows new content)
#   Effect's base class tick loop runs in parallel with orchestrator for chaining.
# ============================================================================

@tool
@icon("res://addons/Juice_V1/icons/JuiceUtilityMethods.svg")
class_name SceneActionJuiceUtilityBase
extends JuiceEffectBase

# Preload the orchestrator script (no class_name — internal only)
const _Orchestrator := preload("res://addons/Juice_V1/Meta/_JuiceSceneActionOrchestrator.gd")


# =============================================================================
# ENUMS
# =============================================================================

## Which scene management action to perform when triggered.
enum SceneAction {
	SWITCH_SCENE,    ## Replace current scene with target (irreversible)
	OVERLAY_SCENE,   ## Add target scene on top of current (reversible, toggle-friendly)
	RELOAD_SCENE,    ## Reload current scene from disk
	QUIT_GAME,       ## Quit the application
}

## Visual transition type played before/after the scene action.
enum TransitionOverlay {
	NONE,            ## Instant cut — no visual transition
	SOLID_COLOR,     ## Fade through solid color
	IMAGE,           ## Fade through image/texture
	SCENE,           ## Custom animated transition scene (user-provided PackedScene)
}

## Where to switch from when action is SWITCH_SCENE.
enum SwitchFrom {
	THIS_SCENE,              ## Replaces the entire current scene tree
	SCENE_IN_TREE,           ## Swaps a specific scene node in the tree
	FIRST_SCENE_IN_CONTAINER,## Swaps the first child of a parent container
}

## What happens to the old scene after the switch.
enum OldScenePostSwitchAction {
	FREE,            ## Permanently destroys the old scene.
	HIDE,            ## Keeps in tree, invisible and paused.
	REMOVE_FROM_TREE,## Detaches from tree; orchestrator holds reference.
}


# =============================================================================
# CONFIGURATION (all managed via _get_property_list / _set / _get)
# =============================================================================

# --- Scene Action ---
var action: int = SceneAction.SWITCH_SCENE:
	set(value):
		action = value
		notify_property_list_changed()

var from: int = SwitchFrom.THIS_SCENE:
	set(value):
		from = value
		notify_property_list_changed()

var switch_from_path: NodePath = NodePath()
var container_path: NodePath = NodePath()
var to: PackedScene = null
var old_scene_post_switch_action: int = OldScenePostSwitchAction.FREE

# --- Overlay Behavior (OVERLAY_SCENE only) ---
var overlay_canvas_layer: int = 100

var use_time_effect: bool = false:
	set(value):
		use_time_effect = value
		notify_property_list_changed()

var time_mode: int = 0:
	set(value):
		time_mode = value
		notify_property_list_changed()

var time_target_scale: float = 0.3
var time_smooth_transition: bool = true
var time_freeze_frames: int = 3
var time_exempt_nodes: Array[NodePath] = []

# --- Transition ---
var overlay_type: int = TransitionOverlay.NONE:
	set(value):
		overlay_type = value
		notify_property_list_changed()

var overlay_color: Color = Color.BLACK
var overlay_image: Texture2D = null
var overlay_blend_mode: int = 0
var transition_scene: PackedScene = null

var use_scene_timing: bool = true:
	set(value):
		use_scene_timing = value
		notify_property_list_changed()

var fallback_cover_duration: float = 0.5
var fallback_reveal_duration: float = 0.5


# =============================================================================
# CONDITIONAL EXPORT SYSTEM (_get_property_list + _set + _get)
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true
	# Default to PLAY_IN_AND_OUT so both cover and reveal timing groups appear
	trigger_behaviour = TriggerBehaviour.PLAY_IN_AND_OUT


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# --- Utility group (action config + base class trigger/start_delay) ---
	props.append({"name": "Utility", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	props.append({"name": "action", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Switch Scene,Overlay Scene,Reload Scene,Quit Game",
		"usage": PROPERTY_USAGE_DEFAULT})

	if action == SceneAction.SWITCH_SCENE:
		props.append({"name": "from", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "This Scene,Scene In Tree,First Scene In Container",
			"usage": PROPERTY_USAGE_DEFAULT})

		if from == SwitchFrom.SCENE_IN_TREE:
			props.append({"name": "switch_from_path", "type": TYPE_NODE_PATH,
				"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES, "hint_string": "Node",
				"usage": PROPERTY_USAGE_DEFAULT})

		if from == SwitchFrom.FIRST_SCENE_IN_CONTAINER:
			props.append({"name": "container_path", "type": TYPE_NODE_PATH,
				"hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES, "hint_string": "Node",
				"usage": PROPERTY_USAGE_DEFAULT})

	if action == SceneAction.SWITCH_SCENE or action == SceneAction.OVERLAY_SCENE:
		props.append({"name": "to", "type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "PackedScene",
			"usage": PROPERTY_USAGE_DEFAULT})

	if action == SceneAction.SWITCH_SCENE and from != SwitchFrom.THIS_SCENE:
		props.append({"name": "old_scene_post_switch_action", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Free,Hide,Remove From Tree",
			"usage": PROPERTY_USAGE_DEFAULT})

	# Base class properties (trigger_behaviour, start_delay) inside Utility group
	props.append_array(_get_effect_base_properties())

	# --- Overlay Behavior group (OVERLAY_SCENE only) ---
	if action == SceneAction.OVERLAY_SCENE:
		props.append({"name": "Overlay Behavior", "type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

		props.append({"name": "overlay_canvas_layer", "type": TYPE_INT,
			"usage": PROPERTY_USAGE_DEFAULT})

		props.append({"name": "use_time_effect", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})

		if use_time_effect:
			props.append({"name": "time_mode", "type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM, "hint_string": "Freeze,Slow Mo,Bullet Time",
				"usage": PROPERTY_USAGE_DEFAULT})

			if time_mode != 0:  # Not FREEZE
				props.append({"name": "time_target_scale", "type": TYPE_FLOAT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,2.0,0.01",
					"usage": PROPERTY_USAGE_DEFAULT})
				props.append({"name": "time_smooth_transition", "type": TYPE_BOOL,
					"usage": PROPERTY_USAGE_DEFAULT})

			if time_mode == 0:  # FREEZE
				props.append({"name": "time_freeze_frames", "type": TYPE_INT,
					"hint": PROPERTY_HINT_RANGE, "hint_string": "1,600,1,or_greater",
					"usage": PROPERTY_USAGE_DEFAULT})

			if time_mode == 2:  # BULLET_TIME
				props.append({"name": "time_exempt_nodes", "type": TYPE_ARRAY,
					"hint": PROPERTY_HINT_TYPE_STRING, "hint_string": "%d:" % TYPE_NODE_PATH,
					"usage": PROPERTY_USAGE_DEFAULT})

	# --- Transition group (visible for ALL actions — transition applies to switch/reload/quit too) ---
	props.append({"name": "Transition", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})

	props.append({"name": "overlay_type", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "None,Solid Color,Image,Scene",
		"usage": PROPERTY_USAGE_DEFAULT})

	if overlay_type == TransitionOverlay.SOLID_COLOR or overlay_type == TransitionOverlay.IMAGE:
		props.append({"name": "overlay_color", "type": TYPE_COLOR,
			"usage": PROPERTY_USAGE_DEFAULT})

	if overlay_type == TransitionOverlay.IMAGE:
		props.append({"name": "overlay_image", "type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "Texture2D",
			"usage": PROPERTY_USAGE_DEFAULT})

	if overlay_type == TransitionOverlay.SOLID_COLOR or overlay_type == TransitionOverlay.IMAGE:
		props.append({"name": "overlay_blend_mode", "type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM, "hint_string": "Mix,Add,Sub,Mul,Premult Alpha",
			"usage": PROPERTY_USAGE_DEFAULT})

	if overlay_type == TransitionOverlay.SCENE:
		props.append({"name": "transition_scene", "type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE, "hint_string": "PackedScene",
			"usage": PROPERTY_USAGE_DEFAULT})

		props.append({"name": "use_scene_timing", "type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT})

		if not use_scene_timing:
			props.append({"name": "fallback_cover_duration", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,10.0,0.05,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
			props.append({"name": "fallback_reveal_duration", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,10.0,0.05,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"action": action = value; return true
		&"from": from = value; return true
		&"switch_from_path": switch_from_path = value; return true
		&"container_path": container_path = value; return true
		&"to": to = value; return true
		&"old_scene_post_switch_action": old_scene_post_switch_action = value; return true
		&"overlay_canvas_layer": overlay_canvas_layer = value; return true
		&"use_time_effect": use_time_effect = value; return true
		&"time_mode": time_mode = value; return true
		&"time_target_scale": time_target_scale = value; return true
		&"time_smooth_transition": time_smooth_transition = value; return true
		&"time_freeze_frames": time_freeze_frames = value; return true
		&"time_exempt_nodes": time_exempt_nodes = value; return true
		&"overlay_type": overlay_type = value; return true
		&"overlay_color": overlay_color = value; return true
		&"overlay_image": overlay_image = value; return true
		&"overlay_blend_mode": overlay_blend_mode = value; return true
		&"transition_scene": transition_scene = value; return true
		&"use_scene_timing": use_scene_timing = value; return true
		&"fallback_cover_duration": fallback_cover_duration = value; return true
		&"fallback_reveal_duration": fallback_reveal_duration = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"action": return action
		&"from": return from
		&"switch_from_path": return switch_from_path
		&"container_path": return container_path
		&"to": return to
		&"old_scene_post_switch_action": return old_scene_post_switch_action
		&"overlay_canvas_layer": return overlay_canvas_layer
		&"use_time_effect": return use_time_effect
		&"time_mode": return time_mode
		&"time_target_scale": return time_target_scale
		&"time_smooth_transition": return time_smooth_transition
		&"time_freeze_frames": return time_freeze_frames
		&"time_exempt_nodes": return time_exempt_nodes
		&"overlay_type": return overlay_type
		&"overlay_color": return overlay_color
		&"overlay_image": return overlay_image
		&"overlay_blend_mode": return overlay_blend_mode
		&"transition_scene": return transition_scene
		&"use_scene_timing": return use_scene_timing
		&"fallback_cover_duration": return fallback_cover_duration
		&"fallback_reveal_duration": return fallback_reveal_duration
	return null


func _validate_property(property: Dictionary) -> void:
	var prop_name := StringName(property.name)
	var is_destructive := _is_destructive_action()

	# --- Hide chaining for destructive actions ---
	if prop_name in [&"chain_to", &"interrupt_siblings", &"chained_preroll"]:
		if is_destructive:
			property.usage = PROPERTY_USAGE_NO_EDITOR

	# --- Hide looping/crossfade (meaningless for one-shot fire-and-forget) ---
	if prop_name in [&"crossfade_time", &"loop_count", &"ping_pong",
			&"loop_delay", &"loop_phase_offset"]:
		property.usage = PROPERTY_USAGE_NO_EDITOR


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

## Resolves NodePaths from the inspector, stamps all config onto a new orchestrator,
## and spawns it on the scene tree root (deferred). Fire-and-forget — the orchestrator
## manages the full cover → action → reveal lifecycle independently.
func _on_animate_start(target: Node) -> void:
	if Engine.is_editor_hint():
		return

	# Resolve NodePaths now (while host node is alive) and spawn orchestrator
	var orchestrator := _Orchestrator.new()

	# --- Copy scene action config ---
	orchestrator.scene_action = action
	orchestrator.switch_from_mode = from
	orchestrator.target_scene = to
	orchestrator.old_scene_post_switch_action = old_scene_post_switch_action

	# --- Resolve node references ---
	if _host_node != null:
		if from == SwitchFrom.SCENE_IN_TREE and not switch_from_path.is_empty():
			orchestrator.switch_from_node = _host_node.get_node_or_null(switch_from_path)
		if from == SwitchFrom.FIRST_SCENE_IN_CONTAINER and not container_path.is_empty():
			orchestrator.container_node = _host_node.get_node_or_null(container_path)

	# --- Copy overlay behavior ---
	orchestrator.overlay_canvas_layer = overlay_canvas_layer
	orchestrator.use_time_effect = use_time_effect
	orchestrator.time_mode = time_mode
	orchestrator.time_target_scale = time_target_scale
	orchestrator.time_smooth_transition = time_smooth_transition
	orchestrator.time_freeze_frames = time_freeze_frames
	orchestrator.time_exempt_nodes = time_exempt_nodes

	# --- Copy transition config ---
	orchestrator.overlay_type = overlay_type
	orchestrator.overlay_color = overlay_color
	orchestrator.overlay_image = overlay_image
	orchestrator.overlay_blend_mode = overlay_blend_mode
	orchestrator.transition_scene = transition_scene
	orchestrator.use_scene_timing = use_scene_timing
	orchestrator.fallback_cover_duration = fallback_cover_duration
	orchestrator.fallback_reveal_duration = fallback_reveal_duration

	# --- Copy timing from base class Animate In/Out = cover/reveal ---
	orchestrator.cover_duration = duration_in
	orchestrator.cover_transition = transition_in
	orchestrator.cover_ease = ease_in
	orchestrator.cover_curve = custom_curve_in
	orchestrator.hold_duration = hold_at_peak
	orchestrator.reveal_duration = duration_out
	orchestrator.reveal_transition = transition_out
	orchestrator.reveal_ease = ease_out
	orchestrator.reveal_curve = custom_curve_out

	# --- Debug ---
	orchestrator.debug_enabled = debug_enabled

	# --- Spawn on tree root (deferred — _on_animate_start may fire during _ready chain) ---
	var tree_root: Node = null
	if _host_node != null and _host_node.is_inside_tree():
		tree_root = _host_node.get_tree().root
	elif target != null and target.is_inside_tree():
		tree_root = target.get_tree().root

	if tree_root == null:
		push_error("[SceneAction] Cannot spawn orchestrator — no valid tree access")
		orchestrator.free()
		return

	# Deferred add + execute: the tree may be busy setting up children during
	# _ready(). Deferring ensures the orchestrator is fully in-tree before
	# execute() calls get_tree(), add_child(), etc.
	tree_root.add_child.call_deferred(orchestrator)
	orchestrator.execute.call_deferred()

	if debug_enabled:
		print("[SceneAction] Orchestrator spawn deferred to root — fire and forget")


func _apply_effect(_progress: float, _target: Node) -> void:
	pass  # No visual output — orchestrator handles everything.


func _supports_editor_preview() -> bool:
	return false


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if (action == SceneAction.SWITCH_SCENE or action == SceneAction.OVERLAY_SCENE) \
			and to == null:
		warnings.append("To scene is not set. No scene will be loaded.")

	if action == SceneAction.SWITCH_SCENE and from == SwitchFrom.SCENE_IN_TREE:
		if switch_from_path.is_empty():
			warnings.append("Scene In Tree mode requires switch_from_path to be set.")

	if action == SceneAction.SWITCH_SCENE and from == SwitchFrom.FIRST_SCENE_IN_CONTAINER:
		if container_path.is_empty():
			warnings.append("First Scene In Container mode requires container_path to be set.")

	if overlay_type == TransitionOverlay.SCENE and transition_scene == null:
		warnings.append("overlay_type is SCENE but transition_scene is not set.")

	return warnings


# =============================================================================
# HELPERS
# =============================================================================

# Returns true if the current action config destroys the host scene.
func _is_destructive_action() -> bool:
	if action == SceneAction.RELOAD_SCENE or action == SceneAction.QUIT_GAME:
		return true
	if action == SceneAction.SWITCH_SCENE and from == SwitchFrom.THIS_SCENE:
		return true
	return false
