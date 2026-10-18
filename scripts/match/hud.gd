class_name Hud
extends CanvasLayer
## Health bars, turn text, controls hint, and the greybox start and result panels.
## Built in code for Phase 1; Phase 4 replaces the panels with real menu scenes.

signal start_requested(fighter: FighterData, difficulty: int)
signal rematch_requested
signal change_fighter_requested

const INK := Color(0.12, 0.1, 0.14)
const PAPER := Color(1.0, 0.96, 0.88)
const BUTTON := Color(1.0, 0.78, 0.3)
const GHOST := Color(1.0, 0.95, 0.75)
const HINT_TEXT := "Drag back anywhere to aim, release to throw  •  Drag back to the start to cancel  •  Keys: ↑↓ angle, ←→ power, Space throws"
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]

var _roster: Array[FighterData] = []
var _picked: FighterData
var _difficulty: int = AiAimer.Difficulty.NORMAL
var _theme: Theme
var _names: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _ghosts: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _turn_label: Label
var _hint: Label
var _title: Label
var _top_bar: Control
var _start_panel: Control
var _result_panel: Control
var _result_title: Label
var _result_detail: Label
var _time := 0.0


func setup(roster: Array[FighterData]) -> void:
	_roster = roster
	_picked = roster[0]
	_theme = _make_theme()
	_build_top_bar()
	_build_hint()
	_start_panel = _build_start_panel()
	_result_panel = _build_result_panel()
	_top_bar.hide()
	_hint.hide()
	hide_overlays()


func bind_fighters(fighters: Array[Fighter]) -> void:
	_top_bar.show()
	for i in fighters.size():
		var fighter := fighters[i]
		_names[i].text = fighter.data.display_name + ("  · AI" if fighter.is_ai else "")
		_bars[i].add_theme_stylebox_override("fill", _box(fighter.data.body_color, 8, 0))
		_bars[i].value = fighter.health
		_ghosts[i].value = fighter.health
		_hp_labels[i].text = str(fighter.health)
		fighter.health_changed.connect(_on_health_changed.bind(i))


func set_turn(text: String) -> void:
	_turn_label.text = text
	if text.is_empty():
		return
	_turn_label.pivot_offset = _turn_label.size / 2
	_turn_label.scale = Vector2(1.4, 1.4)
	var tween := _turn_label.create_tween()
	tween.tween_property(_turn_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_hint(visible_now: bool) -> void:
	_hint.visible = visible_now


func show_start() -> void:
	_result_panel.hide()
	_pop_in(_start_panel)


func show_result(title: String, detail: String) -> void:
	_result_title.text = title
	_result_detail.text = detail
	_start_panel.hide()
	_pop_in(_result_panel)


func hide_overlays() -> void:
	_start_panel.hide()
	_result_panel.hide()
	get_viewport().gui_release_focus()


func _process(delta: float) -> void:
	_time += delta
	if _title != null and _title.is_visible_in_tree():
		_title.pivot_offset = _title.size / 2
		_title.rotation = sin(_time * 2.4) * 0.035
		_title.scale = Vector2.ONE * (1.0 + sin(_time * 4.8) * 0.02)


func _pop_in(overlay: Control) -> void:
	overlay.show()
	overlay.modulate.a = 0.0
	var card := overlay.get_child(0).get_child(0) as Control
	card.pivot_offset = card.size / 2
	card.scale = Vector2(0.85, 0.85)
	var tween := overlay.create_tween().set_parallel()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.18)
	tween.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_health_changed(_fighter: Fighter, health: int, index: int) -> void:
	_hp_labels[index].text = str(health)
	_bars[index].create_tween().tween_property(_bars[index], "value", float(health), 0.18)
	# The pale ghost bar lingers, then drains, so you can see how much a hit took.
	_ghosts[index].create_tween().tween_property(_ghosts[index], "value", float(health), 0.5).set_delay(0.5)
	var label := _hp_labels[index]
	label.pivot_offset = label.size / 2
	label.scale = Vector2(1.6, 1.6)
	label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_fight_pressed() -> void:
	hide_overlays()
	start_requested.emit(_picked, _difficulty)


func _on_rematch_pressed() -> void:
	hide_overlays()
	rematch_requested.emit()


func _build_top_bar() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var row := HBoxContainer.new()
	margin.add_child(row)
	for i in 2:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 340
		var name_label := _hud_label("", 26)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var stack := Panel.new()
		stack.custom_minimum_size.y = 30
		stack.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.35), 10, 3, 0.0, true))
		var ghost := _bar(GHOST)
		var bar := _bar(Color.WHITE)
		if i == 1:
			ghost.fill_mode = ProgressBar.FILL_END_TO_BEGIN
			bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		var hp := _hud_label("100", 18)
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(ghost)
		stack.add_child(bar)
		stack.add_child(hp)
		column.add_child(name_label)
		column.add_child(stack)
		_names.append(name_label)
		_bars.append(bar)
		_ghosts.append(ghost)
		_hp_labels.append(hp)
		row.add_child(column)
		if i == 0:
			_turn_label = _hud_label("", 32)
			_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(_turn_label)
	add_child(margin)
	_ignore_mouse(margin)
	_top_bar = margin


