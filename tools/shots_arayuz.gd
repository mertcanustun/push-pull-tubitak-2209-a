extends SceneTree
## Arayüz doğrulama: farklı ekran boyutu / DPI'da açılış, seçim ve geri
## bildirim karelerini çeker. --headless İLE ÇALIŞMAZ (gerçek render gerekir).
##     godot --path . --script tools/shots_arayuz.gd -- --boyut=2340x1080 --arayuz-dpi=460 --ad=telefon_yatay
## --arayuz-dpi telefonu taklit eder (web'de DPI = 96 x devicePixelRatio).
## PNG'ler res://tools/shots_arayuz/ altına yazılır (ya da --cikis=<mutlak yol>).
var OUT := "res://tools/shots_arayuz"
var AD := "ekran"

func _init() -> void:
	var boyut := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--boyut="):
			var p := a.trim_prefix("--boyut=").split("x")
			boyut = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--ad="):
			AD = a.trim_prefix("--ad=")
		elif a.begins_with("--cikis="):
			OUT = a.trim_prefix("--cikis=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# proje "maximized" açılıyor; pencere yöneticisi bırakınca boyutla
	await process_frame
	root.mode = Window.MODE_WINDOWED
	await process_frame
	root.size = boyut
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _w(0.6)
	print("pencere=%s  olcek=%.3f  dp=%s  fov=%.1f" % [root.size, root.content_scale_factor,
		root.get_visible_rect().size, main.camera.fov])
	await _s("1_acilis")

	main._on_start()
	var waited := 0.0
	while int(main.phase) != 2 and waited < 6.0:
		await process_frame
		waited += 1.0 / 60.0
	await _w(0.3)
	await _s("2_secim")

	main._on_choice("c")
	await _w(0.5)
	await _s("3_geri_bildirim")
	quit(0)

func _w(sec: float) -> void:
	await create_timer(sec).timeout

func _s(n: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [OUT, AD, n])
