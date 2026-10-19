class_name Hud
extends CanvasLayer
## Every screen drawn over the arena: the title screen (with a showcase fighter),
## fighter select, settings, how to play, the VS splash, the in-match HUD, pause and
## results. Built in code from UiStyle pieces; screens are shown one at a time.

## map is null for a random map.
signal play_requested(left: FighterData, right: FighterData, mode: int, difficulty: int, map: MapData)
signal rematch_requested
## Tournament: play (or retry) the current round, or go back to the ladder.
signal round_requested
signal ladder_requested
## Title screen: play today's daily challenge, or continue a saved tournament.
signal daily_requested
signal resume_requested
## Tournament lost and the player gave up: forget the saved run.
signal give_up_requested
## The player armed (or disarmed) their once-per-match special.
signal special_toggled(armed: bool)
signal menu_requested
signal pause_changed(paused: bool)

const INK := UiStyle.INK
const PAPER := UiStyle.PAPER
const GHOST := Color(1.0, 0.95, 0.75)
const VERSION := "v0.1"
const HINT_TEXT := "Drag back to aim, release to throw  •  Drag back to the start to cancel  •  ↑↓ angle  ←→ power  Space throws  •  Esc pauses"
const TOUCH_HINT_TEXT := "Drag back anywhere to aim, let go to throw  •  Drag back to where you started to cancel"
const DIFFICULTY_NAMES := ["Easy", "Normal", "Hard"]
const DIFFICULTY_COLORS := [UiStyle.GREEN, UiStyle.YELLOW, UiStyle.RED]
const SHOWCASE_SCALE := 2.4
const SHOWCASE_CYCLE := 5.5
const LOW_HEALTH := 30

var _roster: Array[FighterData] = []
var _maps: Array[MapData] = []
var _in_match := false
var _time := 0.0

# Match HUD
var _top_bar: Control
var _plates: Array[HBoxContainer] = []
var _names: Array[Label] = []
var _bars: Array[ProgressBar] = []
var _ghosts: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _turn_ribbon: PanelContainer
var _turn_label: Label
var _turn_text := ""
var _wind_gauge: WindGauge
var _special_button: Button
var _special_meter: ProgressBar
var _special_ready := false
var _announcer: VBoxContainer
var _hint: Label
var _pause_button: Button
var _intro: VsIntro

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
var _showcase_area: Control
var _showcase_root: Node2D
var _showcase: Fighter
var _showcase_index := 0
var _showcase_time := 0.0
var _showcase_name: Label
var _showcase_weapon: Label
var _showcase_special: Label
var _menu: VBoxContainer
var _tournament_button: Button
var _daily_button: Button
var _coins_pill: PanelContainer
var _shop_screen: Control
var _shop_content: VBoxContainer
var _stats_screen: Control
var _stats_content: VBoxContainer
var _toasts: VBoxContainer
var _portrait_tip: Button
var _portrait_dismissed := false

# Fighter select
var _select_mode: int = MatchController.Mode.VS_AI
var _select_step := 0
var _picks: Array[FighterData] = [null, null]
var _difficulty: int = AiAimer.Difficulty.NORMAL
var _select_ribbon: PanelContainer
var _card_buttons: Array[Button] = []
var _difficulty_box: Control
var _go_label: Label
## null means a random map.
var _map_choice: MapData
var _map_screen: Control

# Tournament ladder
var _ladder_screen: Control
var _ladder_content: VBoxContainer

# Results
var _result_ribbon: PanelContainer
var _result_detail: Label
var _result_portrait_holder: CenterContainer
var _result_stats: GridContainer
var _result_buttons: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(roster: Array[FighterData], maps: Array[MapData]) -> void:
	_roster = roster
	_maps = maps
	_picks = [roster[0], roster[1]]
	_build_match_hud()
	_title_screen = _build_title()
	_select_screen = _build_select()
	_map_screen = _build_map_screen()
	_ladder_screen = _build_ladder()
	_shop_screen = _build_list_screen("SHOP", UiStyle.YELLOW)
	_shop_content = _shop_screen.get_meta("content")
	_stats_screen = _build_list_screen("TROPHIES & STATS", UiStyle.ORANGE)
	_stats_content = _stats_screen.get_meta("content")
	_settings_screen = _build_settings()
	_howto_screen = _build_howto()
	_pause_screen = _build_pause()
	_result_screen = _build_result()
	_intro = VsIntro.new()
	add_child(_intro)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_left = -440
	_toasts.offset_top = 80
	_toasts.offset_right = -16
	_toasts.add_theme_constant_override("separation", 8)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	_build_portrait_tip()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	_show_screen(null)


# --- public API used by MatchController ---

func show_title() -> void:
	_in_match = false
	_top_bar.hide()
	_hint.hide()
	_pause_button.hide()
	_special_button.hide()
	_set_showcase(_showcase_index)
	_show_screen(_title_screen)
	_refresh_title()
	# Menu buttons fade in one after another.
	var delay := 0.1
	for item in _menu.get_children():
		var control := item as Control
		control.modulate.a = 0.0
		var tween := control.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(control, "modulate:a", 1.0, 0.25)
		delay += 0.07


func show_match() -> void:
	_in_match = true
	_top_bar.show()
	_hint.visible = Save.show_hints
	_pause_button.show()
	_show_screen(null)


## Plays the VS splash; await this before the first turn.
func play_intro(left: FighterData, right: FighterData, names: Array[String]) -> void:
	_top_bar.hide()
	_pause_button.hide()
	_hint.hide()
	_intro.play(left, right, names[0], names[1])
	await _intro.finished
	if _in_match:
		_top_bar.show()
		_pause_button.show()
		_hint.visible = Save.show_hints
		_top_bar.modulate.a = 0.0
		_top_bar.create_tween().tween_property(_top_bar, "modulate:a", 1.0, 0.25)


func bind_fighters(fighters: Array[Fighter], player_names: Array[String]) -> void:
	for i in fighters.size():
		var fighter := fighters[i]
		var plate := _plates[i]
		var old := plate.get_child(0 if i == 0 else plate.get_child_count() - 1)
		plate.remove_child(old)
		old.queue_free()
		var portrait := Portrait.make(fighter.data, fighter.facing, 76.0)
		plate.add_child(portrait)
		plate.move_child(portrait, 0 if i == 0 else plate.get_child_count() - 1)
		_names[i].text = "%s  ·  %s" % [player_names[i], fighter.data.short_name] if i == 0 else "%s  ·  %s" % [fighter.data.short_name, player_names[i]]
		_bars[i].add_theme_stylebox_override("fill", _bar_fill(fighter.data.body_color))
		_bars[i].value = fighter.health
		_ghosts[i].value = fighter.health
		_hp_labels[i].text = str(fighter.health)
		fighter.health_changed.connect(_on_health_changed.bind(i))


## Target Practice has no opponent, so hide the right-hand plate.
func set_practice(on: bool) -> void:
	_plates[1].visible = not on


func set_wind(wind: float) -> void:
	_wind_gauge.set_wind(wind)


## Shows the special button for this fighter (null hides it). charge (0..1) fills the
## meter along its bottom; it can be tapped only when full.
func set_special(data: FighterData, charge: float, armed: bool) -> void:
	if data == null:
		_special_button.hide()
		return
	var ready := charge >= 1.0
	var label: Label = _special_button.get_meta("label")
	label.text = data.special_name if ready else "%s  %d%%" % [data.special_name, roundi(charge * 100.0)]
	UiStyle.paint_button(_special_button, data.body_color if ready else UiStyle.GREY)
	_special_button.disabled = not ready
	_special_button.set_pressed_no_signal(armed)
	_special_meter.value = charge
	_special_meter.add_theme_stylebox_override("fill", UiStyle.flat(data.body_color.lightened(0.2), 4))
	_special_button.show()
	_special_button.tooltip_text = data.special_description
	_special_button.pivot_offset = _special_button.size / 2
	_special_ready = ready


