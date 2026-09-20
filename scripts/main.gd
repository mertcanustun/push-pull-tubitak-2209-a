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

const BALL_RADIUS := 0.119
const BALL_MASS := 0.624
const RESTITUTION := 0.76
const DRAG_CD := 0.47
const DROP_HEIGHT := 3.0
const HALF_X := 1.8
const GROUND_Y := 0.0
## Gercek bir basketbol temasi ~8 ms surer. Secilen kuvvet bu sure boyunca
## uygulanir: J = F·T = m·v·(1+e) oldugundan (a) secenegi solla ayni ciker.
const T_CONTACT := 0.008
const ARROW_K := 0.36
const TOOL_N_PER_M := 40.0
## Sagdaki top bu yuksekligi asarsa ekrandan cikmis sayilir ((b) secenegi).
const ESCAPE_Y := 9.0

enum Phase { READY, FALLING, CHOICE, RESOLVED }

var backend: PhysicsBackend
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
var _applied_f := 0.0
## Top sabitlendi mi ((c) secenegi ya da ekran disi)
var hold_right := false
var hold_pos := Vector3.ZERO
## (c) secenegindeki zit ok ciftini goster
var show_pair := false
## Temas tetigi hazir mi (top zeminden ayrildiktan sonra kurulur)
var right_armed := true
## (a) secenegi soldaki ziplamayla BIREBIR ayni olsun diye: sagdaki top
## soldakinin temasi bitene kadar bekletilir, sonra tam ayni cikis hizini
## verecek impuls uygulanir. Sonraki temaslarda olculen e degeri kullanilir.
var pending_match := false
var match_wait := 0.0
var e_measured := 0.0
var left_was_touching := false
var left_enter_speed := 0.0

var arrow_on := {
	"gravity": true, "drag": true, "contact": true,
	"external": true, "net": true, "net_minus_g": false,
}

var balls := {}          # "left"/"right" -> SimBall
var hud: Hud
var camera: Camera3D
var drag_ball := ""
var drag_origin := Vector3.ZERO
var drag_arrow: ForceArrow


func _ready() -> void:
	_build_environment()
	_build_hud()
	_build_backend()
	_build_balls()
	reset_sim()


# ------------------------------------------------------------------ kurulum

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.09, 0.14)
	sky_mat.sky_horizon_color = Color(0.16, 0.18, 0.24)
	sky_mat.ground_bottom_color = Color(0.05, 0.05, 0.07)
	sky_mat.ground_horizon_color = Color(0.14, 0.15, 0.19)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.62, 4.7)
	camera.look_at_from_position(Vector3(0.0, 1.62, 4.7), Vector3(0.0, 1.38, 0.0), Vector3.UP)
	camera.fov = 54.0
	add_child(camera)

	# --- zemin: iki ayri plaka, ortada ayirici --------------------------
	_add_ground(-HALF_X, Color(0.20, 0.30, 0.42))
	_add_ground(HALF_X, Color(0.42, 0.30, 0.20))

	var divider := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.025, 4.2, 2.2)
	divider.mesh = dm
	divider.position = Vector3(0.0, 2.1, 0.0)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(1, 1, 1, 0.055)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	divider.material_override = dmat
	divider.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(divider)

	# Cetveller ortada, ayiricinin iki yaninda: panellerin arkasinda kalmazlar.
	_add_height_ruler(-0.62)
	_add_height_ruler(0.62)

	drag_arrow = ForceArrow.new(Color(1.0, 1.0, 1.0), "surukle")
	add_child(drag_arrow)


