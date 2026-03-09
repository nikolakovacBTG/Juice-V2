# Upgrades and Fixes TO DO

## Transform Components UX Overhaul (Position, Rotation, Scale)

### Problem Statement

Current Transform2D/3DJuiceComp uses an "offset" model for all transform types:
- **Position**: `position_offset` + `position_offset_unit` — only adds offset to current position
- **Rotation**: `rotation_offset_degrees` — only adds offset to current rotation, no target node support
- **Scale**: `scale_offset` — only adds offset to current scale, cannot animate from zero to current
- **Inconsistent patterns**: Position has units, rotation has degrees, scale has raw multipliers
- **Limited target support**: Position and scale have basic `transform_target_node`, rotation has none
- **Poor inspector organization**: Conditional exports not grouped logically

### Design Goals

1. Replace offset model with explicit **"From [source] To [destination]"** for all three transform types
2. Enable previously impossible animations (e.g., scale from zero to current, rotate toward target)
3. Clean inspector UI with conditional hiding via `_get_property_list()` and `PROPERTY_USAGE_GROUP`
4. Consistent mental model across position, rotation, and scale
5. Preserve position's coordinate system (pixels, fractions, etc.) with better naming
6. Context-aware capture timing — only shown when relevant, inside the group that needs it
7. Backward compatible — all current offset behaviors achievable in new system

---

### Core Concept: "From [source] To [destination]"

Each transform type gets independent **From** and **To** axes. Each axis has a **reference type** that determines where the value comes from:

- **Custom** — Explicit value entered by user
- **Self** — This object's own transform, captured once (when depends on `capture_at`)
- **Target Node** — Another object's transform via NodePath, **tracked live every frame**

This gives **9 combinations** per transform type (3x3 grid) instead of the current limited offset model.

#### Reference Behavior

| Reference | Resolution | Inspector fields |
|---|---|---|
| **Custom** | Static value from inspector | Value field(s) + coordinate system (position only) |
| **Self** | Captured once at a chosen moment | `capture_at` picker (Trigger or Ready) |
| **Target Node** | Live-tracked every frame | NodePath picker |

**Key insight**: Target Node does NOT need a capture moment — it is re-evaluated every frame,
supporting moving targets naturally. Only **Self** needs `capture_at` because Self's transform
changes during animation, so we must know which snapshot to use as reference.

#### Configuration Warning

If both From and To are set to **Self**, the component shows a yellow warning triangle:
"Both From and To reference Self — animation will have no visible effect."

---

### Enums and Types

```gdscript
# --- Shared ---

enum TransformTarget {
    POSITION,
    ROTATION,
    SCALE,
}

## When to capture Self's transform value.
## Only relevant when reference is SELF.
## Field name: capture_at — reads as "capture at trigger" / "capture at ready".
enum CaptureAt {
    TRIGGER,    # Capture when animation starts (default)
    READY       # Capture when scene loads / _ready() (stable baseline)
}

# --- Position ---

enum PositionReference {
    CUSTOM,         # Explicit position values
    SELF,           # This object's own position (captured at capture_at moment)
    TARGET_NODE     # Another object's position (tracked live every frame)
}

## How to interpret custom position values.
## Renamed from "OffsetUnit" / "position_offset_unit" — fractions are not units.
enum PositionIn {
    PIXELS,           # Position in absolute pixels
    FRACTION_OWN,     # Position in fraction of object's own size
    FRACTION_PARENT,  # Position in fraction of parent's size
    FRACTION_VIEWPORT # Position in fraction of viewport size (2D only)
}

## 3D equivalent — no viewport fraction, uses world units instead of pixels.
enum PositionIn3D {
    WORLD_UNITS,      # Position in world units
    FRACTION_OWN,     # Position in fraction of object's own AABB
    FRACTION_PARENT   # Position in fraction of parent's AABB
}

# --- Rotation ---

enum RotationReference {
    CUSTOM,         # Explicit rotation value
    SELF,           # This object's current rotation (captured at capture_at moment)
    TARGET_NODE     # Another object's rotation (tracked live — NEW)
}

## 3D only — rotation values can be entered in degrees or radians.
## 2D rotation is always a single float in degrees (no unit picker needed).
enum RotationUnit {
    DEGREES,    # More intuitive for most users (default)
    RADIANS     # For precise control
}

# --- Scale ---

enum ScaleReference {
    CUSTOM,         # Explicit scale value (Vector2/Vector3)
    SELF,           # This object's current scale (captured at capture_at moment)
    TARGET_NODE     # Another object's scale (tracked live)
}
```

