class_name Hud
extends CanvasLayer
## Health bars, turn text, controls hint, and the greybox start and result panels.
## Built in code for Phase 1; Phase 4 replaces the panels with real menu scenes.

signal start_requested(fighter: FighterData, difficulty: int)
signal rematch_requested
signal change_fighter_requested

const INK := Color(0.12, 0.1, 0.14)
const PAPER := Color(1.0, 0.96, 0.88)
const HINT_TEXT := "Drag back anywhere to aim, release to throw  •  Drag back to the start to cancel  •  Keys: ↑↓ angle, ←→ power, Space throws"
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]

var _roster: Array[FighterData] = []
var _picked: FighterData
var _difficulty: int = AiAimer.Difficulty.NORMAL
var _names: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _turn_label: Label
var _hint: Label
var _top_bar: Control
var _start_panel: Control
var _result_panel: Control
var _result_title: Label
var _result_detail: Label


func setup(roster: Array[FighterData]) -> void:
	_roster = roster
	_picked = roster[0]
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
		_bars[i].add_theme_stylebox_override("fill", _box(fighter.data.body_color, 6, 3))
		_bars[i].value = fighter.health
		fighter.health_changed.connect(_on_health_changed.bind(i))


func set_turn(text: String) -> void:
	_turn_label.text = text


func show_hint(visible_now: bool) -> void:
	_hint.visible = visible_now


func show_start() -> void:
	_result_panel.hide()
	_start_panel.show()


func show_result(title: String, detail: String) -> void:
	_result_title.text = title
	_result_detail.text = detail
	_start_panel.hide()
	_result_panel.show()


func hide_overlays() -> void:
	_start_panel.hide()
	_result_panel.hide()
	get_viewport().gui_release_focus()


func _on_health_changed(_fighter: Fighter, health: int, index: int) -> void:
	create_tween().tween_property(_bars[index], "value", float(health), 0.35)


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
		var bar := ProgressBar.new()
		bar.max_value = Rules.MAX_HEALTH
		bar.show_percentage = false
		bar.custom_minimum_size.y = 22
		bar.add_theme_stylebox_override("background", _box(Color(0, 0, 0, 0.35), 6, 3))
		column.add_child(name_label)
		column.add_child(bar)
		_names.append(name_label)
		_bars.append(bar)
		row.add_child(column)
		if i == 0:
			_turn_label = _hud_label("", 30)
			_turn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(_turn_label)
	add_child(margin)
	_ignore_mouse(margin)
	_top_bar = margin


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
	content.add_child(_panel_label("WOBBLE WARS", 60))
	content.add_child(_panel_label("Choose your fighter", 22))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var fighter_group := ButtonGroup.new()
	for fighter in _roster:
		var weapon := fighter.weapon
		var button := _button("%s\n%s  ·  %d body / %d head" % [fighter.display_name, weapon.display_name, weapon.body_damage, weapon.head_damage], 18)
		button.custom_minimum_size = Vector2(340, 70)
		button.toggle_mode = true
		button.button_group = fighter_group
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
		button.custom_minimum_size = Vector2(130, 48)
		button.toggle_mode = true
		button.button_group = difficulty_group
		button.button_pressed = level == _difficulty
		button.pressed.connect(func() -> void: _difficulty = level)
		difficulty_row.add_child(button)
	content.add_child(difficulty_row)

	var fight := _button("Fight!", 32)
	fight.custom_minimum_size = Vector2(240, 64)
	fight.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fight.pressed.connect(_on_fight_pressed)
	content.add_child(fight)
	return _make_overlay(content)


func _build_result_panel() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	_result_title = _panel_label("", 54)
	_result_detail = _panel_label("", 22)
	content.add_child(_result_title)
	content.add_child(_result_detail)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var rematch := _button("Rematch", 26)
	rematch.custom_minimum_size = Vector2(200, 60)
	rematch.pressed.connect(_on_rematch_pressed)
	var change := _button("Change fighter", 26)
	change.custom_minimum_size = Vector2(240, 60)
	change.pressed.connect(change_fighter_requested.emit)
	row.add_child(rematch)
	row.add_child(change)
	content.add_child(row)
	return _make_overlay(content)


## Dims the screen (which also blocks aiming) and centres content on a paper card.
func _make_overlay(content: Control) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PAPER, 18, 4, 28))
	card.add_child(content)
	center.add_child(card)
	shade.add_child(center)
	add_child(shade)
	return shade


func _box(color: Color, radius: int, border: int, padding: float = 0.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = INK
	box.set_border_width_all(border)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(padding)
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
	return button


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
