shader_type canvas_item;
// "Renk | saydamlık" biçiminde yan yana kodlanmış videoyu saydam figür olarak çizer
// (bkz. tools/sanat/figur_video.py). Sol yarı renktir (figürün dışı kenar rengiyle dolguludur), sağ yarı mattır.

varying vec4 renklendirme;

void vertex() {
	renklendirme = COLOR;
}

void fragment() {
	vec2 uv = vec2(clamp(UV.x, 0.004, 0.996) * 0.5, UV.y);
	vec3 renk = texture(TEXTURE, uv).rgb;
	float alfa = smoothstep(0.12, 0.92, texture(TEXTURE, uv + vec2(0.5, 0.0)).r);
	COLOR = vec4(renk * renklendirme.rgb, alfa * renklendirme.a);
}
