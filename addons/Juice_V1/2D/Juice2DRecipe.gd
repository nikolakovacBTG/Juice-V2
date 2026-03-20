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

## Narrow the effects array element type from JuiceEffectBase to Juice2DEffectBase.
## This makes the inspector "New" dropdown only show 2D-domain effects.
func _validate_property(property: Dictionary) -> void:
	if property.name == "effects":
		property.hint_string = str(TYPE_OBJECT) + "/" + str(PROPERTY_HINT_RESOURCE_TYPE) + ":Juice2DEffectBase"
