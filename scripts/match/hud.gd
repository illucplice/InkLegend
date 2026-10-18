class_name Hud
extends CanvasLayer
## Every screen drawn over the arena: the title screen (with a showcase fighter),
## fighter select, settings, how to play, the in-match HUD, pause and results.
## Built in code; the screens are plain Controls shown one at a time.

signal play_requested(left: FighterData, right: FighterData, mode: int, difficulty: int)
signal rematch_requested
signal menu_requested
signal pause_changed(paused: bool)

const INK := Color(0.12, 0.1, 0.14)
const PAPER := Color(1.0, 0.96, 0.88)
const BUTTON := Color(1.0, 0.78, 0.3)
const GO := Color(0.45, 0.82, 0.4)
const GHOST := Color(1.0, 0.95, 0.75)
const TITLE_ORANGE := Color(1.0, 0.62, 0.25)
const VERSION := "v0.1"
const HINT_TEXT := "Drag back anywhere to aim, release to throw  •  Drag back to the start to cancel  •  Keys: ↑↓ angle, ←→ power, Space throws  •  Esc pauses"
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]
const SHOWCASE_SCALE := 2.4
const SHOWCASE_CYCLE := 5.5

var _roster: Array[FighterData] = []
var _theme: Theme
var _in_match := false
var _time := 0.0

# Match HUD
var _top_bar: Control
var _names: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _ghosts: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _turn_label: Label
var _hint: Label
var _pause_button: Button

# Screens
var _screens: Array[Control] = []
var _title_screen: Control
var _select_screen: Control
var _settings_screen: Control
var _howto_screen: Control
var _pause_screen: Control
var _result_screen: Control
var _settings_return: Control

# Title showcase
var _showcase_root: Node2D
var _showcase_area: Control
var _showcase: Fighter
var _showcase_index := 0
var _showcase_time := 0.0
var _showcase_name: Label
var _showcase_weapon: Label
var _showcase_special: Label
var _title_label: Label

# Fighter select
var _select_mode: int = MatchController.Mode.VS_AI
var _select_step := 0
var _picks: Array[FighterData] = [null, null]
var _difficulty: int = AiAimer.Difficulty.NORMAL
var _select_header: Label
var _card_buttons: Array[Button] = []
var _difficulty_box: Control
var _go_button: Button

# Results
var _result_title: Label
var _result_detail: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(roster: Array[FighterData]) -> void:
	_roster = roster
	_picks = [roster[0], roster[1]]
	_theme = _make_theme()
	_build_match_hud()
	_title_screen = _build_title()
	_select_screen = _build_select()
	_settings_screen = _build_settings()
	_howto_screen = _build_howto()
	_pause_screen = _build_pause()
	_result_screen = _build_result()
	_show_screen(null)


# --- public API used by MatchController ---

func show_title() -> void:
	_in_match = false
	_top_bar.hide()
	_hint.hide()
	_pause_button.hide()
	_set_showcase(_showcase_index)
	_show_screen(_title_screen)


func show_match() -> void:
	_in_match = true
	_top_bar.show()
	_hint.visible = Save.show_hints
	_pause_button.show()
	_show_screen(null)