func _add_ground(x: float, tint: Color) -> void:
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.1, 0.18, 2.2)
	slab.mesh = bm
	slab.position = Vector3(x, GROUND_Y - 0.09, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.92
	slab.material_override = mat
	add_child(slab)


func _add_height_ruler(x: float) -> void:
	var sign_x: float = signf(x)
	for m in range(1, 4):
		var tick := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.44, 0.014, 0.014)
		tick.mesh = bm
		tick.position = Vector3(x + sign_x * 0.22, float(m), 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1, 0.35)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tick.material_override = mat
		tick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tick)

		var lbl := Label3D.new()
		lbl.text = "%d m" % m
		lbl.font_size = 40
		lbl.pixel_size = 0.0028
		lbl.modulate = Color(1, 1, 1, 0.5)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.position = Vector3(x + sign_x * 0.16, float(m) + 0.13, 0.0)
		add_child(lbl)


func _build_hud() -> void:
	hud = Hud.new()
	add_child(hud)
	hud.start_pressed.connect(_on_start)
	hud.reset_pressed.connect(reset_sim)
	hud.speed_changed.connect(func(v: float): user_speed = v)
	hud.arrow_toggled.connect(func(key: String, on: bool): arrow_on[key] = on)
	hud.tool_toggled.connect(func(on: bool): tool_active = on)
	hud.choice_made.connect(_on_choice)


## Hangi fizik arka ucu kullanilsin:
##   "auto"    - MuJoCo varsa onu kullan, yoksa GDScript cozucuye dus
##   "mujoco"  - MuJoCo'yu zorla (yoksa yine de dusuyoruz ama uyari basar)
##   "native"  - MuJoCo derlenmis olsa bile GDScript cozucuyu kullan
## Karsilastirma yaparken bu satiri degistirip iki arka ucu yan yana denersin.
const FORCE_BACKEND := "mujoco"


func _build_backend() -> void:
	if FORCE_BACKEND == "native":
		backend = NativeBackend.new()
	else:
		var mj := MuJoCoBackend.new()
		if mj.initialize():
			backend = mj
		else:
			backend = NativeBackend.new()
			push_warning("MuJoCo kullanılamadı: %s" % mj.get_error())

	for side in ["left", "right"]:
		var spec := PhysicsBackend.BodySpec.new(side)
		spec.mass = BALL_MASS
		spec.radius = BALL_RADIUS
		spec.restitution = RESTITUTION
		spec.drag_coefficient = DRAG_CD
		spec.position = Vector3(-HALF_X if side == "left" else HALF_X, DROP_HEIGHT, 0.0)
		# Senaryo planinin can alici noktasi: sagda carpisma KAPALI,
		# yercekimi ve hava surtunmesi ACIK.
		spec.collisions_enabled = (side == "left")
		backend.add_body(spec)


func _build_balls() -> void:
	for side in ["left", "right"]:
		var b := SimBall.new(BALL_RADIUS)
		add_child(b)
		balls[side] = b


# ------------------------------------------------------------------- akis

func reset_sim() -> void:
	backend.reset()
	phase = Phase.READY
	running = false
	choice = ""
	f_real = 0.0
	v_impact = 0.0
	impulse_left = 0.0
	impulse_force = 0.0
	_applied_f = 0.0
	pending_match = false
	match_wait = 0.0
	e_measured = 0.0
	left_was_touching = false
	left_enter_speed = 0.0
	hold_right = false
	hold_pos = Vector3.ZERO
	show_pair = false
	right_armed = true
	drag_ball = ""
	drag_arrow.set_force(Vector3.ZERO, ARROW_K)
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


func _process(_dt: float) -> void:
	if tool_active and drag_ball != "":
		var p := _mouse_on_plane(get_viewport().get_mouse_position())
		drag_arrow.global_position = drag_origin
		drag_arrow.set_force((p - drag_origin) * TOOL_N_PER_M, ARROW_K)


func _physics_process(delta: float) -> void:
	if running and phase != Phase.CHOICE:
		var step := delta * user_speed * _slowmo()
		_pre_step(step)
		backend.step(step)
		_after_step(step)
	_sync_visuals()
	_update_readouts()


