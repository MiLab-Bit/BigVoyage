extends Node
## 跨场景弱耦合事件总线（UI / 演出 / 链 订阅；结算核不依赖本总线）

signal day_advanced(day: int)
signal island_selected(island_id: String)
signal sailed(from_id: String, to_id: String)
signal poi_resolved(island_id: String, result: Dictionary)
signal battle_resolved(island_id: String, result: Dictionary)
signal island_captured(island_id: String)
signal fleet_changed(fleet: Array)
signal toast_requested(msg: String)
signal chain_commit_done(receipt: Dictionary)
signal codex_opened
signal gacha_pull_done(results: Array)

func _ready() -> void:
	# 桥接 GameState 已有信号，避免双轨漏发
	if GameState.has_signal("day_advanced"):
		GameState.day_advanced.connect(func(d): day_advanced.emit(d))
	if GameState.has_signal("island_captured"):
		GameState.island_captured.connect(func(id): island_captured.emit(id))
	if GameState.has_signal("toast"):
		GameState.toast.connect(func(m): toast_requested.emit(m))