func bind_fighters(fighters: Array[Fighter], player_names: Array[String]) -> void:
	for i in fighters.size():
		var fighter := fighters[i]
		_names[i].text = "%s  ·  %s" % [player_names[i], fighter.data.display_name] if i == 0 else "%s  ·  %s" % [fighter.data.display_name, player_names[i]]
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
	_turn_label.create_tween().tween_property(_turn_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_hint(visible_now: bool) -> void:
	_hint.visible = visible_now and Save.show_hints


func show_result(title: String, detail: String) -> void:
	_result_title.text = title
	_result_detail.text = detail
	_pause_button.hide()
	_show_screen(_result_screen)


# --- screen switching ---

func _show_screen(screen: Control) -> void:
	for other in _screens:
		other.visible = other == screen
	get_viewport().gui_release_focus()
	if screen == null:
		return
	screen.modulate.a = 0.0
	var tween := screen.create_tween()
	tween.tween_property(screen, "modulate:a", 1.0, 0.2)
	if screen.has_meta("card"):
		var card := screen.get_meta("card") as Control
		card.pivot_offset = card.size / 2
		card.scale = Vector2(0.88, 0.88)
		tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _open_select(mode: int) -> void:
	_select_mode = mode
	_select_step = 0
	_refresh_select()
	_show_screen(_select_screen)


func _open_settings(return_to: Control) -> void:
	_settings_return = return_to
	_show_screen(_settings_screen)


func _set_paused(paused: bool) -> void:
	if not _in_match:
		return
	pause_changed.emit(paused)
	_show_screen(_pause_screen if paused else null)
	_pause_button.visible = not paused


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _settings_screen.visible:
		_close_settings()
	elif _select_screen.visible:
		_select_back()
	elif _howto_screen.visible:
		show_title()
	elif _pause_screen.visible:
		_set_paused(false)
	elif _in_match and not _result_screen.visible:
		_set_paused(true)


func _process(delta: float) -> void:
	_time += delta
	if _title_label != null and _title_label.is_visible_in_tree():
		_title_label.pivot_offset = _title_label.size / 2
		_title_label.rotation = sin(_time * 2.4) * 0.035
		_title_label.scale = Vector2.ONE * (1.0 + sin(_time * 4.8) * 0.02)
	if _title_screen != null and _title_screen.visible:
		_showcase_root.position = Vector2(_showcase_area.size.x * 0.5, _showcase_area.size.y * 0.64)
		_animate_showcase(delta)


# --- in-match HUD ---

func _build_match_hud() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	var row := HBoxContainer.new()
	margin.add_child(row)
	for i in 2:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 380
		var name_label := _hud_label("", 24)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		name_label.clip_text = true
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

	_hint = _hud_label(HINT_TEXT, 17)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -44
	_hint.offset_bottom = -12
	_hint.offset_right = -90
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_pause_button = _button("II", 26)
	_pause_button.theme = _theme
	_pause_button.custom_minimum_size = Vector2(64, 60)
	_pause_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_pause_button.offset_left = -84
	_pause_button.offset_top = -80
	_pause_button.offset_right = -20
	_pause_button.offset_bottom = -20
	_pause_button.pressed.connect(_set_paused.bind(true))
	add_child(_pause_button)


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


func _on_health_changed(_fighter: Fighter, health: int, index: int) -> void:
	_hp_labels[index].text = str(health)
	_bars[index].create_tween().tween_property(_bars[index], "value", float(health), 0.18)
	# The pale ghost bar lingers, then drains, so you can see how much a hit took.
	_ghosts[index].create_tween().tween_property(_ghosts[index], "value", float(health), 0.5).set_delay(0.5)
	var label := _hp_labels[index]
	label.pivot_offset = label.size / 2
	label.scale = Vector2(1.6, 1.6)
	label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- title screen ---

func _build_title() -> Control:
	var screen := _screen_root(false)

	# Darken the edges so the menu reads over the busy arena.
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.03, 0.12, 0.55))
	gradient.set_color(1, Color(0.05, 0.03, 0.12, 0.7))
	gradient.add_point(0.45, Color(0.05, 0.03, 0.12, 0.05))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(shade)

	# Left half: the showcase fighter on a pedestal, with arrows to browse.
	var left := Control.new()
	left.anchor_right = 0.5
	left.anchor_bottom = 1.0
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(left)
	_showcase_root = Node2D.new()
	_showcase_root.draw.connect(_draw_pedestal)
	left.add_child(_showcase_root)
	_showcase_area = left

	var plate := VBoxContainer.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	plate.anchor_top = 0.72
	plate.anchor_bottom = 0.98
	plate.offset_left = -260
	plate.offset_right = 260
	plate.offset_top = 0
	plate.offset_bottom = 0
	plate.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_theme_constant_override("separation", 4)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 16)
	var prev := _button("‹", 34)
	prev.theme = _theme
	prev.custom_minimum_size = Vector2(56, 56)
	prev.pressed.connect(func() -> void: _set_showcase(_showcase_index - 1))
	_showcase_name = _hud_label("", 34)
	_showcase_name.custom_minimum_size.x = 320
	_showcase_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := _button("›", 34)
	next.theme = _theme
	next.custom_minimum_size = Vector2(56, 56)
	next.pressed.connect(func() -> void: _set_showcase(_showcase_index + 1))
	name_row.add_child(prev)
	name_row.add_child(_showcase_name)
	name_row.add_child(next)
	plate.add_child(name_row)
	_showcase_weapon = _hud_label("", 20)
	_showcase_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(_showcase_weapon)
	_showcase_special = _hud_label("", 17)
	_showcase_special.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_showcase_special.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	plate.add_child(_showcase_special)
	left.add_child(plate)

	# Right half: title and the main menu.
	var right := VBoxContainer.new()
	right.anchor_left = 0.5
	right.anchor_right = 1.0
	right.anchor_top = 0.0
	right.anchor_bottom = 1.0
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 12)
	screen.add_child(right)

	_title_label = _hud_label("WOBBLE\nWARS", 88)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", TITLE_ORANGE)
	_title_label.add_theme_constant_override("outline_size", 18)
	_title_label.add_theme_constant_override("line_spacing", -18)
	right.add_child(_title_label)
	var tagline := _hud_label("Aim.  Throw.  Wobble.", 22)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(tagline)
	right.add_child(_spacer(10))

	var menu := VBoxContainer.new()
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.add_theme_constant_override("separation", 12)
	menu.theme = _theme
	right.add_child(menu)
	var play_ai := _menu_button("Play vs AI", "Duel the computer", GO)
	play_ai.pressed.connect(_open_select.bind(MatchController.Mode.VS_AI))
	menu.add_child(play_ai)
	var play_2p := _menu_button("1v1 with a friend", "Take turns on one device", BUTTON)
	play_2p.pressed.connect(_open_select.bind(MatchController.Mode.LOCAL_2P))
	menu.add_child(play_2p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var settings := _button("Settings", 22)
	settings.custom_minimum_size = Vector2(169, 58)
	settings.pressed.connect(_open_settings.bind(screen))
	var howto := _button("How to play", 22)
	howto.custom_minimum_size = Vector2(169, 58)
	howto.pressed.connect(func() -> void: _show_screen(_howto_screen))
	row.add_child(settings)
	row.add_child(howto)
	menu.add_child(row)
	if not OS.has_feature("web"):
		var quit := _button("Quit", 20)
		quit.custom_minimum_size = Vector2(0, 48)
		quit.add_theme_stylebox_override("normal", _button_box(PAPER.darkened(0.15)))
		quit.pressed.connect(func() -> void: get_tree().quit())
		menu.add_child(quit)

	var version := _hud_label(VERSION, 16)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -80
	version.offset_top = -36
	version.offset_right = -16
	version.offset_bottom = -10
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(version)
	return screen


func _menu_button(title: String, subtitle: String, color: Color) -> Button:
	var button := _button("%s\n%s" % [title, subtitle], 18)
	button.custom_minimum_size = Vector2(350, 86)
	button.add_theme_stylebox_override("normal", _button_box(color))
	button.add_theme_stylebox_override("hover", _button_box(color.lightened(0.15)))
	button.add_theme_stylebox_override("pressed", _button_box(color.darkened(0.1), true))
	# First line bigger: Button can't mix sizes, so draw the title over the button.
	button.text = ""
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", -2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := _panel_label(title, 28)
	var small := _panel_label(subtitle, 16)
	small.add_theme_color_override("font_color", INK.lightened(0.25))
	stack.add_child(big)
	stack.add_child(small)
	button.add_child(stack)
	return button


func _set_showcase(index: int) -> void:
	_showcase_index = posmod(index, _roster.size())
	_showcase_time = 0.0
	if _showcase != null:
		_showcase.queue_free()
	var data := _roster[_showcase_index]
	_showcase = preload("res://scenes/fighter/fighter.tscn").instantiate()
	_showcase_root.add_child(_showcase)
	_showcase.setup(data, 1, false, false)
	_showcase.scale = Vector2.ONE * SHOWCASE_SCALE
	_showcase.reset_physics_interpolation()
	_showcase.modulate.a = 0.0
	_showcase.create_tween().tween_property(_showcase, "modulate:a", 1.0, 0.25)
	_showcase_name.text = data.display_name
	_showcase_weapon.text = "%s  ·  %d body / %d head" % [data.weapon.display_name, data.weapon.body_damage, data.weapon.head_damage]
	_showcase_special.text = "Special: %s — %s" % [data.special_name, data.special_description]
	_showcase_root.queue_redraw()


## Idles, lines up a throw, throws, then moves on to the next fighter.
func _animate_showcase(delta: float) -> void:
	if _showcase == null:
		return
	var before := _showcase_time
	_showcase_time += delta
	if before < 1.6 and _showcase_time >= 1.6:
		_showcase.aiming = true
		_showcase.aim_angle = 25.0
		_showcase.aim_power = 0.0
		var tween := _showcase.create_tween().set_parallel()
		tween.tween_property(_showcase, "aim_angle", 55.0, 0.9).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_showcase, "aim_power", 0.9, 0.9).set_trans(Tween.TRANS_SINE)
	if before < 2.8 and _showcase_time >= 2.8:
		_showcase.play_throw()
	if before < 3.6 and _showcase_time >= 3.6:
		_showcase.holding_weapon = true
	if _showcase_time >= SHOWCASE_CYCLE:
		_set_showcase(_showcase_index + 1)
	_showcase_root.queue_redraw()


