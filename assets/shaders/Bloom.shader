// Zikozythia - Layered Bloom composite
// Each element type (notes, cursor, border, background, effects) is rendered
// to its own layer buffer, then blurred through a chain of low-res gaussian
// passes so the glow energy SPREADS into a wide soft halo (not a bright copy
// stacked on the element). The composite upscales each low-res glow with a
// 4-tap bilinear sample so the result stays smooth - no pixelation.

shader_type canvas_item;

uniform float bloom_saturation : hint_range(0.0, 2.0) = 1.2;
uniform vec2 bloom_texel = vec2(0.003, 0.005);

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

vec3 sample_layer(sampler2D tex, vec2 uv) {
	// manual bilinear: average the 4 texels around the sample point so the
	// low-res glow upscales smoothly instead of showing blocks
	vec2 fuv = vec2(uv.x, 1.0 - uv.y);
	vec2 h = bloom_texel * 0.5;
	vec3 c = texture(tex, fuv + vec2(-h.x, -h.y));
	c += texture(tex, fuv + vec2(h.x, -h.y));
	c += texture(tex, fuv + vec2(-h.x, h.y));
	c += texture(tex, fuv + vec2(h.x, h.y));
	return c * 0.25;
}

float gradient_dither(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715)))) - 0.5;
}

void fragment() {
	vec3 source = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	float bloomAmount = 0.0;

	if (notes_strength > 0.0) {
		vec3 b = sample_layer(notes_tex, UV);
		float lum = dot(b, vec3(0.2126, 0.7152, 0.0722));
		b = mix(vec3(lum), b, bloom_saturation) * notes_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (cursor_strength > 0.0) {
		vec3 b = sample_layer(cursor_tex, UV);
		float lum = dot(b, vec3(0.2126, 0.7152, 0.0722));
		b = mix(vec3(lum), b, bloom_saturation) * cursor_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (border_strength > 0.0) {
		vec3 b = sample_layer(border_tex, UV);
		float lum = dot(b, vec3(0.2126, 0.7152, 0.0722));
		b = mix(vec3(lum), b, bloom_saturation) * border_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (background_strength > 0.0) {
		vec3 b = sample_layer(background_tex, UV);
		float lum = dot(b, vec3(0.2126, 0.7152, 0.0722));
		b = mix(vec3(lum), b, bloom_saturation) * background_strength;
		source += b;
		bloomAmount = max(bloomAmount, max(max(b.r, b.g), b.b));
	}
	if (world_strength > 0.0) {
		vec3 b = sample_layer(world_tex, UV);
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
