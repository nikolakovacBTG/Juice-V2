# Core Assertions for Juice Tests

## Basic Float/Vector Comparisons

```gdscript
# Floats
assert_approx_float(actual: float, expected: float, message: String = "")
assert_not_approx_float(actual: float, expected: float, message: String = "")

# Vector2 (2D & Control)
assert_approx_vec2(actual: Vector2, expected: Vector2, message: String = "")
assert_not_approx_vec2(actual: Vector2, expected: Vector2, message: String = "")

# Vector3 (3D)
assert_approx_vec3(actual: Vector3, expected: Vector3, message: String = "")
assert_not_approx_vec3(actual: Vector3, expected: Vector3, message: String = "")
```

## State Verification

### Wait for animation completion
```gdscript
juice.animate_in()
# Add small buffer to duration to ensure completion
await wait_seconds(effect.duration_in + 0.1) 
```

### Wait for mid-animation
```gdscript
juice.animate_in()
# Wait half duration to catch it in motion
await wait_seconds(effect.duration_in * 0.5)
```

## Helper Nodes

```gdscript
# Create target based on domain
var target = create_control_target("TargetName")
var target = create_2d_target("TargetName")
var target = create_3d_target("TargetName")

# Create and configure juice node
var juice = create_juice_control(effect, target)
var juice = create_juice_2d(effect, target)
var juice = create_juice_3d(effect, target)
```

## Common Testing Patterns

### Volume Preservation (Squash/Stretch)
```gdscript
# Verify area/volume stays constant despite scale changes
var start_area = natural_scale.x * natural_scale.y
var current_area = target.scale.x * target.scale.y
assert_approx_float(current_area, start_area, "Volume should be preserved")
```

### Noise/Procedural (Changing values)
```gdscript
# Record value, wait one frame, ensure it changed
var val1 = target.position
await get_tree().process_frame
var val2 = target.position
assert_not_approx_vec2(val1, val2, "Procedural effect should change per frame")
```
