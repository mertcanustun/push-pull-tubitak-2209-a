extends Node
class_name BGosterimKamera

## (b) seçeneğinde fırlayan topu kamerayla izler (Sim2Config → "(b) gösterimi").
## YALNIZCA görüntü: fiziğe dokunmaz. main.gd topu tepe noktasında durdurur
## ve notify_apex() çağırır; bu düğüm kamerayı yönetir.
##
## Durumlar:  BOS → TAKIP (kamera topa kilitli yükselir) → BEKLE (tepede) →
##            DONUS (ana kamera pozuna yumuşak dönüş; son karede BİREBİR aynı
##            transform) → BOS
##
## Süreler GERÇEK zamanla sayılır (Engine.time_scale'den etkilenmez), oyun
## duraklatılınca (is_running false) sayaçlar durur.

signal takip_sure_doldu   ## takip üst süresi tepeye varmadan doldu
signal donus_basladi      ## kamera ana poza dönmeye başladı

enum Durum { BOS, TAKIP, BEKLE, DONUS }

const BASLANGIC_GECISI := 0.12   # sn — kameranın topa kilitlenme geçişi
const KADRAJ_PAYI := -0.4        # m — top kadrajın biraz üstünde dursun

var durum: int = Durum.BOS

var _cfg: Sim2Config
var _cam: Camera3D
var _is_running: Callable
var _base: Transform3D
var _from: Transform3D
var _ball: Node3D
var _t := 0.0
var _max_cam_y := 0.0
var _markers: Array = []
var _layer: CanvasLayer
var _label: Label


func setup(cfg: Sim2Config, cam: Camera3D, is_running: Callable) -> void:
	_cfg = cfg
	_cam = cam
	_is_running = is_running
	_base = cam.global_transform
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color("ffd54a"))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.offset_top = 92
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.visible = false
	_layer.add_child(_label)


func is_following() -> bool:
	return durum == Durum.TAKIP

func is_active() -> bool:
	return durum != Durum.BOS


## Top ekrandan çıktığı anda main.gd çağırır.
func start_follow(ball: Node3D) -> void:
	_ball = ball
	_t = 0.0
	_max_cam_y = 0.0
	durum = Durum.TAKIP
	_build_markers()
	_label.visible = true


## Top tepe noktasına vardı (main.gd topu orada tutuyor).
func notify_apex(height_m: float) -> void:
	if durum != Durum.TAKIP:
		return
	durum = Durum.BEKLE
	_t = 0.0
	_label.text = "Tepe noktası: %.0f m" % height_m


func reset() -> void:
	durum = Durum.BOS
	_ball = null
	if _cam:
		_cam.global_transform = _base
	_clear_markers()
	if _label:
		_label.visible = false


func _process(delta: float) -> void:
	if durum == Durum.BOS:
		return
	# gerçek zaman: Engine.time_scale (ağır çekim) bu süreleri uzatmasın
	var real_dt := delta / maxf(Engine.time_scale, 1e-6)
	var running: bool = _is_running.call()
	match durum:
		Durum.TAKIP:
			if running:
				_t += real_dt
			var h := _ball.global_position.y
			var target := _base
			var rise: float = clampf(h - _base.origin.y - KADRAJ_PAYI, 0.0, _cfg.kamera_takip_max_yukseklik)
			target.origin += Vector3(_ball.global_position.x * 0.9, rise, 0.0)
			var w := clampf(_t / BASLANGIC_GECISI, 0.0, 1.0)
			_cam.global_transform = _base.interpolate_with(target, w)
			_max_cam_y = maxf(_max_cam_y, _cam.global_position.y)
			_label.text = "Sağdaki top: %.0f m  ↑" % maxf(h - 0.119, 0.0)
			if _t >= _cfg.kamera_takip_suresi:
				durum = Durum.BEKLE
				_t = 0.0
				takip_sure_doldu.emit()
		Durum.BEKLE:
			if running:
				_t += real_dt
			if _t >= _cfg.kamera_tepe_bekleme:
				durum = Durum.DONUS
				_t = 0.0
				_from = _cam.global_transform
				donus_basladi.emit()
		Durum.DONUS:
			_t += real_dt
			var u := clampf(_t / maxf(_cfg.kamera_donus_suresi, 0.01), 0.0, 1.0)
			u = u * u * (3.0 - 2.0 * u)   # smoothstep
			_cam.global_transform = _from.interpolate_with(_base, u)
			if u >= 1.0:
				# son karede BİREBİR ana kamera pozu (yuvarlama kalıntısı olmasın)
				_cam.global_transform = _base
				durum = Durum.BOS
				_clear_markers()
				_label.visible = false


## Ölçüm/test için: takip boyunca kameranın çıktığı en yüksek konum.
func max_camera_height() -> float:
	return _max_cam_y

func base_transform() -> Transform3D:
	return _base


func _build_markers() -> void:
	# Topun yanında dikey bir CETVEL: çizgi + her 1 m'de çentik + her
	# yukseklik_isaret_araligi'nde (varsayılan 5 m) etiket. Kadraj dikeyde
	# yalnızca ~5 m gösterdiği için seyrek işaretler çoğu an görünmüyordu;
	# sık çentikler hem yüksekliği hem (akarken) hızı hissettirir.
	_clear_markers()
	# Topun SOLUNDA: kuvvet okları topun sağına dizildiği için (bkz. main.gd
	# _set_arrow) sağda cetvel okların üstünden geçiyordu.
	var x: float = _ball.global_position.x - 0.9
	var top: float = _cfg.kamera_takip_max_yukseklik + 10.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.75)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, top, 0.025)
	bar.mesh = bm
	bar.material_override = mat
	bar.position = Vector3(x, top * 0.5, 0.0)
	add_child(bar)
	_markers.append(bar)

	var label_step: float = maxf(_cfg.yukseklik_isaret_araligi, 1.0)
	var n := int(top)
	var tick := BoxMesh.new()
	tick.size = Vector3(0.12, 0.02, 0.02)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tick
	mm.instance_count = n
	for i in n:
		var h := float(i + 1)
		var long := is_zero_approx(fmod(h, label_step))
		var sx := 2.2 if long else 1.0
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(sx, 1, 1)),
			Vector3(x - 0.06 * sx, h, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	_markers.append(mmi)

	var h2 := label_step
	while h2 <= top:
		var l := Label3D.new()
		l.text = "%d m" % int(h2)
		l.font_size = 48
		l.pixel_size = 0.004
		l.outline_size = 10
		l.modulate = Color(1, 1, 1, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.position = Vector3(x - 0.35, h2, 0.0)
		add_child(l)
		_markers.append(l)
		h2 += label_step


func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
