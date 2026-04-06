# From/To Layout Pattern

When an effect moves a property from a starting state to an ending state, and its nature allows for `From` and `To` endpoints, it MUST use the standard `From` and `To` inspector pattern.

This pattern is deeply rooted in the core design established in `@Transform_FromTo_Design` (included in this skill folder for deep architectural reference).

## Inspector Appearance
The `From` and `To` groups are **separate groups** (not properties inside the `Effect` group). They are placed after the main `Effect` group and any effect-specific subgroups, but before `Animate In`.

```text
[From]
├─ from_reference: [Custom ▼]
├─ [from-specific params...]

[To]
├─ to_reference: [Custom ▼]
├─ [to-specific params...]
```

## The Reference Enum
Endpoints generally use a reference enum to determine how their value is acquired. While the standard 3-option pattern (`Custom`, `Self`, `Target Node`) is common in effects like Transform, **this is not a strict requirement for all effects**. 

Some effects may only support a subset (e.g., omitting `Target Node` if it doesn't make sense for that specific effect type). Use the options that are logically applicable to the effect's nature.

## Capture Timing
When `Self` is available and selected, the effect must know *when* to capture the snapshot. This is controlled by a `capture_at` property (Trigger, Ready, or In Editor).
**Rule:** The `capture_at` property belongs inside the `From` or `To` group, visible only when the reference is set to `Self`.

## Implementation Example (Dynamic Groups)
Because entire groups appear and disappear based on the effect's nature, this pattern is implemented using the `_get_property_list()` approach (see `@conditional-exports-hybrid`).

```gdscript
func _get_property_list() -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    
    # ... (Effect group emitted first) ...
    
    # --- From Group ---
    props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append(_make_enum("from_reference", TransformReference))
    
    if from_reference == TransformReference.CUSTOM:
        props.append({"name": "from_position", "type": TYPE_VECTOR2, "usage": PROPERTY_USAGE_EDITOR})
    elif from_reference == TransformReference.SELF:
        props.append(_make_enum("capture_at", CaptureAt))
        
    # --- To Group ---
    props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append(_make_enum("to_reference", TransformReference))
    
    # ... (Conditional To properties) ...
    
    return props
```
