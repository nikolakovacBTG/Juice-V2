## OutlineJuiceComp.gd
## ============================================================================
## WHAT: Animates outline visibility on 3D objects using the "Inverted Hull" technique.
## WHY: Highlight interactables on hover, selection feedback, object focus.
## SYSTEM: Juicing System (addons/juice/)
## DOES NOT: 2D outlines - those require shader-based edge detection.
## ============================================================================
##
## ARCHITECTURE:
## - Uses StandardMaterial3D "Grow" feature + Next Pass for outline
## - The "Inverted Hull" technique: grow mesh outward + cull front faces = outline
## - Animates the grow_amount property from 0 to outline_width
## - Can create the Next Pass material automatically if none exists
##
## HOW INVERTED HULL WORKS:
## 1. Main material renders the object normally
## 2. Next Pass material: solid color, unshaded, cull_mode=CULL_FRONT, grow > 0
## 3. This renders only the "backside" of a slightly larger mesh = outline effect
##
## USAGE:
## - Add as child of MeshInstance3D
## - Configure outline_color and outline_width
## - animate_in() shows outline, animate_out() hides it
## - Set trigger_on=ON_HOVER_START for hover outlines
##
## EXAMPLES:
## - Hover highlight: outline_color=Yellow, outline_width=0.02,
## - Selection: outline_color=White, outline_width=0.03
## - Danger: outline_color=Red, outline_width=0.025
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase3D.svg")
class_name OutlineJuiceComp
extends JuiceCompBase

# =============================================================================
# OUTLINE CONFIGURATION
# =============================================================================

@export_group("Outline Effect")

## Color of the outline
@export var outline_color: Color = Color.YELLOW

## Maximum width of the outline (grow amount in local units)
## Typical values: 0.01 - 0.05 depending on mesh scale
@export var outline_width: float = 0.02

## If true, automatically create the outline material if none exists
## If false, expects a Next Pass material to already be configured
@export var auto_create_outline: bool = true

## For Node3D: Which child GeometryInstance3D to outline (leave empty to search)
@export_node_path("GeometryInstance3D") var geometry_path: NodePath

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Reference to geometry instance
var _geometry_instance: GeometryInstance3D

## Reference to the main material (for Next Pass access)
var _main_material: Material

## Reference to the outline material (Next Pass)
var _outline_material: StandardMaterial3D

## Whether we created the outline material (vs using existing)
var _created_outline_material: bool = false

## Base grow amount (should be 0 when no outline)
var _base_grow: float = 0.0

## Whether we've set up the outline
var _is_setup: bool = false


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

func _invalidate_base_cache() -> void:
	_is_setup = false
	_outline_material = null
	_main_material = null
	_created_outline_material = false


func _on_animate_start() -> void:
	# Set up outline if not already done
	if not _is_setup:
		_setup_outline()
	
	if not _outline_material:
		if debug_enabled:
			push_warning("[%s] No outline material available" % name)
		return
	
	if debug_enabled:
		print("[%s] Outline start: color=%s, width=%.3f" % [
			name, outline_color, outline_width
		])


func _apply_effect(progress: float) -> void:
	if not _outline_material:
		return
	
	# Animate grow amount from 0 to outline_width
	var current_grow := _base_grow + (outline_width * progress)
	_outline_material.grow_amount = current_grow
	
	# Also update color in case it was changed in inspector during runtime
	_outline_material.albedo_color = outline_color


func _on_animate_out_complete() -> void:
	if not _outline_material:
		return
	
	# Restore base grow (0 = no outline visible)
	_outline_material.grow_amount = _base_grow
	
	if debug_enabled:
		print("[%s] Outline complete, grow reset to %.3f" % [name, _base_grow])


# =============================================================================
# OUTLINE SETUP
# =============================================================================

## Set up the outline material system
func _setup_outline() -> void:
	_geometry_instance = _find_geometry_instance()
	
	if not _geometry_instance:
		if debug_enabled:
			push_warning("[%s] No GeometryInstance3D found for outline" % name)
		return
	
	# Get the main material
	_main_material = _get_main_material()
	
	if not _main_material:
		if debug_enabled:
			push_warning("[%s] No main material found on '%s'" % [name, _geometry_instance.name])
		return
	
	# Check for existing Next Pass material
	if _main_material.next_pass is StandardMaterial3D:
		_outline_material = _main_material.next_pass as StandardMaterial3D
		if debug_enabled:
			print("[%s] Using existing Next Pass material for outline" % name)
	elif auto_create_outline:
		# Create the outline material
		_outline_material = _create_outline_material()
		_main_material.next_pass = _outline_material
		_created_outline_material = true
		if debug_enabled:
			print("[%s] Created outline material as Next Pass" % name)
	else:
		if debug_enabled:
			push_warning("[%s] No Next Pass material and auto_create_outline is false" % name)
		return
	
	# Start with grow at 0 (invisible outline)
	_base_grow = 0.0
	_outline_material.grow_amount = _base_grow
	
	_is_setup = true


## Get the main material from the geometry instance
func _get_main_material() -> Material:
	# Check material_override first
	if _geometry_instance.material_override:
		# Ensure it's unique
		if not _geometry_instance.material_override.resource_local_to_scene:
			var unique := _geometry_instance.material_override.duplicate()
			unique.resource_local_to_scene = true
			_geometry_instance.material_override = unique
		return _geometry_instance.material_override
	
	# For MeshInstance3D, check surface materials
	if _geometry_instance is MeshInstance3D:
		var mesh_inst := _geometry_instance as MeshInstance3D
		if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
			var surface_mat := mesh_inst.get_active_material(0)
			if surface_mat:
				# Create a unique override based on surface material
				var unique := surface_mat.duplicate()
				unique.resource_local_to_scene = true
				mesh_inst.material_override = unique
				return unique
	
	# Fallback: Create a basic material
	var new_mat := StandardMaterial3D.new()
	new_mat.resource_local_to_scene = true
	_geometry_instance.material_override = new_mat
	return new_mat


## Create the outline material with proper settings for Inverted Hull technique
func _create_outline_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_local_to_scene = true
	
	# Outline appearance
	mat.albedo_color = outline_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # No lighting
	
	# Inverted Hull settings
	mat.cull_mode = BaseMaterial3D.CULL_FRONT  # Only render back faces
	mat.grow = true                             # Enable vertex grow
	mat.grow_amount = 0.0                       # Start with no outline
	
	# Render behind the main mesh (depth-wise)
	mat.no_depth_test = false
	
	return mat


## Find a GeometryInstance3D for 3D nodes
func _find_geometry_instance() -> GeometryInstance3D:
	if not _target_node:
		return null
	
	# First try the explicit path
	if not geometry_path.is_empty():
		var node := get_node_or_null(geometry_path)
		if node is GeometryInstance3D:
			return node as GeometryInstance3D
	
	# If target IS a GeometryInstance3D, use it directly
	if _target_node is GeometryInstance3D:
		return _target_node as GeometryInstance3D
	
	# Search children for first GeometryInstance3D
	for child in _target_node.get_children():
		if child is GeometryInstance3D:
			return child as GeometryInstance3D
	
	return null

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node3D:
		warnings.append("Parent must be a Node3D node with a GeometryInstance3D (MeshInstance3D). (ignore if comp is a child of a sequencer)")
	return warnings
