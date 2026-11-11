shader_type canvas_item;
// Tek bir figür görselini canlandırır: göz kırpma, konuşma, yanak şişirme (öfleme),
// baş eğme/sallama, nefes ve kaş hareketi. Büstlerde de tam boy figürlerde de kullanılır.
//
// Yüz noktaları (göz, ağız, çene) doku koordinatındadır (0..1); data/portreler.json'dan gelir.
// Yöntem: her çıktı pikseli için "bu piksele kaynak görselin neresi gelmeli?" sorusu yanıtlanır
// (ters eşleme). Uzunluklar karışmasın diye yatay farklar `oran` (en/boy) ile dikey birime çevrilir.
//
// Konuşma: portrenin elle boyanmış iki ağız karesi varsa (hafif açık / açık) ağız bu karelerle
// oynatılır; kareler `agiz_dokusu` içinde yan yanadır ve yüzün alt bölümüne yumuşak kenarla biner.
// Karesi olmayan görsellerde yüz dudak çizgisinden ikiye ayrılarak açılır (yedek yöntem).

uniform float dolgu = 0.08;        // düğüm dokudan bu oranda büyüktür: baş oynayınca kenarda kesilmesin
uniform float oran = 1.0;          // doku eni / boyu
uniform vec2 goz_a = vec2(0.42, 0.31);
uniform vec2 goz_b = vec2(0.56, 0.31);
uniform vec2 goz_boyut = vec2(0.030, 0.016);   // göz yarıçapları (x: en birimi, y: boy birimi)
uniform vec2 agiz = vec2(0.50, 0.47);
uniform float agiz_yari = 0.06;    // ağzın yarı genişliği (en birimi)
uniform float cene = 0.58;         // çenenin dikey yeri
uniform float boyun_olcegi = 1.0;  // boyun geçişinin ölçeği: büstte 1, başı küçük kalan tam boy figürde < 1
uniform float nefes_alti = 1.0;    // bu çizginin altı nefesle oynamaz (büstte alt kenar, tam boyda bel)

uniform sampler2D agiz_dokusu : filter_linear, repeat_disable;
uniform bool agiz_kareli = false;
uniform vec4 agiz_kare = vec4(0.0, 0.0, 1.0, 1.0);    // karelerin portredeki yeri (x, y, en, boy)
uniform vec4 agiz_atlas = vec4(0.0, 0.0, 0.5, 1.0);   // ilk karenin atlastaki yeri; ikincisi yatayda +0.5

