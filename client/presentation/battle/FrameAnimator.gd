extends RefCounted
class_name FrameAnimator
## 逐帧战斗：正式 4 帧 sheet（idle→windup→strike→recover）；缺 sheet 时用立绘合成兜底

static func attach(host: Node, tr: TextureRect, card_id: String) -> void:
	var frames: Array = _load_frames(card_id)
	if frames.is_empty():
		return
	var idx := {"i": 0}
	tr.texture = frames[0]
	var timer := Timer.new()
	timer.wait_time = 0.16
	timer.autostart = true
	timer.timeout.connect(func():
		if not is_instance_valid(tr):
			return
		idx.i = (idx.i + 1) % frames.size()
		tr.texture = frames[idx.i]
	)
	host.add_child(timer)

static func _load_frames(card_id: String) -> Array:
	var frames: Array = []
	var sheet_path := "res://assets/art/characters/anim/char_%s_sheet.png" % card_id
	if ResourceLoader.exists(sheet_path):
		var sheet: Texture2D = load(sheet_path)
		if sheet:
			var fw := int(sheet.get_width() / 4.0)
			var fh := sheet.get_height()
			if fw > 0 and fh > 0:
				for i in 4:
					var at := AtlasTexture.new()
					at.atlas = sheet
					at.region = Rect2(i * fw, 0, fw, fh)
					frames.append(at)
				return frames
	var soft: Array = []
	for tex in [AssetDB.card_head(card_id), AssetDB.card_bust(card_id), AssetDB.card_illu(card_id), AssetDB.card_bust(card_id)]:
		if tex != null:
			soft.append(tex)
	if soft.size() >= 2:
		return soft
	return soft
