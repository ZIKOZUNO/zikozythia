// Zikozythia bloom - in-viewport blur pass.
// Runs INSIDE each layer's viewport: samples the viewport's own back-buffer
// (the previous pass output / the 3D render) so the whole blur chain
// completes within a single frame - no viewport-to-viewport handoffs, no lag.
// The first pass in each chain applies the soft-knee bright-pass threshold.

shader_type canvas_item;

uniform vec2 texel = vec2(0.002, 0.0014);
uniform float offset : hint_range(0.0, 64.0) = 1.0;
uniform float threshold : hint_range(0.0, 1.0) = 0.08;
uniform bool threshold_enabled = false;

vec3 soft_threshold(vec3 color) {
	float brightness = max(max(color.r, color.g), color.b);
	float knee = max(threshold * 0.5, 0.0001);
	float soft = clamp(brightness - threshold + knee, 0.0, 2.0 * knee);
	soft = soft * soft / (4.0 * knee);
	float contribution = max(brightness - threshold, soft) / max(brightness, 0.0001);
	return color * max(contribution, 0.0) / max(1.0 - threshold, 0.0001);
}

vec3 tap(vec2 uv) {
	vec3 c = texture(SCREEN_TEXTURE, uv).rgb;
	if (threshold_enabled) {
		c = soft_threshold(c);
	}
	return c;
}

void fragment() {
	vec2 o = texel * offset;
	vec3 c = tap(SCREEN_UV) * 4.0;
	c += tap(SCREEN_UV + vec2(o.x, 0.0)) * 2.0;
	c += tap(SCREEN_UV - vec2(o.x, 0.0)) * 2.0;
	c += tap(SCREEN_UV + vec2(0.0, o.y)) * 2.0;
	c += tap(SCREEN_UV - vec2(0.0, o.y)) * 2.0;
	c += tap(SCREEN_UV + o);
	c += tap(SCREEN_UV - o);
	c += tap(SCREEN_UV + vec2(o.x, -o.y));
	c += tap(SCREEN_UV + vec2(-o.x, o.y));
	COLOR = vec4(c / 16.0, 1.0);
}
