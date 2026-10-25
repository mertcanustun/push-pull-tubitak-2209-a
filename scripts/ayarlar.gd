extends Node

## AUTOLOAD "Ayarlar" (Proje Ayarları → Globals → Autoload). Oyun boyunca
## tek olan durum burada:
##   - yazı ölçeği ve arayüz ölçeği (user://arayuz.cfg'ye kaydedilir)
##   - referanssız mod (doğru simülasyon gizli) — "student_build" özellik
##     etiketiyle dışa aktarılan sürümde ZORLA açık, ayar düğmesi gizli
##   - seçenek metinleri / son sorular / geri bildirimler (config/secenekler.json)
##   - öğrenci cevaplarının kaydı (user://cevaplar.csv)
##
## ÖĞRENCİ SÜRÜMÜ: Proje → Dışa Aktar → ön ayarı seç → Features → Custom
## alanına  student_build  yaz. O sürümde referans simülasyon hiç görünmez.

signal degisti

const DOSYA := "user://arayuz.cfg"
const OGRENCI_OZELLIGI := "student_build"
const SECENEK_DOSYASI := "res://config/secenekler.json"
const CEVAP_DOSYASI := "user://cevaplar.csv"
## Yazı boyutu adımları (Ayarlar → Yazı boyutu, A− / A+)
const YAZI_ADIMLARI := [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5]
## Arayüz (her şey: düğme, boşluk, yazı) boyutu adımları
const ARAYUZ_ADIMLARI := [0.8, 0.9, 1.0, 1.1, 1.25, 1.4, 1.6]

var yazi_olcek := 1.0
var arayuz_olcek := 1.0
var _referanssiz := false
## config/secenekler.json içeriği (bkz. secenek_listesi()).
var veri: Dictionary = {}


func _ready() -> void:
	_oku()
	veri = _veri_oku()


# ------------------------------------------------------------------ yazı

## Taban (dp) yazı boyutunu yazı ölçeğiyle çarpar. Arayüzdeki TÜM yazı
## boyutları buradan geçer (Hud._boyut, Hud tema, BGosterimKamera).
func fs(taban: float) -> int:
	return maxi(roundi(taban * yazi_olcek), 6)


func yazi_olcek_adim(yon: int) -> void:
	yazi_olcek = _adim(YAZI_ADIMLARI, yazi_olcek, yon)
	_kaydet()
	degisti.emit()


func arayuz_olcek_adim(yon: int) -> void:
	arayuz_olcek = _adim(ARAYUZ_ADIMLARI, arayuz_olcek, yon)
	_kaydet()
	degisti.emit()


func _adim(adimlar: Array, simdiki: float, yon: int) -> float:
	var i := 0
	var en_yakin := INF
	for k in adimlar.size():
		var d := absf(float(adimlar[k]) - simdiki)
		if d < en_yakin:
			en_yakin = d
			i = k
	return adimlar[clampi(i + yon, 0, adimlar.size() - 1)]


# ------------------------------------------------------------ referanssız mod

## Referans (doğru fizik, sol taraf) gizli mi?
func referanssiz() -> bool:
	return referanssiz_zorunlu() or _referanssiz


## Öğrenci sürümünde mod zorla açık; ayarlardaki onay kutusu gizlenir.
func referanssiz_zorunlu() -> bool:
	return OS.has_feature(OGRENCI_OZELLIGI)


func referanssiz_ayarla(on: bool) -> void:
	if on == _referanssiz:
		return
	_referanssiz = on
	_kaydet()
	degisti.emit()


# ------------------------------------------------------------------ dosya

func _oku() -> void:
	var c := ConfigFile.new()
	if c.load(DOSYA) != OK:
		return
	arayuz_olcek = clampf(float(c.get_value("arayuz", "olcek", 1.0)), 0.5, 2.0)
	yazi_olcek = clampf(float(c.get_value("arayuz", "yazi_olcek", 1.0)), 0.5, 1.5)
	_referanssiz = bool(c.get_value("mod", "referanssiz", false))


func _kaydet() -> void:
	var c := ConfigFile.new()
	c.load(DOSYA)   # başka anahtarlar silinmesin
	c.set_value("arayuz", "olcek", arayuz_olcek)
	c.set_value("arayuz", "yazi_olcek", yazi_olcek)
	c.set_value("mod", "referanssiz", _referanssiz)
	c.save(DOSYA)


# ------------------------------------------------------- seçenek verisi

func _veri_oku() -> Dictionary:
	var metin := FileAccess.get_file_as_string(SECENEK_DOSYASI)
	var d = JSON.parse_string(metin) if metin != "" else null
	if not (d is Dictionary) or not (d.get("secenekler") is Array):
		push_error("%s okunamadı ya da bozuk (JSON sözdizimini kontrol et)." % SECENEK_DOSYASI)
		return {"secenekler": []}
	return d


## [{id, harf, metin, davranis, oklari_gizle, son_soru, geri_bildirim}, ...]
func secenek_listesi() -> Array:
	return veri.get("secenekler", [])


func secenek(id: String) -> Dictionary:
	for s in secenek_listesi():
		if s.get("id", "") == id:
			return s
	return {}


func metin(anahtar: String, varsayilan: String = "") -> String:
	return str(veri.get(anahtar, varsayilan))


# ------------------------------------------------------- cevap kaydı

## Öğrencinin son soruya yazdığı cevabı user://cevaplar.csv'ye ekler
## (Excel / LibreOffice ile açılır; UTF-8). Sütunlar:
##   zaman, mod, secenek, secenek_metni, soru, cevap
func cevap_kaydet(secenek_id: String, secenek_metni: String, soru: String, cevap: String) -> void:
	var yeni := not FileAccess.file_exists(CEVAP_DOSYASI)
	var f := FileAccess.open(CEVAP_DOSYASI, FileAccess.WRITE if yeni else FileAccess.READ_WRITE)
	if f == null:
		push_error("Cevap kaydedilemedi: %s (%s)" % [CEVAP_DOSYASI, error_string(FileAccess.get_open_error())])
		return
	if yeni:
		f.store_string("﻿")   # Excel UTF-8'i tanısın (Türkçe karakterler)
		f.store_csv_line(PackedStringArray(["zaman", "mod", "secenek", "secenek_metni", "soru", "cevap"]))
	else:
		f.seek_end()
	f.store_csv_line(PackedStringArray([
		Time.get_datetime_string_from_system(false, true),
		"referanssiz" if referanssiz() else "referansli",
		secenek_id, secenek_metni, soru, cevap,
	]))
	f.close()


## Kayıt dosyasının işletim sistemindeki yeri (masaüstünde).
func cevap_dosyasi_yolu() -> String:
	return ProjectSettings.globalize_path(CEVAP_DOSYASI)
