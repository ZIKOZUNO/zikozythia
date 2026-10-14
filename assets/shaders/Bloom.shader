// Zikozythia — Layered Bloom Shader
// Ported from the CapoRhythia (Steam Rhythia fork) bloom pipeline and
// extended with per-element layers: each element type (notes, cursor,
// border, background, effects) has its own low-res render buffer, its own
// soft-knee bright-pass + multi-ring gaussian blur, and its own
// strength/radius. The HUD (2D canvas layer above this rect) stays crisp.

shader_type canvas_item;

uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.08;
uniform float bloom_saturation : hint_range(0.0, 2.0) = 1.2;
uniform vec2 bloom_texel = vec2(0.002, 0.002);

uniform sampler2D notes_tex : hint_black;
uniform float notes_strength : hint_range(0.0, 10.0) = 1.5;
uniform float notes_radius : hint_range(0.0, 50.0) = 5.0;

uniform sampler2D cursor_tex : hint_black;
uniform float cursor_strength : hint_range(0.0, 10.0) = 1.5;
uniform float cursor_radius : hint_range(0.0, 50.0) = 5.0;

uniform sampler2D border_tex : hint_black;
uniform float border_strength : hint_range(0.0, 10.0) = 1.5;
uniform float border_radius : hint_range(0.0, 50.0) = 5.0;

uniform sampler2D background_tex : hint_black;
uniform float background_strength : hint_range(0.0, 10.0) = 1.0;
uniform float background_radius : hint_range(0.0, 50.0) = 8.0;

uniform sampler2D world_tex : hint_black;
uniform float world_strength : hint_range(0.0, 10.0) = 1.0;
uniform float world_radius : hint_range(0.0, 50.0) = 5.0;

vec3 apply_soft_threshold(vec3 color) {
	float brightness = max(max(color.r, color.g), color.b);
	float knee = max(bloom_threshold * 0.5, 0.0001);
	float soft = clamp(brightness - bloom_threshold + knee, 0.0, 2.0 * knee);
	soft = soft * soft / (4.0 * knee);
	float contribution = max(brightness - bloom_threshold, soft) / max(brightness, 0.0001);
	return color * max(contribution, 0.0) / max(1.0 - bloom_threshold, 0.0001);
}

vec3 ring13(sampler2D tex, vec2 center, vec2 offset) {
	vec3 c = apply_soft_threshold(texture(tex, center).rgb) * 4.0;
	c += apply_soft_threshold(texture(tex, center + vec2(offset.x, 0.0)).rgb) * 2.0;
	c += apply_soft_threshold(texture(tex, center - vec2(offset.x, 0.0)).rgb) * 2.0;
	c += apply_soft_threshold(texture(tex, center + vec2(0.0, offset.y)).rgb) * 2.0;
	c += apply_soft_threshold(texture(tex, center - vec2(0.0, offset.y)).rgb) * 2.0;
	c += apply_soft_threshold(texture(tex, center + offset).rgb);
	c += apply_soft_threshold(texture(tex, center - offset).rgb);
	c += apply_soft_threshold(texture(tex, center + vec2(offset.x, -offset.y)).rgb);
	c += apply_soft_threshold(texture(tex, center + vec2(-offset.x, offset.y)).rgb);
	return c / 16.0;
}

vec3 layer_bloom(sampler2D tex, float radius, vec2 uv) {
	// ViewportTextures are stored Y-flipped vs SCREEN_TEXTURE in Godot 3
	vec2 fuv = vec2(uv.x, 1.0 - uv.y);
	// four overlapping gaussian rings give the glow a smooth, banding-free falloff
	vec3 c = ring13(tex, fuv, radius * 0.25 * bloom_texel);
	c += ring13(tex, fuv, radius * 0.5 * bloom_texel);
	c += ring13(tex, fuv, radius * 0.75 * bloom_texel);
	c += ring13(tex, fuv, radius * 1.0 * bloom_texel);
	c /= 4.0;
	float luminance = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(luminance), c, bloom_saturation);
}

void fragment() {
	vec3 source = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	float bloomAmount = 0.0;

	if (notes_strength > 0.0) {
		vec3 b = layer_bloom(notes_tex, notes_radius, UV) * notes_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (cursor_strength > 0.0) {
		vec3 b = layer_bloom(cursor_tex, cursor_radius, UV) * cursor_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (border_strength > 0.0) {
		vec3 b = layer_bloom(border_tex, border_radius, UV) * border_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (background_strength > 0.0) {
		vec3 b = layer_bloom(background_tex, background_radius, UV) * background_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (world_strength > 0.0) {
		vec3 b = layer_bloom(world_tex, world_radius, UV) * world_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}

	if (bloomAmount > 0.0) {
		float dither = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
		source += dither / 255.0 * smoothstep(0.0, 1.0 / 255.0, bloomAmount);
	}

	COLOR = vec4(source, 1.0);
}
