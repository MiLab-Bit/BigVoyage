extends CanvasLayer
## Gacha 仪式屏（Demo 展示）：单抽/十连 + 分层揭示；UR 不可跳过

const GachaFacadeScript := preload("res://systems/gacha/GachaFacade.gd")
const DisplayNamesScript := preload("res://core/DisplayNames.gd")

@onready var dim: ColorRect = $Dim
@onready var panel: PanelContainer = $Center/Panel
@onready var title: Label = $Center/Panel/Margin/VBox/Title
@onready var pity: RichTextLabel = $Center/Panel/Margin/VBox/Pity
@onready var stage: Control = $Center/Panel/Margin/VBox/Stage
@onready var card_back: TextureRect = $Center/Panel/Margin/VBox/Stage/CardBack
@onready var card_front: TextureRect = $Center/Panel/Margin/VBox/Stage/CardFront
@onready var reveal_lbl: RichTextLabel = $Center/Panel/Margin/VBox/RevealLabel
@onready var btn_one: Button = $Center/Panel/Margin/VBox/Btns/One
@onready var btn_ten: Button = $Center/Panel/Margin/VBox/Btns/Ten
@onready var btn_skip: Button = $Center/Panel/Margin/VBox/Btns/Skip
@onready var btn_close: Button = $Center/Panel/Margin/VBox/Btns/Close

var _busy := false
var _queue: Array = []
var _ur_lock := false

func _ready() -> void:
	title.text = "星潮祈愿 · UR 独占入籍"
	panel.theme_type_variation = "VoyageCopperPanel"
	card_back.texture = AssetDB.ui("ui_gacha_cardback")
	card_front.visible = false
	btn_one.pressed.connect(_on_one)
	btn_ten.pressed.connect(_on_ten)
	btn_skip.pressed.connect(_on_skip)
	btn_close.pressed.connect(_try_close)
	_refresh_pity()
	Sfx.play_event("sfx_gacha_open")
	dim.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.18)

func _refresh_pity() -> void:
	var p: Dictionary = GachaFacadeScript.pity_progress()
	var grants := App.flag("gacha_grants", true)
	pity.text = "保底 · UR %d/%d（剩 %d）· SSR %d/%d（剩 %d）· 累计 %d\n[color=#9fc0e8]%s · UR 欲望=独占机制（见图鉴）[/color]" % [
		int(p.get("since_ur", 0)), int(p.get("pity_ur", 70)), int(p.get("ur_in", 0)),
		int(p.get("since_ssr", 0)), int(p.get("pity_ssr", 10)), int(p.get("ssr_in", 0)),
		int(p.get("total", 0)),
		"抽中写入船籍" if grants else "展示模式（不入籍）",
	]

func _on_one() -> void:
	if _busy:
		return
	_queue = [GachaFacadeScript.pull_one()]
	_play_queue()

func _on_ten() -> void:
	if _busy:
		return
	_queue = GachaFacadeScript.pull_ten()
	_play_queue()

func _on_skip() -> void:
	if _ur_lock:
		GameState.emit_signal("toast", "UR 揭示不可跳过")
		Juice.deny_pulse()
		return
	if _busy:
		# 快进当前动画
		_busy = false

func _try_close() -> void:
	if _busy or _ur_lock:
		GameState.emit_signal("toast", "仪式进行中")
		return
	queue_free()

func _play_queue() -> void:
	_busy = true
	btn_one.disabled = true
	btn_ten.disabled = true
	btn_close.disabled = true
	for item in _queue:
		await _reveal_one(item)
		if not is_inside_tree():
			return
	_queue.clear()
	_busy = false
	_ur_lock = false
	btn_skip.disabled = false
	btn_one.disabled = false
	btn_ten.disabled = false
	btn_close.disabled = false
	_refresh_pity()
	EventBus.toast_requested.emit("祈愿仪式结束")

func _reveal_one(item: Dictionary) -> void:
	var rarity := str(item.get("rarity", "R"))
	var card_id := str(item.get("card_id", ""))
	var info: Dictionary = DisplayNamesScript.for_card(card_id)
	_ur_lock = rarity == "UR"
	btn_skip.disabled = _ur_lock
	card_front.visible = false
	card_back.visible = true
	card_back.scale = Vector2(1, 1)
	card_back.modulate = Color.WHITE
	Sfx.play_event("sfx_gacha_pull")
	reveal_lbl.text = "星潮翻涌…"
	var tw := create_tween()
	tw.tween_property(card_back, "scale:x", 0.05, 0.22).set_trans(Tween.TRANS_SINE)
	await tw.finished
	var tex := AssetDB.card_illu(card_id)
	if tex == null:
		tex = AssetDB.card_bust(card_id)
	card_front.texture = tex
	card_front.visible = true
	card_front.scale = Vector2(0.05, 1)
	card_back.visible = false
	var col := _rarity_color(rarity)
	card_front.modulate = col
	var tw2 := create_tween()
	tw2.tween_property(card_front, "scale:x", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw2.finished
	match rarity:
		"UR":
			Sfx.play_event("sfx_gacha_ur")
			Juice.celebrate()
			Juice.shake(10, 0.25)
			var ex := str(item.get("exclusive", ""))
			reveal_lbl.text = "[color=#ffd27a][b]UR · %s[/b][/color]\n%s %s\n%s\n%s" % [
				info.get("display", card_id), info.get("shape", ""), info.get("mechanism", ""),
				ex if ex != "" else "独占机制已锁定进战斗核",
				"已入船籍" if bool(item.get("granted", false)) or bool(item.get("owned", false)) else "",
			]
			await get_tree().create_timer(1.8).timeout
		"SSR":
			Sfx.play_event("sfx_gacha_ssr")
			Juice.punch(card_front, 1.08, 0.12)
			reveal_lbl.text = "[color=#c77dff]SSR · %s[/color]  %s" % [info.get("display", card_id), info.get("shape", "")]
			await get_tree().create_timer(0.7).timeout
		"SR":
			Sfx.play_event("sfx_gacha_sr")
			reveal_lbl.text = "[color=#4cc9f0]SR · %s[/color]" % info.get("display", card_id)
			await get_tree().create_timer(0.45).timeout
		_:
			Sfx.play_event("sfx_gacha_r")
			reveal_lbl.text = "R · %s" % info.get("display", card_id)
			await get_tree().create_timer(0.28).timeout
	_ur_lock = false

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"UR":
			return Color(1.0, 0.86, 0.45)
		"SSR":
			return Color(0.78, 0.55, 1.0)
		"SR":
			return Color(0.4, 0.85, 0.95)
		_:
			return Color(0.9, 0.92, 0.95)
