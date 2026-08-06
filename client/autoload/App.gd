extends Node
## 应用壳：场景路由 / Demo 功能开关 / 启动自检

const SCENE_BOOT := "res://scenes/Boot.tscn"
const SCENE_MAIN := "res://scenes/Main.tscn"
const SCENE_SMOKE := "res://tests/Smoke.tscn"
const SCENE_T3 := "res://tests/T3.tscn"

const VoyageThemeScript := preload("res://themes/VoyageTheme.gd")

## 功能开关：全海默认开；本机完整免费体验（无内购）
var feature_flags := {
	"map": true,
	"poi": true,
	"battle": true,
	"fleet": true,
	"economy_skip30": true,
	"chain_mock": true,
	"true_name_ui": true,
	"codex": true,
	"gacha": true,
	"gacha_grants": true,
	"demo_soft_poi": true,
	"strict_poi": false,
	"tutorial": true,
	"narrative": true,
	"ops": true,
	"full_world": true,  # 默认 36 岛全海
	"llm_harbor": true,  # 港主简报（需 llm.local.json）
}

func _ready() -> void:
	var theme := VoyageThemeScript.build()
	get_tree().root.theme = theme
	if bool(GameData.constants.get("FULL_WORLD_DEFAULT", true)):
		feature_flags["full_world"] = true
	print("[App] BigVoyage · G2=%s %s · full_world=%s · theme=voyage" % [
		EngineLock.ENGINE, EngineLock.ENGINE_VERSION,
		str(feature_flags.get("full_world", true)),
	])

func goto_main() -> void:
	get_tree().change_scene_to_file(SCENE_MAIN)

func goto_boot() -> void:
	get_tree().change_scene_to_file(SCENE_BOOT)

func flag(key: String, default: bool = false) -> bool:
	return bool(feature_flags.get(key, default))
