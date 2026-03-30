## Juice3DRecipe.gd
## ============================================================================
## WHAT: Recipe for 3D-domain juice effects.
## WHY: Narrows the effects array type hint so the inspector dropdown only
##      shows Juice3DEffectBase subclasses (not Control/2D effects).
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Change any recipe behavior — inherits everything from JuiceRecipe.
## ============================================================================

@tool
class_name Juice3DRecipe
extends JuiceRecipe


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Whitelist of concrete 3D-domain effect class names.
## Update this list when adding new 3D effects.
const _CONCRETE_EFFECTS := "Appearance3DJuiceEffect,Noise3DJuiceEffect,ScreenOverlay3DJuiceEffect,Shake3DJuiceEffect,SquashStretch3DJuiceEffect,Time3DJuiceEffect,Transform3DJuiceEffect"

## Override the effects array element type to list only concrete classes.
## This hides Juice3DEffectBase from the inspector dropdown.
func _validate_property(property: Dictionary) -> void:
	if property.name == "effects":
		property.hint_string = str(TYPE_OBJECT) + "/" + str(PROPERTY_HINT_RESOURCE_TYPE) + ":" + _CONCRETE_EFFECTS
