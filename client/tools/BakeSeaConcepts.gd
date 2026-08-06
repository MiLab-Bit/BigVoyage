extends SceneTree
## 非冻洋概念图定稿烘焙：godot --headless --path client -s res://tools/BakeSeaConcepts.gd
## 比占位版增加：海平线、地标剪影、色阶分层、暗角与锚点光

func _init() -> void:
	print("[bake] start non-frozen concept final pass")
	var out_dir := "res://assets/art/env/islands"
	var seas := {
		"abyss": {
			"chart": "res://assets/art/env/env_abyss_chart_base.png",
			"tint": Color(0.28, 0.48, 0.92),
			"sky": Color(0.05, 0.08, 0.18),
			"water": Color(0.08, 0.18, 0.42),
		},
		"blaze": {
			"chart": "res://assets/art/env/env_blaze_chart_base.png",
			"alt": "res://assets/art/env/env_hanhai_chart_base.png",
			"tint": Color(0.92, 0.42, 0.18),
			"sky": Color(0.22, 0.08, 0.05),
			"water": Color(0.35, 0.14, 0.08),
		},
		"tradewind": {
			"chart": "res://assets/art/env/env_tradewind_chart_base.png",
			"tint": Color(0.28, 0.82, 0.72),
			"sky": Color(0.08, 0.16, 0.2),
			"water": Color(0.1, 0.32, 0.34),
		},
	}
	var abs_out := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(abs_out)
	var n := 0
	for sea in seas.keys():
		var cfg: Dictionary = seas[sea]
		var chart_path := str(cfg.chart)
		if not FileAccess.file_exists(chart_path) and cfg.has("alt"):
			chart_path = str(cfg.alt)
		if not FileAccess.file_exists(chart_path):
			push_warning("[bake] missing chart %s" % chart_path)
			continue
		var chart_img := Image.new()
		if chart_img.load(chart_path) != OK:
			push_warning("[bake] load fail %s" % chart_path)
			continue
		for i in range(1, 10):
			var id := ""
			match sea:
				"abyss":
					id = "AB_%02d" % i
				"blaze":
					id = "BL_%02d" % i
				_:
					id = "TW_%02d" % i
			var concept := _make_concept(chart_img, cfg, id, i, sea)
			var icon := _make_icon(chart_img, cfg, id, i)
			var cpath := "%s/env_%s_%s_concept.png" % [abs_out, sea, id]
			var ipath := "%s/env_island_%s_icon.png" % [abs_out, id]
			concept.save_png(cpath)
			icon.save_png(ipath)
			n += 1
			print("[bake] ", id, " → concept+icon (final)")
	print("[bake] done count=", n)
	quit(0)

func _make_concept(chart: Image, cfg: Dictionary, id: String, idx: int, sea: String) -> Image:
	var w := 720
	var h := 405
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var sky: Color = cfg.sky
	var water: Color = cfg.water
	var tint: Color = cfg.tint
	# sky / sea bands
	for y in h:
		var t := float(y) / float(h)
		var band := sky.lerp(water, smoothstep(0.42, 0.62, t))
		band = band.lerp(tint.darkened(0.55), 0.18)
		for x in w:
			out.set_pixel(x, y, band)
	# chart crop as mid-ground texture
	var cw := chart.get_width()
	var ch := chart.get_height()
	var tile := maxi(64, mini(cw, ch) / 3)
	var ox := (idx % 3) * tile
	var oy := ((idx / 3) % 3) * tile
	var crop := chart.get_region(Rect2i(ox, oy, mini(tile, cw - ox), mini(tile, ch - oy)))
	crop.convert(Image.FORMAT_RGBA8)
	crop.resize(w, int(h * 0.72), Image.INTERPOLATE_LANCZOS)
	var cy := int(h * 0.22)
	for y in crop.get_height():
		for x in crop.get_width():
			var p := crop.get_pixel(x, y)
			var dest_y := cy + y
			if dest_y < 0 or dest_y >= h:
				continue
			var base := out.get_pixel(x, dest_y)
			p.r = clampf(p.r * (0.5 + tint.r * 0.6), 0.0, 1.0)
			p.g = clampf(p.g * (0.5 + tint.g * 0.6), 0.0, 1.0)
			p.b = clampf(p.b * (0.5 + tint.b * 0.6), 0.0, 1.0)
			var a := 0.55 + 0.25 * (1.0 - absf(float(y) / float(crop.get_height()) - 0.45))
			out.set_pixel(x, dest_y, base.lerp(p, clampf(a, 0.2, 0.85)))
	_draw_horizon(out, tint.lightened(0.1), int(h * 0.58))
	_draw_landmark(out, sea, idx, tint)
	_draw_beacon(out, tint, idx)
	_vignette(out, 0.55)
	_draw_frame(out, tint.lightened(0.25))
	_stamp_label(out, id)
	# boss islands get stronger rim
	if idx == 9:
		_draw_frame(out, Color(1.0, 0.85, 0.45, 1.0))
	return out

