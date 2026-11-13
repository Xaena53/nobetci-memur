class_name Gorsel
extends RefCounted
## Büyük arka plan görsellerini "doku kalitesi" ayarına göre yükler.
##
## Arka planlar 2560×1440 saklanır (büyük ekranlarda keskin dursun diye); her biri ekran belleğinde
## 14,7 MB tutar. Zayıf bilgisayarlarda (ekranı çoğu zaman 1366×768) bu, gereğinden dört kat büyük
## bir dokudur. Doku kalitesi "düşük" iken görsel yarı çözünürlükte (1280×720, oyunun tasarım
## çözünürlüğü) yüklenir: 3,7 MB.
##
## Yalnızca belirli bir alana gerilerek çizilen görseller için kullanılır (TextureRect); boyutu
## yerleşimde kullanılan görsellere (portreler, çanta kabukları) dokunulmaz.

static var _kucukler: Dictionary = {}      ## yol -> WeakRef(Texture2D): küçültülmüş kopya, kullanan kalmayınca bırakılır


static func yukle(yol: String) -> Texture2D:
	if not ResourceLoader.exists(yol):
		return null
	if str(Oyun.ayar("doku_kalitesi")) != "dusuk":
		return load(yol)
	var eski: WeakRef = _kucukler.get(yol)
	if eski != null:
		var hazir := eski.get_ref() as Texture2D
		if hazir != null:
			return hazir
	var doku := load(yol) as Texture2D
	if doku == null:
		return null
	var g := doku.get_image()
	if g == null:
		return doku
	if g.is_compressed():
		g.decompress()
	@warning_ignore("integer_division")
	g.resize(maxi(1, g.get_width() / 2), maxi(1, g.get_height() / 2), Image.INTERPOLATE_BILINEAR)
	var kucuk := ImageTexture.create_from_image(g)
	_kucukler[yol] = weakref(kucuk)
	return kucuk
