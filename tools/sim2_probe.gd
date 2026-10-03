extends SceneTree
## Adım A gerileme testi: a/b/c senaryolarının ölçümlerini çıkarır.
## --headless ile çalışır (yalnızca fizik, render gerekmez).
##   godot --headless --path . --script tools/sim2_probe.gd
##
## Ölçülenler:
##   - sol topun ilk sekme tepe yüksekliği (m)
##   - (soldaki) ilk temas süresi (ms) ve temas sırasındaki tepe N
##   - (b): sağdaki topun ekrandan çıkıp çıkmadığı + tepe noktası (m)
##   - (c): sağdaki topun seçimden sonra durup durmadığı (konum/hız sabit mi)

const DT := 1.0 / 240.0  # ince adım - ölçüm hassasiyeti için

func _init() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	print("backend: ", main.backend.backend_name())
	print("")

	_measure_left_bounce(main)
	print("")
	_measure_option(main, "b")
	print("")
	_measure_option(main, "c")

	quit(0)


## Soldaki topun İLK sekmesinin tepe yüksekliğini ve temas süresini ölçer.
## Sağ taraf için henüz bir seçim yapılmadığından etkilenmez.
func _measure_left_bounce(main) -> void:
	main.reset_sim()
	main.phase = main.Phase.FALLING
	main.running = true

	var t := 0.0
	var was_touching := false
	var contact_t0 := -1.0
	var contact_t1 := -1.0
	var peak_n := 0.0
	var post_bounce_peak_y := -1.0
	var left_contact_done := false
	var max_t := 4.0
	var choice_made := false

	while t < max_t:
		main._physics_process(DT)
		t += DT
		# Sağ top da aynı anda yere değip faz CHOICE'a geçiyor; o an stepping
		# tamamen duruyor (_physics_process bunu bekliyor). Soldaki topun
		# sekmesini TAMAMLAYABİLMESİ için herhangi bir seçimle (burada "a")
		# devam ettiriyoruz — bu, soldaki topun fiziğini ETKİLEMEZ.
		if main.phase == main.Phase.CHOICE and not choice_made:
			main._on_choice("a")
			choice_made = true
		var sl = main.backend.get_state("left")
		if sl == null:
			break
		if sl.touching_ground and not was_touching:
			contact_t0 = t
		if sl.touching_ground:
			peak_n = maxf(peak_n, sl.f_contact.length())
		if was_touching and not sl.touching_ground:
			contact_t1 = t
			left_contact_done = true
		if left_contact_done and sl.velocity.y <= 0.0 and post_bounce_peak_y < 0.0:
			post_bounce_peak_y = sl.position.y - 0.119  # BALL_RADIUS
			break
		was_touching = sl.touching_ground

	print("SOL TOP (ilk sekme):")
	print("  temas süresi: %.2f ms" % ((contact_t1 - contact_t0) * 1000.0 if contact_t1 > 0 else -1.0))
	print("  tepe N (temas sırasında): %.0f N" % peak_n)
	print("  sekme sonrası tepe yükseklik: %.3f m" % post_bounce_peak_y)


func _measure_option(main, choice: String) -> void:
	main.reset_sim()
	main.phase = main.Phase.FALLING
	main.running = true
	var t := 0.0
	var max_t := 6.0
	var chose := false
	while t < max_t:
		main._physics_process(DT)
		t += DT
		if main.phase == main.Phase.CHOICE and not chose:
			main._on_choice(choice)
			chose = true
		if choice == "b" and main.hold_right and main.hold_pos.y > 1.0:
			break
		if choice == "c" and chose and t > 2.0:
			break

	var sr = main.backend.get_state("right")
	print("SEÇENEK (%s):" % choice)
	if choice == "b":
		print("  ekrandan çıktı mı: %s  (hold_pos.y=%.1f)" % [str(main.hold_right), main.hold_pos.y])
		print("  durum metni: %s" % main.hud._status.text)
	elif choice == "c":
		print("  son hız: %s  (0'a yakın olmalı)" % str(sr.velocity))
		print("  son konum.y: %.3f  (sabit kalmalı)" % sr.position.y)