## Bu karede verilecek kuvveti ayarla. Son (kismi) adimda kuvvet
## kucultulur ki toplam impuls tam olarak J = m*v*(1+e) olsun.
func _pre_step(step: float) -> void:
	_applied_f = 0.0
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
		var gap: float = s.position.y - BALL_RADIUS - GROUND_Y
		var fast := absf(s.velocity.y) > 0.6
		if (s.touching_ground and fast) or (gap < 0.30 and s.velocity.y < -0.6):
			f = 0.05
	return f


func _after_step(step: float) -> void:
	var sl := backend.get_state("left")
	var sr := backend.get_state("right")

	# --- sol: gercek carpisma -------------------------------------------
	if sl.just_hit_ground:
		left_enter_speed = absf(sl.velocity.y)
		(balls["left"] as SimBall).play_impact(GROUND_Y, left_enter_speed)
	# Soldaki top zeminden ayrildi: gercek geri tepme katsayisini olc.
	if left_was_touching and not sl.touching_ground and sl.velocity.y > 0.0:
		if left_enter_speed > 0.1:
			e_measured = sl.velocity.y / left_enter_speed
		if pending_match:
			_deliver_matched_impulse(sl.velocity.y)
	left_was_touching = sl.touching_ground

	if pending_match:
		match_wait += step
		if match_wait > 0.25:
			# Sol taraf beklenenden uzun surdu: teorik degere dus.
			_deliver_matched_impulse(v_impact * RESTITUTION)

	# --- sag: carpisma cozulmuyor, temasi biz yakaliyoruz ----------------
	if hold_right:
		# (c) secenegi, ekrandan cikis ya da (a)'da soldaki ziplamayi bekleme.
		backend.set_position("right", hold_pos)
		sr.position = hold_pos
		# Bekleme sirasinda carpma hizini KORU: impuls bunun uzerine binecek.
		var v_hold := Vector3(0.0, -v_impact, 0.0) if pending_match else Vector3.ZERO
		backend.set_velocity("right", v_hold)
		sr.velocity = v_hold
	else:
		var gap: float = sr.position.y - BALL_RADIUS - GROUND_Y
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
				_apply_choice_force(sr)
				(balls["right"] as SimBall).play_impact(GROUND_Y, v_impact)
		elif phase == Phase.RESOLVED and sr.position.y > ESCAPE_Y:
			# (b) secenegi: top ekrani terk eder. Cikis hizindan tepe
			# noktasini hesaplayip gosteriyoruz - yoksa sadece kaybolurdu.
			var apex: float = sr.position.y + sr.velocity.y * sr.velocity.y / (2.0 * 9.81)
			hold_pos = Vector3(HALF_X, ESCAPE_Y, 0.0)
			hold_right = true
			hud.set_status("Sağdaki top ekrandan çıktı  -  tepe noktası yaklaşık %.0f m   (sol tarafta %.2f m)" % [apex, v_impact * v_impact * RESTITUTION * RESTITUTION / (2.0 * 9.81)])

	if impulse_left > 0.0:
		impulse_left -= _applied_f * step
		if impulse_left <= 1e-9:
			impulse_left = 0.0
			backend.set_external_force("right", Vector3.ZERO)


func _enter_choice(sl: PhysicsBackend.BodyState, sr: PhysicsBackend.BodyState) -> void:
	phase = Phase.CHOICE
	v_impact = absf(sr.velocity.y)
	# Iki topu da tam temas noktasina oturt ki karsilastirma adil olsun.
	for side in ["left", "right"]:
		var x: float = -HALF_X if side == "left" else HALF_X
		backend.set_position(side, Vector3(x, GROUND_Y + BALL_RADIUS, 0.0))
	sl.position.y = GROUND_Y + BALL_RADIUS
	sr.position.y = GROUND_Y + BALL_RADIUS
	# Gercek tepki kuvveti: J = m·v·(1+e) = F·T
	f_real = BALL_MASS * v_impact * (1.0 + RESTITUTION) / T_CONTACT
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
	(balls["right"] as SimBall).play_impact(GROUND_Y, v_impact)
	_show_feedback()


