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
## ZAMANLAMA — neden step() boş değil:
## Godot bir fizik tikinde önce düğümlerin _physics_process'ini (main.gd),
## SONRA fizik sunucusunu adımlar. _integrate_forces adımın BAŞINDA çağrılır.
## Bu yüzden:
##   - _integrate_forces (adım k): kuvvetleri hesaplar/uygular, adımın başındaki
##     hızı ve uygulanan kuvvetleri bir "bekleyen kayıt"a yazar;
##   - step() (bir sonraki tikte main.gd çağırır): adım k'nın SONUCUNU
##     (node'un güncel konumu/hızı) kayıtla birleştirip BodyState'i doldurur.
## Böylece main.gd'nin _after_step'i, Yedek Çözücü'deki gibi "adımdan sonraki"
## durumu görür; oklar/HUD değişmeden çalışır.
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
var _in_contact: Dictionary = {} # id -> bool (son adımda temas var mıydı)
var _active := true
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
	# NativeBackend ile aynı temas modeli: k seçilir, c sekmeden türetilir.
	var k := spec.stiffness
	var e: float = clampf(spec.restitution, 0.01, 0.99)
	var ln_e := log(e)
	var zeta := -ln_e / sqrt(PI * PI + ln_e * ln_e)
	_stiffness[spec.id] = k
	_damping[spec.id] = 2.0 * zeta * sqrt(k * spec.mass)

	var b: RigidBody3D = _bodies[spec.id]
	b.mass = spec.mass
	b.gravity_scale = 1.0
	# Projenin varsayılan sönümü (0.1) de etkilemesin: REPLACE + 0.
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = 0.0
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.angular_damp = 0.0
	b.collision_mask = 0
	b.can_sleep = false
	var id: String = spec.id
	b.set("integrator", func(st: PhysicsDirectBodyState3D) -> void: _integrate(id, st))
	_ext[spec.id] = Vector3.ZERO
	_reset_body(spec)


func _reset_body(spec: PhysicsBackend.BodySpec) -> void:
	var s := PhysicsBackend.BodyState.new()
	s.position = spec.position
	s.velocity = spec.velocity
	s.mass = spec.mass
	s.f_gravity = spec.mass * _gravity()
	_state[spec.id] = s
	_pending.erase(spec.id)
	_in_contact[spec.id] = false
	_ext[spec.id] = Vector3.ZERO
	var b: RigidBody3D = _bodies[spec.id]
	b.global_transform = Transform3D(Basis(), spec.position)
	b.linear_velocity = spec.velocity
	b.angular_velocity = Vector3.ZERO


func reset() -> void:
	for id in _specs:
		_reset_body(_specs[id])
	set_running(false)


func _gravity() -> Vector3:
	var g: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var dir: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN)
	return dir * g


func set_running(on: bool) -> void:
	if on == _active:
		return
	_active = on
	PhysicsServer3D.set_active(on)


func shutdown() -> void:
	for id in _bodies:
		var b: RigidBody3D = _bodies[id]
		if is_instance_valid(b):
			b.set("integrator", Callable())
	PhysicsServer3D.set_active(true)
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
	var s: PhysicsBackend.BodyState = _state.get(id)
	if s:
		s.velocity = vel

func get_state(id: String) -> PhysicsBackend.BodyState:
	return _state.get(id)


## Godot fizik adımının BAŞINDA, her top için (Ball._integrate_forces'tan).
func _integrate(id: String, st: PhysicsDirectBodyState3D) -> void:
	var spec: PhysicsBackend.BodySpec = _specs.get(id)
	if spec == null:
		return
	var s: PhysicsBackend.BodyState = _state[id]
	var p := st.transform.origin
	var v := st.linear_velocity
	var dt := st.step

	# --- hava (seçili modele göre) ---------------------------------------
	var f_d := Vector3.ZERO
	match _cfg.hava_modeli:
		Sim2Config.HavaModeli.GERCEKCI_KARE:
			f_d = PhysicsBackend.drag_force(v, spec.radius, spec.drag_coefficient, spec.air_density)
		Sim2Config.HavaModeli.GODOT_SONUM_DOGRUSAL:
			f_d = -spec.mass * _cfg.dogrusal_sonum * v
		_:
			f_d = Vector3.ZERO

	# --- temas (yalnızca sol top) ---------------------------------------
	var f_c := Vector3.ZERO
	var touching := false
	if spec.collisions_enabled:
		var pen := (PhysicsBackend.GROUND_Y + spec.radius) - p.y
		if pen > 0.0:
			touching = true
			var fn: float = maxf(_stiffness[id] * pen - _damping[id] * v.y, 0.0)
			f_c = Vector3(0.0, fn, 0.0)
			if not _in_contact[id]:
				s.contact_step_count = 0
				s.contact_duration = 0.0
				s.contact_peak = 0.0
			s.contact_step_count += 1
			s.contact_duration += dt
			s.contact_peak = maxf(s.contact_peak, fn)
	if _in_contact[id] and not touching and id == "left":
		print("[Godot Melez] temas bitti: %d adım, %.2f ms, tepe N %.0f  (adım %.3f ms)" % [
			s.contact_step_count, s.contact_duration * 1000.0, s.contact_peak, dt * 1000.0])
	_in_contact[id] = touching

	var f_e: Vector3 = _ext[id]
	st.apply_central_force(f_d + f_c + f_e)

	_pending[id] = {
		"v0": v, "dt": dt, "f_d": f_d, "f_c": f_c, "f_e": f_e,
		"g": st.total_gravity * spec.mass, "touching": touching,
	}


## main.gd her ilerleyen tikte çağırır: bir önceki Godot adımının sonucunu topla.
func step(_dt: float) -> void:
	for id in _specs:
		var s: PhysicsBackend.BodyState = _state[id]
		s.just_hit_ground = false
		if not _pending.has(id):
			continue
		var rec: Dictionary = _pending[id]
		_pending.erase(id)
		var b: RigidBody3D = _bodies[id]
		var was := s.touching_ground
		s.position = b.global_position
		s.velocity = b.linear_velocity
		var dt: float = rec["dt"]
		if dt > 0.0:
			# Net kuvvet OLCUMU: m·Δv/Δt — Yedek Çözücü ile aynı tanım.
			s.f_net = s.mass * (s.velocity - (rec["v0"] as Vector3)) / dt
		s.f_gravity = rec["g"]
		s.f_drag = rec["f_d"]
		s.f_contact = rec["f_c"]
		s.f_external = rec["f_e"]
		s.touching_ground = rec["touching"]
		s.just_hit_ground = s.touching_ground and not was
		s.contact_impulse = (rec["f_c"] as Vector3).y * dt
