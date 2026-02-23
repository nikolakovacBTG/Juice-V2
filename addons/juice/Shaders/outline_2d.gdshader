// Outline 2D Shader
// =============================================================================
// Alpha-edge-detection outline for CanvasItem nodes (Sprite2D, Control, etc.).
//
// HOW IT WORKS:
// 1. vertex() expands the rendered quad outward by outline_width pixels,
//    giving the outline room to render OUTSIDE the original texture bounds.
// 2. fragment() remaps UV back to original texture space, then samples 8
//    neighboring texels to detect alpha edges.
// 3. Outline is drawn where a neighbor is opaque but the current pixel is not.
//
// When outline_width = 0.0, vertex expansion is zero and fragment is passthrough.
//
// SYSTEM: Juice System (Outline2DJuiceComp / OutlineControlJuiceComp)
// =============================================================================

shader_type canvas_item;

// Width of the outline in texels. 0.0 = invisible (passthrough).
// Animated by the juice component's _apply_effect().
uniform float outline_width : hint_range(0.0, 20.0, 0.5) = 0.0;

// Color of the outline (includes alpha).
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);

// Sample texture alpha, returning 0.0 if UV is outside the original 0–1 range.
// Prevents false outlines from edge-clamped sampling.
float safe_alpha(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void vertex() {
	// Expand the rendered quad so the outline extends beyond the original bounds.
	// UV 0→1 maps to direction -1→+1, pushing each corner outward.
	VERTEX += (UV * 2.0 - 1.0) * outline_width;
}

void fragment() {
	// Remap UV back to original texture space.
	// The quad is now (tex_size + 2*outline_width) pixels wide/tall.
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 padded_size = tex_size + vec2(outline_width * 2.0);
	vec2 orig_uv = (UV * padded_size - vec2(outline_width)) / tex_size;

	// Sample original texture (transparent if outside original bounds)
	vec4 tex = vec4(0.0);
	if (orig_uv.x >= 0.0 && orig_uv.x <= 1.0 && orig_uv.y >= 0.0 && orig_uv.y <= 1.0) {
		tex = texture(TEXTURE, orig_uv);
	}

	if (outline_width > 0.0) {
		// Neighbor sampling distance in original UV space
		vec2 step = outline_width / tex_size;

		// 8-direction edge detection — max alpha of neighbors
		float a = 0.0;
		a = max(a, safe_alpha(TEXTURE, orig_uv + vec2(-step.x, 0.0)));
		a = max(a, safe_alpha(TEXTURE, orig_uv + vec2( step.x, 0.0)));
		a = max(a, safe_alpha(TEXTURE, orig_uv + vec2(0.0, -step.y)));
		a = max(a, safe_alpha(TEXTURE, orig_uv + vec2(0.0,  step.y)));
		a = max(a, safe_alpha(TEXTURE, orig_uv + vec2(-step.x, -step.y)));
		a = max(a, safe_alpha(TEXTURE, orig_uv + vec2( step.x, -step.y)));
		a = max(a, safe_alpha(TEXTURE, orig_uv + vec2(-step.x,  step.y)));
		a = max(a, safe_alpha(TEXTURE, orig_uv + vec2( step.x,  step.y)));

		// Outline where neighbors are opaque, original pixel on top
		vec4 outline_pixel = vec4(outline_color.rgb, outline_color.a * a);
		COLOR = mix(outline_pixel, tex, tex.a);
	} else {
		// No outline — perfect passthrough
		COLOR = tex;
	}
}
