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
# SYSTEM: Juice System (addons/Juice_V2/Screen/)
# DOES NOT: Handle Juice timing or triggering — ScreenJuiceEffect does that.
# DOES NOT: Need manual placement — ScreenJuiceEffect auto-bootstraps this.
#           Optionally add manually to a CanvasLayer for custom layer/shader control.
#
# DISCOVERY: Effects find this via the static `instance` variable.
# CHANNELS: See ScreenJuiceEffect for authoring. Utility only accumulates and writes.
# ============================================================================

@icon("res://addons/Juice_V2/icons/JuiceUtilityScreen.svg")
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
## Prints detailed state changes and logic paths to the console.
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

## Radial distortion per axis. Negative = barrel, positive = pincushion.
## X = horizontal deformation, Y = vertical deformation.
## Accumulated from BARREL-channel effects.
var barrel_distortion: Vector2 = Vector2.ZERO

## Wave amplitude (UV normalized). Accumulated from WAVE-channel effects.
var wave_amplitude: float = 0.0

## Wave frequency (waves per screen height). Last-write-wins — config, not accumulated.
var wave_frequency: float = 10.0

## Wave direction: 0=Horizontal, 1=Vertical, 2=Concentric. Last-write-wins.
## Matches WaveDirection enum in ScreenJuiceEffect.
var wave_direction: int = 0

## RGB channel separation (UV normalized). Accumulated from CHROMATIC-channel effects.
var chromatic_amount: float = 0.0

## Chromatic aberration mode: 0=Uniform, 1=VignetteFalloff, 2=NoisePerChannel.
## Last-write-wins. Matches ChromaticMode enum in ScreenJuiceEffect.
var chromatic_mode: int = 0

## Used only in NoisePerChannel mode. Updated each frame by ScreenJuiceEffect._apply_chromatic.
## Carries time * shake_frequency so the shader's sin oscillator runs at the right speed.
var chromatic_time: float = 0.0

## Seed offset for the per-channel oscillator. Set from effect's shake_seed value.
var chromatic_seed: float = 0.0

## Pivot point for Barrel, Zoom, Rotation, and Skew transforms.
## Default (0.5, 0.5) = screen center. Written directly by active ScreenJuiceEffect each frame
## (last-write-wins, not additive). Wave and Chromatic ignore this.
var pivot_uv: Vector2 = Vector2(0.5, 0.5)

## Vignette mask config — modulates Wave and Chromatic intensity by screen-edge distance.
## Last-write-wins (config, not accumulated). Set by WAVE and CHROMATIC channel effects.
## use_vignette: enables mask; when false, vignette_mask = 1.0 (full effect everywhere).
## vignette_scale: per-axis ellipse stretching. (1,1) = circle, (2,1) = wide.
## vignette_softness: falloff power. Higher = sharper. Typical: 0.5–3.0.
var use_vignette:      bool    = false
## Stretches the vignette ellipse per axis. (1,1) = circle, (2,1) = wide.
var vignette_scale:    Vector2 = Vector2.ONE
## Falloff steepness of the vignette mask. Higher = sharper edge. Typical: 0.5–3.0.
var vignette_softness: float   = 1.0


# =============================================================================
# INTERNAL STATE
# =============================================================================

var _was_active: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

# Registers as the singleton (instance = self), sets process_priority = 100 so
# this runs after ScreenJuiceEffect writes (which process at priority 0),
# and validates that a ShaderMaterial is present.
func _ready() -> void:
	if instance != null and instance != self:
		JuiceLogger.log_info(self, "Screen",
				"replacing previous instance (expected during scene transitions)",
				debug_enabled)

	instance = self
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = 100  # After ScreenJuiceEffect writes (priority 0)

	if not material or not material is ShaderMaterial:
		JuiceLogger.warn(self, "Screen",
				"no ShaderMaterial assigned — auto-bootstrap should handle this",
				debug_enabled)

	JuiceLogger.log_info(self, "Screen",
			"ready (static instance registered)", debug_enabled)


# Clears the static instance so effects don't hold a freed-node reference
# after scene transitions or manual utility removal.
func _exit_tree() -> void:
	if instance == self:
		instance = null
		JuiceLogger.log_info(self, "Screen",
				"removed (static instance cleared)", debug_enabled)


