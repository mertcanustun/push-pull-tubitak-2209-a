extends Node3D

## Etki-tepki (Newton 3) kavram yanilgisi simulasyonu.
##
## Sahne ikiye bolunur:
##   SOL  - MuJoCo/fizik motoru her seyi cozer, carpisma dahil. Gercek davranis.
##   SAG  - Yercekimi ve hava surtunmesi isler, CARPISMA cozulmez.
##          Top zemine degdigi an sim durur, ogrenci zemin tepkisini secer.
##
## Secenekler (metinler, son sorular, geri bildirimler: config/secenekler.tres,
## Inspector'dan).
## Her secenegin bir "davranis"i var — sagdaki topun ne yapacagi:
##   a) yukari F            -> sol tarafla birebir ayni gorsel (dogru)
##   b) yukari 100·F        -> top firlar (zemin "daha buyuk" kuvvet uygular yanilgisi)
##   c) yukari F + asagi F  -> top durur ("etki ve tepki topun uzerinde birbirini goturur" yanilgisi)
##   d) davranis c, ama "oklari_gizle": top durur, ustunde HIC kuvvet oku yok
##      ("kuvvet zemine tepki olarak gecer" yanilgisi)
##
## Referanssiz mod (Ayarlar autoload'u): sol top ve paneli gizlenir; sol
## fizik yine de calisir (a secenegi kuvvetini ondan aliyor).
##
## Kosu sonu: secimden cfg.kosu_sonu_bekleme saniye sonra (her durumda; b'de
## kamera takibi surse bile) "En yuksek" rekoru ve secenegin son sorusu gosterilir.
##
## Gorunum (Sim2Config → Görünüm): baslik, SOL/SAG panelleri, geri bildirim,
## cetveller, ok degerleri, secimden sonra agir cekim — hepsi Inspector'dan.

## Kütle/yarıçap/sekme/hava/temas/b-çarpanı/ok-ölçeği/ağır-çekim/ekrandan-çıkış
## artık burada SABİT DEĞİL — res://config/sim2_config.tres içinde (kod
## yazmadan Inspector'dan, hatta oyun ÇALIŞIRKEN "Remote" sekmesinden
## değiştirilir). Bkz. scripts/sim2_config.gd.
@export_group("Ayarlar")
## Tüm simülasyon ayarları (config/sim2_config.tres). Oyun çalışırken Remote
## sekmesinde buradan canlı değiştirilebilir.
@export var cfg: Sim2Config = preload("res://config/sim2_config.tres")

const DROP_HEIGHT := 3.0
const HALF_X := 1.8
const GROUND_Y := 0.0
const TOOL_N_PER_M := 40.0

enum Phase { READY, FALLING, CHOICE, RESOLVED }

var backend: PhysicsBackend
## cfg.backend'in son bilinen değeri — yalnızca FİZİK MOTORU değişince
## otomatik reset_sim() tetiklemek için (bkz. _on_cfg_changed).
var _last_backend: int = -1
var phase: int = Phase.READY
var running := false
var user_speed := 1.0
var tool_active := false
var choice := ""
var f_real := 0.0
var v_impact := 0.0
## Kalan impuls (N*s). Kuvvet SURE ile degil IMPULS ile verilir: aksi halde
## son kismi adim yuzunden her ziplamada fazladan enerji birikiyordu.
var impulse_left := 0.0
var impulse_force := 0.0
## Godot Melez: impuls bitince dis kuvvet bir SONRAKI tikte sifirlanir.
var _zero_ext_next := false
## (b) gosterimi (cfg "(b) gösterimi"): secim anindaki mod, firlatma agir
## cekimi aktif mi, top ekrandan cikti mi, kamera takibi.
var _b_mode: int = Sim2Config.BGosterim.HICBIRI
var _launch_slow := false
var _launch_elapsed := 0.0
var _b_escaped := false
var _bcam: BGosterimKamera
## Kamera sag topu izlerken sol top kadraj disinda. Sekmeye devam ederse her
## yere yaklasisinda kuresel agir cekim (0.05) devreye girer ve sag top havada
## ~1 sn asili kalir. Bu yuzden takip boyunca sol top OLDUGU YERDE, hiziyla
## birlikte dondurulur; kamera donmeye baslayinca kaldigi yerden devam eder.
## Yorunge degismez, yalnizca zamanda kayar (iki top birbirinden bagimsiz).
var _left_frozen := false
var _left_freeze_pos := Vector3.ZERO
var _left_freeze_vel := Vector3.ZERO
var _applied_f := 0.0
## Top sabitlendi mi ((c) secenegi ya da ekran disi)
var hold_right := false
var hold_pos := Vector3.ZERO
## (c) secenegindeki zit ok ciftini goster
var show_pair := false
## Temas tetigi hazir mi (top zeminden ayrildiktan sonra kurulur)
var right_armed := true
## (a) secenegi: sagdaki topa her adimda, soldaki topun zeminden aldigi
## kuvvetin BIREBIR aynisi uygulanir ("zemin topa, topun ona uyguladigi
## kuvvete esit kuvvetle karsilik verir"). Iki top ayni yukseklikten, ayni
## yercekimi ve hava direnciyle dustugu icin yorungeleri ayni olur.
## (Eskiden sagdaki top bekletilip tahmini bir impuls veriliyordu; yercekimi
## hesaba katilmadigi ve e yanlis olculdugu icin her sekmede kayiyordu.)
var _mirror_a := false
var _mirror_native := false   # arka uc aynalamayi kendisi yapiyor mu
var left_enter_speed := 0.0

var arrow_on := {
	"gravity": true, "drag": true, "contact": true,
	"external": true, "net": false, "net_minus_g": false,
}

