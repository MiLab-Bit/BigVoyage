extends CanvasLayer
## 科技屏

const TechServiceScript := preload("res://systems/economy/TechService.gd")
const SystemsOverlayScript := preload("res://ui/systems/SystemsOverlay.gd")

var _body: RichTextLabel
var _actions: VBoxContainer

func _ready() -> void:
	var shell: Dictionary = SystemsOverlayScript.mount(self, "科技树", Vector2(720, 580))
	var v: VBoxContainer = shell.vbox
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size = Vector2(0, 72)
	v.add_child(_body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 380)
	v.add_child(scroll)
	_actions = VBoxContainer.new()
	_actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_actions)
	_refresh()

func _refresh() -> void:
	for c in _actions.get_children():
		c.queue_free()
	var unlocked := "（无）"
	if not GameState.tech_unlocked.is_empty():
		var ps := PackedStringArray()
		for x in GameState.tech_unlocked:
			ps.append(str(x))
		unlocked = ", ".join(ps)
	_body.text = "战略资源：[b]%d[/b]\n已解锁：%s" % [GameState.strategic, unlocked]
	for n in GameData.tech_tree.get("nodes", []):
		var id := str(n.get("id", ""))
		var b := Button.new()
		var owned := GameState.tech_unlocked.has(id)
		b.text = "[%s] %s · %d%s" % [n.get("tier", "?"), n.get("name", id), int(n.get("cost", 0)), " ✓" if owned else ""]
		b.disabled = owned
		b.pressed.connect(func():
			var r: Dictionary = TechServiceScript.unlock(id)
			if not bool(r.get("ok", false)):
				GameState.emit_signal("toast", str(r.get("reason", "失败")))
				Juice.deny_pulse()
				Sfx.play_deny()
			else:
				Sfx.play_event("sfx_ui_reward")
				Juice.punch(b)
				if id == "T4_tide_core":
					NarrativeDirector.try_chapter("tide_core")
				else:
					NarrativeDirector.try_chapter("first_tech")
			_refresh()
		)
		_actions.add_child(b)
