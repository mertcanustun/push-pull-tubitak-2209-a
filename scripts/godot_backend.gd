extends PhysicsBackend
class_name GodotBackend

## ÜÇÜNCÜ fizik seçeneği — "Godot Melez".
##
## Uçuş Godot'nun kendi RigidBody3D fiziğinde (TopSol / TopSag dondurulmaz):
## yerçekimi Godot'nun (proje ayarı 9.81), sönüm 0 (REPLACE). Hava direnci ve
## zemin teması ise BİZİM modelimiz — her fizik adımının başında topun
## _integrate_forces'ında state.apply_central_force ile verilir. Temas yasası
## ve sabitleri Yedek Çözücü (NativeBackend) ile birebir aynı:
##     pen = (GROUND_Y + r) − y > 0  ise  N = max(0, k·pen − c·vy)
## Toplar zeminle Godot çarpışması YAPMAZ (çarpışma maskesi 0, sahnede zemin
## çarpışma gövdesi de yok).
##
## ZAMANLAMA (ölçülerek doğrulandı, bkz. ADIM2 notları):
## Bir tik n'de sıra:  main._physics_process(n)  →  motor adımı n  →
## _integrate_forces(n). Yani geri çağrı adım n BİTTİKTEN sonra gelir
## (state = adım n'in sonu, state.step = adım n'in süresi) ve orada verilen
## KUVVET bir SONRAKİ adımda, o adımın süresiyle entegre edilir. Ağır çekim
## (Engine.time_scale) kare sınırında değiştiği için o süre önceden bilinemez.
## Bu yüzden:
##   - DIŞ kuvvet (seçim kuvveti, ok aracı) kuvvet olarak değil, az önce biten
##     adım için İMPULS olarak verilir: J = F × state.step. main.gd'nin impuls
##     muhasebesi (F × delta, delta = o tikin adım süresi) böylece BİREBİR tutar.
##     (Önceden kuvvet olarak veriliyordu: ağır çekim kapandığı an 0.42 ms için
##     hesaplanan kuvvet 8.3 ms boyunca uygulanıyor, (a)'da sağ top fırlıyordu.)
##   - Hava ve temas kuvvetleri anlık durumdan hesaplanıp kuvvet olarak verilir
##     (bir sonraki adımın süresi ne olursa olsun fiziksel olarak doğru).
##   - Fnet, iki ardışık geri çağrı arasındaki hız farkından ölçülür.
## main.gd bir sonraki tikte step() ile bu kaydı toplar.
##
## YAVAŞLATMA: adımları motor attığı için main.gd zamanı Engine.time_scale ile
## yavaşlatır (fizik adımı = (1/tik) × time_scale). 8 ms'lik temas en az 15
## adıma bölünsün diye bu mod açıkken tik sayısı çalışma zamanında
## cfg.godot_tik_sayisi'na (varsayılan 120) çıkarılır; mod kapanınca
## (shutdown) her şey eski haline döner. Diğer modların sayısal davranışı bu
## yüzden HİÇ değişmez.

var _cfg: Sim2Config
var _bodies: Dictionary = {}     # id -> Ball (RigidBody3D)
var _state: Dictionary = {}      # id -> BodyState
var _pending: Dictionary = {}    # id -> Dictionary (adımın başı + uygulanan kuvvetler)
var _ext: Dictionary = {}        # id -> Vector3
var _stiffness: Dictionary = {}
var _damping: Dictionary = {}
var _in_contact: Dictionary = {} # id -> bool (son geri çağrıda temas kuvveti verildi mi)
var _v_prev: Dictionary = {}     # id -> Vector3 (önceki geri çağrıdaki hız, Fnet için)
var _mirror_src := ""
var _mirror_dst := ""
var _active := true
var _held_vel: Dictionary = {}   # id -> Vector3 (duraklatılmışken saklanan hız)
## (a): devamdan sonraki İLK geri çağrıda hedef, kaynağın adım sonu durumuna
## eşitlenir. Dondurulmuşken hedefe konum/hız yazmak onun bekleyen kuvvetini
## (hava direnci) siliyor, kaynağınki kalıyor; ilk adımda 0.0005 m/s'lik fark
## sekmelerde 1 mm'ye büyüyordu.
var _mirror_sync := false
var _saved_ticks := 60


