## ShaderPropertyJuiceComp.gd
## ============================================================================
## WHAT: Animates any shader uniform on ShaderMaterial.
## WHY: Dissolve effects, custom shader animations, procedural effects.
## SYSTEM: Juicing System (addons/juice/)
## DOES NOT: Built-in material properties - use Appearance3DJuiceComp for that.
## ============================================================================
##
## ARCHITECTURE:
## - Generic animation of shader uniforms by name
## - Supports FLOAT, VECTOR2, VECTOR3, COLOR types
## - Delta-based: adds offset scaled by progress to base value
## - Automatically duplicates shared materials to avoid conflicts
##
## 2D vs 3D SUPPORT:
## - CanvasItem: Uses node.material (CanvasItemMaterial or ShaderMaterial)
## - MeshInstance3D: Uses material_override or surface material
##
## USAGE:
## - Add as child of node with ShaderMaterial
## - Set property_name to the uniform name (e.g., "dissolve_amount")
## - Set property_type and corresponding offset value
## - animate_in() applies offset, animate_out() removes it
##
## EXAMPLES:
## - Dissolve: property_name="dissolve_amount", float_offset=1.0
## - Outline glow: property_name="outline_width", float_offset=4.0
## - UV scroll: property_name="uv_offset", vector2_offset=Vector2(1, 0)
## ============================================================================

@tool
class_name ShaderPropertyJuiceComp
extends JuiceCompBase

# =============================================================================
# SHADER PROPERTY CONFIGURATION
# =============================================================================

@export_group("Shader Property")

## Type of the shader uniform to animate
enum ShaderPropertyType {
	FLOAT,      ## Single float value (e.g., dissolve_amount, glow_intensity)
	VECTOR2,    ## 2D vector (e.g., uv_offset, wind_direction)
	VECTOR3,    ## 3D vector (e.g., tint_color RGB, displacement)
	COLOR       ## Color with alpha (lerps from base to target)
}

## Name of the shader uniform to animate
@export var property_name: String = "dissolve_amount"

## Type of the property (must match shader uniform type).
## Controls which offset property is shown in the inspector.
var property_type: int = ShaderPropertyType.FLOAT:
	set(value):
		property_type = value
		notify_property_list_changed()

## Offset for FLOAT type (added to base value scaled by progress)
var float_offset: float = 1.0

## Offset for VECTOR2 type
var vector2_offset: Vector2 = Vector2.ONE

## Offset for VECTOR3 type
var vector3_offset: Vector3 = Vector3.ONE

## Target color for COLOR type (lerps from base to this)
var color_target: Color = Color.WHITE

