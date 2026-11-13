shader_type canvas_item;
// Sobanın camındaki boyalı alevi canlandırır: alev dilleri yukarı doğru akar, oynar ve parlayıp söner.
// Camın demir parmaklıkları (koyu pikseller) yerinde kalır; yalnızca parlak ve sıcak renkli pikseller oynar.
// Düğüm bir ColorRect'tir; arka plan resmi `zemin` olarak verilir, `bolge` camın resimdeki yeridir.

uniform sampler2D zemin : filter_linear, repeat_disable;
uniform vec4 bolge = vec4(0.0, 0.0, 1.0, 1.0);   // camın arka plandaki yeri (uv): x, y, en, boy
uniform float guc = 1.0;                         // 0 sönük .. 1 harlı
uniform float zaman = 0.0;

float rastgele(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float gurultu(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rastgele(i), rastgele(i + vec2(1.0, 0.0)), f.x),
		mix(rastgele(i + vec2(0.0, 1.0)), rastgele(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 asil = texture(zemin, bolge.xy + UV * bolge.zw);
	float isik = dot(asil.rgb, vec3(0.30, 0.59, 0.11));
	// alev: parlak ve kırmızısı mavisinden belirgin fazla
	float alev = smoothstep(0.20, 0.42, isik) * smoothstep(0.04, 0.22, asil.r - asil.b);

	// diller yukarı akar: örnekleme noktası aşağıdan yukarı kayan gürültüyle oynar
	float n1 = gurultu(vec2(UV.x * 10.0, UV.y * 5.0 + zaman * 3.4));
	float n2 = gurultu(vec2(UV.x * 19.0 + 3.7, UV.y * 9.0 + zaman * 5.8));
	vec2 kay = vec2((n1 - 0.5) * 0.085, (n2 - 0.5) * 0.20 + 0.035 * sin(zaman * 7.3 + UV.x * 21.0));
	vec4 oynak = texture(zemin, bolge.xy + clamp(UV + kay * alev * guc, 0.0, 1.0) * bolge.zw);

	// parıltı: her açıklık kendi hızında parlayıp söner
	float parilti = 0.80 + 0.60 * gurultu(vec2(UV.x * 5.0, zaman * 5.2));
	vec3 renk = mix(asil.rgb, oynak.rgb * mix(1.0, parilti, guc), alev);

	// sıcak çekirdek: dipte sarıya çalan, yukarı doğru uzayıp kısalan parlak diller
	float dil = smoothstep(0.50, 0.92, gurultu(vec2(UV.x * 13.0, UV.y * 4.2 + zaman * 4.6)));
	float dip = smoothstep(0.15, 1.0, UV.y);
	renk += vec3(1.0, 0.56, 0.14) * dil * alev * (0.25 + 0.55 * dip) * guc;
	renk += vec3(1.0, 0.85, 0.45) * smoothstep(0.80, 1.0, n2 * dip + 0.25 * dil) * alev * 0.35 * guc;

	COLOR = vec4(renk, 1.0);
}
