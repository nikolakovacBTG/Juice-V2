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
//
// BLEND MODE (optional — uniforms ignored when blend_amount = 0.0):
// Reads the screen behind the node and mixes toward a blended result.
// blend_amount follows the same progress curve as the effect.
//
// SYSTEM: Juice System (Appearance2DJuiceComp / AppearanceControlJuiceComp)
// ============================================================================

shader_type canvas_item;

uniform vec4 overlay_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

// Blend mode (optional — animated by juice component when use_blend_mode is on)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float blend_amount : hint_range(0.0, 1.0) = 0.0;
uniform int blend_type : hint_range(0, 3) = 0;

void fragment() {
	vec4 original = texture(TEXTURE, UV) * COLOR;
	// Mix original RGB toward overlay color; preserve original alpha
	vec3 effect_rgb = mix(original.rgb, overlay_color.rgb, amount);

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