### Variable Renames

| Current Name | New Name | Reason |
|---|---|---|
| `position_offset` | `from_position` / `to_position` | From/To model replaces offset |
| `position_offset_unit` | `from_position_in` / `to_position_in` | "In" is clearer than "unit" for fractions |
| `rotation_offset_degrees` | `from_rotation_degrees` / `to_rotation_degrees` | From/To model replaces offset |
| `scale_offset` | `from_scale` / `to_scale` | From/To model replaces offset |
| `transform_target_node` | `from_target_node` / `to_target_node` | Separate target per axis |
| `transform_target` | `transform_type` | Clarity |
| `sampling_point` | `capture_at` | Context-aware, no "at" doubling |
| `CURRENT_SELF` | `SELF` | "When" answered by `capture_at`, not the reference name |

### Backing Variables

```gdscript
# Reference enums — trigger inspector refresh on change
var from_reference: int = 0:  # PositionReference / RotationReference / ScaleReference
    set(value):
        from_reference = value
        notify_property_list_changed()

var to_reference: int = 1:  # Default: SELF
    set(value):
        to_reference = value
        notify_property_list_changed()

# Position
var from_position: Vector2 = Vector2.ZERO        # Vector3 for 3D
var from_position_in: int = PositionIn.PIXELS     # PositionIn3D for 3D
var to_position: Vector2 = Vector2.ZERO
var to_position_in: int = PositionIn.PIXELS

# Rotation (2D: single float in degrees. 3D: Vector3 + RotationUnit)
var from_rotation_degrees: float = 0.0       # 2D only
var to_rotation_degrees: float = 0.0         # 2D only
var from_rotation: Vector3 = Vector3.ZERO     # 3D only
var to_rotation: Vector3 = Vector3.ZERO       # 3D only
var rotation_unit: int = RotationUnit.DEGREES # 3D only — applies to Custom values

# Scale
var from_scale: Vector2 = Vector2.ZERO            # Vector3 for 3D
var to_scale: Vector2 = Vector2.ONE

# Target nodes (shared across types)
var from_target_node: NodePath
var to_target_node: NodePath

# Capture timing — only relevant when Self is selected in From or To.
# Placed inside the From/To group that uses Self (not a separate group).
var capture_at: int = CaptureAt.TRIGGER
```

---

### Inspector Structure: `_get_property_list()`

```gdscript
# @export variables at top (always-visible)
@export var transform_type: TransformTarget = TransformTarget.POSITION
@export var pivot_mode: PivotMode = PivotMode.AUTO_CENTER

func _get_property_list() -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    
    match transform_type:
        TransformTarget.POSITION:
            props.append_array(_get_position_properties())
        TransformTarget.ROTATION:
            props.append_array(_get_rotation_properties())
        TransformTarget.SCALE:
            props.append_array(_get_scale_properties())
    
    return props
```

#### Helper: Append `capture_at` inside a group when Self is selected

```gdscript
## Appends the capture_at field. Call this inside From/To group
## immediately after the reference enum, when reference == SELF.
func _append_capture_at(props: Array[Dictionary]) -> void:
    props.append({
        "name": "capture_at",
        "type": TYPE_INT,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Trigger,Ready",
    })
```

#### Position Properties