## Seconds left in a 1v1 turn, shown in the banner (negative hides it).
func set_timer(seconds: int) -> void:
	if _turn_text.is_empty():
		return
	_turn_label.text = _turn_text if seconds < 0 else "%s  ·  %d" % [_turn_text, seconds]


## A big callout in the middle of the screen (combos, specials, close calls).
func announce(text: String, color: Color) -> void:
	var label := UiStyle.game_label(text, 54, true)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcer.add_child(label)
	label.pivot_offset = Vector2(400, 35)
	label.scale = Vector2(1.8, 1.8)
	label.modulate.a = 0.0
	var tween := label.create_tween()
	tween.set_parallel()
	tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.chain().tween_interval(1.1)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(label.queue_free)


## Shows the turn banner in a colour (empty text hides it).
func set_turn(text: String, color: Color = UiStyle.YELLOW) -> void:
	if text.is_empty():
		_turn_ribbon.hide()
		return
	_turn_text = text
	_turn_label.text = text
	_turn_ribbon.add_theme_stylebox_override("panel", UiStyle.candy(color))
	_turn_ribbon.show()
	_turn_ribbon.pivot_offset = _turn_ribbon.size / 2
	_turn_ribbon.scale = Vector2(0.4, 0.4)
	_turn_ribbon.modulate.a = 0.0
	var tween := _turn_ribbon.create_tween().set_parallel()
	tween.tween_property(_turn_ribbon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_turn_ribbon, "modulate:a", 1.0, 0.15)


func show_hint(visible_now: bool) -> void:
	_hint.visible = visible_now and Save.show_hints


## outcome: title, color, detail, winner (FighterData), winner_facing, names
## (Array[String]) and stats (2 Dictionaries: throws, hits, headshots, damage, longest).
func show_result(outcome: Dictionary) -> void:
	var label: Label = _result_ribbon.get_meta("label")
	label.text = outcome["title"]
	_result_ribbon.add_theme_stylebox_override("panel", UiStyle.candy(outcome["color"]))
	_result_detail.text = outcome["detail"]
	for child in _result_portrait_holder.get_children():
		child.queue_free()
	_result_portrait_holder.add_child(Portrait.make(outcome["winner"], outcome["winner_facing"], 128.0))
	_fill_stats(outcome["names"], outcome["stats"])
	_result_stats.get_parent().get_parent().visible = not outcome.has("practice")
	_fill_result_buttons(outcome.get("tournament", {}))
	_special_button.hide()
	_pause_button.hide()
	_hint.hide()
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
		card.scale = Vector2(0.85, 0.85)
		tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	if not event.is_action_pressed("ui_cancel") or _intro.visible:
		return
	get_viewport().set_input_as_handled()
	if _settings_screen.visible:
		_close_settings()
	elif _map_screen.visible:
		_show_screen(_select_screen)
	elif _select_screen.visible:
		_select_back()
	elif _howto_screen.visible:
		show_title()
	elif _ladder_screen.visible:
		menu_requested.emit()
	elif _shop_screen.visible or _stats_screen.visible:
		show_title()
	elif _pause_screen.visible:
		_set_paused(false)
	elif _in_match and not _result_screen.visible:
		_set_paused(true)


func _process(delta: float) -> void:
	_time += delta
	var view := get_viewport().get_visible_rect().size
	_portrait_tip.visible = not _portrait_dismissed and view.y > view.x
	if _title_screen != null and _title_screen.visible:
		_showcase_root.position = Vector2(_showcase_area.size.x * 0.5, _showcase_area.size.y * 0.64)
		_animate_showcase(delta)
	# A ready special button breathes so you notice it.
	if _special_button != null and _special_button.visible and _special_ready:
		_special_button.scale = Vector2.ONE * (1.0 + 0.04 * sin(_time * 6.0))
	# Low health bars pulse red.
	for bar in _bars:
		if bar.value > 0 and bar.value <= LOW_HEALTH:
			bar.modulate = Color.WHITE.lerp(Color(1.0, 0.5, 0.5), 0.5 + 0.5 * sin(_time * 8.0))
		else:
			bar.modulate = Color.WHITE


# --- in-match HUD ---

func _build_match_hud() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	for side in ["left", "right", "top"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var row := HBoxContainer.new()
	margin.add_child(row)
	for i in 2:
		var plate := HBoxContainer.new()
		plate.add_theme_constant_override("separation", 10)
		var placeholder := Control.new()
		placeholder.custom_minimum_size = Vector2(76, 76)
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 330
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 2)
		var name_label := UiStyle.game_label("", 26, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		name_label.clip_text = true
		var stack := Panel.new()
		stack.custom_minimum_size.y = 34
		stack.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.08, 0.05, 0.12, 0.7), 12, 4))
		var ghost := _bar(UiStyle.flat(GHOST, 8))
		var bar := _bar(_bar_fill(Color.WHITE))
		if i == 1:
			ghost.fill_mode = ProgressBar.FILL_END_TO_BEGIN
			bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		var hp := UiStyle.game_label("100", 20, true)
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.add_child(ghost)
		stack.add_child(bar)
		stack.add_child(hp)
		column.add_child(name_label)
		column.add_child(stack)
		if i == 0:
			plate.add_child(placeholder)
			plate.add_child(column)
		else:
			plate.add_child(column)
			plate.add_child(placeholder)
		_plates.append(plate)
		_names.append(name_label)
		_bars.append(bar)
		_ghosts.append(ghost)
		_hp_labels.append(hp)
		row.add_child(plate)
		if i == 0:
			var middle := VBoxContainer.new()
			middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			middle.alignment = BoxContainer.ALIGNMENT_BEGIN
			middle.add_theme_constant_override("separation", 6)
			_turn_ribbon = UiStyle.ribbon("", UiStyle.YELLOW, 30)
			_turn_label = _turn_ribbon.get_meta("label")
			_turn_ribbon.custom_minimum_size.x = 260
			_turn_ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_turn_ribbon.hide()
			middle.add_child(_turn_ribbon)
			_wind_gauge = WindGauge.new()
			_wind_gauge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			middle.add_child(_wind_gauge)
			row.add_child(middle)
	add_child(margin)
	_ignore_mouse(margin)
	_top_bar = margin

	_hint = UiStyle.game_label(TOUCH_HINT_TEXT if Device.uses_touch() else HINT_TEXT, 18 if Device.uses_touch() else 17)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -44
	_hint.offset_bottom = -12
	_hint.offset_right = -100
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_hint)

	_pause_button = _icon_button(&"pause", "", UiStyle.YELLOW, Vector2(72, 68), 0)
	_pause_button.theme = UiStyle.theme()
	_pause_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_pause_button.offset_left = -88
	_pause_button.offset_top = -84
	_pause_button.offset_right = -16
	_pause_button.offset_bottom = -16
	_pause_button.pressed.connect(_set_paused.bind(true))
	add_child(_pause_button)

	_special_button = _icon_button(&"star", "Special", UiStyle.PURPLE, Vector2(230, 68), 22)
	_special_button.theme = UiStyle.theme()
	_special_button.toggle_mode = true
	_special_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_special_button.offset_left = 16
	_special_button.offset_top = -132
	_special_button.offset_right = 246
	_special_button.offset_bottom = -64
	_special_button.toggled.connect(func(on: bool) -> void: special_toggled.emit(on))
	_special_meter = ProgressBar.new()
	_special_meter.max_value = 1.0
	_special_meter.show_percentage = false
	_special_meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_special_meter.offset_left = 14
	_special_meter.offset_right = -14
	_special_meter.offset_top = -16
	_special_meter.offset_bottom = -9
	_special_meter.add_theme_stylebox_override("background", UiStyle.flat(Color(0, 0, 0, 0.3), 4))
	_special_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_special_button.add_child(_special_meter)
	_special_button.hide()
	add_child(_special_button)

	_announcer = VBoxContainer.new()
	_announcer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_announcer.offset_top = 170
	_announcer.offset_left = -400
	_announcer.offset_right = 400
	_announcer.alignment = BoxContainer.ALIGNMENT_BEGIN
	_announcer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_announcer)


