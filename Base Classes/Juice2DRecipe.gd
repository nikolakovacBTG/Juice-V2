## Juice2DRecipe.gd
## ============================================================================
## WHAT: Recipe for 2D-domain juice effects.
## WHY: Narrows the effects array type hint so the inspector dropdown only
##      shows Juice2DEffectBase subclasses (not Control/3D effects).
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Change any recipe behavior — inherits everything from JuiceRecipe.
## ============================================================================

@tool
class_name Juice2DRecipe
extends JuiceRecipe


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Whitelist of concrete 2D-domain effect class names.
## Update this list when adding new 2D effects.
const _CONCRETE_EFFECTS := "Appearance2DJuiceEffect,Noise2DJuiceEffect,ScreenOverlay2DJuiceEffect,Shake2DJuiceEffect,SquashStretch2DJuiceEffect,Time2DJuiceEffect,Transform2DJuiceEffect"

## Override the effects array element type to list only concrete classes.
## This hides Juice2DEffectBase from the inspector dropdown.
func _validate_property(property: Dictionary) -> void:
	if property.name == "effects":
		property.hint_string = str(TYPE_OBJECT) + "/" + str(PROPERTY_HINT_RESOURCE_TYPE) + ":" + _CONCRETE_EFFECTS