```gdscript
func _get_position_properties() -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    
    # --- From group ---
    props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append({
        "name": "from_reference",
        "type": TYPE_INT,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Custom,Self,Target Node",
    })
    
    if from_reference == PositionReference.CUSTOM:
        props.append({
            "name": "from_position_in",
            "type": TYPE_INT,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "Pixels,Fraction Own,Fraction Parent,Fraction Viewport",
            # 3D: "World Units,Fraction Own,Fraction Parent"
        })
        props.append({
            "name": "from_position",
            "type": TYPE_VECTOR2, # TYPE_VECTOR3 for 3D
            "usage": PROPERTY_USAGE_DEFAULT,
        })
    elif from_reference == PositionReference.SELF:
        _append_capture_at(props)
    elif from_reference == PositionReference.TARGET_NODE:
        props.append({
            "name": "from_target_node",
            "type": TYPE_NODE_PATH,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
            "hint_string": "Node2D", # "Node3D" for 3D
        })
    
    # --- To group ---
    props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append({
        "name": "to_reference",
        "type": TYPE_INT,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Custom,Self,Target Node",
    })
    
    if to_reference == PositionReference.CUSTOM:
        props.append({
            "name": "to_position_in",
            "type": TYPE_INT,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "Pixels,Fraction Own,Fraction Parent,Fraction Viewport",
        })
        props.append({
            "name": "to_position",
            "type": TYPE_VECTOR2,
            "usage": PROPERTY_USAGE_DEFAULT,
        })
    elif to_reference == PositionReference.SELF:
        _append_capture_at(props)
    elif to_reference == PositionReference.TARGET_NODE:
        props.append({
            "name": "to_target_node",
            "type": TYPE_NODE_PATH,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
            "hint_string": "Node2D",
        })
    
    return props
```

#### Rotation Properties

```gdscript
func _get_rotation_properties() -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    
    # --- From group ---
    props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append({
        "name": "from_reference",
        "type": TYPE_INT,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Custom,Self,Target Node",
    })
    
    if from_reference == RotationReference.CUSTOM:
        props.append({
            "name": "from_rotation_degrees",
            "type": TYPE_FLOAT,
            "usage": PROPERTY_USAGE_DEFAULT,
        })
    elif from_reference == RotationReference.SELF:
        _append_capture_at(props)
    elif from_reference == RotationReference.TARGET_NODE:
        props.append({
            "name": "from_target_node",
            "type": TYPE_NODE_PATH,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
            "hint_string": "Node2D",
        })
    
    # --- To group ---
    props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append({
        "name": "to_reference",
        "type": TYPE_INT,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Custom,Self,Target Node",
    })
    
    if to_reference == RotationReference.CUSTOM:
        props.append({
            "name": "to_rotation_degrees",
            "type": TYPE_FLOAT,
            "usage": PROPERTY_USAGE_DEFAULT,
        })
    elif to_reference == RotationReference.SELF:
        _append_capture_at(props)
    elif to_reference == RotationReference.TARGET_NODE:
        props.append({
            "name": "to_target_node",
            "type": TYPE_NODE_PATH,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
            "hint_string": "Node2D",
        })
    
    return props
```

#### Rotation Properties (3D version — Vector3 + RotationUnit + pivot)

3D rotation differs from 2D in three ways:
- **3-axis rotation** (Vector3 instead of float)
- **RotationUnit** picker (Degrees/Radians) shown when any Custom reference is selected
- **rotation_pivot_offset** (Vector3) for rotating around arbitrary points (door hinges, levers)
- **Quaternion slerp** used for Target Node mode (handles >180°, no gimbal lock)

