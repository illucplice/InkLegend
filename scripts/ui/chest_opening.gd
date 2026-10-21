class_name ChestOpening
extends ColorRect
## The chest-opening show: the chest rattles, bursts open in a flash of light, and the
## fighter inside is revealed on a card with its rarity, "NEW!" or "DUPLICATE +coins".
## Tap to close.

signal closed

var _chest: ChestArt
var _card: PanelContainer
var _rays := 0.0
var _rays_color := Color.WHITE
var _time := 0.0
var _ready_to_close := false


func _ready() -> void:
	color = Color(0.03, 0.02, 0.08, 0.86)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func play(kind: String, result: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_ready_to_close = false
	_rays = 0.0
	var fighter: FighterData = result["fighter"]
	_rays_color = Chests.RARITY_COLORS[fighter.rarity]
	_chest = ChestArt.new()
	_chest.color = Chests.KINDS[kind]["color"]
	_chest.kind = kind
	_chest.custom_minimum_size = Vector2(300, 300)
	_chest.size = Vector2(300, 300)
	_chest.position = size / 2 - Vector2(150, 110)
	add_child(_chest)
	_card = _build_card(result)
	_card.modulate.a = 0.0
	add_child(_card)
	show()
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	# Rattle harder and harder, then burst open.
	tween.tween_property(_chest, "shake", 1.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Audio.play("hit_head", 0.0, 0.7, 0.0)
		Audio.play("win", -2.0, 1.0, 0.0)
		_chest.shake = 0.0)
	tween.set_parallel()
	tween.tween_property(_chest, "open", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_chest, "glow", 1.0, 0.35)
	tween.tween_property(self, "_rays", 1.0, 0.5)
	tween.chain().tween_interval(0.25)
	tween.chain().tween_callback(_reveal)


func _reveal() -> void:
	_card.pivot_offset = _card.size / 2
	_card.position = size / 2 - _card.size / 2 + Vector2(0, -20)
	_card.scale = Vector2(0.3, 0.3)
	var tween := create_tween().set_parallel()
	tween.tween_property(_card, "modulate:a", 1.0, 0.2)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_chest, "modulate:a", 0.25, 0.3)
	tween.chain().tween_callback(func() -> void: _ready_to_close = true)


func _build_card(result: Dictionary) -> PanelContainer:
	var fighter: FighterData = result["fighter"]
	var rarity_color: Color = Chests.RARITY_COLORS[fighter.rarity]
	var card := PanelContainer.new()
	var box := UiStyle.panel(UiStyle.PAPER, 24, 6, 22.0)
	box.border_color = rarity_color.darkened(0.2)
	card.add_theme_stylebox_override("panel", box)
	card.custom_minimum_size = Vector2(380, 0)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	var ribbon := UiStyle.ribbon(Chests.RARITY_NAMES[fighter.rarity].to_upper(), rarity_color, 30)
	stack.add_child(ribbon)
	var portrait_box := CenterContainer.new()
	portrait_box.add_child(Portrait.make(fighter, 1, 170.0))
	stack.add_child(portrait_box)
	stack.add_child(UiStyle.ink_label(fighter.display_name, 34, true))
	stack.add_child(UiStyle.ink_label("%s  ·  ★ %s" % [fighter.weapon.display_name, fighter.special_name], 18))
	var text := "NEW FIGHTER!"
	if not result["new"]:
		var level := int(result.get("level", 0))
		if level > 0 and int(result["coins"]) == Chests.LEVEL_UP_COINS:
			text = "LEVEL UP!  Lv %d  ·  +%d coins" % [level, result["coins"]]
		else:
			text = "MAXED  +%d coins" % result["coins"]
	var news := UiStyle.game_label(text, 28, true)
	news.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	news.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if result["new"] else Color(1.0, 0.85, 0.35))
	stack.add_child(news)
	var hint := UiStyle.ink_label("Tap to continue", 16)
	hint.add_theme_color_override("font_color", UiStyle.INK.lightened(0.35))
	stack.add_child(hint)
	card.add_child(stack)
	return card


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _rays <= 0.0:
		return
	var centre := size / 2
	for i in 16:
		var a := _time * 0.4 + i * TAU / 16
		var ray := PackedVector2Array([centre, centre + Vector2.from_angle(a - 0.08) * 900.0, centre + Vector2.from_angle(a + 0.08) * 900.0])
		draw_colored_polygon(ray, Color(_rays_color, 0.12 * _rays))


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and _ready_to_close:
		accept_event()
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.2)
		tween.tween_callback(func() -> void:
			hide()
			closed.emit())
