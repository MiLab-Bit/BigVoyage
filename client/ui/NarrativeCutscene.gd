extends CanvasLayer
## 叙事过场壳：全屏关键帧 + 旁白 + 可跳过（Boss 预兆可锁）

signal finished

@onready var dim: ColorRect = $Dim
@onready var art: TextureRect = $Art
@onready var title: Label = $UI/Title
@onready var line: RichTextLabel = $UI/Line
@onready var skip: Button = $UI/Skip

var _skip := false
var _lock_skip := false

func _ready() -> void:
	layer = 40
	skip.pressed.connect(func():
		if _lock_skip:
			return
		_skip = true
	)

func play(chapter: Dictionary) -> void:
	_skip = false
	_lock_skip = bool(chapter.get("lock_skip", false))
	skip.visible = not _lock_skip
	skip.text = "不可跳过" if _lock_skip else "跳过"
	title.text = str(chapter.get("title", ""))
	dim.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.25)
	await tw.finished
	Sfx.play_event("sfx_nar_cutscene_start")
	var frames: Array = chapter.get("frames", [])
	for fr in frames:
		if _skip and not _lock_skip:
			break
		var art_key := str(fr.get("art", ""))
		art.texture = AssetDB.narrative(art_key)
		art.modulate.a = 0.0
		line.text = str(fr.get("line", ""))
		var sfx := str(fr.get("sfx", ""))
		if sfx != "":
			Sfx.play_event(sfx)
		var tw2 := create_tween()
		tw2.tween_property(art, "modulate:a", 1.0, 0.35)
		await tw2.finished
		var wait := 1.6
		var t := 0.0
		while t < wait and not (_skip and not _lock_skip):
			await get_tree().process_frame
			t += get_process_delta_time()
		var tw3 := create_tween()
		tw3.tween_property(art, "modulate:a", 0.0, 0.25)
		await tw3.finished
	var tw4 := create_tween()
	tw4.tween_property(dim, "modulate:a", 0.0, 0.3)
	await tw4.finished
	finished.emit()
	queue_free()
