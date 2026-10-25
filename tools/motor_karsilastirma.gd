extends SceneTree
## Adım D kabul testi: üç fizik motorunu GERÇEK oyun döngüsünde karşılaştırır
## (Godot Melez'de adımları motor attığı için _physics_process elle
## çağrılamaz). Sol topun İLK temasını ölçer:
##   ilk sekme yüksekliği, temas süresi (simüle ms), tepe N, temas adım
##   sayısı, ölçülen sekme katsayısı e = v_çıkış / v_giriş.
##
##   godot --headless --path . --fixed-fps 60 --script tools/motor_karsilastirma.gd
## (--fixed-fps: kareler gerçek zamanı beklemeden, sabit adımla akar.)

const MOTORLAR := [
	[Sim2Config.Backend.MUJOCO, "MuJoCo"],
	[Sim2Config.Backend.YEDEK_COZUCU, "Yedek Çözücü"],
	[Sim2Config.Backend.GODOT_MELEZ, "Godot Melez"],
]

var cfg: Sim2Config = load("res://config/sim2_config.tres")


func _initialize() -> void:
	print("proje yerçekimi: %s m/s²   fizik motoru: %s" % [
		ProjectSettings.get_setting("physics/3d/default_gravity"),
		ProjectSettings.get_setting("physics/3d/physics_engine")])
	var rows: Array = []
	for m in MOTORLAR:
		if m[0] == Sim2Config.Backend.MUJOCO and not MuJoCoBackend.extension_present():
			rows.append([m[1], null])
			continue
		rows.append([m[1], await _olc(m[0])])
	var brows: Array = []
	for m in MOTORLAR:
		if m[0] == Sim2Config.Backend.MUJOCO and not MuJoCoBackend.extension_present():
			brows.append([m[1], null])
			continue
		brows.append([m[1], await _olc_b(m[0])])
	cfg.backend = Sim2Config.Backend.MUJOCO   # paylaşılan kaynağı geri al

	print("")
	print("| Motor | İlk sekme (m) | Temas (ms) | Tepe N | Temas adımı | Adım (ms) | e (ölçülen) |")
	print("|---|---|---|---|---|---|---|")
	for r in rows:
		if r[1] == null:
			print("| %s | yok | yok | yok | yok | yok | yok |" % r[0])
		else:
			var d: Dictionary = r[1]
			print("| %s | %.3f | %.2f | %.0f | %d | %.4f | %.3f |" % [r[0], d.h, d.ms, d.peak, d.steps, d.adim_ms, d.e])
	print("")
	print("| Motor | (b) en yüksek hız (m/s) | (b) tepe noktası (yazılan) |")
	print("|---|---|---|")
	for r in brows:
		if r[1] == null:
			print("| %s | yok | yok |" % r[0])
		else:
			print("| %s | %.0f | %s |" % [r[0], r[1].vmax, r[1].apex])
	quit(0)


## (b) seçeneği: sağdaki topun ulaştığı en yüksek hız ve ekrana yazılan tepe noktası.
func _olc_b(motor: int) -> Dictionary:
	cfg.backend = motor
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.reset_sim()
	main.phase = main.Phase.FALLING
	main.running = true
	var chose := false
	var vmax := 0.0
	for i in 20000:
		await physics_frame
		if main.phase == main.Phase.CHOICE and not chose:
			main._on_choice("b")
			chose = true
		if chose and not main.hold_right:
			vmax = maxf(vmax, main.backend.get_state("right").velocity.y)
		if main.hold_right and main.hold_pos.y > 1.0:
			break
	var txt: String = main.hud._status.text
	var apex := txt.substr(txt.find("tepe noktası"))
	main.queue_free()
	await process_frame
	return {"vmax": vmax, "apex": apex}


func _olc(motor: int) -> Dictionary:
	cfg.backend = motor
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.reset_sim()
	main.phase = main.Phase.FALLING
	main.running = true
	var r := main.cfg.radius as float
	var chose := false
	var was := false
	var contact_done := false
	var v_in := 0.0
	var v_out := 0.0
	var res := {}
	var v_prev := 0.0
	for i in 20000:
		await physics_frame
		if main.phase == main.Phase.CHOICE and not chose:
			main._on_choice("a")
			chose = true
		var s = main.backend.get_state("left")
		if s.touching_ground and not was and not contact_done:
			v_in = absf(v_prev)   # temastan HEMEN ÖNCEKİ hız
		if was and not s.touching_ground and not contact_done:
			contact_done = true
			v_out = s.velocity.y
			res = {"ms": s.contact_duration * 1000.0, "peak": s.contact_peak,
				"steps": s.contact_step_count,
				"adim_ms": s.contact_duration * 1000.0 / maxf(s.contact_step_count, 1),
				"e": v_out / maxf(v_in, 1e-6)}
		if contact_done and s.velocity.y <= 0.0:
			res["h"] = s.position.y - r
			break
		was = s.touching_ground
		v_prev = s.velocity.y
	main.queue_free()
	await process_frame
	return res

