shader_type canvas_item;
// Tek bir büst görselini canlandırır: göz kırpma, konuşurken çene, yanak şişirme (öfleme),
// baş eğme/sallama, nefes ve kaş hareketi.
//
// Yüz noktaları (göz, ağız, çene) doku koordinatındadır (0..1); data/portreler.json'dan gelir.
// Yöntem: her çıktı pikseli için "bu piksele kaynak görselin neresi gelmeli?" sorusu yanıtlanır
// (ters eşleme). Uzunluklar karışmasın diye yatay farklar `oran` (en/boy) ile dikey birime çevrilir.

uniform float dolgu = 0.08;        // düğüm dokudan bu oranda büyüktür: baş oynayınca kenarda kesilmesin
uniform float oran = 1.0;          // doku eni / boyu
uniform vec2 goz_a = vec2(0.42, 0.31);
uniform vec2 goz_b = vec2(0.56, 0.31);
uniform vec2 goz_boyut = vec2(0.030, 0.016);   // göz yarıçapları (x: en birimi, y: boy birimi)
uniform vec2 agiz = vec2(0.50, 0.47);
uniform float agiz_yari = 0.06;    // ağzın yarı genişliği (en birimi)
uniform float cene = 0.58;         // çenenin dikey yeri

uniform float kirpma = 0.0;        // 0 açık .. 1 kapalı
uniform float agiz_acik = 0.0;     // 0 kapalı .. 1 açık
uniform float yanak = 0.0;         // 0 .. 1 şişik
uniform vec2 bas = vec2(0.0);      // başın kayması (doku birimi; +y aşağı)
uniform float bas_egim = 0.0;      // başın yana eğimi (radyan)
uniform float nefes = 0.0;         // 0 .. 1 (göğüs kabarması); eksi değer çökme
uniform float kas = 0.0;           // + kalkık, − çatık

varying vec4 renklendirme;

void vertex() {
	renklendirme = COLOR;
}

void fragment() {
	vec2 uv = (UV - 0.5) * (1.0 + 2.0 * dolgu) + 0.5;

	float boyun = cene + 0.035;
	float bas_m = 1.0 - smoothstep(boyun - 0.02, boyun + 0.07, uv.y);

	// Nefes: gövde alttan sabit; omuzlar ve baş birlikte yükselir.
	uv.y += 0.012 * nefes * (1.0 - max(uv.y, boyun)) / (1.0 - boyun);

	// Baş: boyun ekseni çevresinde döner ve kayar.
	vec2 eksen = vec2(agiz.x, boyun + 0.03);
	vec2 d = uv - eksen;
	d.x *= oran;
	float a = -bas_egim * bas_m;
	d = vec2(cos(a) * d.x - sin(a) * d.y, sin(a) * d.x + cos(a) * d.y);
	d.x /= oran;
	vec2 yuz = eksen + d - bas * bas_m;     // kaynak görselle hizalı "yüz uzayı"

	vec2 k = yuz;

	// Kaşlar: gözlerin hemen üstündeki bant yukarı/aşağı oynar.
	float goz_y = min(goz_a.y, goz_b.y);
	float bant = smoothstep(goz_y - goz_boyut.y * 4.6, goz_y - goz_boyut.y * 3.4, k.y)
		* (1.0 - smoothstep(goz_y - goz_boyut.y * 1.5, goz_y - goz_boyut.y * 0.9, k.y));
	bant *= 1.0 - smoothstep(agiz_yari * 2.6, agiz_yari * 3.8, abs(k.x - agiz.x));
	k.y += kas * goz_boyut.y * 0.85 * bant;

	// Yanaklar: ağız çevresi dışarı doğru şişer.
	vec2 m = k - agiz;
	m.x *= oran;
	float r = length(m) / (agiz_yari * 3.4 * oran);
	k = mix(k, agiz + (k - agiz) * (1.0 - 0.22 * yanak), 1.0 - smoothstep(0.15, 1.0, r));

	// Çene: ağız çizgisinin altı aşağı iner.
	float acik = agiz_acik * agiz_yari * 0.50 * oran;
	float alt_m = smoothstep(agiz.y - 0.002, agiz.y + 0.006, k.y) * (1.0 - smoothstep(cene + 0.01, cene + 0.08, k.y));
	float yan_m = 1.0 - smoothstep(agiz_yari * 1.6, agiz_yari * 3.2, abs(k.x - agiz.x));
	k.y -= acik * alt_m * yan_m;

	vec4 renk = texture(TEXTURE, k);
	if (k.x < 0.0 || k.x > 1.0 || k.y < 0.0 || k.y > 1.0) {
		renk.a = 0.0;
	}

	// Ağız içi: dudakların arasında yumuşak kenarlı, koyu kızıl bir aralık.
	if (acik > 0.0004) {
		vec2 am = yuz - (agiz + vec2(0.0, acik * 0.5));
		am.x /= agiz_yari * 0.60;
		am.y /= max(acik * 0.5, 0.0004);
		float ic = 1.0 - smoothstep(0.45, 1.10, length(am));
		renk.rgb = mix(renk.rgb, vec3(0.24, 0.08, 0.07), ic * 0.82 * renk.a);
	}

	// Göz kapakları: yukarıdan aşağı kapanır. Kapak, gözü kirpik çizgisiyle birlikte örtecek kadar
	// geniştir; rengi gözün hemen altındaki tenden alınır, kapanınca altına ince bir kirpik çizgisi düşer.
	if (kirpma > 0.001) {
		for (int i = 0; i < 2; i++) {
			vec2 g = (i == 0) ? goz_a : goz_b;
			vec2 e = (yuz - g) / (goz_boyut * vec2(1.30, 1.55));
			float ic = 1.0 - smoothstep(0.55, 1.0, length(e));
			float t = e.y * 0.5 + 0.5;
			float kapak = ic * (1.0 - smoothstep(kirpma - 0.12, kirpma + 0.06, t));
			vec3 ten = texture(TEXTURE, k + vec2(0.0, goz_boyut.y * 3.0)).rgb * 0.90;
			renk.rgb = mix(renk.rgb, ten, kapak);
			float cizgi = ic * smoothstep(0.18, 0.36, e.y) * (1.0 - smoothstep(0.36, 0.56, e.y));
			renk.rgb = mix(renk.rgb, vec3(0.20, 0.13, 0.10), cizgi * 0.55 * smoothstep(0.55, 1.0, kirpma));
		}
	}

	COLOR = renk * renklendirme;
}