```gdscript
# 3D variant — differences from 2D marked with # <<< 3D
func _get_rotation_properties() -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    
    # --- From group ---
    props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append({
        "name": "from_reference",
        "type": TYPE_INT,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Custom,Self,Target Node",
    })
    
    if from_reference == RotationReference.CUSTOM:
        props.append({
            "name": "from_rotation",                            # <<< 3D: Vector3
            "type": TYPE_VECTOR3,                               # <<< 3D
            "usage": PROPERTY_USAGE_DEFAULT,
        })
    elif from_reference == RotationReference.SELF:
        _append_capture_at(props)
    elif from_reference == RotationReference.TARGET_NODE:
        props.append({
            "name": "from_target_node",
            "type": TYPE_NODE_PATH,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
            "hint_string": "Node3D",                            # <<< 3D
        })
    
    # --- To group ---
    props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append({
        "name": "to_reference",
        "type": TYPE_INT,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Custom,Self,Target Node",
    })
    
    if to_reference == RotationReference.CUSTOM:
        props.append({
            "name": "to_rotation",                              # <<< 3D: Vector3
            "type": TYPE_VECTOR3,                               # <<< 3D
            "usage": PROPERTY_USAGE_DEFAULT,
        })
    elif to_reference == RotationReference.SELF:
        _append_capture_at(props)
    elif to_reference == RotationReference.TARGET_NODE:
        props.append({
            "name": "to_target_node",
            "type": TYPE_NODE_PATH,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
            "hint_string": "Node3D",                            # <<< 3D
        })
    
    # --- Rotation settings (3D only, shown when any Custom is selected) ---
    if from_reference == RotationReference.CUSTOM or to_reference == RotationReference.CUSTOM:
        props.append({"name": "Rotation Settings", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
        props.append({
            "name": "rotation_unit",
            "type": TYPE_INT,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_ENUM,
            "hint_string": "Degrees,Radians",
        })
    
    # rotation_pivot_offset — always shown for rotation (3D only)
    props.append({
        "name": "rotation_pivot_offset",
        "type": TYPE_VECTOR3,
        "usage": PROPERTY_USAGE_DEFAULT,
    })
    
    return props
```

#### Scale Properties

```gdscript
func _get_scale_properties() -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    
    # --- From group ---
    props.append({"name": "From", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append({
        "name": "from_reference",
        "type": TYPE_INT,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Custom,Self,Target Node",
    })
    
    if from_reference == ScaleReference.CUSTOM:
        props.append({
            "name": "from_scale",
            "type": TYPE_VECTOR2, # TYPE_VECTOR3 for 3D
            "usage": PROPERTY_USAGE_DEFAULT,
        })
    elif from_reference == ScaleReference.SELF:
        _append_capture_at(props)
    elif from_reference == ScaleReference.TARGET_NODE:
        props.append({
            "name": "from_target_node",
            "type": TYPE_NODE_PATH,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
            "hint_string": "Node2D",
        })
    
    # --- To group ---
    props.append({"name": "To", "type": TYPE_NIL, "usage": PROPERTY_USAGE_GROUP})
    props.append({
        "name": "to_reference",
        "type": TYPE_INT,
        "usage": PROPERTY_USAGE_DEFAULT,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "Custom,Self,Target Node",
    })
    
    if to_reference == ScaleReference.CUSTOM:
        props.append({
            "name": "to_scale",
            "type": TYPE_VECTOR2,
            "usage": PROPERTY_USAGE_DEFAULT,
        })
    elif to_reference == ScaleReference.SELF:
        _append_capture_at(props)
    elif to_reference == ScaleReference.TARGET_NODE:
        props.append({
            "name": "to_target_node",
            "type": TYPE_NODE_PATH,
            "usage": PROPERTY_USAGE_DEFAULT,
            "hint": PROPERTY_HINT_NODE_PATH_VALID_TYPES,
            "hint_string": "Node2D",
        })
    
    return props
```

---

### Inspector Flow Diagrams

#### Position (From Custom → To Self)

```
Transform
├─ transform_type: [Position ▼]
├─ pivot_mode: [Auto Center ▼]

From
├─ from_reference: [Custom ▼]
├─ from_position_in: [Pixels ▼]
└─ from_position: [-1000, 0]

To
├─ to_reference: [Self ▼]
└─ capture_at: [Trigger ▼]
```

#### Position (From Self → To Target Node)

```
Transform
├─ transform_type: [Position ▼]
├─ pivot_mode: [Auto Center ▼]

From
├─ from_reference: [Self ▼]
└─ capture_at: [Trigger ▼]

To
├─ to_reference: [Target Node ▼]
└─ to_target_node: [../TargetObject]
```

#### Rotation (From Custom → To Self)

