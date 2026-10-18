// Zikozythia - Layered Bloom composite
// Each element type (notes, cursor, border, background, effects) is rendered
// to its own low-res layer buffer, then blurred through a chain of low-res
// gaussian passes (see bloom_blur.shader) so the glow is genuinely smooth
// with no ghost copies. This pass composites the pre-blurred layers over the
// screen with per-element strength and saturation.

shader_type canvas_item;

uniform float bloom_saturation : hint_range(0.0, 2.0) = 1.2;

uniform sampler2D notes_tex : hint_black;
uniform float notes_strength : hint_range(0.0, 10.0) = 1.5;

uniform sampler2D cursor_tex : hint_black;
uniform float cursor_strength : hint_range(0.0, 10.0) = 1.5;

uniform sampler2D border_tex : hint_black;
uniform float border_strength : hint_range(0.0, 10.0) = 1.5;

uniform sampler2D background_tex : hint_black;
uniform float background_strength : hint_range(0.0, 10.0) = 1.0;

uniform sampler2D world_tex : hint_black;
uniform float world_strength : hint_range(0.0, 10.0) = 1.0;

float gradient_dither(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715)))) - 0.5;
}

void fragment() {
	vec3 source = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	float bloomAmount = 0.0;

	if (notes_strength > 0.0) {
		vec3 b = texture(notes_tex, vec2(UV.x, 1.0 - UV.y)).rgb;
		float lum = dot(b, vec3(0.2126, 0.7152, 0.0722));
		b = mix(vec3(lum), b, bloom_saturation) * notes_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (cursor_strength > 0.0) {
		vec3 b = texture(cursor_tex, vec2(UV.x, 1.0 - UV.y)).rgb;
		float lum = dot(b, vec3(0.2126, 0.7152, 0.0722));
		b = mix(vec3(lum), b, bloom_saturation) * cursor_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (border_strength > 0.0) {
		vec3 b = texture(border_tex, vec2(UV.x, 1.0 - UV.y)).rgb;
		float lum = dot(b, vec3(0.2126, 0.7152, 0.0722));
		b = mix(vec3(lum), b, bloom_saturation) * border_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (background_strength > 0.0) {
		vec3 b = texture(background_tex, vec2(UV.x, 1.0 - UV.y)).rgb;
		float lum = dot(b, vec3(0.2126, 0.7152, 0.0722));
		b = mix(vec3(lum), b, bloom_saturation) * background_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (world_strength > 0.0) {
		vec3 b = texture(world_tex, vec2(UV.x, 1.0 - UV.y)).rgb;
		float lum = dot(b, vec3(0.2126, 0.7152, 0.0722));
		b = mix(vec3(lum), b, bloom_saturation) * world_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}

	if (bloomAmount > 0.0) {
		source += gradient_dither(FRAGCOORD.xy) / 255.0 * smoothstep(0.0, 1.0 / 255.0, bloomAmount);
	}

	COLOR = vec4(source, 1.0);
}