var balls := {}          # "left"/"right" -> Ball (sahnedeki TopSol / TopSag)
var hud: Hud
## Main/Performans: yavaslama avi icin efekt anahtarlari (bkz. performans.gd)
var perf: PerformansDenetimi
## Secilen secenegin davranisi (a/b/c) — choice ise secenek id'si (a/b/c/d).
var _davranis := ""
## Secenek "oklari_gizle": sagdaki topta hic kuvvet oku gosterme (d).
var _oklari_gizle := false
## Kosu sonu: secimden beri gecen gercek sure, bitti mi, sagdaki topun
## secimden sonra ulastigi en yuksek nokta (m, topun alti).
var _kosu_sure := 0.0
var _kosu_bitti := false
var _en_yuksek := 0.0
var camera: Camera3D
## Sahnedeki sabit 1/2/3 m cetvelleri (Ruler*) — Sim2Config → cetveller.
var _cetveller: Array[Node3D] = []
## Gorunum: son uygulanan cetvel durumu (her karede node gezmemek icin).
var _cetvel_acik := true
## Godot Melez: secimden sonraki temaslar ag. cekimsiz ama ayni kucuk fizik
## adimiyla (bkz. _physics_process_engine). Proje varsayilani saklanir.
var _varsayilan_max_adim := 8
var drag_ball := ""
var drag_origin := Vector3.ZERO
var drag_arrow: ForceArrow


func _ready() -> void:
	# Sabit dekor (ortam, gunes, kamera, zemin, ayirici, cetveller) artik
	# scenes/main.tscn icinde gercek node olarak duruyor - editorden duzenlenir.
	# Burada sadece sahneden kameraya referans aliyor ve dinamik surukleme
	# okunu kuruyoruz.
	camera = $Camera3D
	_fov_16_9 = camera.fov
	_kamera_ilk = camera.global_transform
	_kamera_taban = _kamera_ilk
	_varsayilan_max_adim = Engine.max_physics_steps_per_frame
	for n in get_children():
		if n is Node3D and n.name.begins_with("Ruler"):
			_cetveller.append(n)
	get_viewport().size_changed.connect(_kamerayi_uydur)
	_kamerayi_uydur()
	_bcam = BGosterimKamera.new()
	_bcam.name = "BGosterimKamera"
	add_child(_bcam)
	_bcam.setup(cfg, camera, func() -> bool: return running)
	_bcam.takip_sure_doldu.connect(_on_follow_timeout)
	_bcam.donus_basladi.connect(_unfreeze_left)
	drag_arrow = ForceArrow.new(Color(1.0, 1.0, 1.0), "surukle")
	add_child(drag_arrow)
	perf = $Performans
	_build_hud()
	hud.gelistirici_kur(perf)
	_build_balls()     # önce toplar: Godot Melez motoru bu node'ları kullanıyor
	_build_backend()
	_gorunum_uygula()
	reset_sim()
	_last_backend = cfg.backend
	cfg.changed.connect(_on_cfg_changed)


## cfg Inspector'dan ya da ÇALIŞIRKEN "Remote" sekmesinden değişince tetiklenir.
## Fizik Motoru değiştiyse otomatik _build_backend()+reset_sim() yapılır.
## Kütle/sekme/hava/sertlik gibi alanlar bir sonraki Sıfırla/R basışında
## işler (reset_sim() spec'leri cfg'den tazeler). MuJoCo'nun KENDİ fiziği
## yine mujoco/scene.xml'den okunur (bkz. sim2_config.gd başı).
func _on_cfg_changed() -> void:
	if cfg.backend != _last_backend:
		_last_backend = cfg.backend
		_build_backend()
		reset_sim()


# ------------------------------------------------------------------ kurulum

## Sahne 16:9 icin kadrajlandi (fov 54, KEEP_HEIGHT). Arayuz panelleri
## ekranin bir kismini kapliyor (Hud.sahne_payi_degisti); "aksiyon kutusu"
## (iki top, birakilma yuksekliginden zemine + oklar) her ekran oraninda
## panellerin disinda kalan alana sigsin diye:
##   - gerekirse goruntu acisi buyutulur (asla 16:9'dakinden dar olmaz),
##   - dikey telefonda bos alan ekranin ust kismindaysa goruntu, perspektifi
##     bozmadan (lens kaydirma = FRUSTUM ofseti) oraya kaydirilir.
## Genis ekranda (paneller kenarda kaldiginda) eski kadraj aynen korunur.
const KUTU_X := HALF_X + 0.3          # top + sola/saga tasan ok etiketleri
const KUTU_TEK_X := 1.2               # referanssiz: tek top + oklari (merkezden)
const KUTU_ALT := GROUND_Y - 0.5      # zemindeki topun altina inen oklar
const KUTU_UST := DROP_HEIGHT + 0.35
var _fov_16_9 := 54.0
var _kamera_ilk: Transform3D     # sahnedeki kamera (iki topun ortasi)
var _kamera_taban: Transform3D   # su anki ana poz (referanssizda sag topa kayik)
var _sahne_payi := Vector4.ZERO       # sol, sag, ust, alt (ekran orani)

func _sahne_payi_degisti(sol: float, sag: float, ust: float, alt: float) -> void:
	_sahne_payi = Vector4(sol, sag, ust, alt)
	_kamerayi_uydur()