func _bar(fill: StyleBox) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = Rules.MAX_HEALTH
	bar.show_percentage = false
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.offset_left = 5
	bar.offset_top = 5
	bar.offset_right = -5
	bar.offset_bottom = -5
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## Health fill: the fighter's colour with a light top band (a thick top border).
func _bar_fill(color: Color) -> StyleBoxFlat:
	var box := UiStyle.flat(color, 7)
	box.border_color = color.lightened(0.35)
	box.border_width_top = 6
	return box


func _on_health_changed(_fighter: Fighter, health: int, index: int) -> void:
	_hp_labels[index].text = str(health)
	_bars[index].create_tween().tween_property(_bars[index], "value", float(health), 0.18)
	# The pale ghost bar lingers, then drains, so you can see how much a hit took.
	_ghosts[index].create_tween().tween_property(_ghosts[index], "value", float(health), 0.5).set_delay(0.5)
	var label := _hp_labels[index]
	label.pivot_offset = label.size / 2
	label.scale = Vector2(1.6, 1.6)
	label.create_tween().tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var plate := _plates[index]
	plate.pivot_offset = plate.size / 2
	var shake := plate.create_tween()
	for k in 4:
		shake.tween_property(plate, "rotation", 0.04 * (1 if k % 2 == 0 else -1), 0.04)
	shake.tween_property(plate, "rotation", 0.0, 0.05)


# --- title screen ---

func _build_title() -> Control:
	var screen := _screen_root(false)

	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.03, 0.12, 0.5))
	gradient.set_color(1, Color(0.05, 0.03, 0.12, 0.75))
	gradient.add_point(0.45, Color(0.05, 0.03, 0.12, 0.0))
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
	_showcase_area = left
	_showcase_root = Node2D.new()
	_showcase_root.draw.connect(_draw_pedestal)
	left.add_child(_showcase_root)

	var plate := VBoxContainer.new()
	plate.anchor_left = 0.5
	plate.anchor_right = 0.5
	plate.anchor_top = 0.73
	plate.anchor_bottom = 0.98
	plate.offset_left = -290
	plate.offset_right = 290
	plate.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_theme_constant_override("separation", 2)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 14)
	var prev := _icon_button(&"back", "", UiStyle.YELLOW, Vector2(60, 60), 0)
	prev.pressed.connect(func() -> void: _set_showcase(_showcase_index - 1))
	_showcase_name = UiStyle.game_label("", 38, true)
	_showcase_name.custom_minimum_size.x = 340
	_showcase_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := _icon_button(&"play", "", UiStyle.YELLOW, Vector2(60, 60), 0)
	next.pressed.connect(func() -> void: _set_showcase(_showcase_index + 1))
	name_row.add_child(prev)
	name_row.add_child(_showcase_name)
	name_row.add_child(next)
	plate.add_child(name_row)
	_showcase_weapon = UiStyle.game_label("", 20)
	_showcase_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(_showcase_weapon)
	_showcase_special = UiStyle.game_label("", 17)
	_showcase_special.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_showcase_special.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	plate.add_child(_showcase_special)
	left.add_child(plate)

	# Right half: logo and the main menu.
	var right := VBoxContainer.new()
	right.anchor_left = 0.5
	right.anchor_right = 1.0
	right.anchor_bottom = 1.0
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 8)
	screen.add_child(right)
	var logo := WavyTitle.new()
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(logo)
	var tagline := UiStyle.game_label("Aim.  Throw.  Wobble.", 22)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(tagline)
	right.add_child(_spacer(12))

	_menu = VBoxContainer.new()
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu.add_theme_constant_override("separation", 12)
	right.add_child(_menu)
	var play_ai := _menu_button(&"play", "Play vs AI", "Duel the computer", UiStyle.GREEN)
	play_ai.pressed.connect(_open_select.bind(MatchController.Mode.VS_AI))
	_menu.add_child(play_ai)
	_tournament_button = _menu_button(&"trophy", "Tournament", "4 rounds, each one harder", UiStyle.YELLOW)
	_tournament_button.pressed.connect(func() -> void:
		if Save.tournament.is_empty():
			_open_select(MatchController.Mode.TOURNAMENT)
		else:
			resume_requested.emit())
	_menu.add_child(_tournament_button)
	var duo_row := HBoxContainer.new()
	duo_row.add_theme_constant_override("separation", 12)
	var play_2p := _icon_button(&"duo", "1v1 friend", UiStyle.ORANGE, Vector2(184, 64), 22)
	play_2p.pressed.connect(_open_select.bind(MatchController.Mode.LOCAL_2P))
	var practice := _icon_button(&"target", "Practice", UiStyle.BLUE, Vector2(184, 64), 22)
	practice.pressed.connect(_open_select.bind(MatchController.Mode.PRACTICE))
	duo_row.add_child(play_2p)
	duo_row.add_child(practice)
	_menu.add_child(duo_row)
	var extra_row := HBoxContainer.new()
	extra_row.add_theme_constant_override("separation", 12)
	_daily_button = _icon_button(&"star", "Daily", UiStyle.PURPLE, Vector2(184, 64), 22)
	_daily_button.pressed.connect(daily_requested.emit)
	var shop := _icon_button(&"coin", "Shop", UiStyle.YELLOW.lightened(0.1), Vector2(184, 64), 22)
	shop.pressed.connect(_open_shop)
	extra_row.add_child(_daily_button)
	extra_row.add_child(shop)
	_menu.add_child(extra_row)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var settings := _icon_button(&"gear", "", UiStyle.BLUE.lightened(0.25), Vector2(118, 58), 0)
	settings.pressed.connect(_open_settings.bind(screen))
	var stats := _icon_button(&"trophy", "", UiStyle.ORANGE.lightened(0.15), Vector2(118, 58), 0)
	stats.pressed.connect(_open_stats.bind(true))
	var howto := _icon_button(&"help", "", UiStyle.PURPLE.lightened(0.25), Vector2(118, 58), 0)
	howto.pressed.connect(func() -> void: _show_screen(_howto_screen))
	for button in [settings, stats, howto]:
		row.add_child(button)
	_menu.add_child(row)
	if not OS.has_feature("web"):
		var quit := _icon_button(&"quit", "", UiStyle.GREY, Vector2(56, 52), 0)
		quit.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		quit.offset_left = 16
		quit.offset_top = 16
		quit.offset_right = 72
		quit.offset_bottom = 68
		quit.pressed.connect(func() -> void: get_tree().quit())
		screen.add_child(quit)

	_coins_pill = _coin_pill()
	_coins_pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_coins_pill.offset_left = -190
	_coins_pill.offset_top = 16
	_coins_pill.offset_right = -16
	_coins_pill.offset_bottom = 64
	screen.add_child(_coins_pill)

	var version := UiStyle.game_label(VERSION, 16)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -80
	version.offset_top = -36
	version.offset_right = -16
	version.offset_bottom = -10
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen.add_child(version)
	return screen


