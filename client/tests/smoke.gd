extends SceneTree
## 兼容旧入口：转发提示改用 Smoke.tscn
func _init() -> void:
	printerr("[smoke] 请改用: godot --headless --path . res://tests/Smoke.tscn")
	quit(2)
