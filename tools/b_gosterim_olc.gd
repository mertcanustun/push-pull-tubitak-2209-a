extends SceneTree
## Adım E ölçümü: (b) gösteriminin dört modu, iki motorda.
## Tek bir çalışan sahnede modlar cfg'den CANLI değiştirilir (Remote
## sekmesinden değiştirmenin aynısı) — sahne yeniden yüklenmez.
##
##   godot --headless --path . --fixed-fps 60 --script tools/b_gosterim_olc.gd
##
## Ölçülen (süreler GERÇEK/izlenen saniye — --fixed-fps'te her kare 1/60 sn):
##   firlatma: seçimden topun ekrandan çıkışına kadar
##   tepe:     ekrana yazılan (formül) / gerçekten uçulan (yalnız kamera modları)
##   kamera:   en yüksek kamera konumu, tepeye varış, sekansın toplam süresi,
##             kamera son karede ana poza BİREBİR döndü mü

const DT := 1.0 / 60.0
var cfg: Sim2Config = load("res://config/sim2_config.tres")


func _initialize() -> void:
	print("| Motor | Mod | Fırlatma izlenme | Yazılan tepe | Uçulan tepe | Kamera en yüksek | Tepeye varış | Sekans toplam | Kamera geri döndü |")
	print("|---|---|---|---|---|---|---|---|---|")
	for motor in [Sim2Config.Backend.YEDEK_COZUCU, Sim2Config.Backend.GODOT_MELEZ]:
		cfg.backend = motor
		var main = load("res://scenes/main.tscn").instantiate()
		root.add_child(main)
		await process_frame
		for mode in [Sim2Config.BGosterim.HICBIRI, Sim2Config.BGosterim.FIRLATMA_AGIR_CEKIM,
				Sim2Config.BGosterim.KAMERA_TAKIP, Sim2Config.BGosterim.IKISI]:
			cfg.b_gosterim = mode   # canlı değişim — sahne aynı
			var r: Dictionary = await _run(main)
			print("| %s | %s | %.2f sn | %s | %s | %s | %s | %s | %s |" % [
				"Yedek" if motor == Sim2Config.Backend.YEDEK_COZUCU else "Godot Melez",
				Sim2Config.BGosterim.keys()[mode], r.launch, r.apex_txt,
				r.get("apex_sim", "—"), r.get("cam_max", "—"), r.get("t_apex", "—"),
				r.get("t_total", "—"), r.get("cam_ok", "—")])
		main.queue_free()
		await process_frame
	cfg.backend = Sim2Config.Backend.MUJOCO
	cfg.b_gosterim = Sim2Config.BGosterim.IKISI
	quit(0)


func _run(main) -> Dictionary:
	main.reset_sim()
	main.phase = main.Phase.FALLING
	main.running = true
	var bcam: BGosterimKamera = main._bcam
	var base: Transform3D = bcam.base_transform()
	var r := {}
	var chose := false
	var t := 0.0          # seçimden beri gerçek süre
	var escaped := false
	var follow_seen := false
	for i in 4000:
		await process_frame
		if main.phase == main.Phase.CHOICE and not chose:
			main._on_choice("b")
			chose = true
			t = 0.0
			continue
		if not chose:
			continue
		t += DT
		if not escaped and main._b_escaped:
			escaped = true
			r["launch"] = t
			var txt: String = main.hud._status.text
			r["apex_txt"] = txt.substr(txt.find("yaklaşık") + 9).split(" ")[0] + " m"
		if bcam.is_active():
			follow_seen = true
		if follow_seen and bcam.durum == BGosterimKamera.Durum.BEKLE and not r.has("t_apex"):
			r["t_apex"] = "%.2f sn" % t
			r["apex_sim"] = "%.0f m" % (main.hold_pos.y - main.cfg.radius)
		if escaped and not follow_seen and t > r.launch + 0.5:
			break   # kamera modu değil: bitti
		if follow_seen and not bcam.is_active():
			r["t_total"] = "%.2f sn" % t
			r["cam_max"] = "%.0f m" % bcam.max_camera_height()
			r["cam_ok"] = "EVET (birebir)" if main.camera.global_transform == base else "HAYIR"
			break
	if not r.has("launch"):
		r["launch"] = -1.0
		r["apex_txt"] = "?"
	return r