func _kamerayi_uydur() -> void:
	var s := get_viewport().get_visible_rect().size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var a := s.x / s.y
	var t := tan(deg_to_rad(_fov_16_9) * 0.5)   # dikey yari-aci tanjanti
	# ndc bantlari (-1..1): panellerin disinda kalan alan
	var bx := maxf(1.0 - 2.0 * maxf(_sahne_payi.x, _sahne_payi.y), 0.3)
	var b_ust := 1.0 - 2.0 * _sahne_payi.z
	var b_alt := -1.0 + 2.0 * _sahne_payi.w
	if b_ust - b_alt < 0.4:
		b_ust = 1.0
		b_alt = -1.0
	var ters := _kamera_taban.affine_inverse()
	var umin := INF
	var umax := -INF
	# Referanssiz modda tek top var: kutu o topun etrafinda (kamera ona kayik)
	var cx := _kamera_taban.origin.x
	var kutu: Array = [cx - KUTU_TEK_X, cx + KUTU_TEK_X] if Ayarlar.referanssiz() else [-KUTU_X, KUTU_X]
	for x in kutu:
		for y in [KUTU_ALT, KUTU_UST]:
			var p: Vector3 = ters * Vector3(x, y, 0.0)
			var d := -p.z
			t = maxf(t, absf(p.x / d) / (a * bx))
			umin = minf(umin, p.y / d)
			umax = maxf(umax, p.y / d)
	# kaydirmadan sigdirmak icin gereken aci ...
	var t_duz := t
	if umax > 0.0 and b_ust > 0.0:
		t_duz = maxf(t_duz, umax / b_ust)
	if umin < 0.0 and b_alt < 0.0:
		t_duz = maxf(t_duz, umin / b_alt)
	if b_ust <= 0.0 or b_alt >= 0.0:
		t_duz = INF
	# ... ve lens kaydirarak gereken aci
	var t_kay := maxf(t, (umax - umin) / (b_ust - b_alt))
	var merkez := 0.0   # frustum merkezinin dikey kaymasi (tanjant cinsinden)
	if t_kay < t_duz * 0.98:
		t = t_kay
		merkez = (umax + umin) * 0.5 - (b_ust + b_alt) * 0.5 * t
	else:
		t = t_duz
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.size = 2.0 * camera.near * t
	camera.frustum_offset = Vector2(0.0, merkez * camera.near)



func _build_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.start_pressed.connect(_on_start)
	hud.reset_pressed.connect(reset_sim)
	hud.speed_changed.connect(func(v: float): user_speed = v)
	hud.arrow_toggled.connect(func(key: String, on: bool): arrow_on[key] = on)
	hud.tool_toggled.connect(func(on: bool): tool_active = on)
	hud.choice_made.connect(_on_choice)
	hud.sahne_payi_degisti.connect(_sahne_payi_degisti)
	hud.ust_serbest_degisti.connect(func(y: float): _bcam.etiket_ust_ayarla(y))
	hud.soru_kapandi.connect(_on_soru_kapandi)
	hud.referanssiz_degisti.connect(func(_on: bool): reset_sim())


## Hangi fizik arka ucu kullanilsin: cfg.backend'den okunur (Inspector/Remote).
##   MUJOCO        - MuJoCo'yu zorla (yoksa GDScript cozucuye duser, uyari basar)
##   YEDEK_COZUCU  - MuJoCo derlenmis olsa bile GDScript cozucuyu kullan
##   GODOT_MELEZ   - ucus Godot fiziginde, temas + hava bizim modelimiz
##                   (scripts/godot_backend.gd)
func _build_backend() -> void:
	if backend:
		backend.shutdown()   # onceki motorun global ayarlarini (time_scale vb.) geri al
	match cfg.backend:
		Sim2Config.Backend.YEDEK_COZUCU:
			backend = NativeBackend.new()
		Sim2Config.Backend.GODOT_MELEZ:
			backend = GodotBackend.new(cfg, {"left": $TopSol, "right": $TopSag})
		_:  # Sim2Config.Backend.MUJOCO
			var mj := MuJoCoBackend.new()
			if mj.initialize():
				backend = mj
			else:
				backend = NativeBackend.new()
				push_warning("MuJoCo kullanılamadı: %s" % mj.get_error())

	for side in ["left", "right"]:
		var spec := PhysicsBackend.BodySpec.new(side)
		_fill_spec(spec)
		spec.position = Vector3(-HALF_X if side == "left" else HALF_X, DROP_HEIGHT, 0.0)
		# Senaryo planinin can alici noktasi: sagda carpisma KAPALI,
		# yercekimi ve hava surtunmesi ACIK.
		spec.collisions_enabled = (side == "left")
		backend.add_body(spec)

	# MuJoCo / Yedek Cozucu: top KUKLA (Godot fizigi kapali, konum backend'den).
	# Godot Melez: top SERBEST (Godot fizigi isler).
	for side in balls:
		(balls[side] as Ball).set_puppet(not backend.engine_driven())


## Top/Hava/Temas ayarlari: TEK KAYNAK Sim2Config. _build_backend() ve her
## reset_sim() bunu cagirir; backend reset'te spec'ten yeniden kurar (Godot
## Melez'de RigidBody'nin Mass/Damp alanlari dahil).
func _fill_spec(spec: PhysicsBackend.BodySpec) -> void:
	spec.mass = cfg.mass
	spec.radius = cfg.radius
	spec.restitution = cfg.restitution
	spec.drag_coefficient = cfg.drag_cd
	spec.air_density = cfg.hava_yogunlugu
	spec.stiffness = cfg.sertlik


## Toplar artık scenes/main.tscn içinde gerçek node (scenes/ball.tscn
## örnekleri). Kukla mı serbest mi olacakları seçili motora bağlı
## (_build_backend sonunda ayarlanır).
func _build_balls() -> void:
	balls["left"] = $TopSol
	balls["right"] = $TopSag
	for side in balls:
		var b: Ball = balls[side]
		b.radius = cfg.radius
		b.mass = cfg.mass


func _exit_tree() -> void:
	if backend:
		backend.shutdown()


# ------------------------------------------------------------------- akis

