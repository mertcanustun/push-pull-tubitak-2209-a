extends PhysicsBackend
class_name NativeBackend

## MuJoCo derlenmemisken calisan yedek arka uc.
## Yari-ortuk Euler + yay-sonum (spring-damper) temas modeli.
##
## Neden Godot'nun RigidBody3D'si degil: bize temas SIRASINDAKI kuvvet
## gerekiyor (oklarla gosterecegiz ve "gercek F" bundan cikacak).
## RigidBody3D impuls tabanlidir ve bu degeri disariya vermez.

const SUBSTEPS := 40            # 60 FPS'te h = 0.4 ms, temas suresi ~8 ms

var _state: Dictionary = {}     # id -> BodyState
var _stiffness: Dictionary = {} # id -> float (N/m)
var _damping: Dictionary = {}   # id -> float (N*s/m)


func backend_name() -> String:
	return "Native (GDScript integrator)"

func is_available() -> bool:
	return true


func add_body(spec: PhysicsBackend.BodySpec) -> void:
	super.add_body(spec)
	# Temas modeli: k sabit secilir, c geri tepme katsayisindan tureitilir.
	# zeta = -ln(e) / sqrt(pi^2 + ln(e)^2),  c = 2*zeta*sqrt(k*m)
	var k := 1.0e5
	var e: float = clampf(spec.restitution, 0.01, 0.99)
	var ln_e := log(e)
	var zeta := -ln_e / sqrt(PI * PI + ln_e * ln_e)
	_stiffness[spec.id] = k
	_damping[spec.id] = 2.0 * zeta * sqrt(k * spec.mass)
	_reset_body(spec)


func _reset_body(spec: PhysicsBackend.BodySpec) -> void:
	var s := PhysicsBackend.BodyState.new()
	s.position = spec.position
	s.velocity = spec.velocity
	s.mass = spec.mass
	s.f_gravity = spec.mass * PhysicsBackend.GRAVITY
	_state[spec.id] = s


func reset() -> void:
	for id in _specs:
		_reset_body(_specs[id])


func set_external_force(id: String, force: Vector3) -> void:
	var s: PhysicsBackend.BodyState = _state.get(id)
	if s:
		s.f_external = force

func set_position(id: String, pos: Vector3) -> void:
	var s: PhysicsBackend.BodyState = _state.get(id)
	if s:
		s.position = pos

func set_velocity(id: String, vel: Vector3) -> void:
	var s: PhysicsBackend.BodyState = _state.get(id)
	if s:
		s.velocity = vel

func get_state(id: String) -> PhysicsBackend.BodyState:
	return _state.get(id)


func step(dt: float) -> void:
	var h := dt / float(SUBSTEPS)
	for id in _specs:
		var spec: PhysicsBackend.BodySpec = _specs[id]
		var s: PhysicsBackend.BodyState = _state[id]

		var was_touching := s.touching_ground
		var v_before := s.velocity
		s.just_hit_ground = false
		var impulse := 0.0
		var contact_peak := Vector3.ZERO
		var touching := false

		for i in SUBSTEPS:
			var f_g := spec.mass * PhysicsBackend.GRAVITY
			var f_d := PhysicsBackend.drag_force(s.velocity, spec.radius, spec.drag_coefficient)
			var f_c := Vector3.ZERO

			# --- temas (yalnizca collisions_enabled ise) -------------------
			# Sag yarida bu blok hic calismaz: top zeminden gecer. Zaten
			# senaryo geregi orada sim zemine degdigi anda duracak.
			if spec.collisions_enabled:
				var penetration := (PhysicsBackend.GROUND_Y + spec.radius) - s.position.y
				if penetration > 0.0:
					touching = true
					var fn: float = _stiffness[id] * penetration - _damping[id] * s.velocity.y
					fn = maxf(fn, 0.0)   # zemin ceker degil, iter
					f_c = Vector3(0.0, fn, 0.0)
					impulse += fn * h
					if fn > contact_peak.y:
						contact_peak = f_c

			var f_total := f_g + f_d + f_c + s.f_external
			var accel := f_total / spec.mass
			# yari-ortuk Euler: once hiz, sonra konum (enerji acisindan kararli)
			s.velocity += accel * h
			s.position += s.velocity * h

			s.f_gravity = f_g
			s.f_drag = f_d
			s.f_contact = f_c

		# Kare boyunca olculen ortalama temas kuvveti daha okunakli bir ok verir
		if touching:
			s.f_contact = Vector3(0.0, impulse / dt, 0.0) if impulse > 0.0 else contact_peak
		else:
			s.f_contact = Vector3.ZERO

		s.touching_ground = touching
		s.contact_impulse = impulse
		s.just_hit_ground = touching and not was_touching
		# Net kuvvet OLCUMU: m * a, ivme sonlu farkla. MuJoCo arka ucunda da
		# ayni sekilde olculur, boylece iki okun anlami birebir ayni olur.
		s.f_net = spec.mass * (s.velocity - v_before) / dt
