extends Node
class_name PerformansDenetimi

## YAVAŞLAMA AVI: şüpheli efekt/sistemleri tek tek açıp kapatmak için.
## Sahnede Main/Performans düğümü — Inspector'dan (oyun çalışırken "Remote"
## sekmesinden de) ya da oyun içinde Ayarlar → "Geliştirici" bölümünden.
## Oyun içi değişiklikler kaydedilmez; varsayılanlar buradaki değerlerdir.
##
## Önerilen yöntem: FPS + Ayrıntı'yı aç, birkaç koşu yap (Başlat → seç →
## Sıfırla). Düşüş görürsen şüphelileri birer birer kapat. "Yetim düğüm"
## sayısı koşudan koşuya artıyorsa bir şey serbest bırakılmıyor demektir.

signal degisti

@export_group("Gösterge")
## Sağ üstte FPS.
@export var fps_goster := false:
	set(v): fps_goster = v; _degisti()
## FPS'in yanında çizim çağrısı, nesne, düğüm ve yetim düğüm sayısı.
@export var ayrinti_goster := false:
	set(v): ayrinti_goster = v; _degisti()

@export_group("Efektler")
## Topların çarpma tozu (GPUParticles3D).
@export var toz_parcaciklari := true:
	set(v): toz_parcaciklari = v; _degisti()
## Çarpma sesi.
@export var carpma_sesi := true:
	set(v): carpma_sesi = v; _degisti()
## Parlama (glow) — tam ekran son işlem.
@export var parlama := true:
	set(v): parlama = v; _degisti()
## Sis — tam ekran.
@export var sis := true:
	set(v): sis = v; _degisti()
## MSAA 3B + FXAA kenar yumuşatma.
@export var kenar_yumusatma := true:
	set(v): kenar_yumusatma = v; _degisti()
## Yükseklikle atmosfer → uzay geçişi ve yıldızlar (Main/Gokyuzu).
@export var gokyuzu_gecisi := true:
	set(v): gokyuzu_gecisi = v; _degisti()

@export_group("Işıklar")
## Salonun 3 tavan ışığı (OmniLight3D).
@export var tavan_isiklari := true:
	set(v): tavan_isiklari = v; _degisti()
## Güneş (DirectionalLight3D).
@export var gunes := true:
	set(v): gunes = v; _degisti()
## EK AYDINLATMA (isteğe bağlı, varsayılan KAPALI): güneş gölgeleri.
@export var gunes_golgesi := false:
	set(v): gunes_golgesi = v; _degisti()
## EK AYDINLATMA (isteğe bağlı, varsayılan KAPALI): SSAO köşe gölgelenmesi.
## Yalnızca Forward+ (masaüstü); web'de etkisiz.
@export var ssao := false:
	set(v): ssao = v; _degisti()

@export_group("Sahne / her kare yapılan işler")
## Bütün basketbol salonu (parke, tribün, seyirci, duvarlar).
@export var salon := true:
	set(v): salon = v; _degisti()
## Kuvvet okları (12 ok + 3B etiketler, her fizik adımında güncellenir).
@export var kuvvet_oklari := true:
	set(v): kuvvet_oklari = v; _degisti()
## (b) kamera takibindeki yükseklik cetveli (çentikler + 3B etiketler).
@export var b_cetveli := false:
	set(v): b_cetveli = v; _degisti()
## Godot Melez: her sekmede konsola "temas bitti" satırı (web'de konsol yavaş).
@export var temas_logu := true:
	set(v): temas_logu = v; _degisti()