```
Transform
├─ transform_type: [Rotation ▼]
├─ pivot_mode: [Auto Center ▼]

From
├─ from_reference: [Custom ▼]
└─ from_rotation_degrees: [45.0]

To
├─ to_reference: [Self ▼]
└─ capture_at: [Trigger ▼]
```

#### Scale (From Custom → To Self)

```
Transform
├─ transform_type: [Scale ▼]
├─ pivot_mode: [Auto Center ▼]

From
├─ from_reference: [Custom ▼]
└─ from_scale: [0, 0]

To
├─ to_reference: [Self ▼]
└─ capture_at: [Trigger ▼]
```

#### Scale (From Custom → To Custom — no capture_at needed)

```
Transform
├─ transform_type: [Scale ▼]
├─ pivot_mode: [Auto Center ▼]

From
├─ from_reference: [Custom ▼]
└─ from_scale: [0.5, 0.5]

To
├─ to_reference: [Custom ▼]
└─ to_scale: [1.5, 1.5]
```

---

### Use Cases

#### Position

##### "Slide from off-screen to current position"
```
From
├─ from_reference: [Custom ▼]
├─ from_position_in: [Pixels ▼]
└─ from_position: [-1000, 0]

To
├─ to_reference: [Self ▼]
└─ capture_at: [Trigger ▼]
```

##### "Move to target position"
```
From
├─ from_reference: [Self ▼]
└─ capture_at: [Trigger ▼]

To
├─ to_reference: [Target Node ▼]
└─ to_target_node: [../TargetObject]
```

##### "Slide from screen edge to center"
```
From
├─ from_reference: [Custom ▼]
├─ from_position_in: [Fraction Viewport ▼]
└─ from_position: [-0.5, 0]

To
├─ to_reference: [Self ▼]
└─ capture_at: [Trigger ▼]
```

##### "Move from parent edge"
```
From
├─ from_reference: [Custom ▼]
├─ from_position_in: [Fraction Parent ▼]
└─ from_position: [0, -0.5]

To
├─ to_reference: [Self ▼]
└─ capture_at: [Trigger ▼]
```

##### "Both Custom with different coordinate systems"
```
From
├─ from_reference: [Custom ▼]
├─ from_position_in: [Pixels ▼]
└─ from_position: [100, 50]

To
├─ to_reference: [Custom ▼]
├─ to_position_in: [Fraction Own ▼]
└─ to_position: [0.5, 0.25]
```

##### Legacy offset behavior (equivalent)
```
From
├─ from_reference: [Self ▼]
└─ capture_at: [Trigger ▼]

To
├─ to_reference: [Custom ▼]
├─ to_position_in: [Pixels ▼]
└─ to_position: [-50, 0]
```

#### Rotation

##### "Spin from angle to face forward"
```
From
├─ from_reference: [Custom ▼]
└─ from_rotation_degrees: [45.0]

To
├─ to_reference: [Custom ▼]
└─ to_rotation_degrees: [0.0]
```

##### "Face target direction"
```
From
├─ from_reference: [Self ▼]
└─ capture_at: [Trigger ▼]

To
├─ to_reference: [Target Node ▼]
└─ to_target_node: [../TargetObject]
```

##### Legacy offset behavior (equivalent)
```
From
├─ from_reference: [Self ▼]
└─ capture_at: [Trigger ▼]

To
├─ to_reference: [Custom ▼]
└─ to_rotation_degrees: [15.0]
```

#### Scale

##### "Grow from nothing to current scale"
```
From
├─ from_reference: [Custom ▼]
└─ from_scale: [0, 0]

To
├─ to_reference: [Self ▼]
└─ capture_at: [Trigger ▼]
```

##### "Scale to target's size"
```
From
├─ from_reference: [Self ▼]
└─ capture_at: [Trigger ▼]

To
├─ to_reference: [Target Node ▼]
└─ to_target_node: [../OtherObject]
```

##### "Scale from target to custom"
```
From
├─ from_reference: [Target Node ▼]
└─ from_target_node: [../SourceObject]

To
├─ to_reference: [Custom ▼]
└─ to_scale: [2, 2]
```