func reset_sim() -> void:
	# cfg Inspector/Remote'tan degismis olabilir: spec'leri tazele, sonra
	# backend kendini (ve Godot Melez'de RigidBody alanlarini) bunlardan kurar.
	for id in backend.body_ids():
		_fill_spec(backend.get_spec(id))
	_build_balls()
	backend.reset()
	phase = Phase.READY
	running = false
	_launch_slow = false
	_launch_elapsed = 0.0
	_b_escaped = false
	_left_frozen = false
	if _bcam:
		_bcam.reset()
	choice = ""
	_davranis = ""
	_oklari_gizle = false
	_kosu_sure = 0.0
	_kosu_bitti = false
	_en_yuksek = 0.0
	f_real = 0.0
	v_impact = 0.0
	impulse_left = 0.0
	impulse_force = 0.0
	_applied_f = 0.0
	_zero_ext_next = false
	_mirror_a = false
	_mirror_native = false
	left_enter_speed = 0.0
	hold_right = false
	hold_pos = Vector3.ZERO
	show_pair = false
	right_armed = true
	drag_ball = ""
	drag_arrow.set_force(Vector3.ZERO, cfg.ok_olcegi)
	hud.show_choice(false)
	hud.show_feedback("")
	hud.soru_kapat()
	_referans_uygula()
	hud.set_start_text("Başlat")
	hud.set_status("Fizik motoru: %s   -   SPACE / Başlat" % backend.backend_name())
	_sync_visuals()
	_update_readouts()


## Referanssiz mod (Ayarlar autoload'u): sol top, oklari ve paneli gizli;
## ekranda tek top kaldigi icin kamera onu ortalar, ayirici cizgi gizlenir.
func _referans_uygula() -> void:
	var goster := not Ayarlar.referanssiz()
	(balls["left"] as Ball).visible = goster
	hud.referans_goster(goster)
	$Divider.visible = goster
	_kamera_taban = _kamera_ilk
	if not goster:
		_kamera_taban.origin.x += HALF_X   # sag topu ortala
	camera.global_transform = _kamera_taban
	_bcam.taban_ayarla(_kamera_taban)
	_kamerayi_uydur()


## Sim2Config → Görünüm. Her karede cagrilir (Remote'tan canli degisebilsin);
## yalnizca degisen sey dokunulur.
func _gorunum_uygula() -> void:
	hud.gorunum_ayarla(cfg.ust_yazilar, cfg.durum_panelleri)
	ForceArrow.deger_goster = cfg.ok_degerleri
	if cfg.cetveller != _cetvel_acik:
		_cetvel_acik = cfg.cetveller
		for n in _cetveller:
			n.visible = _cetvel_acik


func _on_start() -> void:
	if phase == Phase.CHOICE:
		return
	if phase == Phase.READY:
		phase = Phase.FALLING
	running = not running
	hud.set_start_text("Duraklat" if running else "Devam")


func _unhandled_input(event: InputEvent) -> void:
	if hud.modal_acik():
		return   # ayarlar / soru penceresi acikken SPACE, R ve ok araci calismaz
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_on_start()
		elif event.keycode == KEY_R:
			reset_sim()
	if not tool_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)


func _process(dt: float) -> void:
	_gorunum_uygula()
	if _launch_slow and running:
		# gercek zaman: Engine.time_scale (agir cekim) bu sureyi uzatmasin
		_launch_elapsed += dt / maxf(Engine.time_scale, 1e-6)
		if _launch_elapsed >= cfg.firlatma_agir_cekim_suresi:
			_launch_slow = false
	if tool_active and drag_ball != "":
		var p := _mouse_on_plane(get_viewport().get_mouse_position())
		drag_arrow.global_position = drag_origin
		drag_arrow.set_force((p - drag_origin) * TOOL_N_PER_M, cfg.ok_olcegi)
	if phase == Phase.RESOLVED and running and not _kosu_bitti:
		_kosu_sure += dt / maxf(Engine.time_scale, 1e-6)   # gercek zaman
		# Sure dolunca HER DURUMDA biter (eskiden (b)'de kamera takibi ve
		# firlatma agir cekimi de beklenirdi; takip ~6 sn surdugu icin
		# Inspector'daki sure gecerli olmuyordu).
		if _kosu_sure >= cfg.kosu_sonu_bekleme:
			_kosu_sonu()
	# Panel sayilari ekran karesi hizinda yeterli (fizik 120 Hz olabiliyor)
	if perf.panel_okumalari:
		_update_readouts()


func _physics_process(delta: float) -> void:
	if backend.engine_driven():
		_physics_process_engine(delta)
	elif running and phase != Phase.CHOICE:
		var step := delta * user_speed * _slowmo()
		_pre_step(step)
		backend.step(step)
		_after_step(step)
	_sync_visuals()


## Godot Melez: adimlari fizik motoru atar. Bu tikin delta'si zaten
## Engine.time_scale ile olceklenmis ve motorun bu tikte atacagi adimla
## AYNI — o yuzden impuls hesabinda dogrudan delta kullanilir. Yavaslatma
## (ve kullanici hiz kaydiricisi) Engine.time_scale'e yazilir; Godot bunu
## bir sonraki karede uygular. Secim ekraninda / duraklatilinca bile
## yazmaya devam ediyoruz ki devam edilince ilk adim hizli olmasin.
func _physics_process_engine(delta: float) -> void:
	var advancing := running and phase != Phase.CHOICE
	if advancing:
		# Once son motor adiminin kaydini topla, SONRA kuvvet ata: soldaki
		# topun kaydindaki temas kuvveti, bir sonraki adimda uygulanacak olan.
		# (a)'da sagdaki topa ayni kuvvet ayni adimda boylece verilir.
		backend.step(delta)
		_pre_step(delta)
		_after_step(delta)
	Engine.time_scale = user_speed * _slowmo()
	# Secimden sonraki temaslar ekranda normal hizda gecsin ama fizik adimi
	# agir cekimdeki kadar kucuk kalsin (8 ms'lik temas tek 8 ms'lik adimda
	# cozulurse sekme bozulur): zamani yavaslatmak yerine saniyedeki adim
	# sayisi 1/agir_cekim_carpani kat artar — ayni adim, daha cok adim.
	var tik: int = cfg.godot_tik_sayisi
	if advancing and _temas_yakin(TEMAS_HIZ_ESIGI, true) and not _temas_agir_cekimi():
		tik = mini(roundi(cfg.godot_tik_sayisi / cfg.agir_cekim_carpani), 9600)
	if Engine.physics_ticks_per_second != tik:
		Engine.physics_ticks_per_second = tik
		Engine.max_physics_steps_per_frame = maxi(_varsayilan_max_adim, ceili(tik / 30.0))
	backend.set_running(running and phase != Phase.CHOICE)


