// Dissolve 3D Shader
// =============================================================================
// Noise-based dissolve effect for 3D meshes. Uses alpha scissor to discard
// pixels whose noise value falls below the animated threshold, creating a
// burning/melting disappearance effect with a colored edge band.
//
// HOW IT WORKS:
// 1. Sample a noise texture using the mesh UV.
// 2. Pixels where noise < threshold get alpha = 0 (scissored away).
// 3. Pixels near the threshold edge emit edge_color for a glow/burn band.
//
// When threshold = 0.0, all pixels pass (fully visible).
// When threshold = 1.0, all pixels are discarded (fully dissolved).
//
// USAGE: Set as the mesh's material_override (replaces existing material during effect).
// SYSTEM: Juice System (Appearance3DJuiceComp)
// =============================================================================

shader_type spatial;
render_mode cull_back;

// Dissolve progress. 0.0 = fully visible, 1.0 = fully dissolved.
// Animated by the juice component's _apply_effect().
uniform float threshold : hint_range(0.0, 1.0) = 0.0;

// Noise texture that drives the dissolve pattern.
// Typically a NoiseTexture2D with FastNoiseLite (Simplex, frequency ~0.05).
uniform sampler2D dissolve_noise : hint_default_white;

// Color of the dissolve edge band (the "burn" line).
uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.0, 1.0);

// Width of the colored edge band in noise-space (0.0–0.2 typical).
uniform float edge_width : hint_range(0.0, 0.5) = 0.05;

// Original albedo color to preserve the mesh's base appearance.
uniform vec4 albedo_color : source_color = vec4(1.0);

// Original albedo texture (if the mesh had one).
uniform sampler2D albedo_texture : hint_default_white;

void fragment() {
	float noise = texture(dissolve_noise, UV).r;

	// Alpha scissor: discard pixels below threshold
	float alpha = step(threshold, noise);
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	// Base appearance from the original material
	vec4 tex = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = tex.rgb;

	// Edge emission: glow at the dissolve boundary
	float edge_factor = 1.0 - smoothstep(threshold, threshold + edge_width, noise);
	EMISSION = edge_color.rgb * edge_factor * edge_color.a;
}