func _menu_button(icon: StringName, title: String, subtitle: String, color: Color) -> Button:
	var button := _button("", 18)
	button.custom_minimum_size = Vector2(380, 80)
	UiStyle.paint_button(button, color)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 22
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiIcon.make(icon, 44))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := UiStyle.game_label(title, 30, true)
	var small := UiStyle.ink_label(subtitle, 16)
	button.set_meta("subtitle", small)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	small.add_theme_color_override("font_color", INK.lightened(0.15))
	text.add_child(big)
	text.add_child(small)
	row.add_child(text)
	button.add_child(row)
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
	_showcase.position.y = -40
	_showcase.reset_physics_interpolation()
	_showcase.modulate.a = 0.0
	var tween := _showcase.create_tween().set_parallel()
	tween.tween_property(_showcase, "modulate:a", 1.0, 0.25)
	tween.tween_property(_showcase, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_showcase_name.text = data.display_name
	_showcase_weapon.text = "%s  ·  %d body / %d head" % [data.weapon.display_name, data.weapon.body_damage, data.weapon.head_damage]
	_showcase_special.text = "★ %s — %s" % [data.special_name, data.special_description]
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
	# Light beam from above.
	root.draw_colored_polygon(PackedVector2Array([Vector2(-60, -560), Vector2(60, -560), Vector2(150, 0), Vector2(-150, 0)]), Color(glow.lightened(0.5), 0.08 + 0.04 * pulse))
	root.draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.26))
	for i in 4:
		root.draw_circle(Vector2.ZERO, 150.0 + i * 26.0, Color(glow, 0.07 + 0.04 * pulse), true, -1.0, true)
	root.draw_circle(Vector2.ZERO, 128.0, INK, true, -1.0, true)
	root.draw_circle(Vector2.ZERO, 122.0, Color(0.72, 0.62, 0.62), true, -1.0, true)
	root.draw_circle(Vector2(0, -14), 112.0, Color(0.86, 0.78, 0.74), true, -1.0, true)
	root.draw_set_transform(Vector2.ZERO)
	root.draw_rect(Rect2(-123, 6, 246, 34), Color(0.62, 0.52, 0.54))
	root.draw_rect(Rect2(-123, 14, 246, 6), Color(glow, 0.6 + 0.3 * pulse))
	root.draw_set_transform(Vector2(0, 40), 0.0, Vector2(1.0, 0.26))
	root.draw_circle(Vector2.ZERO, 123.0, Color(0.5, 0.4, 0.44), true, -1.0, true)
	root.draw_set_transform(Vector2.ZERO)


# --- fighter select ---

func _build_select() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	var cards := GridContainer.new()
	cards.columns = 4
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 10)
	var group := ButtonGroup.new()
	for i in _roster.size():
		var card := _fighter_card(_roster[i], group)
		card.pressed.connect(_on_card_picked.bind(i))
		cards.add_child(card)
		_card_buttons.append(card)
	content.add_child(cards)

	var difficulty := HBoxContainer.new()
	difficulty.alignment = BoxContainer.ALIGNMENT_CENTER
	difficulty.add_theme_constant_override("separation", 10)
	var label := UiStyle.ink_label("AI difficulty", 22, true)
	label.custom_minimum_size.x = 150
	difficulty.add_child(label)
	var difficulty_group := ButtonGroup.new()
	for level in DIFFICULTY_NAMES.size():
		var button := _button(DIFFICULTY_NAMES[level], 20)
		button.custom_minimum_size = Vector2(130, 54)
		button.toggle_mode = true
		button.button_group = difficulty_group
		var color: Color = DIFFICULTY_COLORS[level]
		button.add_theme_stylebox_override("normal", UiStyle.candy(color.lerp(PAPER, 0.6)))
		button.add_theme_stylebox_override("hover", UiStyle.candy(color.lerp(PAPER, 0.4)))
		button.add_theme_stylebox_override("pressed", UiStyle.candy(color, true))
		button.add_theme_stylebox_override("hover_pressed", UiStyle.candy(color, true))
		button.button_pressed = level == _difficulty
		button.pressed.connect(func() -> void: _difficulty = level)
		difficulty.add_child(button)
	content.add_child(difficulty)
	_difficulty_box = difficulty

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	var back := _icon_button(&"back", "Back", UiStyle.GREY, Vector2(170, 70), 24)
	back.pressed.connect(_select_back)
	var go := _icon_button(&"sword", "Fight!", UiStyle.GREEN, Vector2(280, 70), 34)
	_go_label = go.get_meta("label")
	go.pressed.connect(_select_next)
	bottom.add_child(back)
	bottom.add_child(go)
	content.add_child(bottom)
	var screen := _card_screen("CHOOSE YOUR FIGHTER", UiStyle.YELLOW, content)
	_select_ribbon = screen.get_meta("ribbon")
	return screen