## Bu karede verilecek kuvveti ayarla. Son (kismi) adimda kuvvet
## kucultulur ki toplam impuls tam olarak J = m*v*(1+e) olsun.
func _pre_step(step: float) -> void:
	_applied_f = 0.0
	if _mirror_a:
		if not _mirror_native:
			# Arka uc aynalamayi kendisi yapmiyorsa: dis kuvvetle yaklasik
			var n := backend.get_state("left").f_contact.y
			backend.set_external_force("right", Vector3(0.0, n, 0.0))
		return
	if _zero_ext_next:
		# Godot Melez: impuls bir onceki tikte bitti; son parca o tikin motor
		# adiminda uygulandi, simdi kuvveti kaldir (bkz. _after_step).
		_zero_ext_next = false
		backend.set_external_force("right", Vector3.ZERO)
	if impulse_left > 0.0 and step > 0.0:
		_applied_f = minf(impulse_force, impulse_left / step)
		backend.set_external_force("right", Vector3(0.0, _applied_f, 0.0))


## Temas ani milisaniyeler surer. Oklarin gorunebilmesi icin top zemine
## yaklasirken zaman otomatik yavaslar — yalnizca ilk carpmada (secim ani);
## secimden sonrakilerde Sim2Config → secimden_sonra_agir_cekim acikken.
func _slowmo() -> float:
	var f := 1.0
	if _temas_agir_cekimi() and _temas_yakin(AGIR_CEKIM_HIZ_ESIGI):
		f = cfg.agir_cekim_carpani
	if _launch_slow:
		f = minf(f, cfg.firlatma_agir_cekim_carpani)
	return f


## Agir cekim yalnizca gercek sekmelerde (yerde titreyen top zamani sonsuza
## kadar yavaslatmasin). Kucuk adim (tik artisi) ise gorunmez: kucuk sekmeler
## ve yerde duran top da yakalanir — bkz. _temas_yakin.
const AGIR_CEKIM_HIZ_ESIGI := 0.6   # m/s
const TEMAS_HIZ_ESIGI := 0.05       # m/s


func _temas_agir_cekimi() -> bool:
	return phase != Phase.RESOLVED or cfg.secimden_sonra_agir_cekim


## Toplardan biri zemine yaklasiyor ya da zemine bastiriyor mu. yerde: zemine
## degen top (hizi ne olursa olsun) da sayilsin — yay-sonumleyici temas 8 ms'lik
## tek adimda kararsiz, yerde duran top bile titreyip ziplardi.
func _temas_yakin(esik: float, yerde: bool = false) -> bool:
	for side in ["left", "right"]:
		var s := backend.get_state(side)
		if s == null:
			continue
		var gap: float = s.position.y - cfg.radius - GROUND_Y
		# Esik dusuk: kucuk sekmeler (< 0.6 m/s) eskiden yakalanmiyordu, temas
		# tek 8 ms'lik adimda cozuluyor ve top enerji kazaniyordu (0.02 m'lik
		# sekme bir sonrakinde 2.3 m).
		var fast := absf(s.velocity.y) > esik
		# Temasin dip noktasinda hiz ~0 oldugu icin "fast" bir an duser ve
		# o kare normal hizda (tek buyuk adim) gecer: Godot Melez'de temas
		# bozulur, diger motorlarda agir cekim bir kare titrer. Temas kuvveti
		# agirliktan belirgin buyukken de yavas kal (top yerde dururken
		# N ~ m·g oldugu icin orada normal hiza doner).
		var pressing: bool = s.touching_ground \
				and s.f_contact.y > 3.0 * s.mass * PhysicsBackend.GRAVITY.length()
		# (zemine 1 cm'den yakin; yalniz zeminle carpisan top — sagdaki topun
		# temasi cozulmuyor, (c)'de yerde tutulurken boşuna hızlanmasın)
		if yerde and gap < 0.01 and backend.get_spec(side).collisions_enabled:
			return true
		if (s.touching_ground and (fast or pressing)) or (gap < 0.30 and s.velocity.y < -esik):
			return true
	return false


