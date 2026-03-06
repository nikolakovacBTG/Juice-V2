// Screen Juice Post-Process Shader
// =============================================================================
// Full-screen UV manipulation shader for ScreenJuiceReceiver.
// Reads the final composited screen image via hint_screen_texture and applies
// offset, rotation, and zoom — driven by ScreenMotionJuiceComp uniforms.
//
// When all uniforms are at defaults (offset=0, rotation=0, zoom=1),
// this is a perfect passthrough with zero visual change.
//
// SYSTEM: Juice System (Screen Effects)
// =============================================================================

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// UV pixel offset, normalized to screen size (set by ScreenJuiceReceiver)
uniform vec2 offset = vec2(0.0);

// Rotation in radians around screen center (set by ScreenJuiceReceiver)
uniform float rotation_angle = 0.0;

// Zoom scale factor — 1.0 = no zoom (set by ScreenJuiceReceiver)
uniform float zoom_amount = 1.0;

void fragment() {
	vec2 center = vec2(0.5);
	vec2 uv = SCREEN_UV;

	// Apply zoom around screen center
	// Values > 1.0 zoom in (shrink UV range), < 1.0 zoom out
	uv = (uv - center) / max(zoom_amount, 0.001) + center;

	// Apply rotation around screen center
	uv -= center;
	float s = sin(rotation_angle);
	float c = cos(rotation_angle);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
	uv += center;

	// Apply offset (pixel offset normalized by receiver before passing here)
	uv += offset;

	// Clamp to valid texture range to prevent edge glitching when offsets push UVs out of bounds
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	COLOR = texture(screen_texture, uv);
}
