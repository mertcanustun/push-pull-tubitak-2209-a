extends SceneTree
## Adım A ek doğrulama:
##   1) cfg.backend üç seçeneği de (MUJOCO/YEDEK_COZUCU/GODOT_MELEZ) hatasız çalışıyor mu
##   2) "Remote'tan canlı değiştirme" demosu: sekmeyi 0.76 -> 0.5 yap, sol topun
##      daha az sektiğini göster (backend.gd Backend enum switch + reset_sim tetikler)
const DT := 1.0 / 240.0

func _init() -> void:
	print("--- 1) backend enum testi ---")
	for b in [Sim2Config.Backend.MUJOCO, Sim2Config.Backend.YEDEK_COZUCU, Sim2Config.Backend.GODOT_MELEZ]:
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		main.cfg.backend = b
		main._build_backend()
		main.reset_sim()
		await process_frame
		print("backend enum=%s -> backend.backend_name()=%s" % [b, main.backend.backend_name()])
		main.queue_free()
		await process_frame

	print("")
	print("--- 2) canlı restitution demosu (0.76 -> 0.5) ---")
	var h76 := await _peak_height(0.76)
	var h50 := await _peak_height(0.50)
	print("restitution=0.76 -> sol topun sekme tepe yüksekliği: %.3f m" % h76)
	print("restitution=0.50 -> sol topun sekme tepe yüksekliği: %.3f m" % h50)
	print("beklenen: 0.50 değeri 0.76'dan BELİRGİN ŞEKİLDE düşük olmalı")
	quit(0)


func _peak_height(restitution: float) -> float:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg.backend = Sim2Config.Backend.YEDEK_COZUCU  # MuJoCo statik XML'den etkilenmez (bkz. not)
	main.cfg.restitution = restitution
	main._build_backend()   # Remote'tan "backend" değiştirmenin yaptığı şey — cfg'yi taze okur
	main.reset_sim()
	main.phase = main.Phase.FALLING
	main.running = true
	var t := 0.0
	var was_touching := false
	var left_contact_done := false
	var peak_y := -1.0
	var choice_made := false
	while t < 4.0:
		main._physics_process(DT)
		t += DT
		if main.phase == main.Phase.CHOICE and not choice_made:
			main._on_choice("a")
			choice_made = true
		var sl = main.backend.get_state("left")
		if was_touching and not sl.touching_ground:
			left_contact_done = true
		if left_contact_done and sl.velocity.y <= 0.0 and peak_y < 0.0:
			peak_y = sl.position.y - main.cfg.radius
			break
		was_touching = sl.touching_ground
	main.queue_free()
	await process_frame
	return peak_y
