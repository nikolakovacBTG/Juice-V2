// blend_mode_2d.gdshader
// ============================================================================
// Animated compositing blend mode for CanvasItem nodes (2D and Control).
// Reads the screen behind the node and applies a blend operation (Add, Subtract,
// Multiply, Screen) with smooth animation via the blend_amount uniform.
//
// Used by AppearanceControlJuiceComp / Appearance2DJuiceComp for non-shader
// effects (Tint, Overbright, Fade, Outline) when blend mode is enabled.
// For shader-based effects (Grayscale, Dissolve, Color Overlay), the blend
// logic is embedded directly in those shaders to avoid material slot conflicts.
//
// Uniforms:
//   blend_amount — 0.0 = normal compositing, 1.0 = fully blended
//   blend_type   — 0=Add, 1=Subtract, 2=Multiply, 3=Screen
//
// HOW IT WORKS:
// 1. Sample the node's own pixels (texture * vertex COLOR, includes modulate).
// 2. Sample the screen behind the node (back-buffer via hint_screen_texture).
// 3. Compute the blend result based on blend_type.
// 4. Mix between normal rendering and blended result by blend_amount.
//
// MATH NOTE:
// The output goes through Godot's standard alpha compositing:
//   final = output * alpha + screen * (1 - alpha)
// This distributes correctly for Add, Subtract, and Multiply when the source
// is fully opaque (alpha = 1.0). Semi-transparent sources have minor
// approximation but are visually acceptable for UI juice effects.
// ============================================================================

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// How strongly the blend mode is applied. 0.0 = normal, 1.0 = full blend.
// Animated by the juice component's progress curve.
uniform float blend_amount : hint_range(0.0, 1.0) = 0.0;

// Which blend operation to use. Matches TargetBlendMode enum:
// 0 = Add (lighten/glow), 1 = Subtract (darken), 2 = Multiply, 3 = Screen
uniform int blend_type : hint_range(0, 3) = 0;

void fragment() {
	vec4 src = texture(TEXTURE, UV) * COLOR;

	if (blend_amount > 0.0) {
		vec3 bg = texture(screen_texture, SCREEN_UV).rgb;

		vec3 blended;
		if (blend_type == 0) { // ADD — brightens, good for glow
			blended = bg + src.rgb;
		} else if (blend_type == 1) { // SUBTRACT — darkens
			blended = max(bg - src.rgb, vec3(0.0));
		} else if (blend_type == 2) { // MULTIPLY — darkens, preserves contrast
			blended = bg * src.rgb;
		} else { // SCREEN — brightens without overblowing
			blended = 1.0 - (1.0 - bg) * (1.0 - src.rgb);
		}

		src.rgb = mix(src.rgb, blended, blend_amount);
	}

	COLOR = src;
}
