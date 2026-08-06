extends CanvasLayer
## 兼容旧入口：转发到 SystemsMenu

func _ready() -> void:
	var parent := get_parent()
	queue_free()
	parent.add_child(load("res://ui/systems/SystemsMenu.gd").new())
