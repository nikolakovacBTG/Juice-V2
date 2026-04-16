// Screen Juice Post-Process Shader
// =============================================================================
// Full-screen UV manipulation shader for ScreenJuiceUtility.
// Reads the final composited screen image via hint_screen_texture and applies
// a chain of UV transforms + chromatic aberration — all driven by uniforms set
// by ScreenJuiceUtility each frame.
//
// Transform order (each is additive, all uniforms default to passthrough):
//   1. Barrel/pincushion distortion (radial UV warp from center)
//   2. Zoom (UV scale from center)
//   3. Rotation (UV rotation around center)
//   4. Skew (UV shear — horizontal and vertical)
//   5. Offset (UV translation)
//   6. Scanline wave (sin-based horizontal distortion)
//   7. Clamp to [0,1]
//   8. Chromatic aberration (RGB channel split — applied after UV is final)
//
// When all uniforms are at defaults, this is a perfect passthrough.
// SYSTEM: Juice System (Screen Effects)
// =============================================================================

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// --- Existing channels ---
uniform vec2 offset = vec2(0.0);
uniform float rotation_angle = 0.0;
uniform float zoom_amount = 1.0;

// --- New channels ---

// Horizontal (x) and vertical (y) shear.
// Typical range: -0.3 to 0.3. Positive x = lean right. Positive y = lean down.
uniform vec2 skew = vec2(0.0);

// Barrel (negative) or pincushion (positive) radial distortion.
// Typical range: -0.5 to 0.5.
uniform float barrel_distortion = 0.0;

// Scanline wave: horizontal displacement driven by sin(uv.y * frequency).
// wave_amplitude: how far each scanline shifts (UV normalized). Typical: 0.0–0.05.
// wave_frequency: how many full waves fit vertically. Typical: 5–30.
uniform float wave_amplitude = 0.0;
uniform float wave_frequency = 10.0;

// RGB channel separation. Positive = redshift right, blueshift left.
// Typical range: 0.0–0.02.
uniform float chromatic_aberration = 0.0;

void fragment() {
	vec2 center = vec2(0.5);
	vec2 uv = SCREEN_UV;

	// 1. Barrel / pincushion distortion (applied first, before other transforms)
	//    Negative barrel_distortion = barrel (edges bow outward).
	//    Positive barrel_distortion = pincushion (edges bow inward).
	if (barrel_distortion != 0.0) {
		vec2 d = uv - center;
		float r2 = dot(d, d);
		uv = uv + d * r2 * barrel_distortion;
	}

	// 2. Zoom around screen center
	//    Values > 1.0 zoom in (shrink UV range), < 1.0 zoom out
	uv = (uv - center) / max(zoom_amount, 0.001) + center;

	// 3. Rotation around screen center
	uv -= center;
	float s = sin(rotation_angle);
	float c = cos(rotation_angle);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
	uv += center;

	// 4. Skew (shear transform)
	//    Each axis is sheared by the other axis minus center.
	//    Horizontal skew: sliding rows up/down. Vertical skew: sliding columns left/right.
	uv.x += skew.x * (uv.y - 0.5);
	uv.y += skew.y * (uv.x - 0.5);

	// 5. Offset (translation)
	uv += offset;

	// 6. Scanline wave
	//    Horizontal displacement: each row shifts by sin(row_position * frequency).
	if (wave_amplitude != 0.0) {
		uv.x += sin(uv.y * wave_frequency * 6.283185) * wave_amplitude;
	}

	// 7. Clamp to valid UV range (prevents edge wrapping/bleeding)
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// 8. Chromatic aberration — sample R/G/B at slightly different UV offsets.
	//    Applied AFTER all UV transforms so the split is screen-aligned, not world-aligned.
	if (chromatic_aberration != 0.0) {
		vec2 ca_offset = vec2(chromatic_aberration, 0.0);
		COLOR.r = texture(screen_texture, clamp(uv + ca_offset, vec2(0.0), vec2(1.0))).r;
		COLOR.g = texture(screen_texture, uv).g;
		COLOR.b = texture(screen_texture, clamp(uv - ca_offset, vec2(0.0), vec2(1.0))).b;
		COLOR.a = texture(screen_texture, uv).a;
	} else {
		COLOR = texture(screen_texture, uv);
	}
}
