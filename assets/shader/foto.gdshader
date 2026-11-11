shader_type canvas_item;
// Vesikalık fotoğraf: renkli portreyi sıcak tonlu siyah-beyaz baskıya çevirir.

uniform vec3 ton : source_color = vec3(0.94, 0.91, 0.84);
uniform float kontrast = 1.18;

void fragment() {
	vec4 renk = texture(TEXTURE, UV);
	float gri = dot(renk.rgb, vec3(0.299, 0.587, 0.114));
	gri = clamp((gri - 0.5) * kontrast + 0.54, 0.0, 1.0);
	COLOR.rgb = vec3(gri) * ton;
}
