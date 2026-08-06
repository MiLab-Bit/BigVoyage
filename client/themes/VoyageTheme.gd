extends RefCounted
class_name VoyageTheme
## 运行时 Theme 构建（对齐 需求文档/06-UI组件 + 美术圣经色板）
## App._ready 挂到 root；亦可 ResourceSaver 导出 voyage_theme.tres

const PARCHMENT := Color("E8DCC0")
const COPPER := Color("C9A227")
const INK := Color("1A2430")
const PANEL_BG := Color(0.06, 0.10, 0.16, 0.94)
const DANGER := Color("D84A3A")
const SUCCESS := Color("5CBF8A")
const WARN := Color("FFB703")
const MUTED := Color("7A8899")
const INFO := Color("9FC0E8")
const OVERLAY_DIM := Color(0.02, 0.04, 0.08, 0.75)
const FLAME := Color("E85D04")
const IRON := Color("ADB5BD")
const WIND := Color("4CC9F0")
const TIDE := Color("7B2CBF")
const TIER_START := Color("73D9B2")
const TIER_LIGHT := Color("66A6E6")
const TIER_HEAVY := Color("F28C40")
const TIER_BOSS := Color("F24D59")
const CURRENT := Color("FFDB66")

static func build() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", PARCHMENT.lightened(0.08))
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.58, 0.62))
	t.set_color("default_color", "RichTextLabel", PARCHMENT.lightened(0.05))
	t.set_font_size("font_size", "Label", 16)
	t.set_font_size("font_size", "Button", 16)
	t.set_font_size("font_size", "RichTextLabel", 15)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)

	t.set_stylebox("panel", "PanelContainer", _panel())
	t.set_stylebox("normal", "Button", _btn(Color(0.10, 0.16, 0.24, 0.96), COPPER))
	t.set_stylebox("hover", "Button", _btn(Color(0.16, 0.24, 0.34, 0.98), COPPER.lightened(0.15)))
	t.set_stylebox("pressed", "Button", _btn(Color(0.08, 0.12, 0.18, 1.0), COPPER.darkened(0.1)))
	t.set_stylebox("disabled", "Button", _btn(Color(0.08, 0.09, 0.11, 0.7), Color(0.35, 0.35, 0.38)))
	t.set_stylebox("focus", "Button", _btn(Color(0.12, 0.18, 0.28, 0.96), WIND))

	t.set_stylebox("background", "ProgressBar", _bar_bg())
	t.set_stylebox("fill", "ProgressBar", _bar_fill(WIND))

	t.set_type_variation("VoyageDangerButton", "Button")
	t.set_stylebox("normal", "VoyageDangerButton", _btn(Color(0.28, 0.10, 0.10, 0.95), DANGER))
	t.set_stylebox("hover", "VoyageDangerButton", _btn(Color(0.36, 0.14, 0.12, 0.98), DANGER.lightened(0.1)))
	t.set_stylebox("pressed", "VoyageDangerButton", _btn(Color(0.20, 0.08, 0.08, 1.0), DANGER.darkened(0.1)))

	t.set_type_variation("VoyageCopperPanel", "PanelContainer")
	t.set_stylebox("panel", "VoyageCopperPanel", _panel(COPPER, PANEL_BG))

	t.set_type_variation("VoyageStatusStrip", "PanelContainer")
	t.set_stylebox("panel", "VoyageStatusStrip", _strip_panel())

	t.set_type_variation("VoyageDock", "PanelContainer")
	t.set_stylebox("panel", "VoyageDock", _dock_panel())
	return t

static func _panel(border: Color = COPPER, bg: Color = PANEL_BG) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

static func _strip_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.12, 0.82)
	sb.set_border_width_all(1)
	sb.border_color = Color(COPPER.r, COPPER.g, COPPER.b, 0.55)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func _dock_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.14, 0.9)
	sb.set_border_width_all(1)
	sb.border_color = Color(COPPER.r, COPPER.g, COPPER.b, 0.65)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func _btn(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

static func _bar_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.10, 0.9)
	sb.set_corner_radius_all(4)
	return sb

static func _bar_fill(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(4)
	return sb

static func bar_fill(c: Color) -> StyleBoxFlat:
	return _bar_fill(c)

static func bar_bg() -> StyleBoxFlat:
	return _bar_bg()

static func island_style(tier: String, owned: bool, revealed: bool, is_current: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	if not revealed:
		sb.bg_color = Color(0.05, 0.06, 0.09, 0.85)
		sb.border_color = MUTED.darkened(0.25)
		return sb
	sb.bg_color = Color(0.12, 0.22, 0.2, 0.95) if owned else Color(0.08, 0.12, 0.18, 0.92)
	match tier:
		"start":
			sb.border_color = TIER_START
		"heavy":
			sb.border_color = TIER_HEAVY
		"boss":
			sb.border_color = TIER_BOSS
		_:
			sb.border_color = TIER_LIGHT
	if is_current:
		sb.border_color = CURRENT
		sb.set_border_width_all(3)
	return sb

static func system_color(sys: String) -> Color:
	match sys:
		"flame":
			return FLAME
		"ironwall":
			return IRON
		"wind":
			return WIND
		"tide":
			return TIDE
		_:
			return PARCHMENT

static func bb(color: Color, text: String) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), text]

static func island_label(id: String) -> String:
	if GameData.islands.has(id):
		return str(GameData.islands[id].get("name", id))
	return id

static func portrait_frame(sys: String, accent: Color = Color()) -> StyleBoxFlat:
	var border := accent if accent.a > 0.01 else system_color(sys)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.08, 0.45)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb

static func chip_frame(sys: String) -> StyleBoxFlat:
	var col := system_color(sys)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, 0.22)
	sb.set_border_width_all(2)
	sb.border_color = col
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb

static func verdict_color(verdict: String) -> Color:
	match verdict:
		"可胜":
			return SUCCESS
		"险胜":
			return WARN
		"不利":
			return DANGER
		_:
			return MUTED
