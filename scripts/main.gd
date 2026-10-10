extends Node3D

## Etki-tepki (Newton 3) kavram yanilgisi simulasyonu.
##
## Sahne ikiye bolunur:
##   SOL  - MuJoCo/fizik motoru her seyi cozer, carpisma dahil. Gercek davranis.
##   SAG  - Yercekimi ve hava surtunmesi isler, CARPISMA cozulmez.
##          Top zemine degdigi an sim durur, ogrenci zemin tepkisini secer.
##
## Secenekler:
##   a) yukari F            -> sol tarafla birebir ayni gorsel (dogru)
##   b) yukari 100·F        -> top firlar (zemin "daha buyuk" kuvvet uygular yanilgisi)
##   c) yukari F + asagi F  -> top durur ("etki ve tepki topun uzerinde birbirini goturur" yanilgisi)

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
	"external": true, "net": true, "net_minus_g": false,
}

var balls := {}          # "left"/"right" -> Ball (sahnedeki TopSol / TopSag)
var hud: Hud
var camera: Camera3D
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
	_build_hud()
	_build_balls()     # önce toplar: Godot Melez motoru bu node'ları kullanıyor
	_build_backend()
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

## Sahne 16:9 icin kadrajlandi (fov dikey aci, KEEP_HEIGHT). Daha dar
## ekranda (dikey telefon, 4:3'ten dar tablet) yanlar kesilip toplar
## kadrajdan cikiyordu: yatayda 16:9 goruntunun en az KAMERA_MIN_YATAY
## kadari gorunsun diye dikey aciyi buyutuyoruz. Genis ekranda degismez.
const KAMERA_MIN_YATAY := 0.70
var _fov_16_9 := 54.0

func _kamerayi_uydur() -> void:
	var s := get_viewport().get_visible_rect().size
	if s.x <= 0.0 or s.y <= 0.0:
		return
	var t0 := tan(deg_to_rad(_fov_16_9) * 0.5)
	var t := maxf(t0, KAMERA_MIN_YATAY * t0 * (16.0 / 9.0) / (s.x / s.y))
	camera.fov = rad_to_deg(2.0 * atan(t))


func _build_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.start_pressed.connect(_on_start)
	hud.reset_pressed.connect(reset_sim)
	hud.speed_changed.connect(func(v: float): user_speed = v)
	hud.arrow_toggled.connect(func(key: String, on: bool): arrow_on[key] = on)
	hud.tool_toggled.connect(func(on: bool): tool_active = on)
	hud.choice_made.connect(_on_choice)


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
	hud.set_start_text("Başlat")
	hud.set_status("Fizik motoru: %s   -   SPACE / Başlat" % backend.backend_name())
	_sync_visuals()


func _on_start() -> void:
	if phase == Phase.CHOICE:
		return
	if phase == Phase.READY:
		phase = Phase.FALLING
	running = not running
	hud.set_start_text("Duraklat" if running else "Devam")


func _unhandled_input(event: InputEvent) -> void:
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
	if _launch_slow and running:
		# gercek zaman: Engine.time_scale (agir cekim) bu sureyi uzatmasin
		_launch_elapsed += dt / maxf(Engine.time_scale, 1e-6)
		if _launch_elapsed >= cfg.firlatma_agir_cekim_suresi:
			_launch_slow = false
	if tool_active and drag_ball != "":
		var p := _mouse_on_plane(get_viewport().get_mouse_position())
		drag_arrow.global_position = drag_origin
		drag_arrow.set_force((p - drag_origin) * TOOL_N_PER_M, cfg.ok_olcegi)


