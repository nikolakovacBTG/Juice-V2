// Dissolve 2D Shader
// =============================================================================
// Noise-based dissolve effect for CanvasItem nodes. Pixels whose noise value
// falls below the animated threshold are discarded, creating a burning/melting
// disappearance effect with a colored edge band.
//
// HOW IT WORKS:
// 1. Sample a noise texture at the current UV.
// 2. Discard pixels where noise < threshold (animated by juice component).
// 3. Pixels near the threshold edge get tinted with edge_color for a glow band.
//
// When threshold = 0.0, all pixels pass (fully visible).
// When threshold = 1.0, all pixels are discarded (fully dissolved).
//
// SYSTEM: Juice System (Appearance2DJuiceComp / AppearanceControlJuiceComp)
// =============================================================================

shader_type canvas_item;

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

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float noise = texture(dissolve_noise, UV).r;

	// Discard pixels below threshold
	if (noise < threshold) {
		discard;
	}

	// Edge band: blend edge_color where noise is near the threshold
	float edge_factor = 1.0 - smoothstep(threshold, threshold + edge_width, noise);
	vec3 final_rgb = mix(tex.rgb, edge_color.rgb, edge_factor * edge_color.a);
	COLOR = vec4(final_rgb, tex.a);
}
