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
// 4. Optionally apply a compositing blend mode (Add/Subtract/Multiply/Screen).
//
// When threshold = 0.0, all pixels pass (fully visible).
// When threshold = 1.0, all pixels are discarded (fully dissolved).
//
// BLEND MODE (optional — uniforms ignored when blend_amount = 0.0):
// Reads the screen behind the node and mixes toward a blended result.
// blend_amount follows the same progress curve as the effect.
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

// Blend mode (optional — animated by juice component when use_blend_mode is on)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float blend_amount : hint_range(0.0, 1.0) = 0.0;
uniform int blend_type : hint_range(0, 3) = 0;

void fragment() {
	vec4 original = texture(TEXTURE, UV) * COLOR;
	float noise = texture(dissolve_noise, UV).r;

	// Discard pixels below threshold
	if (noise < threshold) {
		discard;
	}

	// Edge band: blend edge_color where noise is near the threshold
	float edge_factor = 1.0 - smoothstep(threshold, threshold + edge_width, noise);
	vec3 effect_rgb = mix(original.rgb, edge_color.rgb, edge_factor * edge_color.a);

	// Apply blend mode if active
	if (blend_amount > 0.0) {
		vec3 bg = texture(screen_texture, SCREEN_UV).rgb;
		vec3 blended;
		if (blend_type == 0) { // ADD
			blended = bg + effect_rgb;
		} else if (blend_type == 1) { // SUBTRACT
			blended = max(bg - effect_rgb, vec3(0.0));
		} else if (blend_type == 2) { // MULTIPLY
			blended = bg * effect_rgb;
		} else { // SCREEN
			blended = 1.0 - (1.0 - bg) * (1.0 - effect_rgb);
		}
		effect_rgb = mix(effect_rgb, blended, blend_amount);
	}

	COLOR = vec4(effect_rgb, original.a);
}