func _physics_process(delta: float) -> void:
	if backend.engine_driven():
		_physics_process_engine(delta)
	elif running and phase != Phase.CHOICE:
		var step := delta * user_speed * _slowmo()
		_pre_step(step)
		backend.step(step)
		_after_step(step)
	_sync_visuals()
	_update_readouts()


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
## yaklasirken zaman otomatik yavaslar.
func _slowmo() -> float:
	var f := 1.0
	for side in ["left", "right"]:
		var s := backend.get_state(side)
		if s == null:
			continue
		var gap: float = s.position.y - cfg.radius - GROUND_Y
		var fast := absf(s.velocity.y) > 0.6
		# Temasin dip noktasinda hiz ~0 oldugu icin "fast" bir an duser ve
		# o kare normal hizda (tek buyuk adim) gecer: Godot Melez'de temas
		# bozulur, diger motorlarda agir cekim bir kare titrer. Temas kuvveti
		# agirliktan belirgin buyukken de yavas kal (top yerde dururken
		# N ~ m·g oldugu icin orada normal hiza doner).
		var pressing: bool = s.touching_ground \
				and s.f_contact.y > 3.0 * s.mass * PhysicsBackend.GRAVITY.length()
		if (s.touching_ground and (fast or pressing)) or (gap < 0.30 and s.velocity.y < -0.6):
			f = cfg.agir_cekim_carpani
	if _launch_slow:
		f = minf(f, cfg.firlatma_agir_cekim_carpani)
	return f


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
			hud.set_status("Sağdaki top ekrandan çıktı  -  tepe noktası yaklaşık %.0f m   (sol tarafta %.2f m)" % [apex, _rise_height(v_impact * cfg.restitution)])
			if choice == "b" and (_b_mode == Sim2Config.BGosterim.KAMERA_TAKIP \
					or _b_mode == Sim2Config.BGosterim.IKISI):
				# Top TUTULMAZ, ucmaya devam eder; kamera onu tepeye kadar izler.
				_bcam.start_follow(balls["right"])
				_left_frozen = true
				_left_freeze_pos = sl.position
				_left_freeze_vel = sl.velocity
			else:
				hold_pos = Vector3(HALF_X, cfg.ekrandan_cikis_yuksekligi, 0.0)
				hold_right = true
		elif _bcam.is_following() and sr.velocity.y <= 0.0:
			# Kamera takibinde tepe noktasi: topu orada tut (geri dusup yeniden
			# "temas" tetiklemesin), kamera kisa bekleyip geri donsun.
			hold_pos = sr.position
			hold_right = true
			_bcam.notify_apex(sr.position.y - cfg.radius)

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
	choice = c
	phase = Phase.RESOLVED
	hud.show_choice(false)
	var sr := backend.get_state("right")
	_apply_choice_force(sr)
	(balls["right"] as Ball).play_impact(GROUND_Y, v_impact)
	_show_feedback()
	if c == "b":
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
	match choice:
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


func _show_feedback() -> void:
	var txt := ""
	match choice:
		"a":
			txt = "[color=#6ee7a0][b]a) doğru.[/b][/color] Zemin topa yukarı yönlü N ≈ %.0f N uyguluyor; "
			txt += "top bu impulsla soldaki gerçek simülasyonla aynı yüksekliğe çıkıyor. "
			txt += "Etki–tepki çifti top ile zemin arasındadır: top zemine aşağı %.0f N uygularken zemin topa yukarı %.0f N uygular. "
			txt += "İkisi FARKLI cisimlere etki ettiği için birbirini götürmez."
			txt = txt % [f_real, f_real, f_real]
		"b":
			txt = "[color=#ffb84d][b]b) yanlış.[/b][/color] {carpan}·F ≈ {f} N uygulandı ve top bırakıldığı yükseklikten "
			txt += "çok daha yukarı fırladı — günlük hayatta böyle bir şey görmüyorsun. "
			txt += "Zemin 'daha güçlü ittiği için' top zıplamıyor; tepki kuvveti etki kuvvetine tam eşittir."
			txt = txt.format({
				"carpan": ("%d" % cfg.b_carpani) if is_equal_approx(cfg.b_carpani, roundf(cfg.b_carpani)) else ("%.1f" % cfg.b_carpani),
				"f": "%.0f" % (cfg.b_carpani * f_real),
			})
		"c":
			txt = "[color=#ff7d7d][b]c) yanlış — ama en sık yapılan hata bu.[/b][/color] Yukarı F ve aşağı F aynı cisme "
			txt += "etki ettiği için top duruyor. Oysa Newton'un 3. yasasındaki çift AYNI cisme etki etmez: "
			txt += "biri topa (zemin → top), diğeri zemine (top → zemin) etki eder. "
			txt += "Topun üzerindeki tek yukarı kuvvet N ≈ %.0f N'dur ve top bu yüzden zıplar. Sol tarafa bak."
			txt = txt % [f_real]
	hud.show_feedback(txt)


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
	if arrow_on.get(key, false):
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
		t += "[color=#f05a5a]G[/color] %.1f N   " % (d["gravity"] as Vector3).length()
		t += "[color=#6bb8ff]Fs[/color] %.2f N   " % (d["drag"] as Vector3).length()
		t += "[color=#66e68c]N[/color] %.0f N\n" % (d["contact"] as Vector3).length()
		t += "[color=#ffd83d]Fnet[/color] %.0f N" % (d["net"] as Vector3).length()
		if side == "right" and (d["external"] as Vector3).length() > 0.01:
			t += "   [color=#d98cff]F[/color] %.0f N" % (d["external"] as Vector3).length()
		hud.set_readout(side, t)


# ------------------------------------------------------------- ok araci

func _mouse_on_plane(screen_pos: Vector2) -> Vector3:
	# Toplar z = 0 duzleminde; fareyi o duzleme izdusur.
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
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