func _apply_choice_force(sr: PhysicsBackend.BodyState) -> void:
	backend.set_position("right", Vector3(HALF_X, GROUND_Y + BALL_RADIUS, 0.0))
	sr.position.y = GROUND_Y + BALL_RADIUS
	# Her temasta kuvvet o temasin hizindan yeniden hesaplanir; aksi halde
	# top her ziplamada enerji kazanirdi.
	f_real = BALL_MASS * absf(sr.velocity.y) * (1.0 + RESTITUTION) / T_CONTACT
	match choice:
		"a":
			if e_measured > 0.0:
				# Soldaki ziplamadan olculen gercek e ile ayni cikis hizi.
				f_real = BALL_MASS * absf(sr.velocity.y) * (1.0 + e_measured) / T_CONTACT
				impulse_force = f_real
				impulse_left = f_real * T_CONTACT
			else:
				# Ilk temas: soldaki top ziplamasini bitirene kadar bekle,
				# sonra birebir ayni impulsu ver.
				pending_match = true
				match_wait = 0.0
				hold_pos = Vector3(HALF_X, GROUND_Y + BALL_RADIUS, 0.0)
				hold_right = true
		"b":
			impulse_force = 100.0 * f_real
			impulse_left = 100.0 * f_real * T_CONTACT
		"c":
			# Yukari F + asagi F -> bilesike sifir, top duruyor.
			backend.set_external_force("right", Vector3.ZERO)
			backend.set_velocity("right", Vector3.ZERO)
			sr.velocity = Vector3.ZERO
			hold_pos = Vector3(HALF_X, GROUND_Y + BALL_RADIUS, 0.0)
			hold_right = true
			show_pair = true
			impulse_left = 0.0


## Soldaki topun olculen cikis hizina gore sagdaki topa impuls ver.
func _deliver_matched_impulse(exit_speed: float) -> void:
	pending_match = false
	hold_right = false
	match_wait = 0.0
	# J = m * (|v_giris| + v_cikis)  -> ayni cikis hizi, ayni yukseklik.
	var j: float = BALL_MASS * (v_impact + absf(exit_speed))
	f_real = j / T_CONTACT
	impulse_force = f_real
	impulse_left = j
	right_armed = false


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
			txt = "[color=#ffb84d][b]b) yanlış.[/b][/color] 100·F ≈ %.0f N uygulandı ve top bırakıldığı yükseklikten "
			txt += "çok daha yukarı fırladı — günlük hayatta böyle bir şey görmüyorsun. "
			txt += "Zemin 'daha güçlü ittiği için' top zıplamıyor; tepki kuvveti etki kuvvetine tam eşittir."
			txt = txt % [100.0 * f_real]
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
		var ball: SimBall = balls[side]
		if s == null or not is_instance_valid(ball):
			continue
		ball.global_position = s.position
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

func _set_arrow(ball: SimBall, key: String, force: Vector3, slot: int) -> void:
	var a: ForceArrow = ball.arrows[key]
	a.position = Vector3((float(slot) - 1.6) * ARROW_SPACING, 0.0, 0.0)
	a.label_lift = float(slot) * 0.13
	if arrow_on.get(key, false):
		a.set_force(force, ARROW_K)
	else:
		a.set_force(Vector3.ZERO, ARROW_K)


func _update_readouts() -> void:
	for side in ["left", "right"]:
		var s := backend.get_state(side)
		if s == null:
			continue
		# Oklarla AYNI kaynak - iki yerde farkli sayi cikmasin.
		var d := _display_forces(side, s)
		var h: float = maxf(s.position.y - BALL_RADIUS, 0.0)
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
	drag_arrow.set_force(Vector3.ZERO, ARROW_K)
	hud.set_status("%s topa %.0f N uygulandı (ok aracı)" % [label, force.length()])
