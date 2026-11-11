class_name Tarih
extends RefCounted
## "GG.AA.YYYY" biçimindeki tarihlerle hesap: gün/ay ekleme, karşılaştırma, uzun yazım.

const AYLAR := ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
	"Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]
const GUNLER := ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
const AY_UZUNLUGU := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]


## "09.01.1984" → {gun: 9, ay: 1, yil: 1984}; bozuksa boş sözlük.
static func coz(metin: String) -> Dictionary:
	var p := metin.strip_edges().split(".")
	if p.size() != 3 or not (p[0].is_valid_int() and p[1].is_valid_int() and p[2].is_valid_int()):
		return {}
	var t := {"gun": int(p[0]), "ay": int(p[1]), "yil": int(p[2])}
	if t.ay < 1 or t.ay > 12 or t.gun < 1 or t.gun > ay_gunu(t.ay, t.yil):
		return {}
	return t


static func yaz(gun: int, ay: int, yil: int) -> String:
	return "%02d.%02d.%04d" % [gun, ay, yil]


static func artik_mi(yil: int) -> bool:
	return (yil % 4 == 0 and yil % 100 != 0) or yil % 400 == 0


static func ay_gunu(ay: int, yil: int) -> int:
	return 29 if (ay == 2 and artik_mi(yil)) else AY_UZUNLUGU[ay - 1]


## Jülyen gün numarası; gün farkı ve haftanın günü buradan çıkar.
@warning_ignore("integer_division")
static func gun_no(metin: String) -> int:
	var t := coz(metin)
	if t.is_empty():
		return 0
	var a: int = (14 - t.ay) / 12
	var y: int = t.yil + 4800 - a
	var m: int = t.ay + 12 * a - 3
	return t.gun + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045


@warning_ignore("integer_division")
static func gun_nodan(j: int) -> String:
	var a := j + 32044
	var b := (4 * a + 3) / 146097
	var c := a - 146097 * b / 4
	var d := (4 * c + 3) / 1461
	var e := c - 1461 * d / 4
	var m := (5 * e + 2) / 153
	return yaz(e - (153 * m + 2) / 5 + 1, m + 3 - 12 * (m / 10), 100 * b + d - 4800 + m / 10)


static func gun_ekle(metin: String, adet: int) -> String:
	return gun_nodan(gun_no(metin) + adet)


## Ay ekler/çıkarır; hedef ayda o gün yoksa ayın son gününe çeker (31 Mart − 1 ay = 29 Şubat).
@warning_ignore("integer_division")
static func ay_ekle(metin: String, adet: int) -> String:
	var t := coz(metin)
	if t.is_empty():
		return metin
	var toplam: int = t.yil * 12 + (t.ay - 1) + adet
	var yil := toplam / 12
	var ay := toplam % 12 + 1
	return yaz(mini(t.gun, ay_gunu(ay, yil)), ay, yil)


## b − a (gün). Pozitifse b daha geç.
static func fark_gun(a: String, b: String) -> int:
	return gun_no(b) - gun_no(a)


static func haftanin_gunu(metin: String) -> String:
	return GUNLER[posmod(gun_no(metin), 7)]


## "09.01.1984" → "9 Ocak 1984 Pazartesi"
static func uzun(metin: String, gun_adi: bool = true) -> String:
	var t := coz(metin)
	if t.is_empty():
		return metin
	var s := "%d %s %d" % [t.gun, AYLAR[t.ay - 1], t.yil]
	return s + " " + haftanin_gunu(metin) if gun_adi else s


## Belge tarihi, bugünden en çok `ay` ay önce mi (ve gelecekte değil mi)?
static func ay_icinde_mi(belge_tarihi: String, bugun: String, ay: int) -> bool:
	var n := gun_no(belge_tarihi)
	return n != 0 and n <= gun_no(bugun) and n >= gun_no(ay_ekle(bugun, -ay))


## Belge tarihi, bugünden en çok `gun` gün önce mi (ve gelecekte değil mi)?
static func gun_icinde_mi(belge_tarihi: String, bugun: String, gun: int) -> bool:
	var n := gun_no(belge_tarihi)
	return n != 0 and n <= gun_no(bugun) and n >= gun_no(bugun) - gun
