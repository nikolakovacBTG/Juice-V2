## Appearance3DJuiceComp.gd
## ============================================================================
## WHAT: Animates built-in material properties (albedo, emission, roughness, grow)
##       on 3D geometry. Part of the unified Appearance family.
## WHY:  Quick material effects without needing custom shaders. Provides the 3D
##       equivalent of AppearanceControlJuiceComp / Appearance2DJuiceComp but
##       targeting StandardMaterial3D properties instead of CanvasItem modulate.
## SYSTEM: Juicing System (addons/juice/) - Appearance Family
## DOES NOT: Custom shader uniforms — use ShaderPropertyJuiceComp for that.
## DOES NOT: CanvasItem modulate — use AppearanceControlJuiceComp / Appearance2DJuiceComp.
## ============================================================================
##
## ARCHITECTURE:
## - Animates StandardMaterial3D properties by enum selection
## - Supports common properties: albedo_color, emission, roughness, metallic, grow
## - Color properties support blend modes (LERP, ADDITIVE, MULTIPLY)
## - Numeric properties use delta-based offset addition
## - Automatically duplicates shared materials to avoid cross-node conflicts
## - Optional hold phase at peak before animate_out (flash effects on materials)
##
## COLOR BLEND MODES (visible only for ALBEDO_COLOR and EMISSION):
## - LERP: Interpolate base → target (default, simple tween)
## - ADDITIVE: Add target color scaled by progress (brightening/glow)
## - MULTIPLY: Multiply base by target scaled by progress (tinting)
##
## USAGE:
## - Add as child of MeshInstance3D or GeometryInstance3D
## - Select material_property to animate
## - Set offset/target value
## - animate_in() applies effect, animate_out() removes it
##
## EXAMPLES:
## - Glow: property=EMISSION_ENERGY, float_offset=2.0
## - Damage red: property=ALBEDO_COLOR, color_target=Red, color_blend_mode=MULTIPLY
## - Hit flash: property=ALBEDO_COLOR, color_target=White, color_blend_mode=ADDITIVE, hold_time=0.1
## - Outline grow: property=GROW, float_offset=0.05
## ============================================================================

@tool
class_name Appearance3DJuiceComp
extends JuiceCompBase

# =============================================================================
# MATERIAL PROPERTY CONFIGURATION
# =============================================================================

@export_group("Material Property")

## Which material property to animate
enum MaterialProperty {
	ALBEDO_COLOR,      ## Main color/tint of the material
	EMISSION,          ## Emission color (glow color)
	EMISSION_ENERGY,   ## Emission intensity (scalar)
	ROUGHNESS,         ## Surface roughness (0 = mirror, 1 = rough)
	METALLIC,          ## Metallic appearance (0 = dielectric, 1 = metal)
	GROW,              ## Vertex displacement along normals (for outlines)
	RIM,               ## Rim lighting intensity
	RIM_TINT,          ## How much rim is tinted by albedo
	CLEARCOAT,         ## Clearcoat intensity
	REFRACTION         ## Refraction scale (for transparent materials)
}

## Which property to animate
@export var material_property: MaterialProperty = MaterialProperty.EMISSION_ENERGY:
	set(value):
		material_property = value
		# Refresh inspector to show/hide conditional properties
		# (color_blend_mode and allow_hdr only visible for color properties)
		notify_property_list_changed()

## Offset for numeric properties (EMISSION_ENERGY, ROUGHNESS, METALLIC, GROW, RIM, etc.)
## Added to base value scaled by progress
@export var float_offset: float = 1.0

## Target color for color properties (ALBEDO_COLOR, EMISSION)
## Lerps from base color to this
@export var color_target: Color = Color.WHITE

## Time to hold at peak value before animating out (seconds)
## Set to 0 for no hold (default). Useful for hit-flash effects on materials.
@export var hold_time: float = 0.0

## For Node3D: Which child GeometryInstance3D to affect (leave empty to search)
@export_node_path("GeometryInstance3D") var geometry_path: NodePath

# =============================================================================
# CONDITIONAL PROPERTIES (shown via _get_property_list for color properties only)
# =============================================================================

## How color properties are blended with the base material color.
## Only applies to ALBEDO_COLOR and EMISSION — numeric properties always use offset.
enum ColorBlendMode {
	LERP,        ## Interpolate base → target (default, simple tween)
	ADDITIVE,    ## Add target color scaled by progress (brightens)
	MULTIPLY     ## Multiply base by target scaled by progress (tints)
}

## Backing variable for conditional color_blend_mode export
var color_blend_mode: int = ColorBlendMode.LERP

## Backing variable for conditional allow_hdr export.
## If true, color values above 1.0 are kept (useful for bloom/glow).
## If false, values are clamped to 0.0–1.0.
var allow_hdr: bool = true


## Conditional export visibility — color_blend_mode and allow_hdr only shown
## when material_property is a color type (ALBEDO_COLOR or EMISSION).
func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	if _is_color_property():
		props.append({
			"name": "color_blend_mode",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "LERP,ADDITIVE,MULTIPLY",
			"usage": PROPERTY_USAGE_DEFAULT
		})
		props.append({
			"name": "allow_hdr",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_DEFAULT
		})
	return props


