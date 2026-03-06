## VisibilityJuiceComp.gd
## ============================================================================
## WHAT: Consolidated visibility/alpha juice component with three modes:
##       BLINK (hard visible toggle), FLICKER (alpha oscillation patterns),
##       and FADE (base-class curve-driven alpha animation).
## WHY: Replaces 3 separate scripts (BlinkJuiceComp, FlickerJuiceComp,
##      FadeJuiceComp) with one unified component, reducing duplication of
##      shared alpha capture/apply/restore plumbing.
## SYSTEM: Juicing System (addons/juice/) - Visibility family
## DOES NOT: Handle color changes (use AppearanceControlJuiceComp / Appearance2DJuiceComp).
##           Handle screen overlays (use ScreenOverlayJuiceComp).
##           Handle shader-driven effects (use ShaderPropertyJuiceComp).
## ============================================================================
##
## ARCHITECTURE:
## - Single script, mode-switched via VisibilityMode enum
## - Shared alpha capture/apply logic for CanvasItem (Control + 2D) and
##   GeometryInstance3D (3D) — domain-agnostic, no 3+1 split needed
## - BLINK: Hard visible toggle with own on/off timer, ignores base progress
## - FLICKER: Time-driven alpha oscillation with sub-patterns (RANDOM, MORSE_SOS,
##   PULSE); base progress acts as intensity envelope
## - FADE: Pure base-class progress → alpha; easing curves drive everything
##
## CONDITIONAL EXPORTS:
## Changing visibility_mode triggers notify_property_list_changed() which
## shows/hides the relevant parameters via _get_property_list(). Properties
## added this way appear AFTER all @export properties in the inspector.
##
## DOMAIN SUPPORT:
## - CanvasItem (all Control + all Node2D): modulate.a
## - GeometryInstance3D (MeshInstance3D, CSG, etc.): transparency
## - Works on any node with a visual representation
##
## SEQUENCER RECIPE CONTRACT:
## Supports _recipe_capture_natural / _recipe_apply_natural / _recipe_restore_natural
## for all modes, enabling SequencerJuiceComp recipe mode compatibility.
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBaseVisibility.svg")
class_name VisibilityJuiceComp
extends JuiceCompBase

# =============================================================================
# MODE ENUMS
# =============================================================================

## Primary visibility effect mode
enum VisibilityMode {
	BLINK,    ## Hard visible toggle (own timer, on/off duration)
	FLICKER,  ## Alpha oscillation with sub-pattern (RANDOM, MORSE_SOS, PULSE)
	FADE,     ## Base class progress → alpha (curve-driven, delta-based)
}

## Sub-pattern for FLICKER mode
enum FlickerPattern {
	RANDOM,      ## Chaotic on/off each interval
	MORSE_SOS,   ## Distress signal: ... --- ...
	PULSE,       ## Smooth sine wave oscillation between min/max alpha
}

# =============================================================================
# ALWAYS-VISIBLE CONFIGURATION
# =============================================================================

@export_group("Visibility Effect")

## Which visibility mode to use
var visibility_mode: VisibilityMode = VisibilityMode.FADE:
	set(value):
		visibility_mode = value
		notify_property_list_changed()

## For Node3D: Which child GeometryInstance3D to affect (leave empty to search)
## Needed because Node3D itself has no visual — its children do
@export_node_path("GeometryInstance3D") var geometry_path: NodePath

# =============================================================================
# CONDITIONAL BACKING VARIABLES
# These are NOT @export — they are shown/hidden via _get_property_list()
# =============================================================================

# --- BLINK ---

## Duration of visible state per cycle (seconds)
var blink_on_duration: float = 0.5

## Duration of hidden state per cycle (seconds)
var blink_off_duration: float = 0.5

## Whether to start in visible state (true) or hidden state (false)
var blink_start_visible: bool = true

# --- FLICKER ---

## Pattern for flickering
var flicker_pattern: FlickerPattern = FlickerPattern.RANDOM

