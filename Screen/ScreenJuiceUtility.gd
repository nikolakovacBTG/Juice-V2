## Full-screen post-process accumulator for Juice screen effects.
##
## Sits as a ColorRect inside a CanvasLayer at layer=128, reading the final
## composited screen image via the bundled screen_juice shader and manipulating
## UV sampling. Anything rendered underneath — 3D, 2D, HUD — moves as one image.

# ============================================================================
# WHAT: Receiver that applies accumulated screen offsets (offset/rotation/zoom/
#       skew/barrel/wave/chromatic) via shader uniforms to a full-screen ColorRect.
# WHY:  Screen-space effects must composite AFTER everything renders. A ColorRect
#       with hint_screen_texture reads the final frame and re-samples it with
#       UV transforms — the correct Godot pattern for fullscreen effects.
# SYSTEM: Juice System (addons/Juice_V1/Screen/)
# DOES NOT: Handle Juice timing or triggering — ScreenJuiceEffect does that.
# DOES NOT: Need manual placement — ScreenJuiceEffect auto-bootstraps this.
#           Optionally add manually to a CanvasLayer for custom layer/shader control.
#
# DISCOVERY: Effects find this via the static `instance` variable.
# CHANNELS: See ScreenJuiceEffect for authoring. Utility only accumulates and writes.
# ============================================================================

@icon("res://addons/Juice_V1/icons/JuiceUtilityScreen.svg")
class_name ScreenJuiceUtility
extends ColorRect


# =============================================================================
# STATIC INSTANCE
# =============================================================================

## Global reference for ScreenJuiceEffect to find the receiver.
## Set in _ready() and by auto-bootstrap before _ready() fires.
static var instance: ScreenJuiceUtility = null


# =============================================================================
# CONFIGURATION
# =============================================================================

@export_group("Debug")
@export var debug_enabled: bool = false


# =============================================================================
# PUBLIC ACCUMULATORS (written by ScreenJuiceEffect via delta-first writes)
# =============================================================================

## UV offset. Accumulated from all active OFFSET-channel effects.
var offset: Vector2 = Vector2.ZERO

## Rotation in radians. Accumulated from ROTATION-channel effects.
var rotation_amount: float = 0.0

## Zoom scale offset. Added to 1.0 → shader receives (1.0 + zoom_offset).
## Accumulated from ZOOM-channel effects.
var zoom_offset: float = 0.0

## Horizontal (x) and vertical (y) shear. Accumulated from SKEW-channel effects.
var skew_offset: Vector2 = Vector2.ZERO

## Radial distortion. Negative = barrel, positive = pincushion.
## Accumulated from BARREL-channel effects.
var barrel_distortion: float = 0.0

## Wave amplitude (UV normalized). Accumulated from WAVE-channel effects.
var wave_amplitude: float = 0.0

## Wave frequency (waves per screen height). Last-write-wins — config, not accumulated.
var wave_frequency: float = 10.0

## RGB channel separation (UV normalized). Accumulated from CHROMATIC-channel effects.
var chromatic_amount: float = 0.0


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _was_active: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if instance != null and instance != self:
		if debug_enabled:
			print("[ScreenJuiceUtility] Replacing previous instance (expected during scene transitions).")

	instance = self
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = 100  # After ScreenJuiceEffect writes (priority 0)

	if not material or not material is ShaderMaterial:
		push_warning("[ScreenJuiceUtility] No ShaderMaterial assigned. Auto-bootstrap should handle this.")

	if debug_enabled:
		print("[ScreenJuiceUtility] Ready (static instance registered)")


func _exit_tree() -> void:
	if instance == self:
		instance = null
		if debug_enabled:
			print("[ScreenJuiceUtility] Removed (static instance cleared)")


func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if not mat:
		return

	var has_effect := (
		offset != Vector2.ZERO or
		rotation_amount != 0.0 or
		zoom_offset != 0.0 or
		skew_offset != Vector2.ZERO or
		barrel_distortion != 0.0 or
		wave_amplitude != 0.0 or
		chromatic_amount != 0.0
	)

	if not has_effect:
		if _was_active:
			_reset_shader_to_passthrough(mat)
			_was_active = false
		return

	_was_active = true
	_write_shader_uniforms(mat)

	if debug_enabled:
		print("[ScreenJuiceUtility] offset=%s rot=%.4f zoom=%.4f skew=%s barrel=%.4f wave=%.4f chroma=%.4f" % [
			offset, rotation_amount, zoom_offset, skew_offset, barrel_distortion, wave_amplitude, chromatic_amount
		])


# =============================================================================
# SHADER WRITE HELPERS
# =============================================================================

func _write_shader_uniforms(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("offset", offset)
	mat.set_shader_parameter("rotation_angle", rotation_amount)
	mat.set_shader_parameter("zoom_amount", 1.0 + zoom_offset)
	mat.set_shader_parameter("skew", skew_offset)
	mat.set_shader_parameter("barrel_distortion", barrel_distortion)
	mat.set_shader_parameter("wave_amplitude", wave_amplitude)
	mat.set_shader_parameter("wave_frequency", wave_frequency)
	mat.set_shader_parameter("chromatic_aberration", chromatic_amount)


func _reset_shader_to_passthrough(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("offset", Vector2.ZERO)
	mat.set_shader_parameter("rotation_angle", 0.0)
	mat.set_shader_parameter("zoom_amount", 1.0)
	mat.set_shader_parameter("skew", Vector2.ZERO)
	mat.set_shader_parameter("barrel_distortion", 0.0)
	mat.set_shader_parameter("wave_amplitude", 0.0)
	mat.set_shader_parameter("chromatic_aberration", 0.0)
	if debug_enabled:
		print("[ScreenJuiceUtility] Shader reset to passthrough")


# =============================================================================
# PUBLIC API
# =============================================================================

## Instantly clears all accumulated juice offsets and resets shader to passthrough.
func reset_all() -> void:
	offset              = Vector2.ZERO
	rotation_amount     = 0.0
	zoom_offset         = 0.0
	skew_offset         = Vector2.ZERO
	barrel_distortion   = 0.0
	wave_amplitude      = 0.0
	wave_frequency      = 10.0
	chromatic_amount    = 0.0

	var mat := material as ShaderMaterial
	if mat:
		_reset_shader_to_passthrough(mat)

	if debug_enabled:
		print("[ScreenJuiceUtility] All offsets reset")
