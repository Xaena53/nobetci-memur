shader_type canvas_item;
// Röntgen cihazının tüplü ekranı. Girdi, eşyaların çarpılarak biriktiği geçirgenlik haritasıdır
// (beyaz: boş, siyah: yoğun); burada yoğunluğa çevrilip fosfor rengine boyanır.
// kip 0: olağan (yoğun = parlak) · 1: negatif · 2: yalnızca yoğun (maden) parçalar

uniform int kip = 0;
uniform float guc : hint_range(0.0, 1.0) = 1.0;      // 0: ekran kapalı (saydam)
uniform float alarm : hint_range(0.0, 1.0) = 0.0;    // alarm verilince ekran kızarır
uniform vec2 oran = vec2(380.0, 290.0);
uniform vec3 koyu : source_color = vec3(0.020, 0.055, 0.040);
uniform vec3 parlak : source_color = vec3(0.78, 1.0, 0.83);

float rastgele(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = TEXTURE_PIXEL_SIZE * 1.6;
	float t = texture(TEXTURE, uv).r;
	float cevre = (texture(TEXTURE, uv + vec2(p.x, 0.0)).r + texture(TEXTURE, uv - vec2(p.x, 0.0)).r
		+ texture(TEXTURE, uv + vec2(0.0, p.y)).r + texture(TEXTURE, uv - vec2(0.0, p.y)).r) * 0.25;
	float d = 1.0 - mix(t, cevre, 0.3);
	if (kip == 1) {
		d = 1.0 - d * 0.94;
	} else if (kip == 2) {
		d = smoothstep(0.60, 0.76, d);
	}
	d = pow(clamp(d, 0.0, 1.0), 0.82);

	vec3 renk = mix(koyu, parlak, d);
	// tarama çizgileri, ağır ağır kayan parlaklık bandı ve karıncalanma
	renk *= 0.90 + 0.10 * sin(uv.y * oran.y * 2.094);
	renk *= 0.96 + 0.04 * sin(uv.y * 5.0 - TIME * 1.3);
	renk += (rastgele(uv * oran + vec2(TIME * 37.0, TIME * 11.0)) - 0.5) * 0.045;
	// kenarlara doğru kararma
	vec2 m = uv * 2.0 - 1.0;
	renk *= 1.0 - 0.30 * dot(m, m) * 0.5;
	renk = mix(renk, renk * vec3(1.9, 0.45, 0.4) + vec3(0.10, 0.0, 0.0), alarm);

	// camın yuvarlak köşeleri
	vec2 q = abs(m) * oran * 0.5;
	float r = 24.0;
	vec2 k = max(q - (oran * 0.5 - vec2(r)), vec2(0.0));
	float maske = 1.0 - smoothstep(r - 1.5, r, length(k));
	COLOR = vec4(renk, maske * guc);
}