## Flickers per second (capped at 60 to avoid epilepsy concerns)
var flicker_rate: float = 20.0

## Alpha during "off" state (when flickered down)
var flicker_min_alpha: float = 0.2

## Alpha during "on" state (when flickered up)
var flicker_max_alpha: float = 1.0

# --- FADE ---

## How much to change alpha when animated in
## Positive = increase alpha (fade in), Negative = decrease alpha (fade out)
## At progress=0 (natural), alpha is unchanged
## At progress=1 (animated in), alpha is changed by this amount
var fade_amount: float = -1.0

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Base alpha before effect started
var _base_alpha: float = 1.0

## Whether we've captured the base alpha
var _has_base_alpha: bool = false

## Reference to geometry instance for 3D nodes
var _geometry_instance: GeometryInstance3D

# --- BLINK state ---

## Base visibility before blinking started
var _base_visible: bool = true

## Current blink state (true = visible, false = hidden)
var _blink_current_state: bool = true

## Time accumulated in current blink state
var _blink_state_time: float = 0.0

## Current blink cycle count
var _blink_count: int = 0

# --- FLICKER state ---

## Accumulated time for flicker pattern
var _flicker_time: float = 0.0

## Current flicker state (true = on/bright, false = off/dim)
var _flicker_current_state: bool = true

## Time until next random state change (for RANDOM pattern)
var _next_random_time: float = 0.0

## Current position in morse pattern (for MORSE_SOS)
var _morse_index: int = 0
var _morse_element_time: float = 0.0

## Morse SOS timing pattern: dot=0.1s, dash=0.3s, gap=0.1s, letter_gap=0.3s
## Pattern: ... --- ... with appropriate gaps
## Format: [duration, is_on] pairs
const MORSE_SOS_PATTERN: Array = [
	# S: ...
	[0.1, true], [0.1, false],  # dot, gap
	[0.1, true], [0.1, false],  # dot, gap
	[0.1, true], [0.3, false],  # dot, letter gap
	# O: ---
	[0.3, true], [0.1, false],  # dash, gap
	[0.3, true], [0.1, false],  # dash, gap
	[0.3, true], [0.3, false],  # dash, letter gap
	# S: ...
	[0.1, true], [0.1, false],  # dot, gap
	[0.1, true], [0.1, false],  # dot, gap
	[0.1, true], [0.5, false],  # dot, word gap (longer pause before repeat)
]


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []

	# Always show visibility_mode at top
	props.append({
		"name": "visibility_mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "BLINK,FLICKER,FADE",
		"usage": PROPERTY_USAGE_DEFAULT,
	})

	match visibility_mode:
		VisibilityMode.BLINK:
			props.append({
				"name": "blink_on_duration",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.01,10.0,0.01,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "blink_off_duration",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.01,10.0,0.01,or_greater",
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "blink_start_visible",
				"type": TYPE_BOOL,
				"usage": PROPERTY_USAGE_DEFAULT,
			})

		VisibilityMode.FLICKER:
			props.append({
				"name": "flicker_pattern",
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "RANDOM,MORSE_SOS,PULSE",
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "flicker_rate",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "1.0,60.0,0.5",
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "flicker_min_alpha",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT,
			})
			props.append({
				"name": "flicker_max_alpha",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT,
			})

		VisibilityMode.FADE:
			props.append({
				"name": "fade_amount",
				"type": TYPE_FLOAT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "-1.0,1.0,0.01",
				"usage": PROPERTY_USAGE_DEFAULT,
			})

	return props


func _set(property: StringName, value: Variant) -> bool:
	match property:
		# Mode
		&"visibility_mode": visibility_mode = value; return true
		# Blink
		&"blink_on_duration": blink_on_duration = value; return true
		&"blink_off_duration": blink_off_duration = value; return true
		&"blink_start_visible": blink_start_visible = value; return true
		# Flicker
		&"flicker_pattern": flicker_pattern = value; return true
		&"flicker_rate": flicker_rate = value; return true
		&"flicker_min_alpha": flicker_min_alpha = value; return true
		&"flicker_max_alpha": flicker_max_alpha = value; return true
		# Fade
		&"fade_amount": fade_amount = value; return true
	return false


