# Conditional Exports (Hybrid Approach)

Juice effects often need to show or hide properties—or entire groups—based on the state of a "selector" variable (like `transform_target` or `appearance_effect`).

We use a **Hybrid Approach** combining two methods depending on the need:

## Approach A: `_validate_property` (Simple Toggles)

Use this when you have static groups, but want to hide specific `@export` properties within them based on a condition.

**Rules:**
1. Properties are normal `@export var`s. They serialize normally.
2. The controlling variable MUST have a GDScript setter that calls `notify_property_list_changed()`.
3. Override `_validate_property()` to hide properties by setting `PROPERTY_USAGE_NO_EDITOR`.

```gdscript
@export var use_flicker: bool = false:
    set(value):
        use_flicker = value
        notify_property_list_changed()

@export var flicker_rate: float = 10.0

func _validate_property(property: Dictionary) -> void:
    if not use_flicker and property.name == "flicker_rate":
        property.usage |= PROPERTY_USAGE_NO_EDITOR
```

## Approach B: `_get_property_list` (Dynamic Groups)

Use this when you need **entire groups to appear/disappear**, need **custom property ordering**, or have properties that should **NOT serialize** when hidden.

**Rules:**
1. Backing variables are plain `var` (not `@export`).
2. The controlling variable MUST have a GDScript setter that calls `notify_property_list_changed()`.
3. Build and return the properties/groups dynamically in `_get_property_list()`.

```gdscript
var transform_target: int = TransformTarget.POSITION:
    set(value):
        transform_target = value
        notify_property_list_changed()

func _get_property_list() -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    
    # 1. Main group
    props.append({"name": "Effect", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append(_make_enum("transform_target", TransformTarget))
    
    # 2. Dynamic groups based on target
    if transform_target == TransformTarget.ROTATION:
        props.append({"name": "Pivot", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
        props.append({"name": "pivot_mode", "type": TYPE_INT, ...})
        
    return props
```

## Critical Shared Rules

**NEVER rely solely on `_set()` to trigger inspector updates.** Godot may bypass `_set()` and set the member variable directly when a matching variable name exists on the class. The GDScript setter on the variable itself (`set(value):`) is the only reliable way to trigger `notify_property_list_changed()`.
