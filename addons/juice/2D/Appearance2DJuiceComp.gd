## Appearance2DJuiceComp.gd
## ============================================================================
## WHAT: Unified surface appearance effect for Node2D/CanvasItem nodes.
##       Replaces the separate Flash and Color components with one configurable
##       component that handles all color/tint/flash effects via blend modes.
## WHY:  Artists think in terms of "change how this looks" — one component for
##       all appearance changes reduces cognitive load and fills feature gaps
##       (blend modes, hold_time, HDR now available everywhere).
## SYSTEM: Juicing System (addons/juice/) - Appearance Family
## DOES NOT: Handle 3D material properties — use Appearance3DJuiceComp for that.
## DOES NOT: Handle alpha/visibility toggling — use VisibilityJuiceComp for that.
## DOES NOT: Handle shader uniforms — use ShaderPropertyJuiceComp for that.
## ============================================================================
##
## ARCHITECTURE:
## - Blends between color_from and color_to using the selected blend mode
## - progress=0.0 → color_from state, progress=1.0 → color_to state
## - Optional hold phase at peak (progress=1.0) before animate_out
## - Uses modulate or self_modulate on CanvasItem targets
##
## NOTE: This is functionally identical to AppearanceControlJuiceComp.
## Both operate on CanvasItem.modulate/self_modulate. Two files exist purely
## for UX discoverability — artists searching "2D" in Add Node find this comp.
##
## BLEND MODES:
## - ADDITIVE: Adds color contribution (brightens). Good for hit flashes, glow.
##   With allow_hdr=true, values above 1.0 trigger WorldEnvironment bloom.
## - MULTIPLY: Multiplies base by blend factor (tints). Good for damage overlays.
## - REPLACE: Directly lerps from color_from to color_to. Hard color swaps.
##
## COMMON SETUPS:
## - Hit flash: ADDITIVE, from=White, to=White, hold_time=0.05, PLAY_IN_AND_OUT
## - Damage tint: MULTIPLY, from=White, to=Red, hold_time=0.1
## - HDR glow: ADDITIVE, to=Color(3,3,3), allow_hdr=true
## - Power-up glow: REPLACE, from=White, to=Color(1.5,1.5,0.8)
## - Selection pulse: REPLACE, from=White, to=Yellow, loop_count=-1
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase2D.svg")
class_name Appearance2DJuiceComp
extends JuiceCompBase

# =============================================================================
# APPEARANCE CONFIGURATION
# =============================================================================

@export_group("Appearance")

## How the color is blended with the target's base color
enum BlendMode {
	ADDITIVE,   ## Add color contribution (brightens) — hit flashes, glow
	MULTIPLY,   ## Multiply by blend factor (tints) — damage overlay, color wash
	REPLACE     ## Override color entirely — hard color swap, direct tween
}

## Color at progress=0 (start state).
## White = no tint in ADDITIVE/MULTIPLY modes (neutral element).
@export var color_from: Color = Color.WHITE

## Color at progress=1 (peak state). The "target" or "flash" color.
@export var color_to: Color = Color.RED

## Time to hold at peak (progress=1.0) before animate_out begins. 0 = no hold.
## Creates the classic "flash" feel: quick in → hold at peak → quick out.
@export var hold_time: float = 0.0

## If true, alpha is interpolated along with RGB.
## If false, the target's original alpha is preserved throughout.
@export var animate_alpha: bool = false

## If true, uses modulate (affects this node AND all children).
## If false, uses self_modulate (only this node, children unaffected).
@export var affect_children: bool = true

## Blend mode for color calculation. Controls how color_from/color_to
## are combined with the target's base color.
@export var blend_mode: BlendMode = BlendMode.REPLACE:
	set(value):
		blend_mode = value
		notify_property_list_changed()

## Backing variable for conditional allow_hdr export.
## If true, ADDITIVE mode allows modulate values above 1.0 for bloom/glow.
## Requires a WorldEnvironment with glow enabled in the scene.
var allow_hdr: bool = true

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	if blend_mode == BlendMode.ADDITIVE:
		props.append({
			"name": "allow_hdr",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT,
		})
	return props


func _set(prop: StringName, value: Variant) -> bool:
	match prop:
		&"allow_hdr":
			allow_hdr = value
			return true
	return false


func _get(prop: StringName) -> Variant:
	match prop:
		&"allow_hdr":
			return allow_hdr
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Base color captured from the target's modulate/self_modulate before animation
var _base_color: Color = Color.WHITE

## Guard to avoid re-capturing base color during a running animation
var _has_base_color: bool = false

## Whether we're currently in the hold phase at peak intensity
var _in_hold_phase: bool = false

## Elapsed time during hold phase
var _hold_timer: float = 0.0


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


func _process(delta: float) -> void:
	# Handle hold phase timing before letting base class process.
	# During hold, the base class animation is paused — we just count time,
	# then trigger animate_out when the hold period expires.
	if _in_hold_phase:
		_hold_timer += delta
		if _hold_timer >= hold_time:
			_in_hold_phase = false
			_hold_timer = 0.0
			animate_out()
		return

	# Normal animation — let base class drive progress and call _apply_effect
	super._process(delta)


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