func _draw_pedestal() -> void:
	var root := _showcase_root
	var glow := Color(1.0, 0.75, 0.4)
	if _showcase != null and _showcase.data != null:
		glow = _showcase.data.body_color
	var pulse := 0.5 + 0.5 * sin(_time * 2.0)
	root.draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.26))
	for i in 4:
		root.draw_circle(Vector2.ZERO, 150.0 + i * 26.0, Color(glow, 0.07 + 0.04 * pulse), true, -1.0, true)
	root.draw_circle(Vector2.ZERO, 128.0, INK, true, -1.0, true)
	root.draw_circle(Vector2.ZERO, 122.0, Color(0.72, 0.62, 0.62), true, -1.0, true)
	root.draw_circle(Vector2(0, -14), 112.0, Color(0.86, 0.78, 0.74), true, -1.0, true)
	root.draw_set_transform(Vector2.ZERO)
	root.draw_rect(Rect2(-123, 6, 246, 34), Color(0.62, 0.52, 0.54))
	root.draw_set_transform(Vector2(0, 40), 0.0, Vector2(1.0, 0.26))
	root.draw_circle(Vector2.ZERO, 123.0, Color(0.5, 0.4, 0.44), true, -1.0, true)
	root.draw_set_transform(Vector2.ZERO)


