// Screen Juice Post-Process Shader
// =============================================================================
// Full-screen UV manipulation shader for ScreenJuiceUtility.
// Reads the final composited screen image via hint_screen_texture and applies
// a chain of UV transforms + chromatic aberration — all driven by uniforms set
// by ScreenJuiceUtility each frame.
//
// Transform order (each is additive, all uniforms default to passthrough):
//   1. Barrel/pincushion distortion (radial UV warp from pivot_uv)
//   2. Zoom (UV scale from pivot_uv)
//   3. Rotation (UV rotation around pivot_uv)
//   4. Skew (UV shear — anchored to pivot_uv)
//   5. Offset (UV translation)
//   6. Scanline wave (sin-based horizontal distortion)
//   7. Clamp to [0,1]
//   8. Chromatic aberration (RGB channel split — applied after UV is final)
//
// PIVOT: pivot_uv (default vec2(0.5, 0.5)) is the origin for Barrel/Zoom/Rotation/Skew.
//        Set via ScreenJuiceEffect.pivot_offset. Wave and Chromatic ignore this.
// When all uniforms are at defaults, this is a perfect passthrough.
// SYSTEM: Juice System (Screen Effects)
// =============================================================================

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// --- Existing channels ---
uniform vec2 offset = vec2(0.0);
uniform float rotation_angle = 0.0;
uniform float zoom_amount = 1.0;

// Pivot point for Barrel, Zoom, Rotation, and Skew transforms.
// (0.5, 0.5) = screen center (default). Set by ScreenJuiceUtility from effect's pivot_offset.
// Wave and Chromatic Aberration are full-screen effects that ignore this.
uniform vec2 pivot_uv = vec2(0.5, 0.5);

// --- New channels ---

// Horizontal (x) and vertical (y) shear.
// Typical range: -0.3 to 0.3. Positive x = lean right. Positive y = lean down.
uniform vec2 skew = vec2(0.0);

// Barrel (negative) or pincushion (positive) radial distortion.
// X controls horizontal deformation, Y controls vertical deformation.
// Typical range: -0.5 to 0.5 per axis.
uniform vec2 barrel_distortion = vec2(0.0);

// Scanline wave: horizontal displacement driven by sin(uv.y * frequency).
// wave_amplitude: how far each scanline shifts (UV normalized). Typical: 0.0–0.05.
// wave_frequency: how many full waves fit vertically. Typical: 5–30.
// wave_direction: 0=Horizontal (scanlines drift sideways)
//                 1=Vertical   (columns drift up/down)
//                 2=Concentric (radial ripples expanding from pivot_uv)
uniform float wave_amplitude  = 0.0;
uniform float wave_frequency  = 10.0;
uniform int   wave_direction  = 0;  // 0=Horizontal, 1=Vertical, 2=Concentric

// RGB channel separation. Positive = redshift right, blueshift left.
// Typical range: 0.0–0.02.
uniform float chromatic_aberration = 0.0;

// Chromatic aberration mode:
//   0 (Uniform)        — equal horizontal split on all channels (classic)
//   1 (VignetteFalloff)— same as Uniform but strength is scaled by vignette_mask
//   2 (NoisePerChannel)— R, G, B each get independent X+Y noise offset
//                         ( drunken/lens-warp look; needs chromatic_time + chromatic_seed )
uniform int   chromatic_mode = 0;

// Used only in NoisePerChannel mode. chromatic_time is updated every frame by
// ScreenJuiceUtility (monotone time * shake_frequency from the effect).
// chromatic_seed controls the per-channel base offset in the noise field.
uniform float chromatic_time = 0.0;
uniform float chromatic_seed = 0.0;

