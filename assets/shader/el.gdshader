shader_type canvas_item;
// Vatandaşın elleri: boyalı el görsellerinde kol ağzı nötr gridir; burada vatandaşın giysisinin rengine
// boyanır. Ten (doygun, sıcak renkli pikseller) olduğu gibi kalır, yalnızca gri pikseller renklenir.

uniform vec3 kol_rengi = vec3(0.45, 0.42, 0.40);
uniform float ten_koyulugu = 1.0;      // 1: olduğu gibi; < 1 daha esmer

varying vec4 renklendirme;

void vertex() {
	renklendirme = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float en_buyuk = max(c.r, max(c.g, c.b));
	float en_kucuk = min(c.r, min(c.g, c.b));
	float doygunluk = (en_buyuk - en_kucuk) / max(en_buyuk, 0.001);
	float kumas = 1.0 - smoothstep(0.10, 0.24, doygunluk);
	float isik = dot(c.rgb, vec3(0.30, 0.59, 0.11));
	vec3 boyali = kol_rengi * (isik / 0.46);
	vec3 renk = mix(c.rgb * ten_koyulugu, boyali, kumas);
	COLOR = vec4(renk, c.a) * renklendirme;
}
