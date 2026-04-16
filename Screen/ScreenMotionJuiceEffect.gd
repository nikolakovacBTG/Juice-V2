## Animates screen UV offset, rotation, or zoom via ScreenJuiceUtility.
##
## Drop in any domain recipe on any entity — chest, enemy, explosion, UI button.
## On trigger, discovers (or auto-creates) ScreenJuiceUtility and writes accumulated
## deltas to a full-screen post-process shader, affecting the entire rendered output.

# ============================================================================
# WHAT: Domain-agnostic meta effect for full-screen camera-space motion:
#       UV offset (positional shake/push), rotation (screen tilt), zoom (punch).
# WHY:  Screen effects should be authored on the entity that triggers them, not
#       on a camera or global node. This effect self-discovers the single screen
#       utility and writes deltas additively — multiple simultaneous effects stack
#       correctly at zero coupling cost.
# SYSTEM: Juice System (addons/Juice_V1/Screen/)
# DOES NOT: Animate the host entity's transform — writes to ScreenJuiceUtility only.
# DOES NOT: Handle per-layer effects or depth-sensitive compositing.
# DOES NOT: Run in the editor — auto-bootstrap would overlay the Godot editor UI.
#           Camera/Screen editor preview is a Transport responsibility (see tracker).
# DOES NOT: Require manual scene setup — ScreenJuiceUtility is auto-created at
#           runtime on first use. Manual placement is respected as an opt-in.
#
# STACKING: Delta-first write pattern. Each effect tracks its own contribution
#           (_my_offset etc.) and writes only the change per frame. Multiple effects
#           on different entities accumulate cleanly on the single utility receiver.
# ============================================================================

@tool
class_name ScreenMotionJuiceEffect
extends JuiceEffectBase


# =============================================================================
# ENUMS
# =============================================================================

## Which screen property to animate.
enum Channel {
	OFFSET,    ## UV offset — positional shake, kick, push. Normalized coords (~0.01–0.05).
	ROTATION,  ## Screen rotation — tilt, disorientation. Degrees.
	ZOOM,      ## Screen zoom — punch zoom, breathe. Linear scale offset (~0.05–0.3).
}


# =============================================================================
# CONFIGURATION
# =============================================================================

## Which screen channel to animate.
var channel: int = Channel.OFFSET:
	set(value):
		channel = value
		notify_property_list_changed()

## UV offset at progress=1.0 (normalized screen coords).
## Typical range: -0.05 to 0.05. X=horizontal, Y=vertical.
var screen_offset: Vector2 = Vector2(0.02, 0.0)

## Screen rotation offset at progress=1.0 (degrees).
## Typical range: -5.0 to 5.0.
var screen_rotation_degrees: float = 2.0

## Screen zoom offset at progress=1.0 (linear scale added to 1.0).
## Positive = zoom in. Typical range: -0.2 to 0.2.
var screen_zoom_offset: float = 0.05


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _init() -> void:
	_subclass_owns_effect_group = true