// Vignette mask: fades Wave and Chromatic effects toward the center of the screen.
// Gives a realistic lens-edge distortion look (stronger at corners, zero at pivot).
// use_vignette: enables the mask for Wave and Chromatic channels.
// vignette_scale: stretches the vignette ellipse. (1,1) = circle; (2,1) = wide; (1,2) = tall.
// vignette_softness: falloff steepness. Higher = sharper edge. Typical: 0.5–3.0.
uniform bool  use_vignette     = false;
uniform vec2  vignette_scale   = vec2(1.0);
uniform float vignette_softness = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Pre-compute vignette mask from UNDISTORTED screen position.
	// Using SCREEN_UV (not the distorted uv) keeps the mask in screen space,
	// so the vignette tracks the viewport edge, not the warped image.
	// vignette_mask = 1.0 means full effect; 0.0 = no effect at center.
	float vignette_mask = 1.0;
	if (use_vignette) {
		vec2 vd = (SCREEN_UV - pivot_uv) * vignette_scale;
		// dot(vd,vd) = squared distance from pivot_uv, scaled by vignette_scale per axis.
		// pow(..., softness) controls how quickly the mask rises from center to edge.
		vignette_mask = clamp(pow(dot(vd, vd), vignette_softness), 0.0, 1.0);
	}

	// 1. Barrel / pincushion distortion (applied first, before other transforms)
	//    barrel_distortion.x: horizontal axis warp. barrel_distortion.y: vertical axis warp.
	//    Negative = barrel (edges bow outward). Positive = pincushion (edges bow inward).
	if (barrel_distortion != vec2(0.0)) {
		vec2 d = uv - pivot_uv;
		float r2 = dot(d, d);
		// vec2 * float * vec2 is component-wise: each axis warps independently.
		uv = uv + d * r2 * barrel_distortion;
	}

	// 2. Zoom around pivot_uv
	//    Values > 1.0 zoom in (shrink UV range), < 1.0 zoom out
	uv = (uv - pivot_uv) / max(zoom_amount, 0.001) + pivot_uv;

	// 3. Rotation around pivot_uv
	uv -= pivot_uv;
	float s = sin(rotation_angle);
	float c = cos(rotation_angle);
	uv = vec2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
	uv += pivot_uv;

	// 4. Skew (shear transform) anchored to pivot_uv
	//    Each axis is sheared by the other axis offset from the pivot.
	//    Horizontal skew: sliding rows up/down. Vertical skew: sliding columns left/right.
	uv.x += skew.x * (uv.y - pivot_uv.y);
	uv.y += skew.y * (uv.x - pivot_uv.x);

	// 5. Offset (translation)
	uv += offset;

	// 6. Scanline wave — direction-switched; optional vignette falloff attenuates strength.
	//    All modes share wave_frequency (cycles) and wave_amplitude (peak UV shift).
	if (wave_amplitude != 0.0) {
		float amp = wave_amplitude * vignette_mask;
		if (wave_direction == 0) {
			// Horizontal: each row (same y) shifts in x by sin(y * freq).
			uv.x += sin(uv.y * wave_frequency * 6.283185) * amp;
		} else if (wave_direction == 1) {
			// Vertical: each column (same x) shifts in y by sin(x * freq).
			uv.y += sin(uv.x * wave_frequency * 6.283185) * amp;
		} else {
			// Concentric: radial ripples expanding from pivot_uv.
			// dist = distance from pivot; offset direction = radial outward unit vector.
			vec2  d    = uv - pivot_uv;
			float dist = length(d);
			// Avoid division by zero at the exact pivot center.
			if (dist > 0.0001) {
				vec2 dir = d / dist;
				uv += dir * sin(dist * wave_frequency * 6.283185) * amp;
			}
		}
	}

	// 7. Clamp to valid UV range (prevents edge wrapping/bleeding)
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// 8. Chromatic aberration — 3 modes controlled by chromatic_mode.
	//    Applied AFTER all UV transforms so the split is screen-aligned, not world-aligned.
	//    When use_vignette: vignette_mask pre-computed above is used to modulate strength.
	if (chromatic_aberration != 0.0) {
		if (chromatic_mode == 2) {
			// NoisePerChannel: lightweight sin-sum oscillator — no texture needed.
			// Each channel gets an independent 2D offset driven by chromatic_time + seed.
			// Using 3 harmonics per channel gives smooth, non-repeating motion.
			// The seed offsets (100, 200, 300 etc.) decorrelate the three channels.
			float t = chromatic_time;
			float s = chromatic_seed;
			// Red channel noise: X and Y independent
			vec2 r_off = vec2(
				(sin(t * 1.0 + s       ) + sin(t * 2.3 + s + 1.0) * 0.5 + sin(t * 4.1 + s + 2.0) * 0.25) / 1.75,
				(sin(t * 1.0 + s + 50.0) + sin(t * 2.3 + s + 51.0) * 0.5 + sin(t * 4.1 + s + 52.0) * 0.25) / 1.75
			) * chromatic_aberration * vignette_mask;
			// Green channel noise (different seed row)
			vec2 g_off = vec2(
				(sin(t * 1.0 + s + 100.0) + sin(t * 2.3 + s + 101.0) * 0.5 + sin(t * 4.1 + s + 102.0) * 0.25) / 1.75,
				(sin(t * 1.0 + s + 150.0) + sin(t * 2.3 + s + 151.0) * 0.5 + sin(t * 4.1 + s + 152.0) * 0.25) / 1.75
			) * chromatic_aberration * vignette_mask;
			// Blue channel noise (different seed row)
			vec2 b_off = vec2(
				(sin(t * 1.0 + s + 200.0) + sin(t * 2.3 + s + 201.0) * 0.5 + sin(t * 4.1 + s + 202.0) * 0.25) / 1.75,
				(sin(t * 1.0 + s + 250.0) + sin(t * 2.3 + s + 251.0) * 0.5 + sin(t * 4.1 + s + 252.0) * 0.25) / 1.75
			) * chromatic_aberration * vignette_mask;
			COLOR.r = texture(screen_texture, clamp(uv + r_off, vec2(0.0), vec2(1.0))).r;
			COLOR.g = texture(screen_texture, clamp(uv + g_off, vec2(0.0), vec2(1.0))).g;
			COLOR.b = texture(screen_texture, clamp(uv + b_off, vec2(0.0), vec2(1.0))).b;
			COLOR.a = texture(screen_texture, uv).a;
		} else {
			// Uniform (0) or VignetteFalloff (1): simple horizontal R/B split.
			// VignetteFalloff scales strength by vignette_mask (0 at center, 1 at corners).
			// Uniform: vignette_mask = 1.0 (no falloff) when use_vignette is false.
			vec2 ca_offset = vec2(chromatic_aberration * vignette_mask, 0.0);
			COLOR.r = texture(screen_texture, clamp(uv + ca_offset, vec2(0.0), vec2(1.0))).r;
			COLOR.g = texture(screen_texture, uv).g;
			COLOR.b = texture(screen_texture, clamp(uv - ca_offset, vec2(0.0), vec2(1.0))).b;
			COLOR.a = texture(screen_texture, uv).a;
		}
	} else {
		COLOR = texture(screen_texture, uv);
	}
}
