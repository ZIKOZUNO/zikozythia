// Zikozythia bloom blur pass - 13-tap gaussian over an (already smoothed)
// source. Chained passes at low resolution produce a genuinely smooth glow
// with no ghost copies. The first pass in each chain applies the soft-knee
// bright-pass threshold.

shader_type canvas_item;

uniform sampler2D src : hint_black;
uniform vec2 texel = vec2(0.004, 0.006);
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
	vec3 c = texture(src, uv).rgb;
	if (threshold_enabled) {
		c = soft_threshold(c);
	}
	return c;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	vec2 o = texel * offset;
	vec3 c = tap(uv) * 4.0;
	c += tap(uv + vec2(o.x, 0.0)) * 2.0;
	c += tap(uv - vec2(o.x, 0.0)) * 2.0;
	c += tap(uv + vec2(0.0, o.y)) * 2.0;
	c += tap(uv - vec2(0.0, o.y)) * 2.0;
	c += tap(uv + o);
	c += tap(uv - o);
	c += tap(uv + vec2(o.x, -o.y));
	c += tap(uv + vec2(-o.x, o.y));
	COLOR = vec4(c / 16.0, 1.0);
}