func _fighter_card(data: FighterData, group: ButtonGroup) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = group
	card.custom_minimum_size = Vector2(232, 200)
	card.add_theme_stylebox_override("normal", UiStyle.candy(data.body_color.lerp(PAPER, 0.72)))
	card.add_theme_stylebox_override("hover", UiStyle.candy(data.body_color.lerp(PAPER, 0.5)))
	card.add_theme_stylebox_override("pressed", UiStyle.candy(data.body_color.lerp(PAPER, 0.15), true))
	card.add_theme_stylebox_override("hover_pressed", UiStyle.candy(data.body_color.lerp(PAPER, 0.1), true))
	card.pressed.connect(Audio.play.bind("click", -4.0))

	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_top = 8
	stack.offset_left = 12
	stack.offset_right = -12
	stack.offset_bottom = -14
	stack.add_theme_constant_override("separation", 3)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 100)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.clip_contents = true
	var fighter: Fighter = preload("res://scenes/fighter/fighter.tscn").instantiate()
	preview.add_child(fighter)
	fighter.setup(data, 1, false, false)
	fighter.scale = Vector2(0.62, 0.62)
	preview.resized.connect(func() -> void:
		fighter.position = Vector2(preview.size.x / 2, preview.size.y - 6)
		fighter.reset_physics_interpolation())
	stack.add_child(preview)
	stack.add_child(UiStyle.ink_label(data.display_name, 19, true))
	var weapon := UiStyle.ink_label(data.weapon.display_name, 15)
	weapon.add_theme_color_override("font_color", INK.lightened(0.25))
	stack.add_child(weapon)
	var power := data.weapon.body_damage * data.weapon.count
	stack.add_child(_stat_row("Power", clampi(roundi(power / 7.0), 1, 5), data.body_color))
	stack.add_child(_stat_row("Speed", clampi(roundi((data.weapon.max_speed - 1150.0) / 55.0), 1, 5), data.body_color))
	card.add_child(stack)
	card.set_meta("fighter", fighter)
	card.set_meta("data", data)
	# Locked: dim the card and show the Shop price.
	var lock := PanelContainer.new()
	var lock_box := UiStyle.flat(Color(0.08, 0.05, 0.12, 0.88), 14, 0)
	lock.add_theme_stylebox_override("panel", lock_box)
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.offset_bottom = -6
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lock_label := UiStyle.game_label("LOCKED
%d coins in the Shop" % data.price, 18, true)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock.add_child(lock_label)
	card.add_child(lock)
	card.set_meta("lock", lock)
	return card


## A toggle showing a tiny painting of the map (sky, hills, ground). null = random.
func _map_button(map: MapData, group: ButtonGroup) -> Button:
	var color := map.accent if map != null else UiStyle.GREY
	var button := _button("", 16)
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(330, 120)
	button.add_theme_stylebox_override("normal", UiStyle.candy(color.lerp(PAPER, 0.6)))
	button.add_theme_stylebox_override("hover", UiStyle.candy(color.lerp(PAPER, 0.4)))
	button.add_theme_stylebox_override("pressed", UiStyle.candy(color, true))
	button.add_theme_stylebox_override("hover_pressed", UiStyle.candy(color, true))
	button.button_pressed = map == _map_choice
	button.pressed.connect(func() -> void: _map_choice = map)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -8
	row.offset_top = 6
	row.offset_bottom = -12
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(150, 0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, preview.size)
		if map == null:
			preview.draw_style_box(UiStyle.flat(Color(0.3, 0.28, 0.35), 8, 2), r)
			var font := UiStyle.title_font()
			preview.draw_string(font, Vector2(0, r.size.y * 0.72), "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color.WHITE)
			return
		var bands := [map.sky_top, map.sky_mid, map.sky_low, map.sky_horizon]
		for i in bands.size():
			preview.draw_rect(Rect2(0, r.size.y * 0.16 * i, r.size.x, r.size.y * 0.17), bands[i])
		var hills := PackedVector2Array([Vector2(0, r.size.y * 0.7), Vector2(r.size.x * 0.3, r.size.y * 0.42), Vector2(r.size.x * 0.55, r.size.y * 0.6), Vector2(r.size.x * 0.8, r.size.y * 0.38), Vector2(r.size.x, r.size.y * 0.62), Vector2(r.size.x, r.size.y), Vector2(0, r.size.y)])
		preview.draw_colored_polygon(hills, map.far_color)
		preview.draw_rect(Rect2(0, r.size.y * 0.78, r.size.x, r.size.y * 0.22), map.ground_top)
		preview.draw_rect(r, INK, false, 2.0))
	row.add_child(preview)
	var name_label := UiStyle.game_label(map.display_name if map != null else "Random", 17, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	button.add_child(row)
	return button


## A label and five pips, `value` of them filled.
func _stat_row(label_text: String, value: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiStyle.ink_label(label_text, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.custom_minimum_size.x = 64
	row.add_child(label)
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(130, 18)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func() -> void:
		for i in 5:
			var filled := i < value
			pips.draw_style_box(UiStyle.flat(color if filled else Color(0, 0, 0, 0.12), 5, 2 if filled else 0), Rect2(i * 26.0, 2, 22, 14)))
	row.add_child(pips)
	return row


func _refresh_select() -> void:
	var vs_ai := _select_mode == MatchController.Mode.VS_AI
	var is_tournament := _select_mode == MatchController.Mode.TOURNAMENT
	var label: Label = _select_ribbon.get_meta("label")
	var color := UiStyle.YELLOW
	if is_tournament:
		label.text = "CHOOSE YOUR CHAMPION"
		color = UiStyle.ORANGE
	elif _select_mode == MatchController.Mode.PRACTICE:
		label.text = "TARGET PRACTICE"
		color = UiStyle.BLUE
	elif vs_ai:
		label.text = "CHOOSE YOUR FIGHTER"
	else:
		label.text = "PLAYER %d, CHOOSE!" % (_select_step + 1)
		color = UiStyle.BLUE if _select_step == 0 else UiStyle.RED
	_select_ribbon.add_theme_stylebox_override("panel", UiStyle.candy(color))
	_difficulty_box.visible = vs_ai
	var two_player := _select_mode == MatchController.Mode.LOCAL_2P
	var picks_map := vs_ai or (two_player and _select_step == 1)
	_go_label.text = "Next" if picks_map or (two_player and _select_step == 0) else "Start!"
	# Only fighters you own can be picked; fall back to the first owned one.
	if not Save.is_unlocked(_picks[_select_step]):
		for fighter in _roster:
			if Save.is_unlocked(fighter):
				_picks[_select_step] = fighter
				break
	var picked := _roster.find(_picks[_select_step])
	for i in _card_buttons.size():
		_card_buttons[i].set_pressed_no_signal(i == picked)
		var locked := not Save.is_unlocked(_card_buttons[i].get_meta("data"))
		_card_buttons[i].disabled = locked
		(_card_buttons[i].get_meta("lock") as Control).visible = locked
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
	# Vs AI and 1v1 go on to choose a map; tournaments and practice start straight away.
	if _select_mode == MatchController.Mode.VS_AI or _select_mode == MatchController.Mode.LOCAL_2P:
		_show_screen(_map_screen)
		return
	_start_selected()


func _start_selected() -> void:
	var right := _picks[1] if _select_mode == MatchController.Mode.LOCAL_2P else null
	play_requested.emit(_picks[0], right, _select_mode, _difficulty, _map_choice)


## Choose a map (or Random) before a vs AI or 1v1 match.
func _build_map_screen() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var group := ButtonGroup.new()
	for map in _maps:
		grid.add_child(_map_button(map, group))
	content.add_child(grid)
	var random := _map_button(null, group)
	random.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(random)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	var back := _icon_button(&"back", "Back", UiStyle.GREY, Vector2(170, 70), 24)
	back.pressed.connect(func() -> void: _show_screen(_select_screen))
	var go := _icon_button(&"sword", "Fight!", UiStyle.GREEN, Vector2(280, 70), 34)
	go.pressed.connect(_start_selected)
	bottom.add_child(back)
	bottom.add_child(go)
	content.add_child(bottom)
	return _card_screen("CHOOSE A MAP", UiStyle.PURPLE, content)


# --- settings, how to play, pause, results ---

func _build_settings() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
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
	content.add_child(_toggle_row("Music", "music_on"))
	var music_row := _setting_row("Music volume")
	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = Save.music_volume
	music_slider.custom_minimum_size = Vector2(220, 36)
	music_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	music_slider.value_changed.connect(func(value: float) -> void:
		Save.music_volume = value
		Save.apply()
		Save.save_settings())
	music_row.add_child(music_slider)
	content.add_child(music_row)
	content.add_child(_toggle_row("Screen shake", "screen_shake"))
	content.add_child(_toggle_row("Long aim guide", "long_aim_guide"))
	content.add_child(_toggle_row("Controls hint", "show_hints"))
	if Device.is_mobile():
		content.add_child(_toggle_row("Vibration", "vibration"))
	var done := _icon_button(&"play", "Done", UiStyle.GREEN, Vector2(220, 66), 26)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(_close_settings)
	content.add_child(done)
	return _card_screen("SETTINGS", UiStyle.BLUE, content)


func _close_settings() -> void:
	if _in_match:
		_hint.visible = Save.show_hints and not _result_screen.visible
	_show_screen(_settings_return)


func _setting_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var label := UiStyle.ink_label(label_text, 24, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.custom_minimum_size.x = 240
	row.add_child(label)
	return row


## A row with an ON/OFF button bound to a bool property on Save.
func _toggle_row(label_text: String, property: String) -> HBoxContainer:
	var row := _setting_row(label_text)
	var button := _button("", 22)
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(220, 54)
	button.add_theme_stylebox_override("normal", UiStyle.candy(UiStyle.GREY))
	button.add_theme_stylebox_override("hover", UiStyle.candy(UiStyle.GREY.lightened(0.1)))
	button.add_theme_stylebox_override("pressed", UiStyle.candy(UiStyle.GREEN, true))
	button.add_theme_stylebox_override("hover_pressed", UiStyle.candy(UiStyle.GREEN.lightened(0.1), true))
	button.button_pressed = Save.get(property)
	button.text = "ON" if button.button_pressed else "OFF"
	button.toggled.connect(func(on: bool) -> void:
		button.text = "ON" if on else "OFF"
		Save.set(property, on)
		Save.apply()
		Save.save_settings())
	row.add_child(button)
	return row


func _build_howto() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var lines := [
		[&"play", "Drag back anywhere and let go to throw. Drag further to throw harder."],
		[&"back", "Drag back to where you started to cancel."],
		[&"gear", "Keyboard: ↑↓ angle, ←→ power, Space throws."],
		[&"sword", "Hit the head for big damage. Knock your rival to 0 health to win."],
		[&"home", "Towers, walls and floating slabs block throws. Lob over or sneak under."],
		[&"pause", "Esc or the pause button stops the match."],
	]
	for line: Array in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var badge := PanelContainer.new()
		badge.add_theme_stylebox_override("panel", UiStyle.flat(UiStyle.PURPLE.lightened(0.2), 10, 3))
		badge.add_child(UiIcon.make(line[0], 30))
		row.add_child(badge)
		var label := UiStyle.ink_label(line[1], 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 600
		row.add_child(label)
		content.add_child(row)
	var back := _icon_button(&"play", "Got it!", UiStyle.GREEN, Vector2(220, 66), 26)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_title)
	content.add_child(back)
	return _card_screen("HOW TO PLAY", UiStyle.PURPLE, content)


func _build_pause() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var resume := _icon_button(&"play", "Resume", UiStyle.GREEN, Vector2(300, 66), 26)
	resume.pressed.connect(_set_paused.bind(false))
	var restart := _icon_button(&"restart", "Restart match", UiStyle.YELLOW, Vector2(300, 62), 22)
	restart.pressed.connect(func() -> void:
		_set_paused(false)
		rematch_requested.emit())
	var settings := _icon_button(&"gear", "Settings", UiStyle.BLUE.lightened(0.25), Vector2(300, 62), 22)
	var menu := _icon_button(&"home", "Main menu", UiStyle.GREY, Vector2(300, 62), 22)
	menu.pressed.connect(func() -> void:
		_set_paused(false)
		menu_requested.emit())
	for button in [resume, restart, settings, menu]:
		content.add_child(button)
	var screen := _card_screen("PAUSED", UiStyle.ORANGE, content)
	settings.pressed.connect(_open_settings.bind(screen))
	return screen


func _build_result() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_result_portrait_holder = CenterContainer.new()
	content.add_child(_result_portrait_holder)
	_result_detail = UiStyle.ink_label("", 22)
	content.add_child(_result_detail)
	_result_stats = GridContainer.new()
	_result_stats.columns = 3
	_result_stats.add_theme_constant_override("h_separation", 30)
	_result_stats.add_theme_constant_override("v_separation", 4)
	var stats_panel := PanelContainer.new()
	var stats_box := UiStyle.flat(Color(0, 0, 0, 0.06), 14)
	stats_box.set_content_margin_all(12)
	stats_panel.add_theme_stylebox_override("panel", stats_box)
	var stats_center := CenterContainer.new()
	stats_center.add_child(_result_stats)
	stats_panel.add_child(stats_center)
	content.add_child(stats_panel)
	_result_buttons = HBoxContainer.new()
	_result_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_buttons.add_theme_constant_override("separation", 12)
	content.add_child(_result_buttons)
	var screen := _card_screen("VICTORY!", UiStyle.GREEN, content)
	_result_ribbon = screen.get_meta("ribbon")
	return screen


## Normal matches: Rematch / Fighters / Menu. Tournament: Next round after a win,
## Retry or Give up after a loss, and just Menu once you are champion.
func _fill_result_buttons(ladder: Dictionary) -> void:
	for child in _result_buttons.get_children():
		_result_buttons.remove_child(child)
		child.queue_free()
	var buttons: Array[Button] = []
	if ladder.is_empty():
		var rematch := _icon_button(&"restart", "Rematch", UiStyle.GREEN, Vector2(200, 66), 24)
		rematch.pressed.connect(rematch_requested.emit)
		var change := _icon_button(&"duo", "Fighters", UiStyle.YELLOW, Vector2(190, 66), 22)
		change.pressed.connect(func() -> void: _open_select(_select_mode))
		buttons = [rematch, change]
	elif ladder["won"] and not ladder["final"]:
		var next := _icon_button(&"trophy", "Next round", UiStyle.GREEN, Vector2(260, 66), 24)
		next.pressed.connect(ladder_requested.emit)
		buttons = [next]
	elif not ladder["won"]:
		var retry := _icon_button(&"restart", "Retry round %d" % ladder["round"], UiStyle.YELLOW, Vector2(260, 66), 22)
		retry.pressed.connect(round_requested.emit)
		buttons = [retry]
	var giving_up: bool = not ladder.is_empty() and not ladder["won"]
	var menu := _icon_button(&"home", "Give up" if giving_up else "Menu", UiStyle.GREY, Vector2(170, 66), 22)
	menu.pressed.connect(give_up_requested.emit if giving_up else menu_requested.emit)
	buttons.append(menu)
	for button in buttons:
		button.theme = UiStyle.theme()
		_result_buttons.add_child(button)


## The tournament ladder: four round cards (won, next or locked) and a start button.
func _build_ladder() -> Control:
	_ladder_content = VBoxContainer.new()
	_ladder_content.add_theme_constant_override("separation", 16)
	return _card_screen("TOURNAMENT", UiStyle.ORANGE, _ladder_content)


func show_ladder(info: Dictionary) -> void:
	_in_match = false
	_top_bar.hide()
	_hint.hide()
	_pause_button.hide()
	for child in _ladder_content.get_children():
		_ladder_content.remove_child(child)
		child.queue_free()
	var pick: FighterData = info["pick"]
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 14)
	header.add_child(Portrait.make(pick, 1, 64.0))
	var you := UiStyle.ink_label("%s's road to glory" % pick.short_name, 26, true)
	header.add_child(you)
	_ladder_content.add_child(header)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var rounds: Array = info["rounds"]
	for i in rounds.size():
		row.add_child(_round_card(i, rounds[i], i == rounds.size() - 1))
	_ladder_content.add_child(row)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	var quit := _icon_button(&"home", "Quit", UiStyle.GREY, Vector2(170, 70), 24)
	quit.pressed.connect(menu_requested.emit)
	var go := _icon_button(&"sword", "Fight round %d!" % (info["round"] + 1), UiStyle.GREEN, Vector2(320, 70), 30)
	go.pressed.connect(round_requested.emit)
	buttons.add_child(quit)
	buttons.add_child(go)
	_ladder_content.add_child(buttons)
	_show_screen(_ladder_screen)


func _round_card(index: int, round_info: Dictionary, boss: bool) -> PanelContainer:
	var state: String = round_info["state"]
	var opponent: FighterData = round_info["opponent"]
	var map: MapData = round_info["map"]
	var card := PanelContainer.new()
	var color := UiStyle.GREEN if state == "won" else (UiStyle.YELLOW if state == "next" else UiStyle.GREY)
	if boss and state != "won":
		color = UiStyle.PURPLE if state == "locked" else UiStyle.RED
	card.add_theme_stylebox_override("panel", UiStyle.candy(color.lerp(PAPER, 0.35 if state == "next" else 0.55)))
	card.custom_minimum_size = Vector2(200, 270)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	stack.add_child(UiStyle.game_label("FINAL" if boss else "ROUND %d" % (index + 1), 24, true))
	var portrait_box := CenterContainer.new()
	var portrait := Portrait.make(opponent, -1, 96.0)
	if state == "locked" and not boss:
		portrait.modulate = Color(0.25, 0.22, 0.3)
	portrait_box.add_child(portrait)
	stack.add_child(portrait_box)
	stack.add_child(UiStyle.ink_label(opponent.display_name if state != "locked" or boss else "???", 18, true))
	stack.add_child(UiStyle.ink_label(map.display_name, 15))
	var level: int = round_info["difficulty"]
	var level_name: String = ["Easy", "Normal", "Hard", "Champion"][level]
	var pill := PanelContainer.new()
	var pill_box := UiStyle.flat([UiStyle.GREEN, UiStyle.YELLOW, UiStyle.RED, UiStyle.PURPLE][level], 10, 2)
	pill_box.content_margin_left = 10
	pill_box.content_margin_right = 10
	pill.add_theme_stylebox_override("panel", pill_box)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_child(UiStyle.game_label(level_name, 16, true))
	stack.add_child(pill)
	if state == "won":
		stack.add_child(UiStyle.game_label("✔ WON", 20, true))
	card.add_child(stack)
	if state == "next":
		card.pivot_offset = card.custom_minimum_size / 2
		var pulse := card.create_tween().set_loops()
		pulse.tween_property(card, "scale", Vector2(1.04, 1.04), 0.5).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	return card


func _fill_stats(names: Array[String], stats: Array) -> void:
	for child in _result_stats.get_children():
		_result_stats.remove_child(child)
		child.queue_free()
	for text: String in ["", names[0], names[1]]:
		_result_stats.add_child(UiStyle.ink_label(text, 18, true))
	var rows := [["Throws", "throws"], ["Hits", "hits"], ["Headshots", "headshots"], ["Damage", "damage"], ["Longest hit", "longest"]]
	for stat: Array in rows:
		var name_label := UiStyle.ink_label(stat[0], 18)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_result_stats.add_child(name_label)
		for side in 2:
			var value: float = stats[side][stat[1]]
			var text := "%d m" % roundi(value) if stat[1] == "longest" else str(roundi(value))
			_result_stats.add_child(UiStyle.ink_label(text, 18, true))


# --- building blocks ---

## A full-screen Control registered as a screen. dim adds a dark backdrop.
func _screen_root(dim: bool) -> Control:
	var root: Control
	if dim:
		var shade := ColorRect.new()
		shade.color = Color(0.05, 0.03, 0.12, 0.55)
		root = shade
	else:
		root = Control.new()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiStyle.theme()
	add_child(root)
	_screens.append(root)
	return root


## A dimmed screen with a paper card topped by a coloured ribbon. The dim also blocks aiming.
func _card_screen(title: String, color: Color, content: Control) -> Control:
	var screen := _screen_root(true)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.panel(PAPER, 26, 5, 24.0))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	var ribbon := UiStyle.ribbon(title, color, 40)
	stack.add_child(ribbon)
	stack.add_child(content)
	card.add_child(stack)
	center.add_child(card)
	screen.add_child(center)
	screen.set_meta("card", card)
	screen.set_meta("ribbon", ribbon)
	return screen


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


## A candy button with an icon and optional text. font_size 0 means icon only.
func _icon_button(icon: StringName, text: String, color: Color, min_size: Vector2, font_size: int) -> Button:
	var button := _button("", 20)
	button.custom_minimum_size = min_size
	UiStyle.paint_button(button, color)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_bottom = -6
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiIcon.make(icon, 30 if font_size > 0 else 34))
	if font_size > 0:
		var label := UiStyle.game_label(text, font_size, true)
		row.add_child(label)
		button.set_meta("label", label)
	button.add_child(row)
	return button


func _button(text: String, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", UiStyle.title_font())
	button.add_theme_font_size_override("font_size", font_size)
	button.pressed.connect(Audio.play.bind("click", -4.0))
	button.mouse_entered.connect(func() -> void:
		button.pivot_offset = button.size / 2
		button.create_tween().tween_property(button, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	button.mouse_exited.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.1))
	button.button_down.connect(func() -> void:
		button.pivot_offset = button.size / 2
		button.create_tween().tween_property(button, "scale", Vector2(0.95, 0.95), 0.05))
	button.button_up.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return button


func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


# --- progression: coins, shop, trophies and stats, toasts ---

## A little pop-up in the top-right corner (achievements, unlocks).
func toast(text: String, color: Color) -> void:
	var pill := PanelContainer.new()
	var box := UiStyle.flat(Color(0.08, 0.05, 0.12, 0.9), 14, 3)
	box.border_color = color
	box.set_content_margin_all(12)
	pill.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiIcon.make(&"trophy", 30))
	var label := UiStyle.game_label(text, 20, true)
	label.add_theme_color_override("font_color", color)
	row.add_child(label)
	pill.add_child(row)
	_ignore_mouse(pill)
	_toasts.add_child(pill)
	pill.modulate.a = 0.0
	var tween := pill.create_tween()
	tween.tween_property(pill, "modulate:a", 1.0, 0.2)
	tween.tween_interval(2.8)
	tween.tween_property(pill, "modulate:a", 0.0, 0.4)
	tween.tween_callback(pill.queue_free)
	Audio.play("win", -6.0, 1.4, 0.0)


func _coin_pill() -> PanelContainer:
	var pill := PanelContainer.new()
	var box := UiStyle.flat(Color(0.08, 0.05, 0.12, 0.75), 20, 3)
	box.content_margin_left = 12
	box.content_margin_right = 16
	pill.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiIcon.make(&"coin", 32))
	var label := UiStyle.game_label(str(Save.coins), 26, true)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	row.add_child(label)
	pill.add_child(row)
	pill.set_meta("label", label)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pill