uniform float kirpma = 0.0;        // 0 açık .. 1 kapalı
uniform float agiz_acik = 0.0;     // 0 kapalı .. 0.5 hafif açık .. 1 açık
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

	float boyun = cene + 0.035 * boyun_olcegi;
	float bas_m = 1.0 - smoothstep(boyun - 0.02 * boyun_olcegi, boyun + 0.07 * boyun_olcegi, uv.y);

	// Nefes: gövde `nefes_alti` çizgisinde sabit; omuzlar ve baş birlikte yükselir.
	float govde = clamp((nefes_alti - max(uv.y, boyun)) / max(nefes_alti - boyun, 0.001), 0.0, 1.0);
	uv.y += 0.012 * nefes * govde;

	// Baş: boyun ekseni çevresinde döner ve kayar.
	vec2 eksen = vec2(agiz.x, boyun + 0.03 * boyun_olcegi);
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

	// Yedek ağız (boyalı karesi olmayan görseller): yüz, dudak çizgisinden ikiye ayrılır. Alt dudak
	// ve çene aşağı iner; ağzın köşeleri yerinde kalır. Aradaki badem biçimli boşluk ağız içidir.
	float dx = (k.x - agiz.x) / agiz_yari;                  // köşeden köşeye −1 .. 1
	float dar = max(0.0, 1.0 - dx * dx);                    // dudak açıklığının yatay biçimi
	float genis = 1.0 - smoothstep(1.0, 2.8, abs(dx));      // çenenin inişi daha geniş bir alana yayılır
	float tam = agiz_kareli ? 0.0 : agiz_acik * agiz_yari * 0.58 * oran;
	float bosluk = tam * dar;
	float asagi = k.y - agiz.y;                             // dudak çizgisinin altında artı
	float ic = 0.0;
	if (asagi > 0.0 && tam > 0.0002) {
		float yumusak = 0.0022;
		ic = smoothstep(0.0, yumusak, asagi) * (1.0 - smoothstep(bosluk - yumusak, bosluk, asagi));
		if (asagi >= bosluk) {
			float inis = clamp(asagi / max(cene - agiz.y, 0.001), 0.0, 1.0);
			float bicim = mix(dar, genis, smoothstep(0.0, 1.0, inis));
			k.y -= tam * bicim * (1.0 - smoothstep(cene, cene + 0.08, k.y));
		}
	}

	vec4 renk = texture(TEXTURE, k);
	if (k.x < 0.0 || k.x > 1.0 || k.y < 0.0 || k.y > 1.0) {
		renk.a = 0.0;
	}

	if (ic > 0.0) {
		vec3 agiz_ici = vec3(0.18, 0.06, 0.06);
		float dis = (1.0 - smoothstep(0.18, 0.42, asagi / max(bosluk, 0.0005)))
			* smoothstep(0.55, 0.9, agiz_acik) * (1.0 - smoothstep(0.45, 0.8, abs(dx)));
		agiz_ici = mix(agiz_ici, vec3(0.86, 0.82, 0.72), dis * 0.75);
		renk.rgb = mix(renk.rgb, agiz_ici, ic * renk.a);
	}

	// Boyalı ağız kareleri: kapalı (ana görsel) → hafif açık → açık. Geçişler kısa tutulur ki
	// iki kare üst üste binip dudaklar çiftlenmesin.
	if (agiz_kareli && agiz_acik > 0.01) {
		vec2 p = (k - agiz_kare.xy) / agiz_kare.zw;
		if (p.x > 0.0 && p.x < 1.0 && p.y > 0.0 && p.y < 1.0) {
			vec2 au = agiz_atlas.xy + p * agiz_atlas.zw;
			vec4 hafif = texture(agiz_dokusu, au);
			vec4 acik = texture(agiz_dokusu, au + vec2(0.5, 0.0));
			renk.rgb = mix(renk.rgb, hafif.rgb, hafif.a * smoothstep(0.10, 0.36, agiz_acik));
			renk.rgb = mix(renk.rgb, acik.rgb, acik.a * smoothstep(0.62, 0.88, agiz_acik));
		}
	}

	// Göz kapakları: yukarıdan aşağı kapanır. Kapak, gözü kirpik çizgisiyle birlikte örtecek kadar
	// geniştir; rengi gözün hemen altındaki tenden alınır, kapanınca altına ince bir kirpik çizgisi düşer.
	if (kirpma > 0.001) {
		for (int i = 0; i < 2; i++) {
			vec2 g = (i == 0) ? goz_a : goz_b;
			vec2 e = (yuz - g) / (goz_boyut * vec2(1.30, 1.55));
			float goz_ici = 1.0 - smoothstep(0.55, 1.0, length(e));
			float t = e.y * 0.5 + 0.5;
			float kapak = goz_ici * (1.0 - smoothstep(kirpma - 0.12, kirpma + 0.06, t));
			vec3 ten = texture(TEXTURE, k + vec2(0.0, goz_boyut.y * 3.0)).rgb * 0.90;
			renk.rgb = mix(renk.rgb, ten, kapak);
			float cizgi = goz_ici * smoothstep(0.18, 0.36, e.y) * (1.0 - smoothstep(0.36, 0.56, e.y));
			renk.rgb = mix(renk.rgb, vec3(0.20, 0.13, 0.10), cizgi * 0.55 * smoothstep(0.55, 1.0, kirpma));
		}
	}

	COLOR = renk * renklendirme;
}
