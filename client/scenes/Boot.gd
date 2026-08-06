extends Control
## Boot：淡入 slogan → 进入主海图

func _ready() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var boot_tex := AssetDB.env("env_boot_frozen")
	if boot_tex:
		bg.texture = boot_tex
	else:
		bg.modulate = Color(0.04, 0.07, 0.12)
	add_child(bg)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.04, 0.08, 0.45)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	Bgm.play_boot()

	var title := Label.new()
	title.text = "大航海"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.modulate = Color(0.95, 0.88, 0.65, 0.0)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title)

	var sub := Label.new()
	sub.text = "沉没的世界，由你的航线重建秩序"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.modulate = Color(0.65, 0.78, 0.95, 0.0)
	sub.anchor_left = 0
	sub.anchor_right = 1
	sub.anchor_top = 0.58
	sub.anchor_bottom = 0.58
	sub.offset_top = 0
	sub.offset_bottom = 36
	add_child(sub)

	var tip := Label.new()
	tip.text = "四海域 · 36 岛 · 赛季联航"
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 16)
	tip.modulate = Color(0.5, 0.6, 0.7, 0.0)
	tip.anchor_left = 0
	tip.anchor_right = 1
	tip.anchor_top = 0.68
	tip.anchor_bottom = 0.68
	tip.offset_bottom = 28
	add_child(tip)

	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.55)
	tw.parallel().tween_property(sub, "modulate:a", 1.0, 0.7).set_delay(0.2)
	tw.parallel().tween_property(tip, "modulate:a", 1.0, 0.5).set_delay(0.45)
	tw.tween_interval(0.85)
	tw.tween_property(title, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(sub, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(tip, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		_enter()
	)

func _enter() -> void:
	await ComplianceGate.ensure_interactive()
	if App.flag("narrative", true) and not bool(GameState.tutorial_flags.get("nar_prologue", false)):
		await NarrativeDirector.play_chapter("prologue")
	App.goto_main()
