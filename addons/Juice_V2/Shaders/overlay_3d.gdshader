// overlay_3d.gdshader
// ============================================================================
// Color overlay for 3D spatial nodes, designed as a next_pass material.
// Mixes a flat overlay color onto the already-rendered surface — the "Normal
// blend at X% opacity" that artists expect.
//
// Uses render_mode unshaded so the overlay pass ignores scene lighting.
// Reads the screen texture to get the first-pass result, then mixes toward
// the overlay color.
//
// Uniforms:
//   overlay_color — the flat color to mix in
//   amount        — 0.0 = original, 1.0 = fully replaced with overlay_color
// ============================================================================

shader_type spatial;
render_mode unshaded;

uniform vec4 overlay_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

// Screen texture sampler to read the first-pass rendered result
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 screen_col = texture(screen_texture, SCREEN_UV).rgb;
	// Mix original rendered color toward overlay; output as unshaded albedo
	ALBEDO = mix(screen_col, overlay_color.rgb, amount);
	// Fully opaque pass — the mix handles the blending
	ALPHA = 1.0;
}
