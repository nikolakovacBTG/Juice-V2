// overlay_2d.gdshader
// ============================================================================
// Color overlay for CanvasItem nodes (2D and Control).
// Mixes a flat overlay color onto every pixel — the "Normal blend at X% opacity"
// that artists expect. Unlike modulate (which multiplies), this truly replaces
// pixel color toward the overlay color.
//
// Uniforms:
//   overlay_color — the flat color to mix in (alpha channel ignored)
//   amount        — 0.0 = original, 1.0 = fully replaced with overlay_color
// ============================================================================

shader_type canvas_item;

uniform vec4 overlay_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	// Mix original RGB toward overlay color; preserve original alpha
	COLOR = vec4(mix(tex.rgb, overlay_color.rgb, amount), tex.a);
}
