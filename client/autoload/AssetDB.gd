extends Node
## 运行时资产索引（对齐 需求文档/07-全量资产生产规划）

const ROOT := "res://assets/"

var _tex_cache: Dictionary = {}
var _missing: Dictionary = {}

func _ready() -> void:
	print("[AssetDB] ready · root=%s" % ROOT)

func card_illu(card_id: String) -> Texture2D:
	return _tex("art/characters/char_%s_illu.png" % card_id)

func card_bust(card_id: String) -> Texture2D:
	var t := _tex("art/characters/char_%s_bust.png" % card_id)
	if t == null:
		t = card_illu(card_id)
	return t

func card_head(card_id: String) -> Texture2D:
	var t := _tex("art/characters/char_%s_head.png" % card_id)
	if t == null:
		t = card_bust(card_id)
	return t

func skill_icon(card_id: String) -> Texture2D:
	return _tex("art/icons/icon_%s_skill.png" % card_id)

func sys_icon(sys: String) -> Texture2D:
	return _tex("art/icons/icon_sys_%s.png" % sys)

func env(name: String) -> Texture2D:
	var t := _tex("art/env/%s.png" % name)
	if t == null:
		t = _tex("art/env/%s.jpg" % name)
	return t

func island_concept(island_id: String) -> Texture2D:
	# 海域感知路径；缺省回退冻洋命名 / 图标 / 程序海图占位
	var sea := _island_sea(island_id)
	var candidates := [
		"art/env/islands/env_%s_%s_concept.png" % [sea, island_id],
		"art/env/islands/env_frozen_%s_concept.png" % island_id,
		"art/env/islands/env_island_%s_concept.png" % island_id,
	]
	for p in candidates:
		var t := _tex(p)
		if t != null:
			return t
	var icon := island_icon(island_id)
	if icon != null:
		return icon
	return _procedural_sea_art(island_id, sea, false)

func island_icon(island_id: String) -> Texture2D:
	var t := _tex("art/env/islands/env_island_%s_icon.png" % island_id)
	if t != null:
		return t
	var sea := _island_sea(island_id)
	if sea == "frozen":
		return null
	return _procedural_sea_art(island_id, sea, true)

func _island_sea(island_id: String) -> String:
	if Engine.get_main_loop() != null:
		var gd = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameData")
		if gd and gd.islands.has(island_id):
			return str(gd.islands[island_id].get("sea", "frozen"))
	if island_id.begins_with("AB_"):
		return "abyss"
	if island_id.begins_with("BL_"):
		return "blaze"
	if island_id.begins_with("TW_"):
		return "tradewind"
	return "frozen"

func _procedural_sea_art(island_id: String, sea: String, as_icon: bool) -> Texture2D:
	var cache_key := "proc_%s_%s" % [island_id, "icon" if as_icon else "concept"]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	var chart_name := "env_%s_chart_base" % sea
	if sea == "blaze":
		var blaze := env("env_blaze_chart_base")
		if blaze == null:
			chart_name = "env_hanhai_chart_base"
	var chart := env(chart_name)
	if chart == null:
		chart = env("env_map_frozen_sea")
	if chart == null:
		return null
	var src := chart.get_image()
	if src == null:
		return null
	var idx := 1
	var parts := island_id.split("_")
	if parts.size() >= 2:
		idx = int(parts[1])
	var tw := 128 if as_icon else 640
	var th := 128 if as_icon else 360
	var tile := maxi(32, mini(src.get_width(), src.get_height()) / 3)
	var ox := ((idx - 1) % 3) * tile
	var oy := (((idx - 1) / 3) % 3) * tile
	var crop := src.get_region(Rect2i(ox, oy, mini(tile, src.get_width() - ox), mini(tile, src.get_height() - oy)))
	crop.convert(Image.FORMAT_RGBA8)
	crop.resize(tw, th, Image.INTERPOLATE_BILINEAR)
	var tint := Color(0.7, 0.8, 1.0)
	match sea:
		"abyss":
			tint = Color(0.45, 0.6, 1.0)
		"blaze":
			tint = Color(1.0, 0.55, 0.3)
		"tradewind":
			tint = Color(0.4, 0.9, 0.8)
	for y in th:
		for x in tw:
			var p := crop.get_pixel(x, y)
			p.r = clampf(p.r * (0.5 + tint.r * 0.5), 0.0, 1.0)
			p.g = clampf(p.g * (0.5 + tint.g * 0.5), 0.0, 1.0)
			p.b = clampf(p.b * (0.5 + tint.b * 0.5), 0.0, 1.0)
			crop.set_pixel(x, y, p)
	var tex := ImageTexture.create_from_image(crop)
	_tex_cache[cache_key] = tex
	return tex

func narrative(name: String) -> Texture2D:
	return _tex("art/narrative/%s.png" % name)

func creature(name: String) -> Texture2D:
	return _tex("art/creatures/%s.png" % name)

func vfx(name: String) -> Texture2D:
	return _tex("art/vfx/%s.png" % name)

func ship(ship_id: String) -> Texture2D:
	var key := ship_id.to_lower().replace("ship_", "")
	if key == "iron":
		key = "iron"  # ship_iron.png
	var t := _tex("art/ships/ship_%s.png" % key)
	return t

func island_marker() -> Texture2D:
	return _tex("art/map/island_marker.png")

func ui(name: String) -> Texture2D:
	return _tex("art/ui/%s.png" % name)

func music_path(key: String) -> String:
	var candidates: PackedStringArray = [
		ROOT + "audio/music/%s.mp3" % key,
		ROOT + "audio/music/bgm_%s.mp3" % key,
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			return p
	return ""

func sfx_path(event_id: String) -> String:
	var aliases := {
		"sfx_btl_dot_flame": "sfx_btl_dot_burn",
		"sfx_btl_control_tide": "sfx_btl_control_stun",
		"sfx_ui_confirm": "sfx_ui_ok",
	}
	var eid := str(aliases.get(event_id, event_id))
	var groups := ["btl", "ui", "nav", "gacha", "nar"]
	for g in groups:
		var p := ROOT + "audio/sfx/%s/%s.wav" % [g, eid]
		if ResourceLoader.exists(p):
			return p
	for g in groups:
		var p2 := ROOT + "audio/sfx/%s/%s.wav" % [g, event_id]
		if ResourceLoader.exists(p2):
			return p2
	return ""

func coverage_snapshot() -> Dictionary:
	var cards_ok := 0
	for id in GameData.cards.keys():
		if card_illu(str(id)) != null and card_head(str(id)) != null:
			cards_ok += 1
	var islands_ok := 0
	for isl in GameData.island_list:
		var id := str(isl.get("id", ""))
		if island_concept(id) != null and island_icon(id) != null:
			islands_ok += 1
	return {
		"cards_full": cards_ok,
		"islands_full": islands_ok,
		"has_map": env("env_map_frozen_sea") != null or env("env_frozen_chart_base") != null,
		"has_bgm_bed": music_path("bgm_sea_frozen_bed") != "",
	}

func _tex(rel: String) -> Texture2D:
	if _tex_cache.has(rel):
		return _tex_cache[rel]
	if _missing.has(rel):
		return null
	var path := ROOT + rel
	var candidates: PackedStringArray = [path]
	if path.ends_with(".png"):
		candidates.append(path.get_basename() + ".jpg")
	elif path.ends_with(".jpg"):
		candidates.append(path.get_basename() + ".png")
	for c in candidates:
		if ResourceLoader.exists(c):
			var res = load(c)
			if res is Texture2D:
				_tex_cache[rel] = res
				return res
	_missing[rel] = true
	return null