# Runs each frame at priority 100. If no channel is active and nothing was
# applied last frame, returns immediately (zero GPU work).
# On the first idle frame after an active effect ends, resets shader to
# passthrough and clears _was_active to prevent repeat reset calls.
func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if not mat:
		return

	var has_effect := (
		offset != Vector2.ZERO or
		rotation_amount != 0.0 or
		zoom_offset != 0.0 or
		skew_offset != Vector2.ZERO or
		barrel_distortion != Vector2.ZERO or
		wave_amplitude != 0.0 or
		chromatic_amount != 0.0 or
		use_vignette  # Vignette alone could be active
	)

	if not has_effect:
		if _was_active:
			_reset_shader_to_passthrough(mat)
			_was_active = false
		return

	_was_active = true
	_write_shader_uniforms(mat)

	JuiceLogger.log_info(self, "Screen",
			"offset=%s rot=%.4f zoom=%.4f skew=%s barrel=%s wave=%.4f chroma=%.4f" % [
			offset, rotation_amount, zoom_offset, skew_offset, barrel_distortion, wave_amplitude, chromatic_amount
		], debug_enabled)


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
	mat.set_shader_parameter("wave_direction", wave_direction)
	mat.set_shader_parameter("chromatic_aberration", chromatic_amount)
	mat.set_shader_parameter("chromatic_mode", chromatic_mode)
	mat.set_shader_parameter("chromatic_time", chromatic_time)
	mat.set_shader_parameter("chromatic_seed", chromatic_seed)
	mat.set_shader_parameter("pivot_uv", pivot_uv)
	mat.set_shader_parameter("use_vignette", use_vignette)
	mat.set_shader_parameter("vignette_scale", vignette_scale)
	mat.set_shader_parameter("vignette_softness", vignette_softness)


# Resets every shader uniform to its neutral value. Note: zoom_amount = 1.0
# (not 0.0) because the shader multiplies UV by zoom_amount — 0 would collapse
# the image, 1.0 is passthrough.
func _reset_shader_to_passthrough(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("offset", Vector2.ZERO)
	mat.set_shader_parameter("rotation_angle", 0.0)
	mat.set_shader_parameter("zoom_amount", 1.0)
	mat.set_shader_parameter("skew", Vector2.ZERO)
	mat.set_shader_parameter("barrel_distortion", Vector2.ZERO)
	mat.set_shader_parameter("wave_amplitude", 0.0)
	mat.set_shader_parameter("wave_direction", 0)
	mat.set_shader_parameter("chromatic_aberration", 0.0)
	mat.set_shader_parameter("chromatic_mode", 0)
	mat.set_shader_parameter("chromatic_time", 0.0)
	mat.set_shader_parameter("chromatic_seed", 0.0)
	mat.set_shader_parameter("pivot_uv", Vector2(0.5, 0.5))
	mat.set_shader_parameter("use_vignette", false)
	mat.set_shader_parameter("vignette_scale", Vector2.ONE)
	mat.set_shader_parameter("vignette_softness", 1.0)
	JuiceLogger.log_info(self, "Screen",
			"shader reset to passthrough", debug_enabled)


# =============================================================================
# PUBLIC API
# =============================================================================

## Instantly clears all accumulated juice offsets and resets shader to passthrough.
func reset_all() -> void:
	offset              = Vector2.ZERO
	rotation_amount     = 0.0
	zoom_offset         = 0.0
	skew_offset         = Vector2.ZERO
	barrel_distortion   = Vector2.ZERO
	wave_amplitude      = 0.0
	wave_frequency      = 10.0
	wave_direction      = 0
	chromatic_amount    = 0.0
	chromatic_mode      = 0
	chromatic_time      = 0.0
	chromatic_seed      = 0.0
	pivot_uv            = Vector2(0.5, 0.5)
	use_vignette        = false
	vignette_scale      = Vector2.ONE
	vignette_softness   = 1.0

	var mat := material as ShaderMaterial
	if mat:
		_reset_shader_to_passthrough(mat)

	JuiceLogger.log_info(self, "Screen",
			"all offsets reset", debug_enabled)
