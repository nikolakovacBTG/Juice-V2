// Grayscale 2D Shader
// =============================================================================
// Desaturates a CanvasItem (Sprite2D, Control, etc.) by blending between
// the original color and its luminance-weighted grayscale equivalent.
//
// HOW IT WORKS:
// 1. Sample the original texture color.
// 2. Compute perceptual luminance using ITU-R BT.601 weights.
// 3. Mix between original and grayscale by the 'amount' uniform.
// 4. Optionally apply a compositing blend mode (Add/Subtract/Multiply/Screen).
//
// When amount = 0.0, output is the original texture (passthrough).
// When amount = 1.0, output is fully desaturated.
//
// BLEND MODE (optional — uniforms ignored when blend_amount = 0.0):
// Reads the screen behind the node and mixes toward a blended result.
// blend_amount follows the same progress curve as the effect.
//
// SYSTEM: Juice System (Appearance2DJuiceComp / AppearanceControlJuiceComp)
// =============================================================================

shader_type canvas_item;

// How fully desaturated the output is. 0.0 = original, 1.0 = full grayscale.
// Animated by the juice component's _apply_effect().
uniform float amount : hint_range(0.0, 1.0) = 0.0;

// Blend mode (optional — animated by juice component when use_blend_mode is on)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float blend_amount : hint_range(0.0, 1.0) = 0.0;
uniform int blend_type : hint_range(0, 3) = 0;

void fragment() {
	vec4 original = texture(TEXTURE, UV) * COLOR;
	// ITU-R BT.601 luminance weights (perceptually accurate grayscale)
	float gray = dot(original.rgb, vec3(0.299, 0.587, 0.114));
	vec3 effect_rgb = mix(original.rgb, vec3(gray), amount);

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