func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	props.append({"name": "Screen Motion Effect", "type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP, "hint_string": ""})
	props.append({"name": "channel", "type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM, "hint_string": "Offset,Rotation,Zoom",
		"usage": PROPERTY_USAGE_DEFAULT})

	match channel:
		Channel.OFFSET:
			props.append({"name": "screen_offset", "type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.ROTATION:
			props.append({"name": "screen_rotation_degrees", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "-45.0,45.0,0.1,or_less,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})
		Channel.ZOOM:
			props.append({"name": "screen_zoom_offset", "type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE, "hint_string": "-1.0,1.0,0.01,or_less,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT})

	props.append_array(_get_effect_base_properties())
	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"channel":                  channel = value;               return true
		&"screen_offset":            screen_offset = value;         return true
		&"screen_rotation_degrees":  screen_rotation_degrees = value; return true
		&"screen_zoom_offset":       screen_zoom_offset = value;    return true
	return super._set(property, value)


func _get(property: StringName) -> Variant:
	match property:
		&"channel":                  return channel
		&"screen_offset":            return screen_offset
		&"screen_rotation_degrees":  return screen_rotation_degrees
		&"screen_zoom_offset":       return screen_zoom_offset
	return super._get(property)


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Delta-first contribution tracking — what THIS effect has written to the utility.
## Tracked separately per channel to isolate our contribution for clean removal.
var _my_offset:   Vector2 = Vector2.ZERO
var _my_rotation: float   = 0.0
var _my_zoom:     float   = 0.0


# =============================================================================
# VIRTUAL METHOD OVERRIDES
# =============================================================================

func _apply_effect(progress: float, _target: Node) -> void:
	# Re-discover (or bootstrap) utility every frame.
	# O(1) static read — no scene scanning cost.
	var util := _find_or_create_utility()
	if not is_instance_valid(util):
		return

	match channel:
		Channel.OFFSET:   _apply_offset(util, progress)
		Channel.ROTATION: _apply_rotation(util, progress)
		Channel.ZOOM:     _apply_zoom(util, progress)


func _on_animate_out_complete(_target: Node) -> void:
	_remove_contribution()


func _restore_to_natural(_target: Node) -> void:
	# Called by stop(). Remove our contribution immediately.
	_remove_contribution()


# =============================================================================
# CHANNEL APPLY
# =============================================================================

func _apply_offset(util: ScreenJuiceUtility, progress: float) -> void:
	var desired := screen_offset * progress
	var delta   := desired - _my_offset
	util.offset += delta
	_my_offset = desired


func _apply_rotation(util: ScreenJuiceUtility, progress: float) -> void:
	var desired := deg_to_rad(screen_rotation_degrees) * progress
	var delta   := desired - _my_rotation
	util.rotation_amount += delta
	_my_rotation = desired


func _apply_zoom(util: ScreenJuiceUtility, progress: float) -> void:
	var desired := screen_zoom_offset * progress
	var delta   := desired - _my_zoom
	util.zoom_offset += delta
	_my_zoom = desired


# =============================================================================
# CONTRIBUTION CLEANUP
# =============================================================================

func _remove_contribution() -> void:
	# Try to undo what we wrote. If utility is gone, just reset tracking.
	var util := _find_or_create_utility()
	if is_instance_valid(util):
		util.offset          -= _my_offset
		util.rotation_amount -= _my_rotation
		util.zoom_offset     -= _my_zoom
	_my_offset   = Vector2.ZERO
	_my_rotation = 0.0
	_my_zoom     = 0.0


# =============================================================================
# UTILITY DISCOVERY + AUTO-BOOTSTRAP
# =============================================================================

## Returns the ScreenJuiceUtility, creating one if absent.
## O(1) — just a static variable read. No scene scanning.
## Returns null in the editor (would overlay Godot's editor UI via root CanvasLayer).
func _find_or_create_utility() -> ScreenJuiceUtility:
	# Guard: never auto-create in editor.
	# SceneTree.root in editor = Godot's own editor window.
	# A CanvasLayer there would overlay panels, menus, everything.
	# Camera/Screen editor preview is a Transport responsibility — see tracker.
	if Engine.is_editor_hint():
		return null

	if is_instance_valid(ScreenJuiceUtility.instance):
		return ScreenJuiceUtility.instance

	# Utility is absent — auto-bootstrap one at the scene tree root.
	# Parented to root (not the current scene) so it survives scene transitions.
	return _bootstrap_utility()


## Creates a CanvasLayer at root and adds a ScreenJuiceUtility to it.
## Only called once — subsequent calls reuse the static instance.
func _bootstrap_utility() -> ScreenJuiceUtility:
	if not is_instance_valid(_host_node):
		return null

	# CanvasLayer at root: layer=128 renders above all game content, below debug overlays.
	var canvas := CanvasLayer.new()
	canvas.name = "JuiceScreenLayer"
	canvas.layer = 128
	_host_node.get_tree().root.add_child(canvas)

	# ColorRect + shader.
	var util := ScreenJuiceUtility.new()
	util.name = "ScreenJuiceUtility"
	util.set_anchors_preset(Control.PRESET_FULL_RECT)

	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://addons/Juice_V1/Screen/screen_juice.gdshader")
	util.material = shader_mat
	util.mouse_filter = Control.MOUSE_FILTER_IGNORE

	canvas.add_child(util)

	# Register instance immediately — _ready() may not fire within this tick.
	util.instance = util

	if debug_enabled:
		print("[ScreenMotionJuiceEffect] Auto-bootstrapped ScreenJuiceUtility at tree root (layer=128)")

	return util
