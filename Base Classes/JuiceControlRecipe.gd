## Resource recipe for Control-domain juice effects.
##
## Narrows the effects array type hint so the inspector dropdown only
## shows JuiceControlEffectBase subclasses (not 2D/3D effects).

# ============================================================================
# WHAT: Recipe for Control-domain juice effects.
# WHY: Narrows the effects array type hint so the inspector dropdown only
#      shows JuiceControlEffectBase subclasses (not 2D/3D effects).
# SYSTEM: Juice System (addons/Juice_V1/)
# DOES NOT: Change any recipe behavior — inherits everything from JuiceRecipe.
# ============================================================================

@tool
class_name JuiceControlRecipe
extends JuiceRecipe


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Whitelist of concrete Control-domain effect class names.
## Update this list when adding new Control effects.
const _CONCRETE_EFFECTS := "AppearanceControlJuiceEffect,CallMethodControlJuiceUtility,Camera2DJuiceEffect,Camera3DJuiceEffect,NoiseControlJuiceEffect,PauseControlJuiceEffect,ProgressTransformControlJuiceEffect,SceneActionControlJuiceUtility,ScreenJuiceEffect,ScreenOverlayControlJuiceEffect,ShakeControlJuiceEffect,SignalEmitControlJuiceUtility,SquashStretchControlJuiceEffect,TimeControlJuiceEffect,TransformControlJuiceEffect,VFXJuiceEffect"

## Override the effects array element type to list only concrete classes.
## This hides JuiceControlEffectBase from the inspector dropdown.
func _validate_property(property: Dictionary) -> void:
	if property.name == "effects":
		property.hint_string = str(TYPE_OBJECT) + "/" + str(PROPERTY_HINT_RESOURCE_TYPE) + ":" + _CONCRETE_EFFECTS