# --- fighter select ---

func _build_select() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_select_header = _panel_label("", 34)
	content.add_child(_select_header)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 12)
	var group := ButtonGroup.new()
	for i in _roster.size():
		var card := _fighter_card(_roster[i], group)
		card.pressed.connect(_on_card_picked.bind(i))
		cards.add_child(card)
		_card_buttons.append(card)
	content.add_child(cards)

	var difficulty := VBoxContainer.new()
	difficulty.add_theme_constant_override("separation", 6)
	difficulty.add_child(_panel_label("AI difficulty", 20))
	var difficulty_row := HBoxContainer.new()
	difficulty_row.alignment = BoxContainer.ALIGNMENT_CENTER
	difficulty_row.add_theme_constant_override("separation", 10)
	var difficulty_group := ButtonGroup.new()
	for level in DIFFICULTY_NAMES.size():
		var button := _button(DIFFICULTY_NAMES[level], 20)
		button.custom_minimum_size = Vector2(130, 50)
		button.toggle_mode = true
		button.button_group = difficulty_group
		button.button_pressed = level == _difficulty
		button.pressed.connect(func() -> void: _difficulty = level)
		difficulty_row.add_child(button)
	difficulty.add_child(difficulty_row)
	content.add_child(difficulty)
	_difficulty_box = difficulty

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	var back := _button("Back", 24)
	back.custom_minimum_size = Vector2(160, 66)
	back.pressed.connect(_select_back)
	_go_button = _button("Fight!", 32)
	_go_button.custom_minimum_size = Vector2(260, 66)
	_go_button.add_theme_stylebox_override("normal", _button_box(GO))
	_go_button.add_theme_stylebox_override("hover", _button_box(GO.lightened(0.12)))
	_go_button.add_theme_stylebox_override("pressed", _button_box(GO.darkened(0.1), true))
	_go_button.pressed.connect(_select_next)
	bottom.add_child(back)
	bottom.add_child(_go_button)
	content.add_child(bottom)
	return _card_screen(content)


