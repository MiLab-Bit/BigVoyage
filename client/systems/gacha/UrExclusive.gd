extends RefCounted
class_name UrExclusive
## UR 独占机制文案（欲望点=机制独占）

static func catalog() -> Dictionary:
	var path := "res://data/ur_exclusive.json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed.get("entries", {})

static func blurb(card_id: String) -> String:
	var e: Dictionary = catalog().get(card_id, {})
	if e.is_empty():
		return ""
	return "[UR 独占·%s] %s — %s" % [e.get("title", ""), e.get("hook", ""), e.get("desire", "")]

static func is_ur(card_id: String) -> bool:
	var c: Dictionary = GameData.cards.get(card_id, {})
	return str(c.get("rarity", "")) == "UR"
