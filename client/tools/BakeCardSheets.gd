extends SceneTree
## 20 卡正式 4 帧 sheet：godot --headless --path client -s res://tools/BakeCardSheets.gd
## 输出 res://assets/art/characters/anim/char_<ID>_sheet.png（横 4 等宽）

const CARD_IDS := [
	"FLAME_R_01", "FLAME_R_02", "FLAME_SR_01", "FLAME_SSR_01", "FLAME_UR_01",
	"IRON_R_01", "IRON_R_02", "IRON_SR_01", "IRON_SSR_01", "IRON_UR_01",
	"WIND_R_01", "WIND_R_02", "WIND_SR_01", "WIND_SSR_01", "WIND_UR_01",
	"TIDE_R_01", "TIDE_R_02", "TIDE_SR_01", "TIDE_SSR_01", "TIDE_UR_01",
]

func _init() -> void:
	print("[bake-sheets] start formal 4-frame sheets")
	var abs_out := ProjectSettings.globalize_path("res://assets/art/characters/anim")
	DirAccess.make_dir_recursive_absolute(abs_out)
	var n := 0
	for id in CARD_IDS:
		var sheet := _compose_sheet(id)
		if sheet == null:
			push_warning("[bake-sheets] skip %s (no source art)" % id)
			continue
		var path := "%s/char_%s_sheet.png" % [abs_out, id]
		sheet.save_png(path)
		n += 1
		print("[bake-sheets] ", id, " → ", path)
	print("[bake-sheets] done count=", n)
	quit(0 if n == 20 else 1)

func _compose_sheet(card_id: String) -> Image:
	var sources: Array = []
	for kind in ["head", "bust", "illu"]:
		var img := _load_card_art(card_id, kind)
		if img != null:
			sources.append(img)
	if sources.is_empty():
		return null
	# 保证至少 3 张源图循环使用
	while sources.size() < 3:
		sources.append(sources[sources.size() - 1].duplicate())
	var fw := 192
	var fh := 192
	var sheet := Image.create(fw * 4, fh, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var sys_tint := _sys_tint(card_id)
	# 帧语义：idle → windup → strike → recover（正式姿态，非软轮播）
	var poses: Array = [
		{"src": 0, "scale": 0.92, "oy": 6, "bright": 0.0, "outline": 0.35},
		{"src": 1, "scale": 0.98, "oy": 2, "bright": 0.05, "outline": 0.5},
		{"src": 2, "scale": 1.06, "oy": -4, "bright": 0.12, "outline": 0.75},
		{"src": 1, "scale": 0.96, "oy": 4, "bright": -0.04, "outline": 0.45},
	]
	for i in 4:
		var pose: Dictionary = poses[i]
		var src: Image = sources[int(pose.src) % sources.size()].duplicate()
		src.convert(Image.FORMAT_RGBA8)
		var tw := int(fw * float(pose.scale))
		var th := int(fh * float(pose.scale))
		src.resize(maxi(8, tw), maxi(8, th), Image.INTERPOLATE_LANCZOS)
		var frame := Image.create(fw, fh, false, Image.FORMAT_RGBA8)
		frame.fill(Color(0.03, 0.05, 0.08, 0.0))
		_fill_radial(frame, sys_tint.darkened(0.55), float(pose.bright))
		var ox := int((fw - src.get_width()) * 0.5)
		var oy := int((fh - src.get_height()) * 0.5) + int(pose.oy)
		frame.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(ox, oy))
		_apply_bright(frame, float(pose.bright))
		_outline(frame, sys_tint.lightened(0.15), float(pose.outline))
		_stamp_frame_index(frame, i)
		sheet.blit_rect(frame, Rect2i(0, 0, fw, fh), Vector2i(i * fw, 0))
	return sheet

func _load_card_art(card_id: String, kind: String) -> Image:
	var candidates: PackedStringArray = [
		"res://assets/art/characters/char_%s_%s.png" % [card_id, kind],
		"res://assets/art/characters/char_%s_%s.jpg" % [card_id, kind],
	]
	for p in candidates:
		if FileAccess.file_exists(p):
			var img := Image.new()
			if img.load(p) == OK:
				return img
	return null

func _sys_tint(card_id: String) -> Color:
	if card_id.begins_with("FLAME"):
		return Color(0.95, 0.45, 0.22)
	if card_id.begins_with("IRON"):
		return Color(0.55, 0.7, 0.85)
	if card_id.begins_with("WIND"):
		return Color(0.45, 0.85, 0.7)
	if card_id.begins_with("TIDE"):
		return Color(0.35, 0.55, 0.95)
	return Color(0.7, 0.75, 0.8)

func _fill_radial(img: Image, base: Color, bright: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w * 0.5
	var cy := h * 0.55
	for y in h:
		for x in w:
			var dx := (x - cx) / (w * 0.55)
			var dy := (y - cy) / (h * 0.55)
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d * 0.85, 0.0, 0.55)
			var c := base.lightened(bright * 0.4)
			c.a = a
			img.set_pixel(x, y, c)

func _apply_bright(img: Image, amount: float) -> void:
	if is_zero_approx(amount):
		return
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a <= 0.01:
				continue
			p.r = clampf(p.r + amount, 0.0, 1.0)
			p.g = clampf(p.g + amount * 0.9, 0.0, 1.0)
			p.b = clampf(p.b + amount * 0.7, 0.0, 1.0)
			img.set_pixel(x, y, p)

func _outline(img: Image, col: Color, strength: float) -> void:
	if strength <= 0.0:
		return
	var w := img.get_width()
	var h := img.get_height()
	var mask := []
	mask.resize(w * h)
	for y in h:
		for x in w:
			mask[y * w + x] = img.get_pixel(x, y).a > 0.35
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if mask[y * w + x]:
				continue
			var edge := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if mask[(y + oy) * w + (x + ox)]:
						edge = true
						break
				if edge:
					break
			if edge:
				var p := img.get_pixel(x, y)
				p = p.lerp(Color(col.r, col.g, col.b, strength), strength)
				img.set_pixel(x, y, p)

func _stamp_frame_index(img: Image, idx: int) -> void:
	var marks := [[2, 2], [6, 2], [2, 6], [6, 6]]
	var m: Array = marks[idx % 4]
	for dy in 3:
		for dx in 3:
			img.set_pixel(int(m[0]) + dx, int(m[1]) + dy, Color(1, 0.95, 0.75, 0.85))