func _bar(fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = Rules.MAX_HEALTH
	bar.show_percentage = false
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 4
	bar.offset_top = 4
	bar.offset_right = -4
	bar.offset_bottom = -4
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("fill", _box(fill, 8, 0))
	return bar


func _build_hint() -> void:
	_hint = _hud_label(HINT_TEXT, 17)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -44
	_hint.offset_bottom = -12
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _build_start_panel() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_title = _panel_label("WOBBLE WARS", 64)
	_title.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
	_title.add_theme_color_override("font_outline_color", INK)
	_title.add_theme_constant_override("outline_size", 14)
	content.add_child(_title)
	content.add_child(_panel_label("Choose your fighter", 22))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var fighter_group := ButtonGroup.new()
	for fighter in _roster:
		var weapon := fighter.weapon
		var button := _button("%s\n%s  ·  %d body / %d head" % [fighter.display_name, weapon.display_name, weapon.body_damage, weapon.head_damage], 18)
		button.custom_minimum_size = Vector2(340, 76)
		button.toggle_mode = true
		button.button_group = fighter_group
		button.add_theme_stylebox_override("normal", _button_box(fighter.body_color.lerp(PAPER, 0.6)))
		button.add_theme_stylebox_override("hover", _button_box(fighter.body_color.lerp(PAPER, 0.4)))
		button.add_theme_stylebox_override("pressed", _button_box(fighter.body_color, true))
		button.add_theme_stylebox_override("hover_pressed", _button_box(fighter.body_color.lightened(0.1), true))
		button.button_pressed = fighter == _picked
		button.pressed.connect(func() -> void: _picked = fighter)
		grid.add_child(button)
	content.add_child(grid)

	content.add_child(_panel_label("AI difficulty", 22))
	var difficulty_row := HBoxContainer.new()
	difficulty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	difficulty_row.add_theme_constant_override("separation", 10)
	var difficulty_group := ButtonGroup.new()
	for level in DIFFICULTY_NAMES.size():
		var button := _button(DIFFICULTY_NAMES[level], 20)
		button.custom_minimum_size = Vector2(130, 52)
		button.toggle_mode = true
		button.button_group = difficulty_group
		button.button_pressed = level == _difficulty
		button.pressed.connect(func() -> void: _difficulty = level)
		difficulty_row.add_child(button)
	content.add_child(difficulty_row)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_row.add_theme_constant_override("separation", 14)
	var sound := _button("Sound: on", 18)
	sound.custom_minimum_size = Vector2(150, 64)
	sound.pressed.connect(func() -> void:
		Audio.muted = not Audio.muted
		sound.text = "Sound: off" if Audio.muted else "Sound: on")
	var fight := _button("Fight!", 34)
	fight.custom_minimum_size = Vector2(260, 72)
	fight.add_theme_stylebox_override("normal", _button_box(Color(0.45, 0.82, 0.4)))
	fight.add_theme_stylebox_override("hover", _button_box(Color(0.55, 0.9, 0.5)))
	fight.add_theme_stylebox_override("pressed", _button_box(Color(0.38, 0.72, 0.34), true))
	fight.pressed.connect(_on_fight_pressed)
	bottom_row.add_child(sound)
	bottom_row.add_child(fight)
	content.add_child(bottom_row)
	return _make_overlay(content)


func _build_result_panel() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	_result_title = _panel_label("", 58)
	_result_title.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
	_result_title.add_theme_color_override("font_outline_color", INK)
	_result_title.add_theme_constant_override("outline_size", 12)
	_result_detail = _panel_label("", 22)
	content.add_child(_result_title)
	content.add_child(_result_detail)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var rematch := _button("Rematch", 26)
	rematch.custom_minimum_size = Vector2(200, 64)
	rematch.pressed.connect(_on_rematch_pressed)
	var change := _button("Change fighter", 26)
	change.custom_minimum_size = Vector2(240, 64)
	change.pressed.connect(change_fighter_requested.emit)
	row.add_child(rematch)
	row.add_child(change)
	content.add_child(row)
	return _make_overlay(content)


## Dims the screen (which also blocks aiming) and centres content on a paper card.
func _make_overlay(content: Control) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.1, 0.2, 0.4)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.theme = _theme
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PAPER, 22, 4, 30.0, true))
	card.add_child(content)
	center.add_child(card)
	shade.add_child(center)
	add_child(shade)
	return shade


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _button_box(BUTTON.lerp(PAPER, 0.45)))
	theme.set_stylebox("hover", "Button", _button_box(BUTTON.lerp(PAPER, 0.2)))
	theme.set_stylebox("pressed", "Button", _button_box(BUTTON, true))
	theme.set_stylebox("hover_pressed", "Button", _button_box(BUTTON.lightened(0.1), true))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "Button", INK)
	return theme


## A chunky cartoon button. Pressed ones sink: less bottom edge, more top padding.
func _button_box(color: Color, pressed: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(3)
	box.border_width_bottom = 3 if pressed else 7
	box.set_corner_radius_all(14)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12 if pressed else 8
	box.content_margin_bottom = 8
	box.anti_aliasing = true
	return box


func _box(color: Color, radius: int, border: int, padding: float = 0.0, shadow: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
	box.anti_aliasing = true
	if shadow:
		box.shadow_color = Color(0, 0, 0, 0.25)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 5)
	return box


func _hud_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 8)
	return label


func _panel_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(Audio.play.bind("click", -4.0))
	button.mouse_entered.connect(func() -> void:
		button.pivot_offset = button.size / 2
		button.create_tween().tween_property(button, "scale", Vector2(1.04, 1.04), 0.1))
	button.mouse_exited.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.1))
	return button


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