func _fighter_card(data: FighterData, group: ButtonGroup) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = group
	card.custom_minimum_size = Vector2(230, 330)
	card.add_theme_stylebox_override("normal", _button_box(data.body_color.lerp(PAPER, 0.7)))
	card.add_theme_stylebox_override("hover", _button_box(data.body_color.lerp(PAPER, 0.5)))
	card.add_theme_stylebox_override("pressed", _button_box(data.body_color.lerp(PAPER, 0.15), true))
	card.add_theme_stylebox_override("hover_pressed", _button_box(data.body_color.lerp(PAPER, 0.1), true))
	card.pressed.connect(Audio.play.bind("click", -4.0))

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_top = 8
	stack.offset_bottom = -12
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 200)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.clip_contents = true
	var fighter: Fighter = preload("res://scenes/fighter/fighter.tscn").instantiate()
	preview.add_child(fighter)
	fighter.setup(data, 1, false, false)
	fighter.scale = Vector2(1.18, 1.18)
	preview.resized.connect(func() -> void:
		fighter.position = Vector2(preview.size.x / 2, preview.size.y - 22)
		fighter.reset_physics_interpolation())
	stack.add_child(preview)
	stack.add_child(_panel_label(data.display_name, 20))
	var weapon := _panel_label("%s  ·  %d / %d" % [data.weapon.display_name, data.weapon.body_damage, data.weapon.head_damage], 15)
	weapon.add_theme_color_override("font_color", INK.lightened(0.2))
	stack.add_child(weapon)
	var special := _panel_label("★ " + data.special_name, 15)
	special.add_theme_color_override("font_color", data.body_color.darkened(0.35))
	stack.add_child(special)
	card.add_child(stack)
	card.set_meta("fighter", fighter)
	return card


func _refresh_select() -> void:
	var vs_ai := _select_mode == MatchController.Mode.VS_AI
	if vs_ai:
		_select_header.text = "Choose your fighter"
	else:
		_select_header.text = "Player %d, choose your fighter" % (_select_step + 1)
	_difficulty_box.visible = vs_ai
	_go_button.text = "Next" if not vs_ai and _select_step == 0 else "Fight!"
	var picked := _roster.find(_picks[_select_step])
	for i in _card_buttons.size():
		_card_buttons[i].set_pressed_no_signal(i == picked)
		var fighter: Fighter = _card_buttons[i].get_meta("fighter")
		fighter.aiming = i == picked


func _on_card_picked(index: int) -> void:
	_picks[_select_step] = _roster[index]
	_refresh_select()


func _select_back() -> void:
	if _select_step == 1:
		_select_step = 0
		_refresh_select()
	else:
		show_title()


func _select_next() -> void:
	if _select_mode == MatchController.Mode.LOCAL_2P and _select_step == 0:
		_select_step = 1
		if _picks[1] == _picks[0]:
			_picks[1] = _roster[(_roster.find(_picks[0]) + 1) % _roster.size()]
		_refresh_select()
		return
	var right := _picks[1] if _select_mode == MatchController.Mode.LOCAL_2P else null
	play_requested.emit(_picks[0], right, _select_mode, _difficulty)


# --- settings, how to play, pause, results ---

func _build_settings() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.add_child(_panel_label("Settings", 40))
	content.add_child(_toggle_row("Sound", "sound_on"))
	var volume_row := _setting_row("Volume")
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Save.volume
	slider.custom_minimum_size = Vector2(220, 36)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(value: float) -> void:
		Save.volume = value
		Save.apply()
		Save.save_settings())
	slider.drag_ended.connect(func(_changed: bool) -> void: Audio.play("click"))
	volume_row.add_child(slider)
	content.add_child(volume_row)
	content.add_child(_toggle_row("Screen shake", "screen_shake"))
	content.add_child(_toggle_row("Long aim guide", "long_aim_guide"))
	content.add_child(_toggle_row("Controls hint", "show_hints"))
	var done := _button("Done", 26)
	done.custom_minimum_size = Vector2(200, 62)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_close_settings)
	content.add_child(done)
	return _card_screen(content)


func _close_settings() -> void:
	if _in_match:
		_hint.visible = Save.show_hints and not _result_screen.visible
	_show_screen(_settings_return)