func _after_step(step: float) -> void:
	var sl := backend.get_state("left")
	var sr := backend.get_state("right")

	if _left_frozen:
		# (b) kamera takibi: sol top bekletiliyor (bkz. _left_frozen)
		backend.set_position("left", _left_freeze_pos)
		backend.set_velocity("left", _left_freeze_vel)
		sl.position = _left_freeze_pos
		sl.velocity = _left_freeze_vel

	# --- sol: gercek carpisma -------------------------------------------
	if sl.just_hit_ground:
		left_enter_speed = absf(sl.velocity.y)
		if (balls["left"] as Ball).visible:   # referanssiz modda sessiz
			(balls["left"] as Ball).play_impact(GROUND_Y, left_enter_speed)

	# --- sag: carpisma cozulmuyor, temasi biz yakaliyoruz ----------------
	if hold_right:
		# (c) secenegi ya da (b)'de ekrandan cikis / tepe noktasi.
		backend.set_position("right", hold_pos)
		sr.position = hold_pos
		backend.set_velocity("right", Vector3.ZERO)
		sr.velocity = Vector3.ZERO
	else:
		var gap: float = sr.position.y - cfg.radius - GROUND_Y
		# Temas yalnizca top zeminden AYRILDIKTAN sonra tekrar tetiklenebilir.
		# Bu kilit olmazsa kuvvet her karede yeniden hesaplanir ve impuls
		# hic tamamlanmaz (topun ziplamasi sonmus gorunurdu).
		if gap > 0.05:
			right_armed = true
		if right_armed and sr.velocity.y < 0.0 and gap <= 0.004:
			right_armed = false
			if phase == Phase.FALLING:
				_enter_choice(sl, sr)
			elif phase == Phase.RESOLVED:
				if not _mirror_a:   # (a)'da kuvvet zaten her adimda soldan geliyor
					_apply_choice_force(sr)
				(balls["right"] as Ball).play_impact(GROUND_Y, absf(sr.velocity.y))
		elif phase == Phase.RESOLVED and sr.position.y > cfg.ekrandan_cikis_yuksekligi and not _b_escaped:
			# (b) secenegi: top ekrani terk eder. Cikis hizindan tepe
			# noktasini hesaplayip gosteriyoruz - yoksa sadece kaybolurdu.
			_b_escaped = true
			_launch_slow = false   # firlatma agir cekimi top ekrandan cikinca biter
			var apex: float = sr.position.y + _rise_height(sr.velocity.y)
			if cfg.en_yuksek_gosterimi != Sim2Config.EnYuksek.CANLI:
				hud.set_status("Sağdaki top ekrandan çıktı")
			elif Ayarlar.referanssiz():
				hud.set_status("Sağdaki top ekrandan çıktı  -  tepe noktası yaklaşık %.0f m" % apex)
			else:
				hud.set_status("Sağdaki top ekrandan çıktı  -  tepe noktası yaklaşık %.0f m   (sol tarafta %.2f m)" % [apex, _rise_height(v_impact * cfg.restitution)])
			if _davranis == "b" and (_b_mode == Sim2Config.BGosterim.KAMERA_TAKIP \
					or _b_mode == Sim2Config.BGosterim.IKISI):
				# Top TUTULMAZ, ucmaya devam eder; kamera onu tepeye kadar izler.
				_bcam.start_follow(balls["right"], perf.b_cetveli and cfg.cetveller)
				_left_frozen = true
				_left_freeze_pos = sl.position
				_left_freeze_vel = sl.velocity
			else:
				hold_pos = Vector3(HALF_X, cfg.ekrandan_cikis_yuksekligi, 0.0)
				hold_right = true
				# top 9 m'de tutuluyor; rekor icin hesaplanan tepe noktasi
				_en_yuksek = maxf(_en_yuksek, apex - cfg.radius)
		elif _bcam.is_following() and sr.velocity.y <= 0.0:
			# Kamera takibinde tepe noktasi: topu orada tut (geri dusup yeniden
			# "temas" tetiklemesin), kamera kisa bekleyip geri donsun.
			hold_pos = sr.position
			hold_right = true
			_bcam.notify_apex(sr.position.y - cfg.radius)

	if phase == Phase.RESOLVED:
		_en_yuksek = maxf(_en_yuksek, sr.position.y - cfg.radius)

	if impulse_left > 0.0:
		impulse_left -= _applied_f * step
		if impulse_left <= 1e-9:
			impulse_left = 0.0
			if backend.engine_driven():
				# Godot Melez'de motor adimi _after_step'ten SONRA gelir: kuvveti
				# simdi sifirlarsak impulsun son parcasi hic uygulanmaz.
				_zero_ext_next = true
			else:
				backend.set_external_force("right", Vector3.ZERO)


## v hızıyla yukarı fırlatılan topun ne kadar YÜKSELECEĞİ (m), seçili hava
## modeline göre. Eskiden y + v²/2g idi (havasız) — (b)'de ~60 000 m
## yazıyordu; kare hava direnciyle gerçekte ~200 m.
##   GERCEKCI_KARE:        ln(1 + k·v²/g) / (2k),  k = ½·ρ·Cd·A / m
##   GODOT_SONUM_DOGRUSAL: v/d − (g/d²)·ln(1 + d·v/g)
##   KAPALI:               v² / 2g
func _rise_height(v: float) -> float:
	if v <= 0.0:
		return 0.0
	var g: float = -PhysicsBackend.GRAVITY.y
	match cfg.hava_modeli:
		Sim2Config.HavaModeli.GERCEKCI_KARE:
			var area := PI * cfg.radius * cfg.radius
			var k: float = 0.5 * cfg.hava_yogunlugu * cfg.drag_cd * area / cfg.mass
			if k > 1e-9:
				return log(1.0 + k * v * v / g) / (2.0 * k)
		Sim2Config.HavaModeli.GODOT_SONUM_DOGRUSAL:
			var d: float = cfg.dogrusal_sonum
			if d > 1e-9:
				return v / d - (g / (d * d)) * log(1.0 + d * v / g)
	# KAPALI (ya da katsayı ~0): havasız formül
	return v * v / (2.0 * g)


func _enter_choice(sl: PhysicsBackend.BodyState, sr: PhysicsBackend.BodyState) -> void:
	phase = Phase.CHOICE
	v_impact = absf(sr.velocity.y)
	# Sagdaki topu soldakiyle AYNI yukseklige koy ki karsilastirma adil olsun.
	# Soldaki top YERINDE kalir: bu adimda zemine en fazla bir adimlik yol
	# (~3 mm) girmis ve temas kuvveti bir sonraki adim icin hesaplanmis
	# olabilir. Onu yukari oturtmak temasi bozuyordu (Godot Melez'de ilk
	# kosuyla sonraki kosularin sekmesi %10 farkliydi).
	var p := Vector3(HALF_X, sl.position.y, sl.position.z)
	backend.set_position("right", p)
	sr.position = p
	# Gercek tepki kuvveti: J = m·v·(1+e) = F·T
	f_real = cfg.mass * v_impact * (1.0 + cfg.restitution) / cfg.temas_suresi
	hud.show_choice(true)
	hud.set_status("Çarpma hızı %.2f m/s  -  zemin topa hangi kuvveti uygular?" % v_impact)


