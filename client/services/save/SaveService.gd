extends RefCounted
class_name SaveService
## 存档门面 — 当前委托 GameState；日后可换槽位/云存

const SAVE_PATH := "user://voyage_save.json"

static func save() -> void:
	GameState.save_game()

static func load_or_new() -> void:
	if not GameState.load_game():
		GameState.new_game()

static func exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

static func reset() -> void:
	GameState.new_game()