func _init(cfg: Sim2Config, bodies: Dictionary) -> void:
	_cfg = cfg
	_bodies = bodies
	_saved_ticks = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = cfg.godot_tik_sayisi
	set_running(false)


func backend_name() -> String:
	return "Godot Melez (Godot uçuş + bizim temas/hava)"

func is_available() -> bool:
	return true

func engine_driven() -> bool:
	return true


func add_body(spec: PhysicsBackend.BodySpec) -> void:
	super.add_body(spec)
	var b: RigidBody3D = _bodies[spec.id]
	var id: String = spec.id
	b.set("integrator", func(st: PhysicsDirectBodyState3D) -> void: _integrate(id, st))
	_ext[spec.id] = Vector3.ZERO
	_reset_body(spec)


## TEK DOĞRULUK KAYNAĞI: her reset'te topun RigidBody fizik alanları
## spec'ten (main.gd onu her reset_sim()'de Sim2Config'ten tazeler) yeniden
## yazılır. Inspector'da topa elle girilen Mass/Damp/Physics Material ikinci
## bir değer oluşturamaz — ilk Sıfırla'da cfg değerine döner.
func _reset_body(spec: PhysicsBackend.BodySpec) -> void:
	# NativeBackend ile aynı temas modeli: k seçilir, c sekmeden türetilir.
	var k := spec.stiffness
	var e: float = clampf(spec.restitution, 0.01, 0.99)
	var ln_e := log(e)
	var zeta := -ln_e / sqrt(PI * PI + ln_e * ln_e)
	_stiffness[spec.id] = k
	_damping[spec.id] = 2.0 * zeta * sqrt(k * spec.mass)
	_apply_body_fields(_bodies[spec.id], spec)

	var s := PhysicsBackend.BodyState.new()
	s.position = spec.position
	s.velocity = spec.velocity
	s.mass = spec.mass
	s.f_gravity = spec.mass * _gravity()
	_state[spec.id] = s
	_pending.erase(spec.id)
	_in_contact[spec.id] = false
	_ext[spec.id] = Vector3.ZERO
	_v_prev[spec.id] = spec.velocity
	var b: RigidBody3D = _bodies[spec.id]
	b.global_transform = Transform3D(Basis(), spec.position)
	b.linear_velocity = spec.velocity
	b.angular_velocity = Vector3.ZERO
	_held_vel[spec.id] = spec.velocity


## Godot'nun fiziğe giren alanlarını bizim modele göre sabitler.
func _apply_body_fields(b: RigidBody3D, spec: PhysicsBackend.BodySpec) -> void:
	b.mass = spec.mass
	b.gravity_scale = 1.0
	# Projenin varsayılan sönümü (0.1) de etkilemesin: REPLACE + 0. Hava
	# direnci bizim modelimizden gelir (Sim2Config → Hava).
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = 0.0
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.angular_damp = 0.0
	# Sekme Godot çarpışmasından değil yay-sönüm temasımızdan gelir.
	b.physics_material_override = null
	b.collision_mask = 0
	b.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO
	b.inertia = Vector3.ZERO
	b.can_sleep = false
	if b is Ball:
		(b as Ball).radius = spec.radius


func reset() -> void:
	_mirror_src = ""
	_mirror_dst = ""
	_mirror_sync = false
	for id in _specs:
		_reset_body(_specs[id])
	set_running(false)


func set_contact_mirror(source: String, target: String) -> bool:
	_mirror_src = source
	_mirror_dst = target
	return true