func _setting_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var label := _panel_label(label_text, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.custom_minimum_size.x = 240
	row.add_child(label)
	return row


## A row with an On/Off button bound to a bool property on Save.
func _toggle_row(label_text: String, property: String) -> HBoxContainer:
	var row := _setting_row(label_text)
	var button := _button("", 20)
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(220, 48)
	button.button_pressed = Save.get(property)
	button.text = "On" if button.button_pressed else "Off"
	button.toggled.connect(func(on: bool) -> void:
		button.text = "On" if on else "Off"
		Save.set(property, on)
		Save.apply()
		Save.save_settings())
	row.add_child(button)
	return row


func _build_howto() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content.add_child(_panel_label("How to play", 40))
	var lines := [
		"Drag back anywhere and let go to throw. The further you drag, the harder you throw.",
		"Drag back to where you started to cancel.",
		"Keyboard: ↑↓ change the angle, ←→ change the power, Space throws.",
		"Hit the head for big damage. Knock your rival to 0 health to win.",
		"Towers, walls and floating slabs block throws. Lob over them or sneak under.",
		"Esc or the II button pauses the match.",
	]
	for line: String in lines:
		var label := _panel_label("•  " + line, 19)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 640
		content.add_child(label)
	var back := _button("Got it", 26)
	back.custom_minimum_size = Vector2(200, 62)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_title)
	content.add_child(back)
	var screen := _card_screen(content)
	return screen


func _build_pause() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.add_child(_panel_label("Paused", 46))
	var resume := _button("Resume", 26)
	resume.pressed.connect(_set_paused.bind(false))
	var restart := _button("Restart match", 22)
	restart.pressed.connect(func() -> void:
		_set_paused(false)
		rematch_requested.emit())
	var settings := _button("Settings", 22)
	var menu := _button("Main menu", 22)
	menu.pressed.connect(func() -> void:
		_set_paused(false)
		menu_requested.emit())
	for button in [resume, restart, settings, menu]:
		button.custom_minimum_size = Vector2(280, 58)
		content.add_child(button)
	var screen := _card_screen(content)
	settings.pressed.connect(_open_settings.bind(screen))
	return screen


func _build_result() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	_result_title = _panel_label("", 58)
	_result_title.add_theme_color_override("font_color", TITLE_ORANGE)
	_result_title.add_theme_color_override("font_outline_color", INK)
	_result_title.add_theme_constant_override("outline_size", 12)
	_result_detail = _panel_label("", 22)
	content.add_child(_result_title)
	content.add_child(_result_detail)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var rematch := _button("Rematch", 24)
	rematch.custom_minimum_size = Vector2(180, 62)
	rematch.add_theme_stylebox_override("normal", _button_box(GO))
	rematch.add_theme_stylebox_override("hover", _button_box(GO.lightened(0.12)))
	rematch.pressed.connect(rematch_requested.emit)
	var change := _button("Change fighters", 22)
	change.custom_minimum_size = Vector2(210, 62)
	change.pressed.connect(func() -> void: _open_select(_select_mode))
	var menu := _button("Main menu", 22)
	menu.custom_minimum_size = Vector2(170, 62)
	menu.pressed.connect(menu_requested.emit)
	row.add_child(rematch)
	row.add_child(change)
	row.add_child(menu)
	content.add_child(row)
	return _card_screen(content)


# --- building blocks ---

## A full-screen Control registered as a screen. dim adds a dark backdrop.
func _screen_root(dim: bool) -> Control:
	var root: Control
	if dim:
		var shade := ColorRect.new()
		shade.color = Color(0.05, 0.03, 0.12, 0.5)
		root = shade
	else:
		root = Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = _theme
	add_child(root)
	_screens.append(root)
	return root


## A dimmed screen with content centred on a paper card. The dim also blocks aiming.
func _card_screen(content: Control) -> Control:
	var screen := _screen_root(true)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(PAPER, 22, 4, 30.0, true))
	card.add_child(content)
	center.add_child(card)
	screen.add_child(center)
	screen.set_meta("card", card)
	return screen


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.set_stylebox("normal", "Button", _button_box(BUTTON.lerp(PAPER, 0.45)))
	theme.set_stylebox("hover", "Button", _button_box(BUTTON.lerp(PAPER, 0.2)))
	theme.set_stylebox("pressed", "Button", _button_box(BUTTON, true))
	theme.set_stylebox("hover_pressed", "Button", _button_box(BUTTON.lightened(0.1), true))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(color_name, "Button", INK)
	var track := _box(INK.lightened(0.2), 8, 0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", _box(BUTTON, 8, 0))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box(BUTTON.lightened(0.2), 8, 0))
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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
