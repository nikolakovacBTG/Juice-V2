## JuiceControlRecipe.gd
## ============================================================================
## WHAT: Recipe for Control-domain juice effects.
## WHY: Narrows the effects array type hint so the inspector dropdown only
##      shows JuiceControlEffectBase subclasses (not 2D/3D effects).
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Change any recipe behavior — inherits everything from JuiceRecipe.
## ============================================================================

@tool
class_name JuiceControlRecipe
extends JuiceRecipe


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Whitelist of concrete Control-domain effect class names.
## Update this list when adding new Control effects.
const _CONCRETE_EFFECTS := "AppearanceControlJuiceEffect,NoiseControlJuiceEffect,ScreenOverlayControlJuiceEffect,ShakeControlJuiceEffect,SquashStretchControlJuiceEffect,TransformControlJuiceEffect"

## Override the effects array element type to list only concrete classes.
## This hides JuiceControlEffectBase from the inspector dropdown.
func _validate_property(property: Dictionary) -> void:
	if property.name == "effects":
		property.hint_string = str(TYPE_OBJECT) + "/" + str(PROPERTY_HINT_RESOURCE_TYPE) + ":" + _CONCRETE_EFFECTS