##### "Pulse between two sizes"
```
From
├─ from_reference: [Custom ▼]
└─ from_scale: [0.5, 0.5]

To
├─ to_reference: [Custom ▼]
└─ to_scale: [1.5, 1.5]
```

##### Legacy offset behavior (equivalent)
```
From
├─ from_reference: [Self ▼]
└─ capture_at: [Trigger ▼]

To
├─ to_reference: [Custom ▼]
└─ to_scale: [1.1, 1.1]
```

---

### Implementation Notes

#### Reference Resolution Behavior

| Reference | When resolved | Re-evaluated? |
|---|---|---|
| **Custom** | Constant from inspector | No |
| **Self** | Once, at moment chosen by `capture_at` | No — snapshot is stable |
| **Target Node** | Every frame in `_process` / `_physics_process` | Yes — supports moving targets |

#### Coordinate System Conversion (Position)

When From and To use different `PositionIn` values, both must be converted to a common
space (world pixels) before interpolation. The current implementation already does this
conversion in `_calculate_position_offset()` — the new system extends it to both axes:

```gdscript
func _convert_to_world_pixels(position: Vector2, position_in: PositionIn) -> Vector2:
    match position_in:
        PositionIn.PIXELS:
            return position
        PositionIn.FRACTION_OWN:
            var size := _infer_node2d_size(_target_node as Node2D)
            return Vector2(position.x * size.x, position.y * size.y)
        PositionIn.FRACTION_PARENT:
            var size := _infer_parent_size()
            return Vector2(position.x * size.x, position.y * size.y)
        PositionIn.FRACTION_VIEWPORT:
            var size := _get_viewport_size()
            return Vector2(position.x * size.x, position.y * size.y)
    return position

func _get_interpolated_position(progress: float) -> Vector2:
    var start := _resolve_from_position()   # Convert to world pixels
    var end := _resolve_to_position()       # Convert to world pixels
    return start.lerp(end, progress)
```

#### Configuration Warnings

Add to `_get_configuration_warnings()`:
- **Self + Self**: "Both From and To reference Self — animation will have no visible effect."

#### Animation Math Change: Offset → Lerp

The current system uses **offset * progress**:
```gdscript
# CURRENT: offset model
var desired := scale_offset * progress
var delta := desired - _my_scale_contribution
target.scale += delta
```

The new system uses **lerp(from, to, progress)** with delta-first writes:
```gdscript
# NEW: From/To model
var from_value := _resolve_from_scale()   # Custom value, Self snapshot, or Target live
var to_value := _resolve_to_scale()       # Custom value, Self snapshot, or Target live
var desired := from_value.lerp(to_value, progress)
var desired_offset := desired - _base_scale  # Convert absolute to delta from base
var delta := desired_offset - _my_scale_contribution
target.scale += delta
_my_scale_contribution = desired_offset
```

Key difference: `_resolve_from/to_*()` returns **absolute values** (not offsets).
The delta-first write pattern is preserved — only the value resolution changes.

#### Internal Naming: `_target_node` vs Reference Nodes

`_target_node` already exists in `JuiceCompBase` (line 415) as **the node being animated**
(usually the parent). The new `from_target_node` / `to_target_node` are **external reference
nodes** whose transforms are read as From/To values.

| Name | What it is | Defined in |
|---|---|---|
| `_target_node` | The node being animated (parent) | `JuiceCompBase` — do NOT rename |
| `from_target_node` | Inspector NodePath for From reference | New backing var |
| `to_target_node` | Inspector NodePath for To reference | New backing var |
| `_from_ref` | Cached resolved node from `from_target_node` | New internal var |
| `_to_ref` | Cached resolved node from `to_target_node` | New internal var |

The old `_target_ref` (single cached reference) is replaced by `_from_ref` and `_to_ref`.

#### 3D Rotation Specifics

3D rotation has significant differences from 2D that must be preserved:

