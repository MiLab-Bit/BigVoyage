extends CanvasLayer
signal finished(won: bool)

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Center/Panel
@onready var title: Label = $Center/Panel/Margin/VBox/Title
@onready var log_box: RichTextLabel = $Center/Panel/Margin/VBox/Log
@onready var bar_a: ProgressBar = $Center/Panel/Margin/VBox/Bars/BarA
@onready var bar_b: ProgressBar = $Center/Panel/Margin/VBox/Bars/BarB
@onready var lbl_a: Label = $Center/Panel/Margin/VBox/Bars/LblA
@onready var lbl_b: Label = $Center/Panel/Margin/VBox/Bars/LblB
@onready var skip_btn: Button = $Center/Panel/Margin/VBox/Skip

var _result: Dictionary
var _playing := false
var _skip := false
var _hp_a := 0.0
var _hp_b := 0.0
var _max_a := 1.0
var _max_b := 1.0

func _ready() -> void:
	skip_btn.pressed.connect(func(): _skip = true)
	dim.modulate.a = 0.0
	panel.pivot_offset = panel.custom_minimum_size * 0.5
	panel.scale = Vector2(0.92, 0.92)
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.2)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func play(result: Dictionary, isl: Dictionary) -> void:
	_result = result
	title.text = "海战 · %s" % isl.get("name", "")
	_max_a = max(1.0, _sum_max(result.get("units_a", [])))
	_max_b = max(1.0, _sum_max(result.get("units_b", [])))
	# bars start full; we replay damage from log so reset to max
	_hp_a = _max_a
	_hp_b = _max_b
	# Rebuild max from spawn HP by reversing final HP + log damage is hard;
	# use final units max_hp fields (still present after battle).
	_max_a = max(1.0, _sum_field(result.get("units_a", []), "max_hp"))
	_max_b = max(1.0, _sum_field(result.get("units_b", []), "max_hp"))
	_hp_a = _max_a
	_hp_b = _max_b
	bar_a.max_value = _max_a
	bar_b.max_value = _max_b
	bar_a.value = _max_a
	bar_b.value = _max_b
	lbl_a.text = "我方舰队"
	lbl_b.text = "护岛者"
	_style_bars()
	log_box.clear()
	await get_tree().process_frame
	_playing = true
	await _run_log()
	_playing = false
	var won := str(result.get("winner", "")) == "A"
	# snap to final HP
	_hp_a = _sum_field(result.get("units_a", []), "hp")
	_hp_b = _sum_field(result.get("units_b", []), "hp")
	bar_a.value = _hp_a
	bar_b.value = _hp_b
	var end := "胜利" if won else "败北"
	log_box.append_text("\n\n[b]%s[/b] · %d 回合 · hash %s" % [end, int(result.get("rounds", 0)), result.get("hash", "")])
	if won:
		Juice.celebrate()
	else:
		Juice.deny_pulse()
	await get_tree().create_timer(0.85).timeout
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 0.0, 0.2)
	tw.parallel().tween_property(panel, "modulate:a", 0.0, 0.2)
	await tw.finished
	emit_signal("finished", won)
	queue_free()

func _style_bars() -> void:
	var fa := StyleBoxFlat.new()
	fa.bg_color = Color(0.35, 0.75, 0.55)
	fa.set_corner_radius_all(4)
	bar_a.add_theme_stylebox_override("fill", fa)
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0.9, 0.4, 0.35)
	fb.set_corner_radius_all(4)
	bar_b.add_theme_stylebox_override("fill", fb)

func _sum_max(units: Array) -> float:
	return _sum_field(units, "max_hp")

func _sum_field(units: Array, key: String) -> float:
	var s := 0.0
	for u in units:
		s += float(u.get(key, 0))
	return s

func _run_log() -> void:
	var log: Array = _result.get("log", [])
	for entry in log:
		if _skip:
			break
		var t: String = str(entry.get("t", ""))
		match t:
			"hit":
				var dmg := int(entry.get("dmg", 0))
				var coef := float(entry.get("restraint", 1.0))
				var is_r := coef > 1.05
				var line := "%s → %s  [color=#ffd166]-%d[/color]" % [entry.get("name_a", "?"), entry.get("name_t", "?"), dmg]
				if is_r:
					line += "  [color=#e85d04]克制×%.2f[/color]" % coef
				elif coef < 0.95:
					line += "  [color=#adb5bd]被克×%.2f[/color]" % coef
				log_box.append_text(line + "\n")
				if str(entry.get("attacker", "")).begins_with("A"):
					_hp_b = max(0.0, _hp_b - float(dmg))
					bar_b.value = _hp_b
					Juice.hit_impact(is_r)
				else:
					_hp_a = max(0.0, _hp_a - float(dmg))
					bar_a.value = _hp_a
					Juice.hit_impact(false)
				Juice.punch(panel, 1.012, 0.07)
			"dot":
				var dmg2 := int(entry.get("dmg", 0))
				log_box.append_text("[color=#e85d04]燃烧[/color] 跳 %d（层数 %s）\n" % [dmg2, str(entry.get("stacks", 1))])
				var tgt := str(entry.get("target", ""))
				if tgt.begins_with("B"):
					_hp_b = max(0.0, _hp_b - float(dmg2))
					bar_b.value = _hp_b
				else:
					_hp_a = max(0.0, _hp_a - float(dmg2))
					bar_a.value = _hp_a
			"kill":
				log_box.append_text("[color=#ff6b6b]击破！[/color]\n")
				Juice.shake(7, 0.15)
			"start":
				log_box.append_text("交战开始 · seed %s\n" % str(entry.get("seed", 0)))
		if not _skip:
			await get_tree().create_timer(0.06).timeout
	if _skip:
		_hp_a = _sum_field(_result.get("units_a", []), "hp")
		_hp_b = _sum_field(_result.get("units_b", []), "hp")
		bar_a.value = _hp_a
		bar_b.value = _hp_b