# =============================================================================
# CONDITIONAL EXPORT SYSTEM
# =============================================================================

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	
	props.append({
		"name": "property_type",
		"type": TYPE_INT,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Float,Vector2,Vector3,Color",
	})
	
	## Only show the offset property that matches the current property_type
	match property_type:
		ShaderPropertyType.FLOAT:
			props.append({
				"name": "float_offset",
				"type": TYPE_FLOAT,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		ShaderPropertyType.VECTOR2:
			props.append({
				"name": "vector2_offset",
				"type": TYPE_VECTOR2,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		ShaderPropertyType.VECTOR3:
			props.append({
				"name": "vector3_offset",
				"type": TYPE_VECTOR3,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
		ShaderPropertyType.COLOR:
			props.append({
				"name": "color_target",
				"type": TYPE_COLOR,
				"usage": PROPERTY_USAGE_DEFAULT,
			})
	
	return props


func _set(prop_name: StringName, value: Variant) -> bool:
	match prop_name:
		&"property_type":
			property_type = value
			return true
		&"float_offset":
			float_offset = value
			return true
		&"vector2_offset":
			vector2_offset = value
			return true
		&"vector3_offset":
			vector3_offset = value
			return true
		&"color_target":
			color_target = value
			return true
	return false


func _get(prop_name: StringName) -> Variant:
	match prop_name:
		&"property_type":
			return property_type
		&"float_offset":
			return float_offset
		&"vector2_offset":
			return vector2_offset
		&"vector3_offset":
			return vector3_offset
		&"color_target":
			return color_target
	return null


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Reference to the ShaderMaterial we're animating
var _shader_material: ShaderMaterial

## Base value of the property (captured on start)
var _base_value: Variant

## Whether we've captured the base value
var _has_base_value: bool = false

## Whether we duplicated the material (to avoid affecting other nodes)
var _is_material_duplicated: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

func _invalidate_base_cache() -> void:
	_has_base_value = false
	_shader_material = null
	_is_material_duplicated = false


func _on_animate_start() -> void:
	# Find and prepare the shader material
	if not _shader_material:
		_shader_material = _find_shader_material()
	
	if not _shader_material:
		if debug_enabled:
			push_warning("[%s] No ShaderMaterial found on target '%s'" % [name, str(_target_node.name) if _target_node else "null"])
		return
	
	# Capture base value if not already done
	if not _has_base_value:
		_capture_base_value()
	
	if debug_enabled:
		print("[%s] Shader property start: %s (type=%s), base=%s" % [
			name, property_name, ShaderPropertyType.keys()[property_type], _base_value
		])


func _apply_effect(progress: float) -> void:
	if not _shader_material:
		return
	
	# Calculate new value based on type and progress
	var new_value: Variant = _calculate_value(progress)
	
	# Apply to shader
	_shader_material.set_shader_parameter(property_name, new_value)


func _on_animate_out_complete() -> void:
	if not _shader_material:
		return
	
	# Restore exact base value
	_shader_material.set_shader_parameter(property_name, _base_value)
	
	if debug_enabled:
		print("[%s] Shader property complete, restored %s to %s" % [name, property_name, _base_value])


# =============================================================================
# VALUE CALCULATION
# =============================================================================

## Calculate the animated value based on type and progress
func _calculate_value(progress: float) -> Variant:
	match property_type:
		ShaderPropertyType.FLOAT:
			# Base + (offset * progress)
			var base_float: float = _base_value if _base_value != null else 0.0
			return base_float + (float_offset * progress)
		
		ShaderPropertyType.VECTOR2:
			var base_vec2: Vector2 = _base_value if _base_value != null else Vector2.ZERO
			return base_vec2 + (vector2_offset * progress)
		
		ShaderPropertyType.VECTOR3:
			var base_vec3: Vector3 = _base_value if _base_value != null else Vector3.ZERO
			return base_vec3 + (vector3_offset * progress)
		
		ShaderPropertyType.COLOR:
			var base_color: Color = _base_value if _base_value != null else Color.WHITE
			return base_color.lerp(color_target, progress)
	
	return _base_value


# =============================================================================
# BASE VALUE CAPTURE
# =============================================================================

## Capture the base value of the shader property
func _capture_base_value() -> void:
	if _has_base_value or not _shader_material:
		return
	
	_base_value = _shader_material.get_shader_parameter(property_name)
	
	# If property doesn't exist, use sensible defaults
	if _base_value == null:
		if debug_enabled:
			push_warning("[%s] Shader property '%s' not found, using default" % [name, property_name])
		match property_type:
			ShaderPropertyType.FLOAT:
				_base_value = 0.0
			ShaderPropertyType.VECTOR2:
				_base_value = Vector2.ZERO
			ShaderPropertyType.VECTOR3:
				_base_value = Vector3.ZERO
			ShaderPropertyType.COLOR:
				_base_value = Color.WHITE
	
	_has_base_value = true
	
	if debug_enabled:
		print("[%s] Captured base value for '%s': %s" % [name, property_name, _base_value])


# =============================================================================
# MATERIAL FINDING
# =============================================================================

## Find the ShaderMaterial on the target node
func _find_shader_material() -> ShaderMaterial:
	if not _target_node:
		return null
	
	# For CanvasItem (Control, Sprite2D, etc.)
	if _target_node is CanvasItem:
		var canvas := _target_node as CanvasItem
		var mat := canvas.material
		if mat is ShaderMaterial:
			return _ensure_material_unique(mat as ShaderMaterial, canvas)
		elif mat == null:
			if debug_enabled:
				push_warning("[%s] CanvasItem '%s' has no material" % [name, _target_node.name])
		else:
			if debug_enabled:
				push_warning("[%s] CanvasItem '%s' material is not ShaderMaterial" % [name, _target_node.name])
		return null
	
	# For MeshInstance3D
	if _target_node is MeshInstance3D:
		var mesh_inst := _target_node as MeshInstance3D
		
		# Check material_override first
		if mesh_inst.material_override is ShaderMaterial:
			return _ensure_material_unique_3d(mesh_inst.material_override as ShaderMaterial, mesh_inst)
		
		# Check surface materials
		if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
			var surface_mat := mesh_inst.get_active_material(0)
			if surface_mat is ShaderMaterial:
				return _ensure_material_unique_3d(surface_mat as ShaderMaterial, mesh_inst)
		
		if debug_enabled:
			push_warning("[%s] MeshInstance3D '%s' has no ShaderMaterial" % [name, _target_node.name])
		return null
	
	# For GeometryInstance3D (parent class)
	if _target_node is GeometryInstance3D:
		var geom := _target_node as GeometryInstance3D
		if geom.material_override is ShaderMaterial:
			return geom.material_override as ShaderMaterial
		if debug_enabled:
			push_warning("[%s] GeometryInstance3D '%s' has no ShaderMaterial override" % [name, _target_node.name])
		return null
	
	if debug_enabled:
		push_warning("[%s] Target '%s' is not a supported node type for shader animation" % [name, _target_node.name])
	return null


## Ensure the material is unique to avoid affecting other nodes
func _ensure_material_unique(mat: ShaderMaterial, canvas: CanvasItem) -> ShaderMaterial:
	# Check if material is already local to this node
	if mat.resource_local_to_scene:
		return mat
	
	# Duplicate the material
	var unique_mat := mat.duplicate() as ShaderMaterial
	unique_mat.resource_local_to_scene = true
	canvas.material = unique_mat
	_is_material_duplicated = true
	
	if debug_enabled:
		print("[%s] Duplicated shared ShaderMaterial for '%s'" % [name, canvas.name])
	
	return unique_mat


## Ensure the material is unique for 3D nodes
func _ensure_material_unique_3d(mat: ShaderMaterial, mesh_inst: MeshInstance3D) -> ShaderMaterial:
	# Check if material is already local to this node
	if mat.resource_local_to_scene:
		return mat
	
	# Duplicate the material and set as override
	var unique_mat := mat.duplicate() as ShaderMaterial
	unique_mat.resource_local_to_scene = true
	mesh_inst.material_override = unique_mat
	_is_material_duplicated = true
	
	if debug_enabled:
		print("[%s] Duplicated shared ShaderMaterial for '%s'" % [name, mesh_inst.name])
	
	return unique_mat

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if property_name.is_empty():
		warnings.append("property_name must be set to the shader uniform name to animate.")
	return warnings