## Yay-sönüm temas kuvveti (yalnızca dikey). Konum/hız verilen cisim için.
func _contact_force(id: String, p: Vector3, v: Vector3) -> float:
	var spec: PhysicsBackend.BodySpec = _specs[id]
	var pen := (PhysicsBackend.GROUND_Y + spec.radius) - p.y
	if pen <= 0.0:
		return 0.0
	return maxf(_stiffness[id] * pen - _damping[id] * v.y, 0.0)


func _gravity() -> Vector3:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var dir: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN)
	return dir * g


## Duraklatma (READY / CHOICE): yalnızca İKİ TOP dondurulur, hızları saklanır.
## (Önceden PhysicsServer3D.set_active(false) ile bütün fizik sunucusu
## durduruluyordu; birkaç durdur/devam döngüsünden sonra motor Output'a
## 'Condition "p_elem->_root" is true' hatası basıyordu.)
func set_running(on: bool) -> void:
	_active = on
	var resumed := false
	for id in _bodies:
		var b: RigidBody3D = _bodies[id]
		if on and b.freeze:
			resumed = true
			b.freeze = false
			b.linear_velocity = _held_vel.get(id, Vector3.ZERO)
			b.angular_velocity = Vector3.ZERO
		elif not on and not b.freeze:
			_held_vel[id] = b.linear_velocity
			b.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			b.freeze = true
	if resumed and _mirror_dst != "":
		_mirror_sync = true


func shutdown() -> void:
	for id in _bodies:
		var b: RigidBody3D = _bodies[id]
		if is_instance_valid(b):
			b.set("integrator", Callable())
	_active = true
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = _saved_ticks


func set_external_force(id: String, force: Vector3) -> void:
	_ext[id] = force
	var s: PhysicsBackend.BodyState = _state.get(id)
	if s:
		s.f_external = force

func set_position(id: String, pos: Vector3) -> void:
	var b: RigidBody3D = _bodies.get(id)
	if b:
		b.global_position = pos
	var s: PhysicsBackend.BodyState = _state.get(id)
	if s:
		s.position = pos

func set_velocity(id: String, vel: Vector3) -> void:
	var b: RigidBody3D = _bodies.get(id)
	if b:
		b.linear_velocity = vel
		if b.freeze:
			_held_vel[id] = vel   # devam edince bu hızla başlasın
	_v_prev[id] = vel   # dışarıdan atanan hız Fnet'te sahte sıçrama yaratmasın
	var s: PhysicsBackend.BodyState = _state.get(id)
	if s:
		s.velocity = vel

func get_state(id: String) -> PhysicsBackend.BodyState:
	return _state.get(id)


