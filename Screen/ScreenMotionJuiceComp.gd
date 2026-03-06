## ScreenMotionJuiceComp.gd
## ============================================================================
## WHAT: Composable, single-axis deterministic screen-space effect.
##       Animates UV offset, rotation, or zoom on the full-screen post-process
##       overlay via ScreenJuiceUtility. Each instance handles ONE target axis
##       — stack multiple for compound effects.
##
## WHY: Replaces the monolithic ScreenMotionJuiceComp (5-mode switcher) with
##      composable single-axis components. Each instance is simple, stackable,
##      and uses JuiceCompBase's animation system for deterministic curves.
##
## WRITE PATTERN: Delta-first. Each frame writes only the CHANGE in this comp's
##   contribution: receiver.property += (desired - _my_contribution). This
##   enables safe stacking with other screen juice effects.
##
## SYSTEM: Juicing System (addons/juice/) - Screen Domain
##
## DOES NOT: Handle procedural effects like shake or sway (use Shake/Noise comps).
## DOES NOT: Handle camera-specific effects (use CameraTransform3D/2DJuiceComp).
##
## REQUIREMENTS:
## A ScreenJuiceUtility must exist in the scene tree. This comp discovers it
## via the static ScreenJuiceUtility.instance reference.
##
## PLACEMENT:
## Add as child of the entity that triggers the screen effect (enemy, button,
## explosion, etc). Works from anywhere in the scene tree.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceUtilityScreen.svg")
class_name ScreenMotionJuiceComp
extends JuiceCompBase

# =============================================================================
# SCREEN TARGET SELECTION
# =============================================================================

## Which screen property to animate via the receiver
enum ScreenTarget {
	OFFSET,    ## UV offset (screen shake/push direction)
	ROTATION,  ## Screen rotation (tilt, disorientation)
	ZOOM       ## Screen zoom (punch zoom, breathe)
}

@export var screen_target: ScreenTarget = ScreenTarget.OFFSET:
	set(value):
		screen_target = value
		notify_property_list_changed()

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- OFFSET ---
## Screen UV offset at progress=1.0 (normalized screen coords, small values)
## X = horizontal, Y = vertical. Typical range: -0.05 to 0.05
var screen_offset: Vector2 = Vector2(0.02, 0)

# --- ROTATION ---
## Screen rotation offset at progress=1.0 (degrees)
var screen_rotation_degrees: float = 2.0

# --- ZOOM ---
## Screen zoom offset at progress=1.0. Positive = zoom in, negative = zoom out.
## Typical range: -0.2 to 0.2
var screen_zoom_offset: float = 0.05

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Discovered ScreenJuiceUtility (via static instance)
var _receiver: ScreenJuiceUtility = null

## Delta-first contribution tracking.
var _my_offset_contribution: Vector2 = Vector2.ZERO
var _my_rotation_contribution: float = 0.0
var _my_zoom_contribution: float = 0.0

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	match screen_target:
		ScreenTarget.OFFSET:
			props.append({
				"name": "screen_offset",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		ScreenTarget.ROTATION:
			props.append({
				"name": "screen_rotation_degrees",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

		ScreenTarget.ZOOM:
			props.append({
				"name": "screen_zoom_offset",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
				"hint": PROPERTY_HINT_NONE,
			})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"screen_offset": screen_offset = value; return true
		&"screen_rotation_degrees": screen_rotation_degrees = value; return true
		&"screen_zoom_offset": screen_zoom_offset = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		&"screen_offset": return screen_offset
		&"screen_rotation_degrees": return screen_rotation_degrees
		&"screen_zoom_offset": return screen_zoom_offset
	return null

# =============================================================================
# LIFECYCLE OVERRIDES
# =============================================================================

func _on_animate_start() -> void:
	_find_receiver()

	if debug_enabled:
		var target_name: String = ScreenTarget.keys()[screen_target]
		print("[%s] ScreenMotion start (%s), receiver=%s" % [
			name, target_name,
			"found" if _receiver else "NONE"
		])


func _apply_effect(progress: float) -> void:
	if not is_instance_valid(_receiver):
		return

	match screen_target:
		ScreenTarget.OFFSET:
			_apply_offset_effect(progress)
		ScreenTarget.ROTATION:
			_apply_rotation_effect(progress)
		ScreenTarget.ZOOM:
			_apply_zoom_effect(progress)


func _on_animate_out_complete() -> void:
	_remove_contribution()
	if debug_enabled:
		print("[%s] ScreenMotion complete (out), contribution cleared" % name)


func _on_animate_in_complete() -> void:
	# Do NOT clear contribution here — effect should hold at full strength
	# for PLAY_IN_ONLY and TOGGLE scenarios.
	if debug_enabled:
		print("[%s] ScreenMotion holding at peak (in complete)" % name)


func _exit_tree() -> void:
	_remove_contribution()


func _invalidate_base_cache() -> void:
	_remove_contribution()
	_receiver = null

# =============================================================================
# OFFSET EFFECT
# =============================================================================

func _apply_offset_effect(progress: float) -> void:
	var desired := screen_offset * progress
	var delta := desired - _my_offset_contribution
	_receiver.offset += delta
	_my_offset_contribution = desired

# =============================================================================
# ROTATION EFFECT
# =============================================================================

func _apply_rotation_effect(progress: float) -> void:
	var desired := deg_to_rad(screen_rotation_degrees) * progress
	var delta := desired - _my_rotation_contribution
	_receiver.rotation_amount += delta
	_my_rotation_contribution = desired

# =============================================================================
# ZOOM EFFECT
# =============================================================================

func _apply_zoom_effect(progress: float) -> void:
	var desired := screen_zoom_offset * progress
	var delta := desired - _my_zoom_contribution
	_receiver.zoom_offset += delta
	_my_zoom_contribution = desired

# =============================================================================
# CONTRIBUTION CLEANUP
# =============================================================================

## Remove our contribution from the receiver and reset tracking.
func _remove_contribution() -> void:
	if not is_instance_valid(_receiver):
		_my_offset_contribution = Vector2.ZERO
		_my_rotation_contribution = 0.0
		_my_zoom_contribution = 0.0
		return

	match screen_target:
		ScreenTarget.OFFSET:
			_receiver.offset -= _my_offset_contribution
		ScreenTarget.ROTATION:
			_receiver.rotation_amount -= _my_rotation_contribution
		ScreenTarget.ZOOM:
			_receiver.zoom_offset -= _my_zoom_contribution

	_my_offset_contribution = Vector2.ZERO
	_my_rotation_contribution = 0.0
	_my_zoom_contribution = 0.0

# =============================================================================
# RECEIVER DISCOVERY
# =============================================================================

## Finds the ScreenJuiceUtility via its static instance.
func _find_receiver() -> void:
	if is_instance_valid(_receiver):
		return

	_receiver = ScreenJuiceUtility.instance

	if _receiver == null and debug_enabled:
		push_warning("[%s] No ScreenJuiceUtility found in scene" % name)