func _get(property: StringName) -> Variant:
	match property:
		# Mode
		&"visibility_mode": return visibility_mode
		# Blink
		&"blink_on_duration": return blink_on_duration
		&"blink_off_duration": return blink_off_duration
		&"blink_start_visible": return blink_start_visible
		# Flicker
		&"flicker_pattern": return flicker_pattern
		&"flicker_rate": return flicker_rate
		&"flicker_min_alpha": return flicker_min_alpha
		&"flicker_max_alpha": return flicker_max_alpha
		# Fade
		&"fade_amount": return fade_amount
	return null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	# Capture base alpha after node is ready
	call_deferred("_capture_base_alpha")


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

func _invalidate_base_cache() -> void:
	_has_base_alpha = false


func _on_animate_start() -> void:
	# Ensure we have base alpha for current target
	if not _has_base_alpha:
		_capture_base_alpha()

	match visibility_mode:
		VisibilityMode.BLINK:
			_start_blink()
		VisibilityMode.FLICKER:
			_start_flicker()
		VisibilityMode.FADE:
			if debug_enabled:
				print("[%s] Fade: base=%.2f, amount=%.2f" % [name, _base_alpha, fade_amount])


func _apply_effect(progress: float) -> void:
	match visibility_mode:
		VisibilityMode.BLINK:
			_apply_blink(progress)
		VisibilityMode.FLICKER:
			_apply_flicker(progress)
		VisibilityMode.FADE:
			_apply_fade(progress)


func _on_animate_out_complete() -> void:
	match visibility_mode:
		VisibilityMode.BLINK:
			# Restore base visibility
			_target_node.visible = _base_visible
			if debug_enabled:
				print("[%s] Blink ended, restored visible=%s" % [name, _base_visible])
		VisibilityMode.FLICKER:
			_set_target_alpha(_base_alpha)
			if debug_enabled:
				print("[%s] Flicker complete, restored alpha to %.2f" % [name, _base_alpha])
		VisibilityMode.FADE:
			_set_target_alpha(_base_alpha)
			if debug_enabled:
				print("[%s] Fade complete, restored alpha to %.2f" % [name, _base_alpha])


# =============================================================================
# BLINK MODE
# =============================================================================

func _start_blink() -> void:
	# Capture base visibility
	_base_visible = _target_node.visible

	# Reset blink state
	_blink_current_state = blink_start_visible
	_blink_state_time = 0.0
	_blink_count = 0

	# Apply initial state
	_target_node.visible = _blink_current_state

	if debug_enabled:
		print("[%s] Blink start: on=%.2fs, off=%.2fs, start_visible=%s, loops=%d" % [
			name, blink_on_duration, blink_off_duration, blink_start_visible, loop_count
		])


func _apply_blink(_progress: float) -> void:
	# Blink uses its own timing system, not base class progress
	var delta := get_process_delta_time()
	_blink_state_time += delta

	# Check if we should toggle state
	var current_duration := blink_on_duration if _blink_current_state else blink_off_duration
	if _blink_state_time >= current_duration:
		_blink_state_time = 0.0
		_blink_toggle_state()

	# Apply current visibility
	_target_node.visible = _blink_current_state


## Toggle between visible and hidden states
func _blink_toggle_state() -> void:
	_blink_current_state = not _blink_current_state

	# Count cycles when completing one full on+off cycle
	if _blink_current_state and not blink_start_visible:
		_blink_count += 1
	elif not _blink_current_state and blink_start_visible:
		_blink_count += 1

	if debug_enabled:
		print("[%s] Blink toggle: visible=%s, cycle=%d/%d" % [
			name, _blink_current_state, _blink_count, loop_count
		])

	# Check if we've completed all cycles
	# loop_count from base class: -1 = infinite, 0 = don't play, 1+ = N cycles
	if loop_count > 0 and _blink_count >= loop_count:
		_finish_blinking()


