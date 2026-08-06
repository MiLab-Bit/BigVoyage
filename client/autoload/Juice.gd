extends Node
## 手感层：震动 / 闪白 / 弹出 / 缩放撞击

signal shake_requested(amount: float, time: float)
signal flash_requested(color: Color, time: float)

var _shake_trauma := 0.0

func punch(node: CanvasItem, scale_to: float = 1.08, time: float = 0.12) -> void:
	if node == null:
		return
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var base: Vector2 = node.scale
	tw.tween_property(node, "scale", base * scale_to, time * 0.45)
	tw.tween_property(node, "scale", base, time * 0.55)

func float_label(parent: Node, text: String, pos: Vector2, color: Color = Color(1, 0.92, 0.55)) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.z_index = 100
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", 22)
	parent.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", pos + Vector2(0, -48), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)

func shake(amount: float = 8.0, time: float = 0.22) -> void:
	emit_signal("shake_requested", amount, time)

func flash(color: Color = Color(1, 1, 1, 0.25), time: float = 0.12) -> void:
	emit_signal("flash_requested", color, time)

func celebrate() -> void:
	shake(5.0, 0.18)
	flash(Color(1.0, 0.85, 0.35, 0.22), 0.16)
	Sfx.play_ok()

func deny_pulse() -> void:
	shake(3.0, 0.12)
	flash(Color(1.0, 0.25, 0.2, 0.18), 0.1)
	Sfx.play_deny()

func hit_impact(is_restraint: bool = false) -> void:
	if is_restraint:
		shake(10.0, 0.2)
		flash(Color(1.0, 0.45, 0.1, 0.28), 0.1)
		Sfx.play_restraint()
	else:
		shake(4.5, 0.12)
		Sfx.play_hit()

## 统一浮层入场：淡入 + 轻微回弹（短、有理由）
func present_overlay(dim: CanvasItem, panel: Control, fade: float = 0.16) -> void:
	if dim:
		dim.modulate.a = 0.0
	if panel:
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.96, 0.96)
	var tw := create_tween()
	tw.set_parallel(true)
	if dim:
		tw.tween_property(dim, "modulate:a", 1.0, fade)
	if panel:
		tw.tween_property(panel, "modulate:a", 1.0, fade + 0.04)
		tw.tween_property(panel, "scale", Vector2.ONE, fade + 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
