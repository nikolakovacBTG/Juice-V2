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

## Narrow the effects array element type from JuiceEffectBase to Juice3DEffectBase.
## This makes the inspector "New" dropdown only show 3D-domain effects.
func _validate_property(property: Dictionary) -> void:
	if property.name == "effects":
		property.hint_string = str(TYPE_OBJECT) + "/" + str(PROPERTY_HINT_RESOURCE_TYPE) + ":Juice3DEffectBase"