## Handle setting conditional properties for serialization
func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"color_blend_mode":
			color_blend_mode = value
			return true
		&"allow_hdr":
			allow_hdr = value
			return true
	return false


## Handle getting conditional properties for serialization
func _get(property: StringName) -> Variant:
	match property:
		&"color_blend_mode":
			return color_blend_mode
		&"allow_hdr":
			return allow_hdr
	return null


## Helper: is the current material_property a color type?
func _is_color_property() -> bool:
	return (material_property == MaterialProperty.ALBEDO_COLOR
		or material_property == MaterialProperty.EMISSION)


# =============================================================================
# INTERNAL STATE
# =============================================================================

## Reference to the material we're animating
var _target_material: StandardMaterial3D

## Reference to geometry instance
var _geometry_instance: GeometryInstance3D

## Base value of the property (captured on start)
var _base_value: Variant

## Whether we've captured the base value
var _has_base_value: bool = false

## Whether we duplicated the material
var _is_material_duplicated: bool = false

## Currently in the hold phase at peak value
var _in_hold_phase: bool = false

## Timer for hold phase
var _hold_timer: float = 0.0


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	super._ready()
	if debug_enabled:
		print("[%s] Appearance3D ready - parent: %s, target: %s" % [
			name,
			str(get_parent().name) if get_parent() else "null",
			str(_target_node.name) if _target_node else "null"
		])


func _process(delta: float) -> void:
	# Handle hold phase timing before letting base class process
	if _in_hold_phase:
		_hold_timer += delta
		if _hold_timer >= hold_time:
			_in_hold_phase = false
			_hold_timer = 0.0
			animate_out()
		return

	# Let base class handle normal animation
	super._process(delta)


# =============================================================================
# VIRTUAL METHOD IMPLEMENTATIONS
# =============================================================================

func _invalidate_base_cache() -> void:
	_has_base_value = false
	_target_material = null
	_is_material_duplicated = false
	_in_hold_phase = false
	_hold_timer = 0.0


func _on_animate_start() -> void:
	# Find and prepare the material
	if not _target_material:
		_find_and_prepare_material()

	if not _target_material:
		if debug_enabled:
			push_warning("[%s] No StandardMaterial3D found on target '%s'" % [name, str(_target_node.name) if _target_node else "null"])
		return

	# Capture base value if not already done
	if not _has_base_value:
		_capture_base_value()

	if debug_enabled:
		var extra := ""
		if _is_color_property():
			extra = ", blend=%s, hdr=%s" % [ColorBlendMode.keys()[color_blend_mode], allow_hdr]
		print("[%s] Appearance3D start: %s, base=%s%s" % [
			name, MaterialProperty.keys()[material_property], _base_value, extra
		])


func _apply_effect(progress: float) -> void:
	if not _target_material:
		return

	# Calculate and apply new value
	var new_value: Variant = _calculate_value(progress)
	_set_material_property(new_value)


func _on_animate_in_complete() -> void:
	# Hold at peak value if configured, then auto-trigger animate_out
	if hold_time > 0.0:
		_in_hold_phase = true
		_hold_timer = 0.0
		if debug_enabled:
			print("[%s] Appearance3D peak reached, holding for %.2fs" % [name, hold_time])


func _on_animate_out_complete() -> void:
	if not _target_material:
		return

	# Restore exact base value
	_set_material_property(_base_value)

	if debug_enabled:
		print("[%s] Appearance3D complete, restored %s to %s" % [
			name, MaterialProperty.keys()[material_property], _base_value
		])


# =============================================================================
# VALUE CALCULATION
# =============================================================================

## Calculate the animated value based on property type, blend mode, and progress
func _calculate_value(progress: float) -> Variant:
	# Color properties support blend modes
	if _is_color_property():
		var base_color: Color = _base_value if _base_value != null else Color.WHITE
		return _calculate_color_value(base_color, progress)

	# Numeric properties always use offset addition
	var base_float: float = _base_value if _base_value != null else 0.0
	return base_float + (float_offset * progress)


## Calculate blended color value using the selected color blend mode
func _calculate_color_value(base_color: Color, progress: float) -> Color:
	match color_blend_mode:
		ColorBlendMode.LERP:
			# Simple interpolation from base to target
			return base_color.lerp(color_target, progress)

		ColorBlendMode.ADDITIVE:
			# Add target color scaled by progress onto base
			var r := base_color.r + color_target.r * progress
			var g := base_color.g + color_target.g * progress
			var b := base_color.b + color_target.b * progress
			if not allow_hdr:
				r = clampf(r, 0.0, 1.0)
				g = clampf(g, 0.0, 1.0)
				b = clampf(b, 0.0, 1.0)
			return Color(r, g, b, base_color.a)

		ColorBlendMode.MULTIPLY:
			# Multiply base by a factor that goes from White (1,1,1) to color_target
			# At progress=0: multiply by 1 (no change). At progress=1: multiply by color_target.
			return Color(
				base_color.r * lerpf(1.0, color_target.r, progress),
				base_color.g * lerpf(1.0, color_target.g, progress),
				base_color.b * lerpf(1.0, color_target.b, progress),
				base_color.a
			)

	return base_color


