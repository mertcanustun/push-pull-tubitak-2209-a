extends SceneTree

## ============================================================================
## SALONU TERMİNALDEN YENİDEN ÜRET
## ============================================================================
## config/ortam_ayarlari.tres'teki ayarlarla scenes/main.tscn'deki "Ortam"ı
## yeniden üretir ve kaydeder. Asıl kod: tools/ortam_uretici.gd.
## Ekip için kolay yol: Godot'da ortam_ayarlari.tres → "Salonu yeniden üret".
##
## Çalıştırma (proje kökünde, --headless OLMADAN — headless'ta parke ve
## seyirci örnekleri yazılmıyor):
##     godot --path . -s tools/build_environment.gd
##
## Tekrar çalıştırılabilir: yalnızca "Ortam" (ve eski GroundLeft/Right)
## değişir; "Ortam/ElleEklenenler" ve içindekiler olduğu gibi korunur.
## Aynı ayarlar + aynı SEED → birebir aynı salon.

func _initialize() -> void:
	var ayar: OrtamAyarlari = load(OrtamUretici.AYAR_PATH)
	if ayar == null:
		push_error("ayar dosyası yüklenemedi: " + OrtamUretici.AYAR_PATH)
		quit(1)
		return
	var msg := OrtamUretici.new().sahne_dosyasini_uret(ayar)
	print(msg)
	quit(0 if msg.begins_with("OK") else 1)
