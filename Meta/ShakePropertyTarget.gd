## Per-property configuration slot for [ShakePropertyJuiceEffectBase].
##
## Extends [PropertyTarget] with a type-matched amplitude field.
## Add one [ShakePropertyTarget] per property to shake-animate.

# =============================================================================
# WHAT: One shake target slot — property path + typed amplitude.
#       Extends PropertyTarget, which provides property-path declaration and
#       base-value capture via JuiceLedger.ensure().
# WHY:  Separates per-property amplitude from the shared shake settings
#       (frequency, randomness) that live on the base effect.
#       Each entry in property_targets carries its own amplitude so that
#       position, rotation, and scale properties can each shake independently.
# SYSTEM: Juice System (addons/Juice_V2/)
# DOES NOT: Compute shake values — that is ShakePropertyJuiceEffectBase's job.
#           Does not support discrete property types (bool, String, etc.) —
#           shake displacement is continuous and only meaningful for numeric types.
# =============================================================================

@tool
@icon("res://addons/Juice_V2/icons/JuiceBaseProperty.svg")
class_name ShakePropertyTarget
extends PropertyTarget

# =============================================================================
# CONFIGURATION
# =============================================================================

## Shake amplitude when the target property is a [float].
@export var amplitude_float: float = 5.0

## Shake amplitude per axis when the target property is a [Vector2].
@export var amplitude_vec2: Vector2 = Vector2(5.0, 5.0)

## Shake amplitude per axis when the target property is a [Vector3].
@export var amplitude_vec3: Vector3 = Vector3(5.0, 5.0, 5.0)

## Shake amplitude (uniform RGBA) when the target property is a [Color].
## Applied additively to each channel. Keep small (0.0–1.0) to avoid saturation.
@export var amplitude_color: float = 0.1

# =============================================================================
# INTERNAL STATE
# =============================================================================

# Detected GDScript type of the property, set by the domain effect base when
# capture_base() resolves the first base value from the Ledger.
# TYPE_NIL means no property has been detected yet (set by PropertyPickerPlugin
# or manually in tests).
var _detected_type: int = TYPE_NIL