# =============================================================================
# BASE VALUE CAPTURE
# =============================================================================

## Capture the base value of the material property
func _capture_base_value() -> void:
	if _has_base_value or not _target_material:
		return

	_base_value = _get_material_property()
	_has_base_value = true

	if debug_enabled:
		print("[%s] Captured base value for %s: %s" % [
			name, MaterialProperty.keys()[material_property], _base_value
		])


## Get the current value of the material property
func _get_material_property() -> Variant:
	match material_property:
		MaterialProperty.ALBEDO_COLOR:
			return _target_material.albedo_color
		MaterialProperty.EMISSION:
			return _target_material.emission
		MaterialProperty.EMISSION_ENERGY:
			return _target_material.emission_energy_multiplier
		MaterialProperty.ROUGHNESS:
			return _target_material.roughness
		MaterialProperty.METALLIC:
			return _target_material.metallic
		MaterialProperty.GROW:
			return _target_material.grow_amount
		MaterialProperty.RIM:
			return _target_material.rim
		MaterialProperty.RIM_TINT:
			return _target_material.rim_tint
		MaterialProperty.CLEARCOAT:
			return _target_material.clearcoat
		MaterialProperty.REFRACTION:
			return _target_material.refraction_scale

	return 0.0


## Set the material property to a new value
func _set_material_property(value: Variant) -> void:
	match material_property:
		MaterialProperty.ALBEDO_COLOR:
			_target_material.albedo_color = value
		MaterialProperty.EMISSION:
			# Enable emission if not already
			if not _target_material.emission_enabled:
				_target_material.emission_enabled = true
			_target_material.emission = value
		MaterialProperty.EMISSION_ENERGY:
			if not _target_material.emission_enabled:
				_target_material.emission_enabled = true
			_target_material.emission_energy_multiplier = value
		MaterialProperty.ROUGHNESS:
			_target_material.roughness = clampf(value, 0.0, 1.0)
		MaterialProperty.METALLIC:
			_target_material.metallic = clampf(value, 0.0, 1.0)
		MaterialProperty.GROW:
			# Enable grow if not already
			if not _target_material.grow:
				_target_material.grow = true
			_target_material.grow_amount = value
		MaterialProperty.RIM:
			if not _target_material.rim_enabled:
				_target_material.rim_enabled = true
			_target_material.rim = clampf(value, 0.0, 1.0)
		MaterialProperty.RIM_TINT:
			_target_material.rim_tint = clampf(value, 0.0, 1.0)
		MaterialProperty.CLEARCOAT:
			if not _target_material.clearcoat_enabled:
				_target_material.clearcoat_enabled = true
			_target_material.clearcoat = clampf(value, 0.0, 1.0)
		MaterialProperty.REFRACTION:
			if not _target_material.refraction_enabled:
				_target_material.refraction_enabled = true
			_target_material.refraction_scale = value


# =============================================================================
# MATERIAL FINDING
# =============================================================================

## Find and prepare the StandardMaterial3D on the target
func _find_and_prepare_material() -> void:
	_geometry_instance = _find_geometry_instance()

	if not _geometry_instance:
		return

	# Check material_override first
	if _geometry_instance.material_override is StandardMaterial3D:
		_target_material = _ensure_material_unique(_geometry_instance.material_override as StandardMaterial3D)
		return

	# For MeshInstance3D, check surface materials
	if _geometry_instance is MeshInstance3D:
		var mesh_inst := _geometry_instance as MeshInstance3D
		if mesh_inst.mesh and mesh_inst.mesh.get_surface_count() > 0:
			var surface_mat := mesh_inst.get_active_material(0)
			if surface_mat is StandardMaterial3D:
				_target_material = _ensure_material_unique(surface_mat as StandardMaterial3D)
				mesh_inst.material_override = _target_material
				return

	# Fallback: Create a new StandardMaterial3D
	var new_mat := StandardMaterial3D.new()
	_geometry_instance.material_override = new_mat
	_target_material = new_mat
	_is_material_duplicated = true

	if debug_enabled:
		print("[%s] Created new StandardMaterial3D for '%s'" % [name, _geometry_instance.name])


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

	if debug_enabled:
		push_warning("[%s] No GeometryInstance3D found for material animation" % name)
	return null


## Ensure the material is unique to avoid affecting other nodes
func _ensure_material_unique(mat: StandardMaterial3D) -> StandardMaterial3D:
	# Check if material is already local to this node
	if mat.resource_local_to_scene:
		return mat

	# Duplicate the material
	var unique_mat := mat.duplicate() as StandardMaterial3D
	unique_mat.resource_local_to_scene = true
	_is_material_duplicated = true

	if debug_enabled:
		print("[%s] Duplicated shared StandardMaterial3D" % name)

	return unique_mat

# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var parent := get_parent()
	if parent and not parent is Node3D:
		warnings.append("Parent must be a Node3D node. Use AppearanceControl/Appearance2D for other domains.")
	return warnings
