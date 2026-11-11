class_name Islemler
extends RefCounted
## Gişede yapılan işlem türleri: görünen adları ve vatandaşın ağzından nasıl söylendiği.

const TABLO := {
	"kayit_ornegi": {
		"ad": "Nüfus kayıt örneği",
		"talep": ["Nüfus kayıt örneği alacaktım.", "Bir nüfus kayıt örneği lazım oldu.",
			"Kayıt örneği çıkartacaktım."],
	},
	"cuzdan_yenileme": {
		"ad": "Cüzdan yenileme",
		"talep": ["Cüzdanımı yenileyecektim.", "Nüfus cüzdanım eskidi, yenisini çıkartacağım.",
			"Cüzdan yenileme için gelmiştim."],
	},
	"nakil": {
		"ad": "Adres nakli",
		"talep": ["Adres naklimi yaptıracaktım.", "Taşındık, kaydımı buraya aldıracağım.",
			"Nakil işlemi için geldim."],
	},
}


static func adi(anahtar: String) -> String:
	return str((TABLO.get(anahtar, {}) as Dictionary).get("ad", anahtar))


static func talepler(anahtar: String) -> Array:
	return (TABLO.get(anahtar, {}) as Dictionary).get("talep", ["İşlem yaptıracaktım."])
