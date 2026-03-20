## ControlJuiceRecipe.gd
## ============================================================================
## WHAT: Recipe for Control-domain juice effects.
## WHY: Narrows the effects array type hint so the inspector dropdown only
##      shows ControlJuiceEffectBase subclasses (not 2D/3D effects).
## SYSTEM: Juicing System (addons/Juice_V1/)
## DOES NOT: Change any recipe behavior — inherits everything from JuiceRecipe.
## ============================================================================

@tool
class_name ControlJuiceRecipe
extends JuiceRecipe


# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

## Narrow the effects array element type from JuiceEffectBase to ControlJuiceEffectBase.
## This makes the inspector "New" dropdown only show Control-domain effects.
func _validate_property(property: Dictionary) -> void:
	if property.name == "effects":
		property.hint_string = str(TYPE_OBJECT) + "/" + str(PROPERTY_HINT_RESOURCE_TYPE) + ":ControlJuiceEffectBase"