## Complete the blink animation
func _finish_blinking() -> void:
	_is_playing = false

	# Restore base visibility
	_target_node.visible = _base_visible

	if debug_enabled:
		print("[%s] Blink complete after %d cycles, restored visible=%s" % [
			name, _blink_count, _base_visible
		])

	# Emit completion signal and trigger chain
	completed.emit()
	_trigger_next_component()


# =============================================================================
# FLICKER MODE
# =============================================================================

func _start_flicker() -> void:
	# Reset flicker state
	_flicker_time = 0.0
	_flicker_current_state = true
	_next_random_time = 0.0
	_morse_index = 0
	_morse_element_time = 0.0

	if debug_enabled:
		print("[%s] Flicker start: pattern=%s, rate=%.1f/s, alpha=[%.2f, %.2f]" % [
			name, FlickerPattern.keys()[flicker_pattern], flicker_rate,
			flicker_min_alpha, flicker_max_alpha
		])


func _apply_flicker(progress: float) -> void:
	var delta := get_process_delta_time()
	_flicker_time += delta

	# Update flicker state based on sub-pattern
	_update_flicker_state(delta)

	# Progress controls intensity of flicker
	# At progress=0: alpha stays at base (no flicker visible)
	# At progress=1: alpha swings full range between min and max
	var target_alpha: float

	if flicker_pattern == FlickerPattern.PULSE:
		# PULSE: smooth sine wave, no binary state — use continuous t value
		var t := (sin(_flicker_time * flicker_rate * TAU) + 1.0) * 0.5  # 0.0 to 1.0
		var pulse_alpha := lerpf(flicker_min_alpha, flicker_max_alpha, t)
		target_alpha = lerpf(_base_alpha, pulse_alpha, progress)
	else:
		# RANDOM / MORSE_SOS: binary state
		if _flicker_current_state:
			target_alpha = lerpf(_base_alpha, flicker_max_alpha, progress)
		else:
			target_alpha = lerpf(_base_alpha, flicker_min_alpha, progress)

	_set_target_alpha(target_alpha)


## Update the current flicker state based on sub-pattern
func _update_flicker_state(delta: float) -> void:
	match flicker_pattern:
		FlickerPattern.RANDOM:
			_update_random_flicker(delta)
		FlickerPattern.MORSE_SOS:
			_update_morse_flicker(delta)
		FlickerPattern.PULSE:
			pass  # PULSE uses continuous sine in _apply_flicker, no state toggle


## Random chaotic flicker
func _update_random_flicker(delta: float) -> void:
	_next_random_time -= delta
	if _next_random_time <= 0.0:
		_flicker_current_state = randf() > 0.5
		# Schedule next change based on flicker rate with some randomness
		var base_interval := 1.0 / flicker_rate
		_next_random_time = base_interval * randf_range(0.5, 1.5)


## Morse code SOS pattern flicker
func _update_morse_flicker(delta: float) -> void:
	_morse_element_time += delta

	var element: Array = MORSE_SOS_PATTERN[_morse_index]
	var element_duration: float = element[0]
	var element_state: bool = element[1]

	_flicker_current_state = element_state

	# Move to next element when duration expires
	if _morse_element_time >= element_duration:
		_morse_element_time = 0.0
		_morse_index = (_morse_index + 1) % MORSE_SOS_PATTERN.size()


# =============================================================================
# FADE MODE
# =============================================================================

func _apply_fade(progress: float) -> void:
	# Pure base-class driven: progress from easing curves → alpha
	# progress=0 -> base alpha (natural state)
	# progress=1 -> base alpha + fade_amount
	var current_alpha := clampf(_base_alpha + (fade_amount * progress), 0.0, 1.0)
	_set_target_alpha(current_alpha)


