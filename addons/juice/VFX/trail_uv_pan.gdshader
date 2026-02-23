// trail_uv_pan.gdshader
// ============================================================================
// Simple UV panning shader for TrailJuiceComp's trail_material slot.
// Creates scrolling texture effects (fire, energy, flowing water, etc.).
//
// USAGE:
// 1. Create a ShaderMaterial using this shader
// 2. Set pan_speed_u / pan_speed_v to desired scroll speeds
// 3. Slot the ShaderMaterial into TrailJuiceComp's trail_material property
// ============================================================================

shader_type canvas_item;

uniform float pan_speed_u : hint_range(-10.0, 10.0, 0.1) = 1.0;
uniform float pan_speed_v : hint_range(-10.0, 10.0, 0.1) = 0.0;

void fragment() {
	vec2 panned_uv = UV + vec2(pan_speed_u, pan_speed_v) * TIME;
	COLOR = texture(TEXTURE, panned_uv) * COLOR;
}
