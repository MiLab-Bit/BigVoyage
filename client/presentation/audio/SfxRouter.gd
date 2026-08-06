extends RefCounted
class_name SfxRouter
## 事件 ID → 当前 Sfx 程序音（素材到位后改为 AudioStream 表）
## 红线：只吃演出，不改 seed / 不回流结算

const BattleLogPresenterScript := preload("res://presentation/battle/BattleLogPresenter.gd")

static func play_event(event_id: String) -> void:
	if event_id == "":
		return
	var sfx = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Sfx")
	if sfx == null:
		return
	if event_id.begins_with("sfx_btl_hit"):
		sfx.play_hit()
	elif event_id.begins_with("sfx_btl_dot"):
		sfx.play_hit()
	elif event_id.begins_with("sfx_btl_kill"):
		sfx.play_ok()
	elif event_id.begins_with("sfx_btl_control"):
		sfx.play_deny()
	elif "restraint" in event_id:
		sfx.play_restraint()
	elif event_id.begins_with("sfx_ui"):
		sfx.play_select()
	else:
		pass  # 未映射：静默，待 需求文档/03-音效SFX 对表

static func play_from_battle_event(event: Dictionary) -> void:
	play_event(BattleLogPresenterScript.sfx_key_for(event))