func _on_choice(c: String) -> void:
	if phase != Phase.CHOICE:
		return
	var sec := Ayarlar.secenek(c)
	choice = c
	_davranis = str(sec.get("davranis", c))
	_oklari_gizle = bool(sec.get("oklari_gizle", false))
	phase = Phase.RESOLVED
	_kosu_sure = 0.0
	_kosu_bitti = false
	_en_yuksek = 0.0
	hud.show_choice(false)
	var sr := backend.get_state("right")
	_apply_choice_force(sr)
	(balls["right"] as Ball).play_impact(GROUND_Y, v_impact)
	_show_feedback()
	if _davranis == "b":
		_b_mode = cfg.b_gosterim
		# Firlatma agir cekimi SECIM ANINDA tetiklenir — _slowmo()'nun
		# "zemine yaklasiyor ve asagi hizli" kosulu yukari firlayan topu
		# yakalamiyor.
		if _b_mode == Sim2Config.BGosterim.FIRLATMA_AGIR_CEKIM \
				or _b_mode == Sim2Config.BGosterim.IKISI:
			_launch_slow = true
			_launch_elapsed = 0.0


func _apply_choice_force(sr: PhysicsBackend.BodyState) -> void:
	backend.set_position("right", Vector3(HALF_X, GROUND_Y + cfg.radius, 0.0))
	sr.position.y = GROUND_Y + cfg.radius
	# Her temasta kuvvet o temasin hizindan yeniden hesaplanir; aksi halde
	# top her ziplamada enerji kazanirdi.
	f_real = cfg.mass * absf(sr.velocity.y) * (1.0 + cfg.restitution) / cfg.temas_suresi
	match _davranis:
		"a":
			# Sagdaki topu soldakiyle ayni duruma getir; bundan sonra her
			# adimda soldakinin zemin kuvvetini alir (_pre_step).
			var sl := backend.get_state("left")
			var p := Vector3(HALF_X, sl.position.y, sl.position.z)
			backend.set_position("right", p)
			backend.set_velocity("right", sl.velocity)
			sr.position = p
			sr.velocity = sl.velocity
			impulse_left = 0.0
			_mirror_a = true
			_mirror_native = backend.set_contact_mirror("left", "right")
		"b":
			impulse_force = cfg.b_carpani * f_real
			impulse_left = cfg.b_carpani * f_real * cfg.temas_suresi
		"c":
			# Yukari F + asagi F -> bilesike sifir, top duruyor.
			backend.set_external_force("right", Vector3.ZERO)
			backend.set_velocity("right", Vector3.ZERO)
			sr.velocity = Vector3.ZERO
			hold_pos = Vector3(HALF_X, GROUND_Y + cfg.radius, 0.0)
			hold_right = true
			show_pair = true
			impulse_left = 0.0


## Geri bildirim metni config/secenekler.tres'ten ("geri_bildirim").
## Sim2Config → Görünüm → geri_bildirim kapaliyken hic gosterilmez.
## Referanssiz modda yalnizca "referanssiz_geri_bildirim": true ise gosterilir.
func _show_feedback() -> void:
	if not cfg.geri_bildirim:
		return
	if Ayarlar.referanssiz() and not bool(Ayarlar.veri.get("referanssiz_geri_bildirim", false)):
		return
	var carpan := ("%d" % cfg.b_carpani) if is_equal_approx(cfg.b_carpani, roundf(cfg.b_carpani)) else ("%.1f" % cfg.b_carpani)
	var txt := str(Ayarlar.secenek(choice).get("geri_bildirim", ""))
	hud.show_feedback(txt.format({
		"f": "%.0f" % f_real,
		"fb": "%.0f" % (cfg.b_carpani * f_real),
		"carpan": carpan,
	}))


## Kosu bitti: rekor (Sim2Config → en_yuksek_gosterimi) ve son soru.
func _kosu_sonu() -> void:
	_kosu_bitti = true
	# (b) kamera takibi / firlatma agir cekimi hala suruyorsa kes: kamera ana
	# poza doner, bekletilen sol top kaldigi yerden devam eder.
	_launch_slow = false
	if _bcam.is_active():
		_bcam.reset()
		_unfreeze_left()
	if cfg.en_yuksek_gosterimi == Sim2Config.EnYuksek.SON_REKOR and _en_yuksek > 0.05:
		_bcam.rekor_goster(_en_yuksek)
	var sec := Ayarlar.secenek(choice)
	var soru := str(sec.get("son_soru", "")).strip_edges()
	if soru == "":
		return   # soru henuz yazilmamis (ör. a): pencere acilmaz
	hud.soru_goster("%s %s" % [sec.get("harf", ""), sec.get("metin", "")], soru,
		bool(Ayarlar.veri.get("soru_metin_girisi", true)))


func _on_soru_kapandi(cevap: String, kaydet: bool) -> void:
	if not kaydet:
		return
	var sec := Ayarlar.secenek(choice)
	Ayarlar.cevap_kaydet(choice, str(sec.get("metin", "")), str(sec.get("son_soru", "")), cevap)
	hud.set_status("Cevabın kaydedildi.")


# ---------------------------------------------------------------- gorseller

## Ekranda gosterilecek kuvvetler.
##
## TEK KAYNAK: hem oklar hem sag/sol paneller bunu kullanir. Daha once
## override yalnizca oklarda vardi, panel ham backend degerini okuyordu -
## ayni top icin ok "N 1002 N", panel "N 0 N" diyordu.
func _display_forces(side: String, s: PhysicsBackend.BodyState) -> Dictionary:
	var d := {
		"gravity": s.f_gravity,
		"drag": s.f_drag,
		"contact": s.f_contact,
		"external": s.f_external,
		"net": s.f_net,
	}
	if side == "right" and hold_right:
		# Top sabitlendi. Backend ivmeyi adim ICINDE olcuyor, biz hizi adim
		# SONRASINDA sifirliyoruz; o yuzden ham f_net yercekimi kadar cikiyor.
		# Ekranda duran bir topun net kuvveti sifir gorunmeli.
		d["net"] = Vector3.ZERO
		d["drag"] = Vector3.ZERO
	if side == "right" and show_pair:
		# (c) secenegi: zemin yukari F, "tepki" asagi F - ikisi de TOPUN
		# uzerinde. Yanilgi tam da bu, o yuzden bilerek boyle gosteriyoruz.
		d["contact"] = Vector3(0.0, f_real, 0.0)
		d["external"] = Vector3(0.0, -f_real, 0.0)
	return d