## Oyun içi Ayarlar → Geliştirici bölümündeki onay kutuları: [özellik, yazı]
const ANAHTARLAR := [
	["fps_goster", "FPS göstergesi"],
	["ayrinti_goster", "Çizim / düğüm sayıları"],
	["toz_parcaciklari", "Toz parçacıkları"],
	["carpma_sesi", "Çarpma sesi"],
	["parlama", "Parlama (glow)"],
	["sis", "Sis"],
	["kenar_yumusatma", "Kenar yumuşatma"],
	["gokyuzu_gecisi", "Gökyüzü geçişi"],
	["tavan_isiklari", "Tavan ışıkları"],
	["gunes", "Güneş"],
	["gunes_golgesi", "Güneş gölgesi (ek ışık)"],
	["ssao", "SSAO (ek ışık)"],
	["salon", "Salon modeli"],
	["kuvvet_oklari", "Kuvvet okları"],
	["b_cetveli", "(b) yükseklik cetveli"],
	["temas_logu", "Temas konsol çıktısı"],
]

var _env: Environment
var _katman: CanvasLayer
var _etiket: Label
var _sayac := 0.0
var _taban := {}


func _ready() -> void:
	var we := get_node_or_null(^"../WorldEnvironment") as WorldEnvironment
	if we:
		_env = we.environment
	var vp := get_viewport()
	_taban = {
		"msaa": vp.msaa_3d,
		"ssaa": vp.screen_space_aa,
		"glow": _env.glow_enabled if _env else false,
		"fog": _env.fog_enabled if _env else false,
	}
	_katman = CanvasLayer.new()
	_katman.layer = 80   # Ayarlar (100) ve soru penceresi (90) bunun üstünde
	add_child(_katman)
	_etiket = Label.new()
	_etiket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_etiket.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_etiket.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_etiket.offset_top = 4
	_etiket.offset_right = -6
	_etiket.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_etiket.add_theme_font_size_override("font_size", 14)
	_etiket.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_etiket.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_etiket.add_theme_constant_override("outline_size", 5)
	_katman.add_child(_etiket)
	uygula()


func _degisti() -> void:
	if is_node_ready():
		uygula()
		degisti.emit()


func uygula() -> void:
	var main := get_parent()
	if _env:
		_env.glow_enabled = _taban["glow"] and parlama
		_env.fog_enabled = _taban["fog"] and sis
		_env.ssao_enabled = ssao
	var vp := get_viewport()
	vp.msaa_3d = _taban["msaa"] if kenar_yumusatma else Viewport.MSAA_DISABLED
	vp.screen_space_aa = _taban["ssaa"] if kenar_yumusatma else Viewport.SCREEN_SPACE_AA_DISABLED
	var g := main.get_node_or_null(^"Gokyuzu") as Gokyuzu
	if g:
		g.etkin = gokyuzu_gecisi
	var tavan := main.get_node_or_null(^"Ortam/TavanIsiklari") as Node3D
	if tavan:
		tavan.visible = tavan_isiklari
	var sun := main.get_node_or_null(^"Sun") as DirectionalLight3D
	if sun:
		sun.visible = gunes
		sun.shadow_enabled = gunes_golgesi
	var ortam := main.get_node_or_null(^"Ortam") as Node3D
	if ortam:
		ortam.visible = salon
	for yol in [^"TopSol", ^"TopSag"]:
		var b := main.get_node_or_null(yol) as Ball
		if b:
			b.toz_acik = toz_parcaciklari
			b.ses_acik = carpma_sesi
	GodotBackend.temas_logu = temas_logu
	_katman.visible = fps_goster or ayrinti_goster
	_sayac = 1.0


func _process(dt: float) -> void:
	if not _katman.visible:
		return
	_sayac += dt / maxf(Engine.time_scale, 1e-6)   # ağır çekimde de gerçek zamanla
	if _sayac < 0.25:
		return
	_sayac = 0.0
	var t := ""
	if fps_goster:
		t = "FPS %d" % Engine.get_frames_per_second()
	if ayrinti_goster:
		t += "\nçizim %d   nesne(3B) %d\ndüğüm %d   yetim %d   obje %d" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
			Performance.get_monitor(Performance.OBJECT_COUNT),
		]
	_etiket.text = t.strip_edges()
