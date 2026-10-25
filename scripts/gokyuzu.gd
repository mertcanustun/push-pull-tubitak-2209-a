extends Node
class_name Gokyuzu

## Yükseklikle ATMOSFERDEN UZAYA geçiş. ZAMANA değil KAMERANIN YÜKSEKLİĞİNE
## bağlı: (b)'de kamera topu izleyip yükseldikçe arka plan rengi önce
## atmosfer mavisine, sonra uzay karasına döner, sis kalkar, yıldızlar belirir.
## Kamera ana pozuna dönünce her şey kendiliğinden eski haline gelir.
##
## Salonun duvarları ~9 m; geçiş duvarların üstünde başlar. Ayarlar sahnede
## Main/Gokyuzu düğümünün Inspector'ında. Performans testi için
## Main/Performans → "Gökyüzü geçişi" ile tamamen kapatılır.

@export_group("Bağlantılar")
@export var kamera_yolu: NodePath = ^"../Camera3D"
@export var ortam_yolu: NodePath = ^"../WorldEnvironment"

@export_group("Yükseklik (kamera, m)")
## Geçişin başladığı kamera yüksekliği. Salon duvarı 9 m.
@export_range(0.0, 100.0, 0.5, "suffix:m") var baslangic: float = 10.0
## Bu yükseklikte tamamen uzay (en koyu renk, tüm yıldızlar).
## (b) kamera takibinin üst sınırı Sim2Config → kamera_takip_max_yukseklik.
@export_range(10.0, 2000.0, 5.0, "suffix:m") var bitis: float = 180.0

@export_group("Renkler")
## Geçişin ortasındaki gökyüzü rengi (başlangıç rengi sahnedeki ortamın
## arka plan rengidir).
@export var atmosfer_rengi: Color = Color(0.16, 0.30, 0.56)
## Geçiş ilerlemesinde (0–1) atmosfer renginin en belirgin olduğu yer.
@export_range(0.05, 0.95, 0.01) var atmosfer_noktasi: float = 0.3
@export var uzay_rengi: Color = Color(0.0, 0.0, 0.012)
## Sis bu ilerlemede tamamen kalkar (sis yıldızları ve uzayı örtmesin).
@export_range(0.01, 1.0, 0.01) var sis_bitisi: float = 0.3

@export_group("Yıldızlar")
## Yıldızların görünmeye başladığı / tam parladığı ilerleme (0–1).
@export_range(0.0, 1.0, 0.01) var yildiz_baslangici: float = 0.3
@export_range(0.0, 1.0, 0.01) var yildiz_tam: float = 0.85
@export_range(0.0, 1.0, 0.01) var yildiz_parlakligi: float = 1.0

## Kapalıyken ortam sahnedeki haliyle kalır (Performans düğümü yazar).
var etkin := true:
	set(v):
		etkin = v
		_son_t = -1.0
		if is_node_ready():
			_uygula(_ilerleme() if v else 0.0)

var _kamera: Camera3D
var _env: Environment
var _taban_renk: Color
var _taban_sis := 0.0
var _taban_sis_renk: Color
var _yildiz: MeshInstance3D
var _mat: ShaderMaterial
var _son_t := -1.0


func _ready() -> void:
	_kamera = get_node_or_null(kamera_yolu)
	var we := get_node_or_null(ortam_yolu) as WorldEnvironment
	if _kamera == null or we == null or we.environment == null:
		push_warning("Gokyuzu: kamera ya da WorldEnvironment bulunamadı, geçiş kapalı.")
		set_process(false)
		return
	_env = we.environment
	_taban_renk = _env.background_color
	_taban_sis = _env.fog_density
	_taban_sis_renk = _env.fog_light_color

	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/yildizlar.gdshader")
	var kure := SphereMesh.new()
	kure.radius = 800.0
	kure.height = 1600.0
	kure.radial_segments = 32
	kure.rings = 16
	_yildiz = MeshInstance3D.new()
	_yildiz.name = "Yildizlar"
	_yildiz.mesh = kure
	_yildiz.material_override = _mat
	_yildiz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_yildiz.extra_cull_margin = 16384.0
	_yildiz.visible = false
	_kamera.add_child(_yildiz)
	_uygula(0.0)


func _process(_dt: float) -> void:
	if not etkin:
		return
	var t := _ilerleme()
	if absf(t - _son_t) > 0.0005 or (t == 0.0 and _son_t != 0.0):
		_uygula(t)


func _ilerleme() -> float:
	if _kamera == null:
		return 0.0
	var t := clampf((_kamera.global_position.y - baslangic) / maxf(bitis - baslangic, 0.01), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)   # smoothstep: iki uçta yumuşak


func _uygula(t: float) -> void:
	if _env == null:
		return
	_son_t = t
	var renk: Color
	if t <= atmosfer_noktasi:
		renk = _taban_renk.lerp(atmosfer_rengi, t / atmosfer_noktasi)
	else:
		renk = atmosfer_rengi.lerp(uzay_rengi, (t - atmosfer_noktasi) / (1.0 - atmosfer_noktasi))
	_env.background_color = renk
	var sis := clampf(1.0 - t / sis_bitisi, 0.0, 1.0)
	_env.fog_density = _taban_sis * sis
	_env.fog_light_color = _taban_sis_renk.lerp(renk, 1.0 - sis)
	var y := clampf((t - yildiz_baslangici) / maxf(yildiz_tam - yildiz_baslangici, 0.01), 0.0, 1.0)
	_mat.set_shader_parameter("yogunluk", y * yildiz_parlakligi)
	_yildiz.visible = y > 0.001


## Ölçüm/test: şu anki geçiş ilerlemesi (0 = salon, 1 = uzay).
func ilerleme() -> float:
	return maxf(_son_t, 0.0)