func _set_coins(pill: PanelContainer) -> void:
	(pill.get_meta("label") as Label).text = str(Save.coins)


## Coins, the tournament button's "continue" text and whether the daily is done.
func _refresh_title() -> void:
	_set_coins(_coins_pill)
	var subtitle: Label = _tournament_button.get_meta("subtitle")
	if Save.tournament.is_empty():
		subtitle.text = "4 rounds, each one harder"
	else:
		subtitle.text = "Continue: round %d of %d" % [int(Save.tournament["round"]) + 1, (Save.tournament["rounds"] as Array).size()]
	var done := Save.daily_done == Rewards.today()
	(_daily_button.get_meta("label") as Label).text = "Daily ✓" if done else "Daily"
	_daily_button.tooltip_text = Rewards.daily(Rewards.today(), _roster, _maps)["text"]


## A dimmed card screen whose content is rebuilt each time it opens.
func _build_list_screen(title: String, color: Color) -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var screen := _card_screen(title, color, content)
	screen.set_meta("content", content)
	return screen


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _back_button(target: Callable) -> Button:
	var back := _icon_button(&"back", "Back", UiStyle.GREY, Vector2(180, 62), 24)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(target)
	return back


func _open_shop() -> void:
	_fill_shop()
	_show_screen(_shop_screen)


