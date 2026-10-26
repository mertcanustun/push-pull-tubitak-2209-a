extends Node

## AUTOLOAD "Kayit" (Proje Ayarları → Globals → Autoload). Olayları
## (seçim, cevap, sıfırlama) Vercel'deki /api/log uç noktasına gönderir.
## Kayıtlar Redis'te tutulur; öğretmen hepsini CSV olarak indirir:
##   https://<site>.vercel.app/api/export?anahtar=<LOG_ADMIN_KEY>
##
## Web sürümünde adres sayfanın kendi kökeninden kurulur (aynı site, ayar
## gerekmez). Masaüstünde MASAUSTU_ADRES boşsa hiçbir şey gönderilmez;
## yerel CSV (Ayarlar.cevap_kaydet) her durumda yazılmaya devam eder.
##
## Gönderilemeyen olay kuyrukta kalır ve YENIDEN_DENEME saniye sonra tekrar
## denenir; oyun hiçbir zaman beklemez.

## Masaüstü sürümünün göndereceği tam adres, ör.
## "https://push-pull-tubitak-2209-a-on-vercel.vercel.app/api/log"
const MASAUSTU_ADRES := ""
const YOL := "/api/log"
const YENIDEN_DENEME := 5.0
const MAKS_KUYRUK := 200

var _adres := ""
var _oturum := ""
var _kuyruk: Array[Dictionary] = []
var _istek: HTTPRequest
var _mesgul := false


func _ready() -> void:
	_adres = _adres_bul()
	if _adres == "":
		return
	_oturum = "%x-%x" % [int(Time.get_unix_time_from_system() * 1000.0), randi()]
	_istek = HTTPRequest.new()
	_istek.timeout = 10.0
	_istek.request_completed.connect(_tamamlandi)
	add_child(_istek)
	olay("oturum_basladi")


func _adres_bul() -> String:
	if OS.has_feature("web"):
		var koken = JavaScriptBridge.eval("window.location.origin", true)
		# file:// ile açılan yerel denemelerde köken "null" olur
		if koken is String and koken.begins_with("http"):
			return koken + YOL
		return ""
	return MASAUSTU_ADRES


## Bir olay gönderir. alanlar: secenek, secenek_metni, soru, cevap.
func olay(ad: String, alanlar: Dictionary = {}) -> void:
	if _adres == "":
		return
	var d := alanlar.duplicate()
	d["olay"] = ad
	d["oturum"] = _oturum
	d["mod"] = "referanssiz" if Ayarlar.referanssiz() else "referansli"
	d["istemci_zamani"] = Time.get_datetime_string_from_system(false, true)
	if _kuyruk.size() >= MAKS_KUYRUK:
		_kuyruk.pop_front()   # sunucu uzun süre yoksa en eskisi düşer
	_kuyruk.append(d)
	_gonder()


func _gonder() -> void:
	if _mesgul or _kuyruk.is_empty():
		return
	_mesgul = true
	var hata := _istek.request(_adres, ["Content-Type: application/json"],
		HTTPClient.METHOD_POST, JSON.stringify(_kuyruk[0]))
	if hata != OK:
		_tamamlandi(HTTPRequest.RESULT_CANT_CONNECT, 0, [], [])


func _tamamlandi(sonuc: int, kod: int, _basliklar: PackedStringArray, _govde: PackedByteArray) -> void:
	_mesgul = false
	if sonuc == HTTPRequest.RESULT_SUCCESS and kod >= 200 and kod < 300:
		_kuyruk.pop_front()
		_gonder()
	elif sonuc == HTTPRequest.RESULT_SUCCESS and kod >= 400 and kod < 500:
		# Sunucu olayı reddetti (geçersiz): tekrar denemek işe yaramaz
		push_warning("Kayıt reddedildi (HTTP %d): %s" % [kod, _kuyruk[0].get("olay", "")])
		_kuyruk.pop_front()
		_gonder()
	else:
		get_tree().create_timer(YENIDEN_DENEME).timeout.connect(_gonder)