| Aspect | 2D | 3D |
|---|---|---|
| **Custom value type** | `float` (degrees) | `Vector3` + `RotationUnit` (degrees/radians) |
| **Inspector field** | `from/to_rotation_degrees` | `from/to_rotation` (Vector3) |
| **Target Node mode** | Simple float difference | Quaternion slerp (handles >180°, no gimbal lock) |
| **Pivot** | `pivot_mode` + `custom_pivot` (Vector2) | `rotation_pivot_offset` (Vector3, always shown) |
| **Interpolation** | Linear float lerp | Quaternion slerp for smooth 3D interpolation |
| **Internal base** | `_base_rotation_radians: float` | `_base_transform: Transform3D` (full transform for quat math) |

For 3D Target Node mode, the existing quaternion slerp in `_apply_rotation_to_target()` maps
directly to the new From/To model — it already computes `base_quat.slerp(target_quat, progress)`.

#### General

- Apply to both Transform2DJuiceComp and Transform3DJuiceComp
- 2D uses Vector2, 3D uses Vector3
- 2D uses `PositionIn`, 3D uses `PositionIn3D`
- Update recipe contract methods for new reference system
- Move `pivot_mode` directly under `transform_type` (affects all transform types)
- Rename `transform_target` to `transform_type` for clarity

---

### Legacy Behavior Mapping

All current behaviors map cleanly to new system:

| Current | New Equivalent |
|---|---|
| `position_offset` + `position_offset_unit` | From Self → To Custom (with `to_position_in`) |
| `rotation_offset_degrees` | From Self → To Custom (`to_rotation_degrees`) |
| `scale_offset` | From Self → To Custom (`to_scale`) |
| `transform_target_node` (position/scale) | From Self → To Target Node |

### Benefits

1. **Consistency** — Same mental model across position, rotation, and scale
2. **Power** — Previously impossible animations become trivial (zero→current, rotate→target)
3. **Clarity** — No more "offset vs absolute" confusion
4. **Clean naming** — `position_in` instead of `position_offset_unit`, `Self` instead of `Current Self`
5. **Context-aware** — `capture_at` only appears inside the group that needs it, not as a separate section
6. **Live tracking** — Target Node tracks every frame, no sampling config needed
7. **Extensibility** — Easy to add new reference types (RELATIVE, INHERITED, etc.)
8. **Target support** — Rotation gains target node capability
9. **Coordinate system preserved** — Position keeps its valuable system with better naming
10. **Backward compatible** — All current offset behaviors achievable
11. **9 combinations** — 3x3 grid per transform type instead of limited offset + flags

### Implementation Priority

1. **Scale** (HIGH) — ✅ DONE
2. **Position** (HIGH) — ✅ DONE
3. **Rotation** (MEDIUM) — ✅ DONE

### Post-Implementation Notes

- All three transform types implemented with From/To model in both 2D and 3D
- Separate `PositionReference`, `RotationReference`, `ScaleReference` enums unified into single `TransformReference` enum
- Class docs brought up to spec (brief + description in `##`, dev notes demoted to `#`)
- Base euler/quaternion caching added in 3D for performance
- Snapshot captures guarded — only if SELF is actually referenced

---

## Performance Profiling (Future — Post-Demo, Pre-Ship)

### When

After all demo scenes are feature-complete and all comps are documented. Before final shipping polish. Profiling results inform whether any optimization is needed.

### What to Test

1. **Stress test scene** — Spawn N targets (100, 500, 1000, 5000) each with a juice stack, trigger all simultaneously
2. **Metrics**:
   - Frame time (ms) via `Performance.get_monitor(Performance.TIME_PROCESS)`
   - Node count via `Performance.get_monitor(Performance.OBJECT_NODE_COUNT)`
   - Memory via `Performance.get_monitor(Performance.MEMORY_STATIC)`
   - Per-comp cost via `Time.get_ticks_usec()` around `_apply_effect`
3. **Variants**: With/without Interaction comps (physics overhead), with/without pivot resolution (math overhead), idle stacks vs all-animating
4. **Output**: CSV or on-screen overlay with frame budget breakdown

### Expected Thresholds

- Hundreds of simultaneously-animating juice stacks should be fine
- Thousands may need profiling to confirm
- Real bottleneck is usually targets (draw calls, physics bodies), not juice nodes