func _sync_visuals() -> void:
	for side in ["left", "right"]:
		var s := backend.get_state(side)
		var ball: Ball = balls[side]
		if s == null or not is_instance_valid(ball):
			continue
		if not backend.engine_driven():
			ball.global_position = s.position   # kukla: konumu backend belirler
		if ball.arrows.is_empty():
			continue

		var d := _display_forces(side, s)

		# Oklar yan yana dizilir; etiketler farkli yuksekliklere kaldirilir.
		_set_arrow(ball, "gravity", d["gravity"], 0)
		_set_arrow(ball, "drag", d["drag"], 1)
		_set_arrow(ball, "contact", d["contact"], 2)
		_set_arrow(ball, "external", d["external"], 3)
		_set_arrow(ball, "net", d["net"], 4)
		_set_arrow(ball, "net_minus_g", d["net"] - d["gravity"], 5)


const ARROW_SPACING := 0.24

func _set_arrow(ball: Ball, key: String, force: Vector3, slot: int) -> void:
	var a: ForceArrow = ball.arrows[key]
	a.position = Vector3((float(slot) - 1.6) * ARROW_SPACING, 0.0, 0.0)
	a.label_lift = float(slot) * 0.13
	var gizli: bool = not perf.kuvvet_oklari or (_oklari_gizle and ball == balls["right"])
	if arrow_on.get(key, false) and not gizli:
		a.set_force(force, cfg.ok_olcegi)
	else:
		a.set_force(Vector3.ZERO, cfg.ok_olcegi)


func _update_readouts() -> void:
	for side in ["left", "right"]:
		var s := backend.get_state(side)
		if s == null:
			continue
		# Oklarla AYNI kaynak - iki yerde farkli sayi cikmasin.
		var d := _display_forces(side, s)
		var h: float = maxf(s.position.y - cfg.radius, 0.0)
		var t := "[color=#c8cddb]Yükseklik[/color]  %.2f m\n" % h
		t += "[color=#c8cddb]Hız[/color]  %.2f m/s\n" % s.velocity.y
		t += "[color=#f05a5a]Fg[/color] %.1f N   " % (d["gravity"] as Vector3).length()
		t += "[color=#6bb8ff]Fs[/color] %.2f N   " % (d["drag"] as Vector3).length()
		t += "[color=#66e68c]N[/color] %.0f N\n" % (d["contact"] as Vector3).length()
		t += "[color=#ffd83d]Fnet[/color] %.0f N" % (d["net"] as Vector3).length()
		if side == "right" and (d["external"] as Vector3).length() > 0.01:
			t += "   [color=#d98cff]F[/color] %.0f N" % (d["external"] as Vector3).length()
		hud.set_readout(side, t)


# ------------------------------------------------------------- ok araci

func _mouse_on_plane(screen_pos: Vector2) -> Vector3:
	# Toplar z = 0 duzleminde; fareyi o duzleme izdusur.
	# Isin projeksiyon matrisinin tersinden kurulur: kamera.project_ray_*
	# FRUSTUM ofsetini (dikey ekrandaki lens kaydirma) hesaba katmiyor.
	var vp := get_viewport().get_visible_rect().size
	var ndc := Vector2(screen_pos.x / vp.x * 2.0 - 1.0, 1.0 - screen_pos.y / vp.y * 2.0)
	var h: Vector4 = camera.get_camera_projection().inverse() * Vector4(ndc.x, ndc.y, 1.0, 1.0)
	var yerel := Vector3(h.x, h.y, h.z) / h.w
	var from := camera.global_position
	var dir := (camera.global_basis * yerel).normalized()
	if absf(dir.z) < 0.0001:
		return from
	var t := -from.z / dir.z
	return from + dir * t


func _begin_drag(screen_pos: Vector2) -> void:
	var p := _mouse_on_plane(screen_pos)
	for side in ["left", "right"]:
		var s := backend.get_state(side)
		if s and p.distance_to(s.position) < 0.55:
			drag_ball = side
			drag_origin = s.position
			return


func _end_drag(screen_pos: Vector2) -> void:
	if drag_ball == "":
		return
	var p := _mouse_on_plane(screen_pos)
	var force := (p - drag_origin) * TOOL_N_PER_M
	force.z = 0.0
	# Bu bir "rigidbody modifier": kuvvet fizik motoruna verilir, dolayisiyla
	# yercekimi ve hava surtunmesiyle birlikte cozulur - okun kendi ozelligi degil.
	backend.set_external_force(drag_ball, force)
	impulse_left = 0.0
	var label: String = "Sol" if drag_ball == "left" else "Sağ"
	drag_ball = ""
	drag_arrow.set_force(Vector3.ZERO, cfg.ok_olcegi)
	hud.set_status("%s topa %.0f N uygulandı (ok aracı)" % [label, force.length()])


## Kamera takibinin ust suresi tepe noktasina varmadan doldu: topu oldugu
## yerde tut (yoksa kamera donerken top ucmaya/geri dusmeye devam ederdi).
func _on_follow_timeout() -> void:
	var sr := backend.get_state("right")
	hold_pos = sr.position
	hold_right = true


## Kamera ana poza donmeye basladi: sol top kaldigi yerden (ayni konum ve
## hizla) devam etsin.
func _unfreeze_left() -> void:
	if not _left_frozen:
		return
	_left_frozen = false
	backend.set_position("left", _left_freeze_pos)
	backend.set_velocity("left", _left_freeze_vel)