## Reset base color cache when target changes (recipe mode, editor preview)
func _invalidate_base_cache() -> void:
	_has_base_color = false
	_in_hold_phase = false
	_hold_timer = 0.0


## Called at the start of every animation cycle
func _on_animate_start() -> void:
	if not _has_base_color:
		_capture_base_color()

	if debug_enabled:
		print("[%s] Appearance start: %s → %s (blend=%s, hold=%.2fs, hdr=%s)" % [
			name, color_from, color_to, BlendMode.keys()[blend_mode], hold_time, allow_hdr
		])


## Core effect: compute blended color from progress and apply to target
func _apply_effect(progress: float) -> void:
	var result_color := _calculate_color(progress)
	_set_target_color(result_color)


## Called when animate_in reaches peak (progress=1.0)
func _on_animate_in_complete() -> void:
	# If hold_time is configured, pause here before triggering animate_out.
	# This creates the classic "flash" feel: ramp up → hold → ramp down.
	if hold_time > 0.0:
		_in_hold_phase = true
		_hold_timer = 0.0
		if debug_enabled:
			print("[%s] Appearance peak reached, holding for %.2fs" % [name, hold_time])


## Called when animate_out completes — restore to clean state
func _on_animate_out_complete() -> void:
	# Snap to color_from state to avoid floating point drift.
	# In REPLACE mode this is color_from directly.
	# In ADDITIVE/MULTIPLY modes, color_from=White means "no change from base."
	_set_target_color(_calculate_color(0.0))

	if debug_enabled:
		print("[%s] Appearance complete, restored to start state" % name)


# =============================================================================
# COLOR CALCULATION
# =============================================================================

## Calculate the output color based on blend mode, base color, and progress.
## progress=0 → color_from state, progress=1 → color_to state.
func _calculate_color(progress: float) -> Color:
	match blend_mode:
		BlendMode.ADDITIVE:
			# Interpolate the additive contribution from color_from to color_to,
			# then add the delta above color_from onto the base color.
			# At progress=0: result = base (no change). At progress=1: result = base + (to - from).
			var blend := color_from.lerp(color_to, progress)
			var r := _base_color.r + (blend.r - color_from.r)
			var g := _base_color.g + (blend.g - color_from.g)
			var b := _base_color.b + (blend.b - color_from.b)
			if not allow_hdr:
				r = clampf(r, 0.0, 1.0)
				g = clampf(g, 0.0, 1.0)
				b = clampf(b, 0.0, 1.0)
			var a := _base_color.a
			if animate_alpha:
				a = lerpf(color_from.a, color_to.a, progress)
			return Color(r, g, b, a)

		BlendMode.MULTIPLY:
			# Multiply base color by the interpolated blend factor.
			# color_from=White means "no tint at start" (multiply by 1).
			# color_to=Red means "tint fully red at peak" (multiply G,B by 0).
			var factor := color_from.lerp(color_to, progress)
			var r := _base_color.r * factor.r
			var g := _base_color.g * factor.g
			var b := _base_color.b * factor.b
			var a := _base_color.a
			if animate_alpha:
				a = _base_color.a * factor.a
			return Color(r, g, b, a)

		BlendMode.REPLACE:
			# Direct lerp from color_from to color_to, ignoring base color.
			# Simplest mode — what you set is what you get.
			var result := color_from.lerp(color_to, progress)
			if not animate_alpha:
				result.a = _base_color.a
			return result

	return _base_color


# =============================================================================
# BASE COLOR CAPTURE
# =============================================================================

## Capture the current modulate/self_modulate from the target CanvasItem.
## This is the "natural" state we blend relative to.
func _capture_base_color() -> void:
	if _has_base_color:
		return

	if _target_node is CanvasItem:
		var canvas := _target_node as CanvasItem
		if affect_children:
			_base_color = canvas.modulate
		else:
			_base_color = canvas.self_modulate
	else:
		_base_color = Color.WHITE
		if debug_enabled:
			push_warning("[%s] Target '%s' is not a CanvasItem — appearance effect won't work" % [
				name, str(_target_node.name) if _target_node else "null"
			])

	_has_base_color = true

	if debug_enabled:
		print("[%s] Captured base color: %s (affect_children=%s)" % [
			name, _base_color, affect_children
		])


# =============================================================================
# COLOR APPLICATION
# =============================================================================

## Write the computed color to the target CanvasItem's modulate or self_modulate
func _set_target_color(color_value: Color) -> void:
	if not _target_node is CanvasItem:
		return

	var canvas := _target_node as CanvasItem
	if affect_children:
		canvas.modulate = color_value
	else:
		canvas.self_modulate = color_value

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node2D:
		warnings.append("Parent must be a Node2D node. Use AppearanceControl/Appearance3D for other domains.")
	return warnings
