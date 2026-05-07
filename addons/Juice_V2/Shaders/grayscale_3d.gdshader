// Grayscale 3D Shader
// =============================================================================
// Desaturates a 3D mesh by blending between the original albedo and its
// luminance-weighted grayscale equivalent. Designed to be used as a next_pass
// material on GeometryInstance3D nodes.
//
// HOW IT WORKS:
// 1. Read the rendered pixel color from the screen texture.
// 2. Compute perceptual luminance using ITU-R BT.601 weights.
// 3. Mix between original and grayscale by the 'amount' uniform.
// 4. Output with full alpha so the next_pass overwrites the previous pass.
//
// When amount = 0.0, output matches the original rendering (passthrough).
// When amount = 1.0, output is fully desaturated.
//
// USAGE: Applied as next_pass on the mesh's existing material.
// SYSTEM: Juice System (Appearance3DJuiceComp)
// =============================================================================

shader_type spatial;
render_mode unshaded;

// How fully desaturated the output is. 0.0 = original, 1.0 = full grayscale.
// Animated by the juice component's _apply_effect().
uniform float amount : hint_range(0.0, 1.0) = 0.0;

// Screen texture to read the already-rendered pixel color from the first pass.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 screen_color = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float gray = dot(screen_color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(screen_color, vec3(gray), amount);
	// Full alpha so this pass fully overwrites the previous
	ALPHA = 1.0;
}