## Her motor adımı BİTTİKTEN sonra, her top için (Ball._integrate_forces'tan).
## st = az önce biten adımın sonu; st.step = o adımın süresi.
func _integrate(id: String, st: PhysicsDirectBodyState3D) -> void:
	var spec: PhysicsBackend.BodySpec = _specs.get(id)
	if spec == null:
		return
	if (_bodies[id] as RigidBody3D).freeze:
		return   # duraklatılmış: ölçüm/kuvvet yok (bkz. set_running)
	if _mirror_sync and id == _mirror_dst:
		_mirror_sync = false
		var ss0 := PhysicsServer3D.body_get_direct_state((_bodies[_mirror_src] as RigidBody3D).get_rid())
		if ss0:
			st.linear_velocity = ss0.linear_velocity
			var t := st.transform
			t.origin.y = ss0.transform.origin.y
			st.transform = t
	var s: PhysicsBackend.BodyState = _state[id]
	var dt := st.step

	# --- biten adımın dış kuvvetini İMPULS olarak ver (bkz. ZAMANLAMA) ---
	var f_e: Vector3 = _ext[id]
	if f_e != Vector3.ZERO and dt > 0.0:
		st.apply_central_impulse(f_e * dt)
	var v := st.linear_velocity + (f_e * dt / spec.mass if dt > 0.0 else Vector3.ZERO)
	var p := st.transform.origin

	# Net kuvvet OLCUMU (biten adım): m·Δv/Δt — Yedek Çözücü ile aynı tanım.
	var f_net := Vector3.ZERO
	if dt > 0.0:
		f_net = spec.mass * (v - (_v_prev[id] as Vector3)) / dt
	_v_prev[id] = v

	# Önceki geri çağrıda temas kuvveti verildiyse, o kuvvet AZ ÖNCE biten
	# adımda (süresi dt) uygulandı: ölçümü burada, gerçek süreyle say.
	if _in_contact[id]:
		s.contact_step_count += 1
		s.contact_duration += dt

	# --- hava (seçili modele göre) — bir sonraki adım için kuvvet --------
	var f_d := Vector3.ZERO
	match _cfg.hava_modeli:
		Sim2Config.HavaModeli.GERCEKCI_KARE:
			f_d = PhysicsBackend.drag_force(v, spec.radius, spec.drag_coefficient, spec.air_density)
		Sim2Config.HavaModeli.GODOT_SONUM_DOGRUSAL:
			f_d = -spec.mass * _cfg.dogrusal_sonum * v
		_:
			f_d = Vector3.ZERO

	# --- temas (yalnızca sol top) — bir sonraki adım için kuvvet ---------
	var f_c := Vector3.ZERO
	var touching := false
	if spec.collisions_enabled:
		var pen := (PhysicsBackend.GROUND_Y + spec.radius) - p.y
		if pen > 0.0:
			touching = true
			var fn: float = _contact_force(id, p, v)
			f_c = Vector3(0.0, fn, 0.0)
			if not _in_contact[id]:
				s.contact_step_count = 0
				s.contact_duration = 0.0
				s.contact_peak = 0.0
			s.contact_peak = maxf(s.contact_peak, fn)
	if _in_contact[id] and not touching and id == "left":
		print("[Godot Melez] temas bitti: %d adım, %.2f ms, tepe N %.0f" % [
			s.contact_step_count, s.contact_duration * 1000.0, s.contact_peak])
	_in_contact[id] = touching

	# (a) aynalama: kaynak topun BU turdaki temas kuvveti — kaynağın durumunu
	# doğrudan fizik sunucusundan okuyoruz ki geri çağrı sırası önemli olmasın.
	var f_m := Vector3.ZERO
	if id == _mirror_dst and _mirror_src != "":
		var src: RigidBody3D = _bodies[_mirror_src]
		var ss := PhysicsServer3D.body_get_direct_state(src.get_rid())
		if ss:
			var sv := ss.linear_velocity + (_ext[_mirror_src] as Vector3) * ss.step / src.mass
			f_m = Vector3(0.0, _contact_force(_mirror_src, ss.transform.origin, sv), 0.0)
		f_e = f_m   # ekranda: sağdaki topa uygulanan kuvvet

	st.apply_central_force(f_d + f_c + f_m)

	_pending[id] = {
		"p": p, "v": v, "f_net": f_net, "f_d": f_d, "f_c": f_c, "f_e": f_e,
		"dt": dt, "g": st.total_gravity * spec.mass, "touching": touching,
	}


## main.gd her ilerleyen tikte çağırır: son motor adımının kaydını topla.
func step(_dt: float) -> void:
	for id in _specs:
		var s: PhysicsBackend.BodyState = _state[id]
		s.just_hit_ground = false
		if not _pending.has(id):
			continue
		var rec: Dictionary = _pending[id]
		_pending.erase(id)
		var was := s.touching_ground
		s.position = rec["p"]
		s.velocity = rec["v"]
		s.f_net = rec["f_net"]
		s.f_gravity = rec["g"]
		s.f_drag = rec["f_d"]
		s.f_contact = rec["f_c"]
		s.f_external = rec["f_e"]
		s.touching_ground = rec["touching"]
		s.just_hit_ground = s.touching_ground and not was
		s.contact_impulse = (rec["f_c"] as Vector3).y * float(rec["dt"])
