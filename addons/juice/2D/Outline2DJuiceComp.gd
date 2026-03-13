## Outline2DJuiceComp.gd
## ============================================================================
## WHAT: Animates a shader-based outline on 2D CanvasItem nodes (Sprite2D, etc.).
## WHY: Highlight interactables on hover, selection feedback, object focus.
## SYSTEM: Juicing System (addons/juice/) - 2D Domain
## DOES NOT: 3D outlines — use OutlineJuiceComp (Inverted Hull) for that.
## ============================================================================
##
## ARCHITECTURE:
## - Uses a shared outline_2d.gdshader applied as ShaderMaterial on the target
## - The shader expands the rendered quad via vertex() so the outline extends
##   OUTSIDE the original texture bounds — no transparent padding needed.
## - Samples 8 neighboring texels to detect alpha edges, draws outline_color
##   where neighbors are opaque but the current pixel is not.
## - Animates outline_width uniform from 0 to max width based on progress
##
## MATERIAL MANAGEMENT:
## - If the target has no material → creates ShaderMaterial with outline shader
## - If the target already has a ShaderMaterial → replaces it (saves original,
##   restores on cleanup). Warning logged if debug_enabled.
## - If the target already has our outline shader → reuses it (re-entrant)
##
## LIMITATIONS:
## - Replaces existing ShaderMaterial on target. Use ShaderPropertyJuiceComp
##   to animate outline uniforms in custom shaders instead.
##
## USAGE:
## - Add as child of Sprite2D, TextureRect, or any CanvasItem with alpha content
## - Configure outline_color and outline_width
## - animate_in() shows outline, animate_out() hides it
## - Set trigger_on=ON_HOVER_START for hover outlines
##
## EXAMPLES:
## - Hover highlight: outline_color=Yellow, outline_width=3.0
## - Selection: outline_color=White, outline_width=4.0
## - Danger: outline_color=Red, outline_width=5.0
## ============================================================================

@tool
@icon("res://addons/juice/Icons/JuiceBase2D.svg")
class_name Outline2DJuiceComp
extends JuiceCompBase


# =============================================================================
# OUTLINE CONFIGURATION
# =============================================================================

@export_group("Effect")

## Color of the outline
@export var outline_color: Color = Color.YELLOW

## Maximum width of the outline in texels (pixel distance for neighbor sampling).
## Typical values: 1.0–5.0 for subtle, 5.0–15.0 for bold.
@export var outline_width: float = 3.0


# =============================================================================
# INTERNAL STATE
# =============================================================================

## The preloaded outline shader (shared across all instances via static var)
static var _outline_shader: Shader

## The ShaderMaterial created for the outline effect
var _shader_material: ShaderMaterial

## The target's original material (saved for restoration when component is removed)
var _original_material: Material

## Whether we've saved the original material
var _has_original_material: bool = false

## Whether setup is complete
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
	_shader_material = null


func _on_animate_start() -> void:
	if not _is_setup:
		_setup_outline()

	if not _shader_material:
		if debug_enabled:
			push_warning("[%s] No outline shader material available" % name)
		return

	if debug_enabled:
		print("[%s] Outline start: color=%s, width=%.1f" % [name, outline_color, outline_width])


func _apply_effect(progress: float) -> void:
	if not _shader_material:
		return

	# Animate outline_width uniform from 0 (invisible) to configured max
	_shader_material.set_shader_parameter("outline_width", outline_width * progress)
	# Update color live so inspector changes take effect immediately
	_shader_material.set_shader_parameter("outline_color", outline_color)


func _on_animate_out_complete() -> void:
	if not _shader_material:
		return

	# Reset to invisible (shader is passthrough at width=0)
	_shader_material.set_shader_parameter("outline_width", 0.0)

	if debug_enabled:
		print("[%s] Outline complete, width reset to 0" % name)


# =============================================================================
# OUTLINE SETUP
# =============================================================================

## Find the target CanvasItem, create or reuse a ShaderMaterial with the outline shader.
func _setup_outline() -> void:
	if not _target_node is CanvasItem:
		if debug_enabled:
			push_warning("[%s] Target '%s' is not a CanvasItem — outline won't work" % [
				name, str(_target_node.name) if _target_node else "null"
			])
		return

	var canvas := _target_node as CanvasItem

	# Save original material for potential restoration
	if not _has_original_material:
		_original_material = canvas.material
		_has_original_material = true

		if _original_material is ShaderMaterial:
			if debug_enabled:
				push_warning("[%s] Target '%s' already has a ShaderMaterial — it will be replaced by outline shader" % [name, canvas.name])

	# Check if target already has our outline shader (e.g., re-setup or shared)
	if canvas.material is ShaderMaterial:
		var existing := canvas.material as ShaderMaterial
		if existing.shader == _get_outline_shader():
			_shader_material = existing
			_is_setup = true
			return

	# Create ShaderMaterial with the outline shader
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = _get_outline_shader()
	_shader_material.resource_local_to_scene = true
	_shader_material.set_shader_parameter("outline_width", 0.0)
	_shader_material.set_shader_parameter("outline_color", outline_color)

	canvas.material = _shader_material
	_is_setup = true

	if debug_enabled:
		print("[%s] Created outline shader material on '%s'" % [name, canvas.name])


## Load the shared outline shader (cached in static var across all instances).
func _get_outline_shader() -> Shader:
	if _outline_shader == null:
		_outline_shader = load("res://addons/juice/Shaders/outline_2d.gdshader")
	return _outline_shader


# =============================================================================
# CONFIGURATION WARNINGS
# =============================================================================

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if _target_node and not _target_node is CanvasItem:
		warnings.append("Target node is not a CanvasItem. Outline2DJuiceComp requires a CanvasItem target (Sprite2D, TextureRect, etc.).")

	return warnings
