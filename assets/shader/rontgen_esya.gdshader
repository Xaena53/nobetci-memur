shader_type canvas_item;
render_mode blend_mul, unshaded;
// Röntgendeki tek bir eşya. Doku bir yoğunluk haritasıdır (siyah: boş, beyaz: yoğun). Eşyalar beyaz
// bir zemine çarpılarak çizilir: üst üste gelen yoğunluklar birikir, hiçbir zaman taşmaz.

uniform float yogun = 1.0;

void fragment() {
	float v = clamp(texture(TEXTURE, UV).r * yogun, 0.0, 1.0);
	COLOR = vec4(vec3(1.0 - v), 1.0);
}