func _make_icon(chart: Image, cfg: Dictionary, id: String, idx: int) -> Image:
	var s := 144
	var out := Image.create(s, s, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.05, 0.07, 0.1, 1))
	var tint: Color = cfg.tint
	var cw := chart.get_width()
	var ch := chart.get_height()
	var tile := maxi(48, mini(cw, ch) / 3)
	var ox := (idx % 3) * tile
	var oy := ((idx / 3) % 3) * tile
	var crop := chart.get_region(Rect2i(ox, oy, mini(tile, cw - ox), mini(tile, ch - oy)))
	crop.convert(Image.FORMAT_RGBA8)
	crop.resize(s, s, Image.INTERPOLATE_LANCZOS)
	out.blit_rect(crop, Rect2i(0, 0, s, s), Vector2i(0, 0))
	_multiply_tint(out, tint)
	for y in s:
		for x in s:
			var dx := x - s * 0.5
			var dy := y - s * 0.5
			var d := sqrt(dx * dx + dy * dy) / (s * 0.52)
			var p := out.get_pixel(x, y)
			if d > 1.0:
				p.a = 0.0
			elif d > 0.78:
				p.a *= 1.0 - (d - 0.78) / 0.22
			out.set_pixel(x, y, p)
	if idx == 9:
		_draw_frame(out, Color(1.0, 0.82, 0.4, 1.0))
	_stamp_label(out, id.substr(0, 5))
	return out

func _draw_horizon(img: Image, col: Color, y0: int) -> void:
	var w := img.get_width()
	for x in w:
		var wobble := int(sin(x * 0.035) * 3.0)
		var yy := clampi(y0 + wobble, 0, img.get_height() - 1)
		var p := img.get_pixel(x, yy)
		img.set_pixel(x, yy, p.lerp(col, 0.55))
		if yy + 1 < img.get_height():
			var p2 := img.get_pixel(x, yy + 1)
			img.set_pixel(x, yy + 1, p2.lerp(col.darkened(0.3), 0.35))

func _draw_landmark(img: Image, sea: String, idx: int, tint: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var base_x := int(w * (0.28 + (idx % 3) * 0.18))
	var base_y := int(h * 0.62)
	var sil := tint.darkened(0.65)
	sil.a = 0.9
	match sea:
		"abyss":
			# spire
			for i in 28 + idx * 2:
				var yy := base_y - i
				var half := maxi(2, 14 - i / 3)
				for x in range(base_x - half, base_x + half):
					if yy >= 0 and yy < h and x >= 0 and x < w:
						img.set_pixel(x, yy, sil)
		"blaze":
			# crater ridge
			for i in 40:
				var yy := base_y - int(sin(i * 0.2) * 10.0) - i / 5
				var x := base_x - 20 + i
				for t in 6:
					var xxx := x
					var yyy := yy + t
					if yyy >= 0 and yyy < h and xxx >= 0 and xxx < w:
						img.set_pixel(xxx, yyy, sil)
		_:
			# sail / mast
			for i in 36:
				var yy := base_y - i
				if yy >= 0 and yy < h and base_x >= 0 and base_x < w:
					img.set_pixel(base_x, yy, sil)
					if i > 10 and i < 28:
						for dx in range(1, 12):
							var xxx := base_x + dx
							if xxx < w:
								img.set_pixel(xxx, yy + (dx / 4), sil.darkened(0.1))

func _draw_beacon(img: Image, tint: Color, idx: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var bx := int(w * (0.62 + (idx % 2) * 0.08))
	var by := int(h * 0.48)
	var glow := Color(tint.r, tint.g, tint.b, 0.35)
	for r in range(18, 0, -1):
		var a := 0.04 * float(18 - r)
		for y in range(by - r, by + r):
			for x in range(bx - r, bx + r):
				if x < 0 or y < 0 or x >= w or y >= h:
					continue
				var dx := x - bx
				var dy := y - by
				if dx * dx + dy * dy <= r * r:
					var p := img.get_pixel(x, y)
					img.set_pixel(x, y, p.lerp(glow, a))

func _vignette(img: Image, strength: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w * 0.5
	var cy := h * 0.5
	for y in h:
		for x in w:
			var dx := (x - cx) / (w * 0.62)
			var dy := (y - cy) / (h * 0.62)
			var d := sqrt(dx * dx + dy * dy)
			if d > 0.75:
				var p := img.get_pixel(x, y)
				var k := clampf((d - 0.75) / 0.55, 0.0, 1.0) * strength
				p = p.darkened(k)
				img.set_pixel(x, y, p)

func _multiply_tint(img: Image, tint: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			p.r = clampf(p.r * (0.55 + tint.r * 0.55), 0.0, 1.0)
			p.g = clampf(p.g * (0.55 + tint.g * 0.55), 0.0, 1.0)
			p.b = clampf(p.b * (0.55 + tint.b * 0.55), 0.0, 1.0)
			img.set_pixel(x, y, p)

func _draw_frame(img: Image, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for x in w:
		img.set_pixel(x, 0, col)
		img.set_pixel(x, h - 1, col)
		if h > 2:
			img.set_pixel(x, 1, col.darkened(0.2))
			img.set_pixel(x, h - 2, col.darkened(0.2))
	for y in h:
		img.set_pixel(0, y, col)
		img.set_pixel(w - 1, y, col)

func _stamp_label(img: Image, text: String) -> void:
	var h := img.get_height()
	var bar_h := 24
	for y in range(h - bar_h, h):
		for x in mini(img.get_width(), 10 + text.length() * 11):
			var p := img.get_pixel(x, y)
			p = p.lerp(Color(0.02, 0.04, 0.08, 0.88), 0.72)
			img.set_pixel(x, y, p)
	var seed := text.hash()
	for i in text.length():
		var px := 8 + i * 10
		var py := h - 17
		var bit := (seed >> (i % 16)) & 7
		for dy in 9:
			for dx in 7:
				if ((dx + dy + bit) % 3) == 0:
					var xx := px + dx
					var yy := py + dy
					if xx < img.get_width() and yy < img.get_height():
						img.set_pixel(xx, yy, Color(0.96, 0.9, 0.68, 1))

func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