# =============================================================================
# SHARED ALPHA CAPTURE AND APPLICATION
# =============================================================================

## Capture the base alpha from the target node
func _capture_base_alpha() -> void:
	if _has_base_alpha:
		return

	if _target_node is CanvasItem:
		# CanvasItem covers ALL Control nodes (Button, Label, etc.) and
		# ALL Node2D nodes (Sprite2D, AnimatedSprite2D, etc.)
		_base_alpha = (_target_node as CanvasItem).modulate.a
	elif _target_node is Node3D:
		_geometry_instance = _find_geometry_instance()
		if _geometry_instance:
			# GeometryInstance3D uses transparency (inverted: 0 = opaque)
			_base_alpha = 1.0 - _geometry_instance.transparency
		else:
			_base_alpha = 1.0
			if debug_enabled:
				push_warning("[%s] No GeometryInstance3D found for 3D visibility effect" % name)
	else:
		_base_alpha = 1.0
		if debug_enabled:
			var target_name: String = "(not set)"
			if _target_node != null:
				target_name = _target_node.name
			push_warning("[%s] Target '%s' is not a supported visual node" % [name, target_name])

	_has_base_alpha = true

	if debug_enabled:
		print("[%s] Captured base alpha: %.2f" % [name, _base_alpha])


## Apply alpha to target based on node type
func _set_target_alpha(alpha_value: float) -> void:
	if _target_node is CanvasItem:
		var canvas := _target_node as CanvasItem
		var mod := canvas.modulate
		mod.a = alpha_value
		canvas.modulate = mod
	elif _geometry_instance:
		# GeometryInstance3D uses transparency (inverted: 0 = opaque, 1 = invisible)
		_geometry_instance.transparency = 1.0 - alpha_value


## Find a GeometryInstance3D for 3D nodes
func _find_geometry_instance() -> GeometryInstance3D:
	# First try the explicit path
	if not geometry_path.is_empty():
		var node := get_node_or_null(geometry_path)
		if node is GeometryInstance3D:
			return node as GeometryInstance3D

	# If target IS a GeometryInstance3D, use it directly
	if _target_node is GeometryInstance3D:
		return _target_node as GeometryInstance3D

	# Search children for first GeometryInstance3D (type-safe discovery)
	for child in _target_node.get_children():
		if child is GeometryInstance3D:
			return child as GeometryInstance3D

	return null


# =============================================================================
# SEQUENCER RECIPE CONTRACT
# Enables SequencerJuiceComp recipe mode compatibility.
# Captures the node's natural alpha state so the sequencer can restore it
# after applying a recipe across multiple targets.
# =============================================================================

func _recipe_capture_natural(target: Node) -> Variant:
	if target is CanvasItem:
		return {"alpha": (target as CanvasItem).modulate.a}

	if target is Node3D:
		var geo := _find_geometry_instance()
		if geo:
			return {"alpha": 1.0 - geo.transparency, "geometry_path": geometry_path}
		return {"alpha": 1.0, "geometry_path": geometry_path}

	return {"alpha": 1.0}


func _recipe_apply_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary
	var alpha_var: Variant = dict.get("alpha")
	_base_alpha = float(alpha_var)
	_has_base_alpha = true

	if target is Node3D:
		_geometry_instance = _find_geometry_instance()


func _recipe_restore_natural(target: Node, natural: Variant) -> void:
	if not (natural is Dictionary):
		return
	var dict := natural as Dictionary
	var alpha_var: Variant = dict.get("alpha")
	var alpha := float(alpha_var)

	if target is CanvasItem:
		var canvas := target as CanvasItem
		var mod := canvas.modulate
		mod.a = alpha
		canvas.modulate = mod
		return

	if target is Node3D:
		var geo := _find_geometry_instance()
		if geo:
			geo.transparency = 1.0 - alpha
