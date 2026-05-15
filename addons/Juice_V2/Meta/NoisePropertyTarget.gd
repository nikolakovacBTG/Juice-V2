## Per-property configuration slot for [NoisePropertyJuiceEffectBase].
##
## Extends [PropertyTarget] with a type-matched amplitude field.
## Add one [NoisePropertyTarget] per property to noise-animate.

# =============================================================================
# WHAT: One noise target slot — property path + amplitude.
#       Extends PropertyTarget, which provides property-path declaration and
#       base-value capture via JuiceLedger.ensure().
# WHY:  Separates per-property amplitude from the shared noise settings
#       (speed, seed, fractal, domain warp) that live on the base effect.
#       Each entry in property_targets is one of these.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Compute noise values — that is NoisePropertyJuiceEffectBase's job.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name NoisePropertyTarget
extends PropertyTarget

# =============================================================================
# CONFIGURATION
# =============================================================================

## Noise amplitude when the target property is a [float].
@export var amplitude_float: float = 5.0

## Noise amplitude per axis when the target property is a [Vector2].
@export var amplitude_vec2: Vector2 = Vector2(5.0, 5.0)

## Noise amplitude per axis when the target property is a [Vector3].
@export var amplitude_vec3: Vector3 = Vector3(5.0, 5.0, 5.0)

## Noise amplitude (uniform RGBA) when the target property is a [Color].
## Applied additively to each channel. Keep small (0.0–1.0) to avoid saturation.
@export var amplitude_color: float = 0.1

# =============================================================================
# INTERNAL STATE
# =============================================================================

# _detected_type is inherited from PropertyTarget — do not redeclare here.
# PropertyTarget._detect_type() auto-updates it from the property path; shadowing
# it here would create a second slot that never syncs with the parent's slot.
