// Grayscale 2D Shader
// =============================================================================
// Desaturates a CanvasItem (Sprite2D, Control, etc.) by blending between
// the original color and its luminance-weighted grayscale equivalent.
//
// HOW IT WORKS:
// 1. Sample the original texture color.
// 2. Compute perceptual luminance using ITU-R BT.601 weights.
// 3. Mix between original and grayscale by the 'amount' uniform.
//
// When amount = 0.0, output is the original texture (passthrough).
// When amount = 1.0, output is fully desaturated.
//
// SYSTEM: Juice System (Appearance2DJuiceComp / AppearanceControlJuiceComp)
// =============================================================================

shader_type canvas_item;

// How fully desaturated the output is. 0.0 = original, 1.0 = full grayscale.
// Animated by the juice component's _apply_effect().
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 original = texture(TEXTURE, UV) * COLOR;
	// ITU-R BT.601 luminance weights (perceptually accurate grayscale)
	float gray = dot(original.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(original.rgb, vec3(gray), amount), original.a);
}