func _fill_shop() -> void:
	_clear(_shop_content)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 16)
	header.add_child(_coin_pill())
	header.add_child(UiStyle.ink_label("Win matches to earn coins. Unlock fighters and pick your colours.", 18))
	_shop_content.add_child(header)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for fighter in _roster:
		grid.add_child(_shop_fighter_tile(fighter))
	_shop_content.add_child(grid)
	_shop_content.add_child(_cosmetic_row("Ink", "ink", Save.INKS, Save.ink))
	_shop_content.add_child(_cosmetic_row("Trail", "trail", Save.TRAILS, Save.trail))
	_shop_content.add_child(_back_button(show_title))


func _shop_fighter_tile(fighter: FighterData) -> PanelContainer:
	var tile := PanelContainer.new()
	var owned := Save.is_unlocked(fighter)
	var box := UiStyle.flat(fighter.body_color.lerp(PAPER, 0.65 if owned else 0.85), 14, 3)
	box.set_content_margin_all(8)
	tile.add_theme_stylebox_override("panel", box)
	tile.custom_minimum_size = Vector2(250, 96)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var portrait := Portrait.make(fighter, 1, 72.0)
	if not owned:
		portrait.modulate = Color(0.45, 0.42, 0.5)
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := UiStyle.ink_label(fighter.short_name, 20, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(name_label)
	if owned:
		var tag := UiStyle.ink_label("✔ Owned", 16)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		tag.add_theme_color_override("font_color", UiStyle.GREEN.darkened(0.3))
		column.add_child(tag)
	else:
		var buy := _icon_button(&"coin", str(fighter.price), UiStyle.YELLOW, Vector2(130, 46), 20)
		buy.theme = UiStyle.theme()
		buy.pressed.connect(_buy_fighter.bind(fighter))
		column.add_child(buy)
	row.add_child(column)
	tile.add_child(row)
	return tile


func _buy_fighter(fighter: FighterData) -> void:
	if Save.buy_fighter(fighter):
		toast("Unlocked %s!" % fighter.short_name, Color(0.6, 1.0, 0.6))
	else:
		toast("Not enough coins", Color(1.0, 0.6, 0.5))
	_fill_shop()


## A row of colour swatches: equip owned ones, buy the rest.
func _cosmetic_row(title: String, kind: String, table: Dictionary, equipped: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var label := UiStyle.ink_label(title, 22, true)
	label.custom_minimum_size.x = 70
	row.add_child(label)
	var owned: Array = Save.owned_inks if kind == "ink" else Save.owned_trails
	for id: String in table:
		var entry: Array = table[id]
		var color: Color = entry[1]
		var is_owned := owned.has(id)
		var text := String(entry[0]) if is_owned else "%s  %d" % [entry[0], entry[2]]
		var button := _button(text, 16)
		button.custom_minimum_size = Vector2(176, 50)
		button.toggle_mode = true
		button.button_pressed = id == equipped
		UiStyle.paint_button(button, color.lerp(PAPER, 0.35) if kind == "trail" else color.lerp(PAPER, 0.55))
		button.pressed.connect(_choose_cosmetic.bind(kind, id))
		row.add_child(button)
	return row


func _choose_cosmetic(kind: String, id: String) -> void:
	if not Save.choose_cosmetic(kind, id):
		toast("Not enough coins", Color(1.0, 0.6, 0.5))
	_fill_shop()


func _open_stats(achievements_tab: bool) -> void:
	_fill_stats_screen(achievements_tab)
	_show_screen(_stats_screen)


func _fill_stats_screen(achievements_tab: bool) -> void:
	_clear(_stats_content)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	for i in 2:
		var tab_text := "Achievements %d/%d" % [Save.achievements.size(), Rewards.ACHIEVEMENTS.size()] if i == 0 else "Fighter stats"
		var tab := _button(tab_text, 20)
		tab.custom_minimum_size = Vector2(260, 52)
		tab.toggle_mode = true
		tab.button_pressed = (i == 0) == achievements_tab
		tab.pressed.connect(_fill_stats_screen.bind(i == 0))
		tabs.add_child(tab)
	_stats_content.add_child(tabs)
	if achievements_tab:
		_stats_content.add_child(_achievement_grid())
	else:
		_stats_content.add_child(_fighter_stats_table())
	_stats_content.add_child(_back_button(show_title))


func _achievement_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for entry: Dictionary in Rewards.ACHIEVEMENTS:
		var got := Save.achievements.has(entry["id"])
		var tile := PanelContainer.new()
		var box := UiStyle.flat(Color(1.0, 0.85, 0.4) if got else Color(0, 0, 0, 0.08), 12, 3 if got else 0)
		box.set_content_margin_all(8)
		tile.add_theme_stylebox_override("panel", box)
		tile.custom_minimum_size = Vector2(330, 70)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := UiIcon.make(&"trophy", 38)
		if not got:
			icon.modulate = Color(0.4, 0.4, 0.45, 0.6)
		row.add_child(icon)
		var column := VBoxContainer.new()
		var title_label := UiStyle.ink_label(entry["name"], 18, true)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var desc := UiStyle.ink_label(entry["desc"], 14)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.add_theme_color_override("font_color", INK.lightened(0.25))
		column.add_child(title_label)
		column.add_child(desc)
		row.add_child(column)
		tile.add_child(row)
		grid.add_child(tile)
	return grid


func _fighter_stats_table() -> CenterContainer:
	var table := GridContainer.new()
	table.columns = 6
	table.add_theme_constant_override("h_separation", 34)
	table.add_theme_constant_override("v_separation", 6)
	for heading: String in ["Fighter", "Matches", "Wins", "Headshots", "Best hit", "Damage"]:
		table.add_child(UiStyle.ink_label(heading, 18, true))
	for fighter in _roster:
		var stats := Save.stats_for(String(fighter.id))
		var name_label := UiStyle.ink_label(fighter.display_name, 17, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not Save.is_unlocked(fighter):
			name_label.add_theme_color_override("font_color", INK.lightened(0.5))
		table.add_child(name_label)
		for value in [stats["matches"], stats["wins"], stats["headshots"], "%d m" % roundi(float(stats["longest"])), stats["damage"]]:
			table.add_child(UiStyle.ink_label(str(value), 17))
	var centre := CenterContainer.new()
	centre.add_child(table)
	return centre


# --- phones: safe area, auto-pause, portrait tip ---

## Keeps the HUD clear of notches and rounded corners.
func _apply_safe_area() -> void:
	var inset := Device.safe_insets(get_viewport())
	_top_bar.add_theme_constant_override("margin_left", 16 + int(inset[0]))
	_top_bar.add_theme_constant_override("margin_top", 16 + int(inset[1]))
	_top_bar.add_theme_constant_override("margin_right", 16 + int(inset[2]))
	_pause_button.offset_left = -88 - inset[2]
	_pause_button.offset_right = -16 - inset[2]
	_pause_button.offset_top = -84 - inset[3]
	_pause_button.offset_bottom = -16 - inset[3]
	_special_button.offset_left = 16 + inset[0]
	_special_button.offset_right = 246 + inset[0]
	_special_button.offset_top = -132 - inset[3]
	_special_button.offset_bottom = -64 - inset[3]
	_hint.offset_bottom = -12 - inset[3]
	_hint.offset_top = -44 - inset[3]


## Switching apps, a call, or locking the phone pauses the match.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _in_match and _pause_screen != null and not _pause_screen.visible and not _result_screen.visible and not _intro.visible:
			_set_paused(true)


## Held upright the game still works, but sideways shows much more of the arena.
func _build_portrait_tip() -> void:
	_portrait_tip = _button("↻  Turn your phone sideways for the best view   ✕", 22)
	_portrait_tip.theme = UiStyle.theme()
	UiStyle.paint_button(_portrait_tip, UiStyle.BLUE.lightened(0.2))
	_portrait_tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_portrait_tip.offset_left = -330
	_portrait_tip.offset_right = 330
	_portrait_tip.offset_top = -170
	_portrait_tip.offset_bottom = -100
	_portrait_tip.pressed.connect(func() -> void: _portrait_dismissed = true)
	_portrait_tip.hide()
	add_child(_portrait_tip)
