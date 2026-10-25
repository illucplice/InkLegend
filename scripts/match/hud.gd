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
## A finished ladder: start a fresh one of the same kind with the same fighter.
signal ladder_again_requested
## Title screen: play today's daily challenge, or continue a saved tournament.
signal daily_requested
signal resume_requested
## Tournament lost and the player gave up: forget the saved run.
signal give_up_requested
## The player armed (or disarmed) their once-per-match special.
signal special_toggled(armed: bool)
## 2v2 against a friend: [player 1's two fighters, player 2's two], and the map.
signal team_play_requested(picks: Array, map: MapData)
signal menu_requested
signal pause_changed(paused: bool)
## Target Practice: play your fighter's fatality on a dummy.
signal fatality_test_requested
## The Fatality Gallery: replay this fighter's fatality.
signal gallery_requested(data: FighterData)

const INK := UiStyle.INK
const PAPER := UiStyle.PAPER
const GHOST := Color(1.0, 0.95, 0.75)
const VERSION := "v0.2"
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
## The fighter each plate shows (so a tag can let go of the one before), and the
## partner waiting on each side in 2v2.
var _bound: Array = [null, null]
var _partner_labels: Array[Label] = []
var _ghosts: Array[ProgressBar] = []
var _hp_labels: Array[Label] = []
var _turn_ribbon: PanelContainer
var _turn_label: Label
var _turn_text := ""
var _wind_gauge: WindGauge
var _special_button: Button
var _special_meter: ProgressBar
var _special_ready := false
var _special_data: FighterData
var _announcer: VBoxContainer
var _hint: Label
var _tip: PanelContainer
var _time_stop: ColorRect
var _pause_button: Button
var _fatality_button: Button
var _practice_on := false
var _intro: VsIntro

# Screens
var _screens: Array[Control] = []
var _title_screen: Control
var _select_screen: Control
var _settings_screen: Control
var _howto_screen: Control
var _patch_screen: Control
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
var _profile: PanelContainer
var _profile_portrait: CenterContainer
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _play_button: Button
var _chest_opening: ChestOpening
var _fighters_screen: Control
var _fighters_content: VBoxContainer
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
var _picks: Array[FighterData] = [null, null, null, null]
var _difficulty: int = AiAimer.Difficulty.NORMAL
var _select_ribbon: PanelContainer
var _card_buttons: Array[Button] = []
var _card_scroll: ScrollContainer
var _difficulty_box: Control
var _go_label: Label
## Vs AI: the second pick (your opponent) can be left to chance instead.
var _random_foe := false
## Chaos (from the map screen): the next match gets a random rule-twisting mutator.
var chaos_on := false
var _random_button: Button
var _skin_button: Button
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
	_picks = [roster[0], roster[1], roster[2], roster[3]]
	_build_match_hud()
	_title_screen = _build_title()
	_select_screen = _build_select()
	_map_screen = _build_map_screen()
	_ladder_screen = _build_ladder()
	_shop_screen = _build_list_screen("SHOP", UiStyle.YELLOW)
	_shop_content = _shop_screen.get_meta("content")
	_stats_screen = _build_list_screen("TROPHIES & STATS", UiStyle.ORANGE)
	_stats_content = _stats_screen.get_meta("content")
	_fighters_screen = _build_list_screen("FIGHTERS", UiStyle.PURPLE)
	_fighters_content = _fighters_screen.get_meta("content")
	_settings_screen = _build_settings()
	_howto_screen = _build_howto()
	_patch_screen = _build_patch_notes()
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
	_chest_opening = ChestOpening.new()
	add_child(_chest_opening)
	_chest_opening.closed.connect(func() -> void:
		_refresh_title()
		if _fighters_screen.visible:
			_fill_fighters())
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
	_set_showcase(_selected_index())
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
		var was: Fighter = _bound[i] if is_instance_valid(_bound[i]) else null
		if was != null and was.health_changed.is_connected(_on_health_changed.bind(i)):
			was.health_changed.disconnect(_on_health_changed.bind(i))
		if not fighter.health_changed.is_connected(_on_health_changed.bind(i)):
			fighter.health_changed.connect(_on_health_changed.bind(i))
		_bound[i] = fighter
	set_partners(["", ""])


## Target Practice has no opponent, so hide the right-hand plate.
func set_practice(on: bool) -> void:
	_plates[1].visible = not on
	_practice_on = on
	_sync_fatality_button()
	if _fatality_button != null:
		_fatality_button.disabled = false


## The Test Fatality button shows in Target Practice, whenever the pause button does.
func _sync_fatality_button() -> void:
	if _fatality_button != null:
		_fatality_button.visible = _practice_on and _pause_button.visible
		# Keep the controls hint clear of the button.
		_hint.offset_right = -370.0 if _practice_on else -100.0
		_hint.offset_top = -66.0 if _practice_on else -44.0


func set_fatality_test_enabled(on: bool) -> void:
	_fatality_button.disabled = not on


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
	_special_data = data
	_show_armed(armed)


## While armed the button says so plainly; tapping it again cancels.
func _show_armed(on: bool) -> void:
	if _special_data == null:
		return
	var label: Label = _special_button.get_meta("label")
	if on:
		label.text = "ARMED! Throw now"
		UiStyle.paint_button(_special_button, Color(1.0, 0.82, 0.25))
	elif _special_ready:
		label.text = _special_data.special_name
		UiStyle.paint_button(_special_button, _special_data.body_color)


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
	_random_foe = false
	var owned := _owned_fighters()
	if not owned.is_empty():
		_picks[0] = owned[_selected_index()]
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
	elif _shop_screen.visible or _stats_screen.visible or _fighters_screen.visible:
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
		_showcase_root.position = Vector2(_showcase_area.size.x * 0.5, _showcase_area.size.y * 0.6)
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

	# Time stop: everything behind the HUD drains to grey-violet.
	_time_stop = ColorRect.new()
	_time_stop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_time_stop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grey := ShaderMaterial.new()
	grey.shader = Shader.new()
	grey.shader.code = "shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float amount = 1.0;
uniform float purple = 1.0;
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 violet = vec3(g * 0.8 + 0.08, g * 0.7 + 0.04, g * 0.95 + 0.14);
	vec3 tint = mix(vec3(g), violet, purple);
	COLOR = vec4(mix(c, tint, amount), 1.0);
}
"
	_time_stop.material = grey
	_time_stop.hide()
	add_child(_time_stop)
	move_child(_time_stop, 0)

	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.08, 0.07, 0.12, 0.88), 18))
	_tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_tip.offset_left = -330
	_tip.offset_right = 330
	_tip.offset_top = -210
	_tip.offset_bottom = -90
	var tip_label := UiStyle.game_label("", 24)
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.custom_minimum_size = Vector2(600, 0)
	_tip.add_child(tip_label)
	_tip.set_meta("label", tip_label)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.hide()
	add_child(_tip)

	_pause_button = _icon_button(&"pause", "", UiStyle.YELLOW, Vector2(72, 68), 0)
	_pause_button.theme = UiStyle.theme()
	_pause_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_pause_button.offset_left = -88
	_pause_button.offset_top = -84
	_pause_button.offset_right = -16
	_pause_button.offset_bottom = -16
	_pause_button.pressed.connect(_set_paused.bind(true))
	add_child(_pause_button)

	# Target Practice only: try your fatality on a dummy whenever you like.
	_fatality_button = _icon_button(&"sword", "Test Fatality", UiStyle.RED, Vector2(250, 68), 22)
	_fatality_button.theme = UiStyle.theme()
	_fatality_button.focus_mode = Control.FOCUS_NONE
	_fatality_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_fatality_button.offset_left = -354
	_fatality_button.offset_top = -84
	_fatality_button.offset_right = -104
	_fatality_button.offset_bottom = -16
	_fatality_button.pressed.connect(func() -> void: fatality_test_requested.emit())
	_fatality_button.hide()
	add_child(_fatality_button)
	_pause_button.visibility_changed.connect(_sync_fatality_button)

	_special_button = _icon_button(&"star", "Special", UiStyle.PURPLE, Vector2(230, 68), 22)
	_special_button.theme = UiStyle.theme()
	_special_button.toggle_mode = true
	_special_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_special_button.offset_left = 16
	_special_button.offset_top = -132
	_special_button.offset_right = 246
	_special_button.offset_bottom = -64
	# No keyboard focus, so Space always throws instead of un-arming the special.
	_special_button.focus_mode = Control.FOCUS_NONE
	_special_button.toggled.connect(func(on: bool) -> void:
		_show_armed(on)
		special_toggled.emit(on))
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

## The home dashboard: profile and level, coins and settings along the top; game modes
## on the left; your fighter on a pedestal in the middle; a big PLAY button and the
## chest shop on the right; a tab bar along the bottom.
func _build_title() -> Control:
	var screen := _screen_root(false)

	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.05, 0.03, 0.12, 0.7))
	gradient.set_color(1, Color(0.05, 0.03, 0.12, 0.8))
	gradient.add_point(0.5, Color(0.05, 0.03, 0.12, 0.15))
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

	# --- top bar ---
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16
	top.offset_right = -16
	top.offset_top = 12
	top.offset_bottom = 86
	top.add_theme_constant_override("separation", 12)
	screen.add_child(top)
	_profile = PanelContainer.new()
	var profile_box := UiStyle.flat(Color(0.08, 0.05, 0.12, 0.78), 18, 3)
	profile_box.set_content_margin_all(6)
	profile_box.content_margin_right = 14
	_profile.add_theme_stylebox_override("panel", profile_box)
	var profile_row := HBoxContainer.new()
	profile_row.add_theme_constant_override("separation", 10)
	_profile_portrait = CenterContainer.new()
	_profile_portrait.custom_minimum_size = Vector2(60, 60)
	profile_row.add_child(_profile_portrait)
	var profile_text := VBoxContainer.new()
	profile_text.alignment = BoxContainer.ALIGNMENT_CENTER
	profile_text.add_theme_constant_override("separation", 2)
	_level_label = UiStyle.game_label("Level 1", 22, true)
	profile_text.add_child(_level_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(190, 16)
	_xp_bar.show_percentage = false
	_xp_bar.add_theme_stylebox_override("background", UiStyle.flat(Color(0, 0, 0, 0.45), 8, 2))
	_xp_bar.add_theme_stylebox_override("fill", UiStyle.flat(Color(0.45, 0.85, 1.0), 8))
	profile_text.add_child(_xp_bar)
	_xp_label = UiStyle.game_label("0 / 100 XP", 14)
	profile_text.add_child(_xp_label)
	profile_row.add_child(profile_text)
	_profile.add_child(profile_row)
	top.add_child(_profile)
	var middle := CenterContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var logo := WavyTitle.new()
	logo.lines = ["INK LEGENDS"]
	logo.font_size = 50
	middle.add_child(logo)
	top.add_child(middle)
	_coins_pill = _coin_pill()
	_coins_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_coins_pill)
	var settings := _icon_button(&"gear", "", UiStyle.BLUE.lightened(0.25), Vector2(62, 58), 0)
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings.pressed.connect(_open_settings.bind(screen))
	top.add_child(settings)
	if not OS.has_feature("web"):
		var quit := _icon_button(&"quit", "", UiStyle.GREY, Vector2(58, 58), 0)
		quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		quit.pressed.connect(func() -> void: get_tree().quit())
		top.add_child(quit)

	# --- left: game modes ---
	_menu = VBoxContainer.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_menu.offset_left = 16
	_menu.offset_right = 296
	_menu.offset_top = 104
	_menu.offset_bottom = -96
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 12)
	screen.add_child(_menu)
	_tournament_button = _mode_button(&"trophy", "Tournament", "13 rounds, Common to Mythic", UiStyle.YELLOW)
	_tournament_button.pressed.connect(func() -> void:
		if Save.tournament.is_empty():
			_open_select(MatchController.Mode.TOURNAMENT)
		else:
			resume_requested.emit())
	_menu.add_child(_tournament_button)
	var arcade := _mode_button(&"sword", "Arcade", "5 fights, then your rival", UiStyle.RED)
	arcade.pressed.connect(_open_select.bind(MatchController.Mode.ARCADE))
	_menu.add_child(arcade)
	var bosses := _mode_button(&"sword", "Boss Rush", "4 bosses, already powered up", UiStyle.PURPLE)
	bosses.pressed.connect(_open_select.bind(MatchController.Mode.BOSS_RUSH))
	_menu.add_child(bosses)
	var duo := _mode_button(&"duo", "1v1 friend", "Take turns, one device", UiStyle.ORANGE)
	duo.pressed.connect(_open_select.bind(MatchController.Mode.LOCAL_2P))
	_menu.add_child(duo)
	var practice := _mode_button(&"target", "Practice", "10 targets, earn stars", UiStyle.BLUE)
	practice.pressed.connect(_open_select.bind(MatchController.Mode.PRACTICE))
	_menu.add_child(practice)
	_daily_button = _mode_button(&"star", "Daily", "New every day", UiStyle.PURPLE)
	_daily_button.pressed.connect(daily_requested.emit)
	_menu.add_child(_daily_button)

	# --- middle: your fighter on a pedestal ---
	var stage := Control.new()
	stage.anchor_left = 0.25
	stage.anchor_right = 0.66
	stage.anchor_top = 0.0
	stage.anchor_bottom = 1.0
	stage.offset_top = 90
	stage.offset_bottom = -90
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(stage)
	_showcase_area = stage
	_showcase_root = Node2D.new()
	_showcase_root.draw.connect(_draw_pedestal)
	stage.add_child(_showcase_root)
	var plate := VBoxContainer.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	plate.offset_left = -270
	plate.offset_right = 270
	plate.offset_top = -120
	plate.offset_bottom = 0
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.alignment = BoxContainer.ALIGNMENT_END
	plate.add_theme_constant_override("separation", 2)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 12)
	var prev := _icon_button(&"back", "", UiStyle.YELLOW, Vector2(54, 54), 0)
	prev.pressed.connect(func() -> void: _set_showcase(_showcase_index - 1))
	_showcase_name = UiStyle.game_label("", 34, true)
	_showcase_name.custom_minimum_size.x = 300
	_showcase_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := _icon_button(&"play", "", UiStyle.YELLOW, Vector2(54, 54), 0)
	next.pressed.connect(func() -> void: _set_showcase(_showcase_index + 1))
	name_row.add_child(prev)
	name_row.add_child(_showcase_name)
	name_row.add_child(next)
	plate.add_child(name_row)
	_showcase_weapon = UiStyle.game_label("", 18)
	_showcase_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.add_child(_showcase_weapon)
	_showcase_special = UiStyle.game_label("", 16)
	_showcase_special.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Wrap to the pedestal's width so a long description can't stretch the plate sideways.
	_showcase_special.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_showcase_special.custom_minimum_size.x = 520
	_showcase_special.max_lines_visible = 2
	_showcase_special.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	plate.add_child(_showcase_special)
	stage.add_child(plate)

	# --- right: PLAY and chests ---
	var right := VBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -416
	right.offset_right = -16
	right.offset_top = 104
	right.offset_bottom = -96
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 14)
	screen.add_child(right)
	var play := _button("", 18)
	play.custom_minimum_size = Vector2(400, 118)
	UiStyle.paint_button(play, UiStyle.GREEN)
	play.pressed.connect(_open_select.bind(MatchController.Mode.VS_AI))
	var play_stack := VBoxContainer.new()
	play_stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_stack.offset_bottom = -8
	play_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	play_stack.add_theme_constant_override("separation", -6)
	play_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var play_label := UiStyle.game_label("PLAY", 64, true)
	play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_stack.add_child(play_label)
	var play_sub := UiStyle.ink_label("Battle the AI", 18)
	play_sub.add_theme_color_override("font_color", INK.lightened(0.15))
	play_stack.add_child(play_sub)
	play.add_child(play_stack)
	right.add_child(play)
	_play_button = play
	var tag := _mode_button(&"duo", "2v2 Tag", "Vs AI or a friend, two fighters each", UiStyle.ORANGE)
	tag.custom_minimum_size.x = 400
	tag.pressed.connect(_open_tag_choice)
	right.add_child(tag)
	var survival := _mode_button(&"trophy", "Survival", "Endless fights, one health bar", UiStyle.RED)
	survival.custom_minimum_size.x = 400
	survival.pressed.connect(_open_select.bind(MatchController.Mode.SURVIVAL))
	right.add_child(survival)
	_survival_button = survival

	var chests := PanelContainer.new()
	var chest_box := UiStyle.flat(Color(0.08, 0.05, 0.12, 0.78), 18, 3)
	chest_box.set_content_margin_all(10)
	chests.add_theme_stylebox_override("panel", chest_box)
	var chest_stack := VBoxContainer.new()
	chest_stack.add_theme_constant_override("separation", 6)
	var chest_title := UiStyle.game_label("CHESTS  ·  win new fighters", 20, true)
	chest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chest_stack.add_child(chest_title)
	chest_stack.add_child(_chest_row())
	chests.add_child(chest_stack)
	right.add_child(chests)

	# --- bottom: tab bar ---
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -80
	var bar_box := UiStyle.flat(Color(0.08, 0.05, 0.12, 0.88), 0, 0)
	bar_box.border_color = Color(1, 1, 1, 0.12)
	bar_box.border_width_top = 3
	bar.add_theme_stylebox_override("panel", bar_box)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	var tab_list := [[&"home", "Home", Callable()], [&"duo", "Fighters", _open_fighters], [&"coin", "Shop", _open_shop], [&"trophy", "Trophies", _open_stats.bind(true)], [&"sword", "Fatalities", open_gallery], [&"help", "Help", func() -> void: _show_screen(_howto_screen)]]
	for i in tab_list.size():
		var tab: Array = tab_list[i]
		var button := _icon_button(tab[0], tab[1], UiStyle.YELLOW if i == 0 else Color(0.3, 0.27, 0.4), Vector2(200, 62), 20)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if (tab[2] as Callable).is_valid():
			button.pressed.connect(tab[2])
		tabs.add_child(button)
	bar.add_child(tabs)
	screen.add_child(bar)

	# The version doubles as a button to the patch notes.
	var version := _icon_button(&"star", "%s  What's new" % VERSION, UiStyle.PURPLE, Vector2(200, 40), 15)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -214
	version.offset_top = -132
	version.offset_right = -14
	version.offset_bottom = -92
	version.pressed.connect(func() -> void: _show_screen(_patch_screen))
	screen.add_child(version)
	return screen


## A compact mode button: icon, title and a one-line subtitle (kept as meta "subtitle").
func _mode_button(icon: StringName, title: String, subtitle: String, color: Color) -> Button:
	var button := _button("", 18)
	button.custom_minimum_size = Vector2(280, 76)
	UiStyle.paint_button(button, color)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiIcon.make(icon, 38))
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", -4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := UiStyle.game_label(title, 25, true)
	var small := UiStyle.ink_label(subtitle, 14)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	small.add_theme_color_override("font_color", INK.lightened(0.15))
	text.add_child(big)
	text.add_child(small)
	row.add_child(text)
	button.add_child(row)
	button.set_meta("label", big)
	button.set_meta("subtitle", small)
	return button


## Three chest buttons (wood, silver, gold) with their prices.
func _chest_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for kind: String in Chests.ORDER:
		var info: Dictionary = Chests.KINDS[kind]
		var button := _button("", 16)
		button.custom_minimum_size = Vector2(122, 150)
		UiStyle.paint_button(button, (info["color"] as Color).lerp(UiStyle.PAPER, 0.55))
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_top = 4
		stack.offset_bottom = -10
		stack.add_theme_constant_override("separation", 0)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art := ChestArt.new()
		art.color = info["color"]
		art.kind = kind
		art.custom_minimum_size = Vector2(0, 82)
		stack.add_child(art)
		var name_label := UiStyle.ink_label(String(info["name"]).split(" ")[0], 16, true)
		stack.add_child(name_label)
		var price := HBoxContainer.new()
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price.add_child(UiIcon.make(&"coin", 20))
		price.add_child(UiStyle.ink_label(str(info["price"]), 17, true))
		stack.add_child(price)
		button.add_child(stack)
		var odds_text := PackedStringArray()
		for r in Chests.RARITIES.size():
			if int(info["odds"][r]) > 0:
				odds_text.append("%d%% %s" % [info["odds"][r], Chests.RARITY_NAMES[Chests.RARITIES[r]]])
		button.tooltip_text = "%s: %s" % [info["name"], ", ".join(odds_text)]
		button.pressed.connect(_buy_chest.bind(kind))
		row.add_child(button)
	return row


func _buy_chest(kind: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var result := Chests.open(kind, _roster, Save, rng)
	if result.is_empty():
		toast("Not enough coins", Color(1.0, 0.6, 0.5))
		return
	_chest_opening.play(kind, result)
	_refresh_title()
	if _shop_screen.visible:
		_fill_shop()


## The fighters you own, in roster order (the showcase cycles through these).
func _owned_fighters() -> Array[FighterData]:
	var owned: Array[FighterData] = []
	for fighter in _roster:
		if Save.is_unlocked(fighter):
			owned.append(fighter)
	return owned


## Shows owned fighter `index` on the pedestal and makes it your selected fighter.
func _set_showcase(index: int) -> void:
	var owned := _owned_fighters()
	_showcase_index = posmod(index, owned.size())
	_showcase_time = 0.0
	if _showcase != null:
		_showcase.queue_free()
	var data := owned[_showcase_index]
	if Save.selected_fighter != String(data.id):
		Save.selected_fighter = String(data.id)
		Save.save_progress()
		if _profile_portrait != null:
			_refresh_profile_portrait()
	_showcase = preload("res://scenes/fighter/fighter.tscn").instantiate()
	_showcase_root.add_child(_showcase)
	_showcase.setup(data, 1, false, false)
	_showcase.ink_color = Save.ink_color()
	_showcase.scale = Vector2.ONE * SHOWCASE_SCALE
	_showcase.position.y = -40
	_showcase.reset_physics_interpolation()
	_showcase.modulate.a = 0.0
	var tween := _showcase.create_tween().set_parallel()
	tween.tween_property(_showcase, "modulate:a", 1.0, 0.25)
	tween.tween_property(_showcase, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var rarity_name: String = Chests.RARITY_NAMES.get(data.rarity, "Common")
	_showcase_name.text = data.display_name
	_showcase_weapon.text = "%s  ·  %s  ·  %d / %d" % [rarity_name, data.weapon.display_name, data.weapon.body_damage, data.weapon.head_damage]
	_showcase_special.text = "★ %s — %s" % [data.special_name, data.special_description]
	_showcase_root.queue_redraw()


## Index of the selected fighter among the ones you own.
func _selected_index() -> int:
	var owned := _owned_fighters()
	for i in owned.size():
		if String(owned[i].id) == Save.selected_fighter:
			return i
	return 0


## Idles, then lines up and fakes a throw, on a loop.
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
		_showcase_time = 0.0
	_showcase_root.queue_redraw()


## The showcase stage behind your fighter, Brawlhalla-style: a tall banner in their
## rarity colour, a spotlight, a floating stone island with a glowing rim and runes,
## banner poles either side and sparks drifting up. The fighter stands at (0, 0).
func _draw_pedestal() -> void:
	var root := _showcase_root
	var glow := Color(1.0, 0.75, 0.4)
	if _showcase != null and _showcase.data != null:
		glow = Chests.RARITY_COLORS.get(_showcase.data.rarity, glow)
	var t := _time
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	var cloth := Color(glow.darkened(0.68), 0.9)
	var gold := Color(1.0, 0.82, 0.35)
	# The big banner hanging behind them, swaying a little.
	var banner := PackedVector2Array()
	for k in 9:
		var y := lerpf(-330.0, -120.0, k / 8.0)
		banner.append(Vector2(-105.0 + sin(t * 1.4 + k * 0.6) * 4.0 * (k / 8.0), y))
	banner.append(Vector2(0, -80.0 + sin(t * 1.4) * 4.0))
	for k in range(8, -1, -1):
		var y := lerpf(-330.0, -120.0, k / 8.0)
		banner.append(Vector2(105.0 + sin(t * 1.4 + k * 0.6 + 1.0) * 4.0 * (k / 8.0), y))
	root.draw_colored_polygon(banner, cloth)
	var trim := banner.duplicate()
	trim.append(banner[0])
	root.draw_polyline(trim, gold, 6.0, true)
	root.draw_rect(Rect2(-118, -342, 236, 16), Color(0.3, 0.22, 0.18))
	root.draw_rect(Rect2(-118, -342, 236, 16), INK, false, 3.0)
	var emblem := Vector2(0, -230)
	root.draw_circle(emblem, 46.0, Color(glow, 0.22 + 0.12 * pulse), true, -1.0, true)
	root.draw_arc(emblem, 40.0, 0.0, TAU, 48, gold, 5.0, true)
	var star := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + k * PI / 5.0
		star.append(emblem + Vector2.from_angle(a) * (28.0 if k % 2 == 0 else 12.0))
	root.draw_colored_polygon(star, gold)
	# Spotlight from above.
	root.draw_colored_polygon(PackedVector2Array([Vector2(-50, -700), Vector2(50, -700), Vector2(230, 0), Vector2(-230, 0)]), Color(1, 1, 1, 0.05 + 0.03 * pulse))
	# Banner poles on the island's edges.
	for side: float in [-1.0, 1.0]:
		var base := Vector2(side * 210.0, -6.0)
		root.draw_line(base, base + Vector2(0, -250), INK, 9.0, true)
		root.draw_line(base, base + Vector2(0, -250), Color(0.55, 0.4, 0.25), 5.0, true)
		root.draw_circle(base + Vector2(0, -254), 8.0, gold, true, -1.0, true)
		var flag := PackedVector2Array([base + Vector2(0, -242)])
		for k in 7:
			var u := k / 6.0
			flag.append(base + Vector2(-side * u * 64.0, -242.0 + sin(t * 4.0 + u * 4.0) * 6.0 * u))
		flag.append(base + Vector2(-side * 64.0, -200.0 + sin(t * 4.0 + 4.0) * 6.0))
		flag.append(base + Vector2(0, -192))
		root.draw_colored_polygon(flag, glow.darkened(0.15))
	# Underside of the floating island: jagged rock with glowing runes.
	var bob := sin(t * 1.6) * 4.0
	var under := PackedVector2Array([Vector2(-240, 6)])
	for k in 9:
		var u := k / 8.0
		var depth := sin(u * PI) * 80.0 + (14.0 if k % 2 == 0 else 0.0)
		under.append(Vector2(lerpf(-230.0, 230.0, u), 10.0 + depth))
	under.append(Vector2(240, 6))
	root.draw_colored_polygon(under, Color(0.32, 0.28, 0.36))
	var under_line := under.duplicate()
	under_line.append(under[0])
	root.draw_polyline(under_line, INK, 4.0, true)
	for k in 5:
		var at := Vector2(-120.0 + k * 60.0, 34.0 + (k % 2) * 16.0)
		root.draw_circle(at, 9.0, Color(glow, 0.25 * pulse), true, -1.0, true)
		root.draw_line(at + Vector2(-5, -5), at + Vector2(5, 5), Color(glow, 0.6 + 0.4 * pulse), 2.5, true)
		root.draw_line(at + Vector2(5, -5), at + Vector2(-5, 5), Color(glow, 0.6 + 0.4 * pulse), 2.5, true)
	for k in 3:
		var rock := Vector2(-170.0 + k * 170.0, 112.0 + sin(t * 1.8 + k * 2.0) * 10.0 + bob)
		root.draw_colored_polygon(PackedVector2Array([rock + Vector2(-18, 0), rock + Vector2(-6, -12), rock + Vector2(16, -6), rock + Vector2(8, 14)]), Color(0.32, 0.28, 0.36))
	# The island's top: stone with a glowing rim.
	root.draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.2))
	for i in 3:
		root.draw_circle(Vector2.ZERO, 250.0 + i * 24.0, Color(glow, 0.06 + 0.04 * pulse), true, -1.0, true)
	root.draw_circle(Vector2.ZERO, 244.0, INK, true, -1.0, true)
	root.draw_circle(Vector2.ZERO, 238.0, Color(0.6, 0.56, 0.62), true, -1.0, true)
	root.draw_circle(Vector2(0, -16), 226.0, Color(0.78, 0.74, 0.8), true, -1.0, true)
	root.draw_arc(Vector2(0, -16), 200.0, 0.0, TAU, 64, Color(glow, 0.5 + 0.4 * pulse), 8.0, true)
	root.draw_set_transform(Vector2.ZERO)
	# Sparks drifting up off the island.
	for k in 18:
		var rise := fmod(t * 0.35 + k * 0.057, 1.0)
		var at := Vector2(sin(k * 3.1) * 220.0, -rise * 420.0)
		root.draw_circle(at, 3.0 * (1.0 - rise), Color(glow.lightened(0.4), 0.8 * (1.0 - rise)), true, -1.0, true)


# --- fighter select ---

func _build_select() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	var cards := GridContainer.new()
	cards.columns = 5
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 10)
	var group := ButtonGroup.new()
	for i in _roster.size():
		var card := _fighter_card(_roster[i], group)
		card.pressed.connect(_on_card_picked.bind(i))
		cards.add_child(card)
		_card_buttons.append(card)
	# Two rows show at once; any more scroll, so the buttons below always fit.
	_card_scroll = ScrollContainer.new()
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.scroll_deadzone = 12
	_card_scroll.custom_minimum_size = Vector2(cards.get_combined_minimum_size().x + 14, 2 * 190 + 10 + 6)
	_card_scroll.add_child(cards)
	content.add_child(_card_scroll)

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
	# Mastery: switch between the colour schemes you have unlocked for this fighter.
	_skin_button = _icon_button(&"star", "Colours", UiStyle.YELLOW, Vector2(200, 70), 22)
	_skin_button.pressed.connect(_next_skin)
	bottom.add_child(_skin_button)
	# Vs AI: let the game choose the opponent.
	_random_button = _icon_button(&"restart", "Random", UiStyle.PURPLE, Vector2(190, 70), 24)
	_random_button.pressed.connect(func() -> void:
		_random_foe = true
		_show_screen(_map_screen))
	bottom.add_child(_random_button)
	bottom.add_child(go)
	content.add_child(bottom)
	var screen := _card_screen("CHOOSE YOUR FIGHTER", UiStyle.YELLOW, content)
	_select_ribbon = screen.get_meta("ribbon")
	return screen


func _fighter_card(data: FighterData, group: ButtonGroup) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = group
	card.custom_minimum_size = Vector2(204, 190)
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
	preview.custom_minimum_size = Vector2(0, 86)
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
	stack.add_child(UiStyle.ink_label(data.short_name, 20, true))
	var weapon := UiStyle.ink_label(data.weapon.display_name, 15)
	weapon.add_theme_color_override("font_color", INK.lightened(0.25))
	stack.add_child(weapon)
	var power := data.weapon.body_damage * data.weapon.count
	stack.add_child(_stat_row("Power", clampi(roundi(power / 7.0), 1, 5), data.body_color))
	stack.add_child(_stat_row("Speed", clampi(roundi((data.weapon.max_speed - 1150.0) / 55.0), 1, 5), data.body_color))
	card.add_child(stack)
	card.set_meta("fighter", fighter)
	card.set_meta("data", data)
	# Mastery level, top right.
	var badge := UiStyle.game_label("", 18, true)
	badge.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -70
	badge.offset_right = -10
	badge.offset_top = 6
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(badge)
	card.set_meta("badge", badge)
	# Locked: dim the card and show the Shop price.
	var lock := PanelContainer.new()
	var lock_box := UiStyle.flat(Color(0.08, 0.05, 0.12, 0.88), 14, 0)
	lock.add_theme_stylebox_override("panel", lock_box)
	lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lock.offset_bottom = -6
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lock_label := UiStyle.game_label("LOCKED
Find in chests", 18, true)
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
	button.custom_minimum_size = Vector2(206, 172)
	button.add_theme_stylebox_override("normal", UiStyle.candy(color.lerp(PAPER, 0.6)))
	button.add_theme_stylebox_override("hover", UiStyle.candy(color.lerp(PAPER, 0.4)))
	button.add_theme_stylebox_override("pressed", UiStyle.candy(color, true))
	button.add_theme_stylebox_override("hover_pressed", UiStyle.candy(color, true))
	button.button_pressed = map == _map_choice
	button.pressed.connect(func() -> void: _map_choice = map)
	var row := VBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 8
	row.offset_bottom = -14
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 92)
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
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	# How far apart the fighters stand here.
	var distance := UiStyle.ink_label("%d–%d m apart" % [roundi(map.min_distance_m), roundi(map.max_distance_m)] if map != null else "Surprise me", 14, true)
	distance.add_theme_color_override("font_color", INK.lightened(0.2))
	row.add_child(distance)
	button.add_child(row)
	return button


## A label and five pips, `value` of them filled.
func _stat_row(label_text: String, value: int, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := UiStyle.ink_label(label_text, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.custom_minimum_size.x = 56
	row.add_child(label)
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(110, 16)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func() -> void:
		for i in 5:
			var filled := i < value
			pips.draw_style_box(UiStyle.flat(color if filled else Color(0, 0, 0, 0.12), 5, 2 if filled else 0), Rect2(i * 22.0, 2, 18, 12)))
	row.add_child(pips)
	return row


func _refresh_select() -> void:
	var vs_ai := _select_mode == MatchController.Mode.VS_AI
	var is_tournament := _select_mode == MatchController.Mode.TOURNAMENT
	var is_arcade := _select_mode == MatchController.Mode.ARCADE
	var label: Label = _select_ribbon.get_meta("label")
	var color := UiStyle.YELLOW
	if is_tournament:
		label.text = "CHOOSE YOUR CHAMPION"
		color = UiStyle.ORANGE
	elif is_arcade:
		label.text = "ARCADE: CHOOSE YOUR FIGHTER"
		color = UiStyle.RED
	elif _select_mode == MatchController.Mode.BOSS_RUSH:
		label.text = "BOSS RUSH: CHOOSE YOUR FIGHTER"
		color = UiStyle.PURPLE
	elif _select_mode == MatchController.Mode.SURVIVAL:
		label.text = "SURVIVAL: CHOOSE YOUR FIGHTER"
		color = UiStyle.RED
	elif _select_mode == MatchController.Mode.TAG:
		label.text = "2V2: FIRST FIGHTER" if _select_step == 0 else "2V2: YOUR PARTNER"
		color = UiStyle.ORANGE if _select_step == 0 else UiStyle.GREEN
	elif _select_mode == MatchController.Mode.TAG_2P:
		label.text = "PLAYER %d: %s" % [_select_step / 2 + 1, "FIRST FIGHTER" if _select_step % 2 == 0 else "PARTNER"]
		color = UiStyle.BLUE if _select_step < 2 else UiStyle.RED
	elif _select_mode == MatchController.Mode.PRACTICE:
		label.text = "TARGET PRACTICE"
		color = UiStyle.BLUE
	elif vs_ai:
		label.text = "CHOOSE YOUR FIGHTER" if _select_step == 0 else "CHOOSE YOUR OPPONENT"
		color = UiStyle.YELLOW if _select_step == 0 else UiStyle.RED
	else:
		label.text = "PLAYER %d, CHOOSE!" % (_select_step + 1)
		color = UiStyle.BLUE if _select_step == 0 else UiStyle.RED
	_select_ribbon.add_theme_stylebox_override("panel", UiStyle.candy(color))
	_difficulty_box.visible = vs_ai or _select_mode == MatchController.Mode.TAG
	_go_label.text = "Next" if _last_step() > 0 else "Start!"
	_random_button.visible = vs_ai and _select_step == 1
	# Your opponent can be anyone, owned or not.
	var any_foe := vs_ai and _select_step == 1
	# Only fighters you own can be picked; fall back to the first owned one.
	if not any_foe and not Save.is_unlocked(_picks[_select_step]):
		for fighter in _roster:
			if Save.is_unlocked(fighter):
				_picks[_select_step] = fighter
				break
	var picked := _roster.find(_picks[_select_step])
	if picked >= 0:
		_card_scroll.ensure_control_visible.call_deferred(_card_buttons[picked])
	for i in _card_buttons.size():
		_card_buttons[i].set_pressed_no_signal(i == picked)
		var locked := not any_foe and not Save.is_unlocked(_card_buttons[i].get_meta("data"))
		_card_buttons[i].disabled = locked
		(_card_buttons[i].get_meta("lock") as Control).visible = locked
		var fighter: Fighter = _card_buttons[i].get_meta("fighter")
		fighter.aiming = i == picked
		var card_data: FighterData = _card_buttons[i].get_meta("data")
		var mastery := Save.mastery_level(String(card_data.id))
		(_card_buttons[i].get_meta("badge") as Label).text = "★%d" % mastery if mastery > 0 else ""
		# Your fighter is shown in the colours they wear.
		var wearing := Save.skin(String(card_data.id)) if not any_foe else 0
		if int(_card_buttons[i].get_meta("skin", 0)) != wearing:
			_card_buttons[i].set_meta("skin", wearing)
			fighter.setup(Mastery.skinned(card_data, wearing), 1, false, false)
	_refresh_skin_button()


func _on_card_picked(index: int) -> void:
	_picks[_select_step] = _roster[index]
	_random_foe = false
	_refresh_select()


## The last pick on the select screen: 0 for one fighter, 1 for a fighter and an
## opponent or partner, 3 for both players' 2v2 teams.
func _last_step() -> int:
	if _select_mode == MatchController.Mode.TAG_2P:
		return 3
	if _select_mode in [MatchController.Mode.LOCAL_2P, MatchController.Mode.VS_AI, MatchController.Mode.TAG]:
		return 1
	return 0


func _select_back() -> void:
	if _select_step > 0:
		_select_step -= 1
		_refresh_select()
	else:
		show_title()


func _select_next() -> void:
	var tag := _select_mode in [MatchController.Mode.TAG, MatchController.Mode.TAG_2P]
	# A 2v2 partner must be someone else.
	if tag and _select_step % 2 == 1 and _picks[_select_step] == _picks[_select_step - 1]:
		toast("Pick a different partner", Color(1.0, 0.6, 0.5))
		return
	if _select_step < _last_step():
		_select_step += 1
		_random_foe = false
		var before: FighterData = _picks[_select_step - 1]
		if _picks[_select_step] == null or _picks[_select_step] == before:
			_picks[_select_step] = _roster[(_roster.find(before) + 1) % _roster.size()]
		_refresh_select()
		return
	# Matches with an opponent or partner go on to choose a map; the rest start now.
	if _last_step() > 0:
		_show_screen(_map_screen)
		return
	_start_selected()


func _start_selected() -> void:
	if _select_mode == MatchController.Mode.TAG_2P:
		team_play_requested.emit(_picks.duplicate(), _map_choice)
		return
	var right := _picks[1] if _select_mode in [MatchController.Mode.LOCAL_2P, MatchController.Mode.TAG] or (_select_mode == MatchController.Mode.VS_AI and not _random_foe) else null
	play_requested.emit(_picks[0], right, _select_mode, _difficulty, _map_choice)


## Choose a map (or Random) before a vs AI or 1v1 match.
func _build_map_screen() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var group := ButtonGroup.new()
	for map in _maps:
		grid.add_child(_map_button(map, group))
	grid.add_child(_map_button(null, group))
	content.add_child(grid)
	# Chaos: a random mutator twists the rules for the match.
	var chaos := _icon_button(&"star", "", UiStyle.GREY, Vector2(460, 58), 22)
	chaos.toggle_mode = true
	chaos.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var chaos_label: Label = chaos.get_meta("label")
	var paint_chaos := func() -> void:
		chaos_label.text = "Chaos: ON  (a random twist)" if chaos_on else "Chaos: off"
		UiStyle.paint_button(chaos, Color(1.0, 0.45, 0.85) if chaos_on else UiStyle.GREY)
	chaos.toggled.connect(func(on: bool) -> void:
		chaos_on = on
		paint_chaos.call())
	paint_chaos.call()
	content.add_child(chaos)
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
	content.add_child(_toggle_row("Gore in fatalities", "gore"))
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
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	var notes := _icon_button(&"star", "Patch notes", UiStyle.PURPLE, Vector2(220, 66), 22)
	notes.pressed.connect(func() -> void: _show_screen(_patch_screen))
	buttons.add_child(notes)
	var back := _icon_button(&"play", "Got it!", UiStyle.GREEN, Vector2(220, 66), 26)
	back.pressed.connect(show_title)
	buttons.add_child(back)
	content.add_child(buttons)
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
	elif ladder.get("kind", "") == "survival":
		# Survival: on to the next fight after a win; a loss ends the run.
		if ladder["won"]:
			var fight := _icon_button(&"sword", "Next fight", UiStyle.GREEN, Vector2(260, 66), 24)
			fight.pressed.connect(round_requested.emit)
			buttons = [fight]
	elif ladder["won"] and not ladder["final"]:
		var next := _icon_button(&"trophy", "Next round", UiStyle.GREEN, Vector2(260, 66), 24)
		next.pressed.connect(ladder_requested.emit)
		buttons = [next]
	elif not ladder["won"] and ladder.get("kind", "tournament") != "bossrush":
		var retry := _icon_button(&"restart", "Retry round %d" % ladder["round"], UiStyle.YELLOW, Vector2(260, 66), 22)
		retry.pressed.connect(round_requested.emit)
		buttons = [retry]
	elif ladder["won"] and ladder["final"]:
		var again := _icon_button(&"restart", "Play again", UiStyle.GREEN, Vector2(240, 66), 24)
		again.pressed.connect(ladder_again_requested.emit)
		buttons = [again]
	var giving_up: bool = not ladder.is_empty() and not ladder["won"] and not ladder.get("kind", "tournament") in ["bossrush", "survival"]
	var menu := _icon_button(&"home", "Give up" if giving_up else "Menu", UiStyle.GREY, Vector2(170, 66), 22)
	menu.pressed.connect(give_up_requested.emit if giving_up else menu_requested.emit)
	buttons.append(menu)
	for button in buttons:
		button.theme = UiStyle.theme()
		_result_buttons.add_child(button)


## The tournament ladder: thirteen round cards (won, next or locked) and a start button.
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
	var kind: String = info.get("kind", "tournament")
	var arcade_run := kind == "arcade"
	var rounds_list: Array = info["rounds"]
	var rival: FighterData = rounds_list[-1]["opponent"]
	var heading: String = {"arcade": "%s's road to %s" % [pick.short_name, rival.short_name], "bossrush": "%s against the bosses" % pick.short_name}.get(kind, "%s's road to glory" % pick.short_name)
	var you := UiStyle.ink_label(heading, 26, true)
	(_ladder_screen.get_meta("ribbon").get_meta("label") as Label).text = {"arcade": "ARCADE", "bossrush": "BOSS RUSH"}.get(kind, "TOURNAMENT")
	header.add_child(you)
	_ladder_content.add_child(header)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var rounds: Array = info["rounds"]
	var next_card: Control = null
	for i in rounds.size():
		var card := _round_card(i, rounds[i], i == rounds.size() - 1)
		row.add_child(card)
		if i == int(info["round"]):
			next_card = card
	# Thirteen rounds are too many to show at once: they scroll, starting at the next one.
	var strip := ScrollContainer.new()
	strip.custom_minimum_size = Vector2(1080, 312)
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.add_child(row)
	_ladder_content.add_child(strip)
	if next_card != null:
		_scroll_to_card(strip, next_card)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	var quit := _icon_button(&"home", "Quit", UiStyle.GREY, Vector2(170, 70), 24)
	quit.pressed.connect(menu_requested.emit)
	var go := _icon_button(&"sword", "Fight round %d!" % (info["round"] + 1), UiStyle.GREEN, Vector2(320, 70), 30)
	go.pressed.connect(round_requested.emit)
	buttons.add_child(quit)
	# Mid-tournament (not yet won a round's result screen): start over with a new pick.
	if kind == "tournament" and (int(info["round"]) > 0 or Save.tournament.size() > 0):
		var fresh := _icon_button(&"restart", "New tournament", UiStyle.ORANGE, Vector2(260, 70), 24)
		fresh.pressed.connect(func() -> void:
			Save.tournament = {}
			Save.save_progress()
			_open_select(MatchController.Mode.TOURNAMENT))
		buttons.add_child(fresh)
	buttons.add_child(go)
	_ladder_content.add_child(buttons)
	_show_screen(_ladder_screen)


## Once the ladder has laid itself out, scrolls so the next round sits near the left.
func _scroll_to_card(strip: ScrollContainer, card: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(strip) and is_instance_valid(card):
		strip.scroll_horizontal = maxi(0, int(card.position.x) - 190)


func _round_card(index: int, round_info: Dictionary, boss: bool) -> PanelContainer:
	var state: String = round_info["state"]
	var opponent: FighterData = round_info["opponent"]
	var map: MapData = round_info["map"]
	var card := PanelContainer.new()
	var color := UiStyle.GREEN if state == "won" else (UiStyle.YELLOW if state == "next" else UiStyle.GREY)
	if boss and state != "won":
		color = UiStyle.PURPLE if state == "locked" else UiStyle.RED
	card.add_theme_stylebox_override("panel", UiStyle.candy(color.lerp(PAPER, 0.35 if state == "next" else 0.55)))
	card.custom_minimum_size = Vector2(170, 290)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 6)
	var kind: String = round_info.get("kind", "tournament")
	var title := "ROUND %d" % (index + 1)
	if kind == "bossrush":
		title = "FINAL BOSS" if boss else "BOSS %d" % (index + 1)
	elif boss:
		title = "RIVAL" if kind == "arcade" else "FINAL"
	stack.add_child(UiStyle.game_label(title, 24, true))
	var portrait_box := CenterContainer.new()
	var portrait := Portrait.make(opponent, -1, 80.0)
	if state == "locked" and not boss:
		portrait.modulate = Color(0.25, 0.22, 0.3)
	portrait_box.add_child(portrait)
	stack.add_child(portrait_box)
	stack.add_child(UiStyle.ink_label(opponent.display_name if state != "locked" or boss else "???", 18, true))
	# How rare they are: the ladder climbs from Common to Mythic.
	var shadow := boss and kind == "tournament"
	var rarity_name: String = "Your shadow" if shadow else String(Chests.RARITY_NAMES.get(opponent.rarity, "Common"))
	var rarity := UiStyle.game_label(rarity_name, 15, true)
	rarity.add_theme_color_override("font_color", Chests.RARITY_COLORS.get(opponent.rarity, Color.WHITE) if not shadow else Color(0.85, 0.45, 1.0))
	stack.add_child(rarity)
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
	# The prize for winning it.
	var prize := "+%d coins" % int(round_info.get("coins", 0))
	if round_info.has("chest"):
		prize += "
+ %s" % Chests.KINDS[round_info["chest"]]["name"]
	var prize_label := UiStyle.ink_label(prize, 15, true)
	prize_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(prize_label)
	if state == "won":
		stack.add_child(UiStyle.game_label("✔ WON", 20, true))
	card.add_child(stack)
	if state == "next":
		card.pivot_offset = card.custom_minimum_size / 2
		var pulse := card.create_tween().set_loops()
		pulse.tween_property(card, "scale", Vector2(1.04, 1.04), 0.5).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	return card


## The tournament champion's prize: a chest, opened over the result screen.
func award_chest(kind: String, result: Dictionary) -> void:
	if result.is_empty():
		return
	toast("CHAMPION'S PRIZE: %s!" % Chests.KINDS[kind]["name"], Color(1.0, 0.8, 0.3))
	await get_tree().create_timer(1.2).timeout
	_chest_opening.play(kind, result)
	_refresh_title()


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
	if _survival_button != null:
		(_survival_button.get_meta("subtitle") as Label).text = "Best run: %d wins" % Save.survival_best if Save.survival_best > 0 else "Endless fights, one health bar"
	var subtitle: Label = _tournament_button.get_meta("subtitle")
	if Save.tournament.is_empty():
		subtitle.text = "13 rounds, Common to Mythic"
	else:
		subtitle.text = "Continue: round %d of %d" % [int(Save.tournament["round"]) + 1, (Save.tournament["rounds"] as Array).size()]
	var done := Save.daily_done == Rewards.today()
	(_daily_button.get_meta("label") as Label).text = "Daily ✓" if done else "Daily"
	(_daily_button.get_meta("subtitle") as Label).text = "Done for today" if done else "New every day"
	_daily_button.tooltip_text = Rewards.daily(Rewards.today(), _roster, _maps)["text"]
	var info := Save.level_info()
	_level_label.text = "Level %d" % info["level"]
	_xp_bar.max_value = info["needed"]
	_xp_bar.value = info["into"]
	_xp_label.text = "%d / %d XP" % [info["into"], info["needed"]]
	_refresh_profile_portrait()


## Your selected fighter's face in the profile card.
func _refresh_profile_portrait() -> void:
	_clear(_profile_portrait)
	var data := _roster[0]
	for fighter in _roster:
		if String(fighter.id) == Save.selected_fighter:
			data = fighter
	_profile_portrait.add_child(Portrait.make(data, 1, 56.0))


func _open_fighters() -> void:
	_fill_fighters()
	_show_screen(_fighters_screen)


## Every fighter with its rarity: owned ones can be picked as your fighter, the rest
## are greyed out and found in chests.
func _fill_fighters() -> void:
	_clear(_fighters_content)
	var owned_count := _owned_fighters().size()
	var header := UiStyle.ink_label("%d of %d collected  ·  Tap one you own to make it your fighter" % [owned_count, _roster.size()], 18)
	_fighters_content.add_child(header)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for fighter in _roster:
		grid.add_child(_fighter_tile(fighter))
	# Two rows show at once and the rest scroll, so Back always stays on screen.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	scroll.custom_minimum_size = Vector2(grid.get_combined_minimum_size().x + 14, 2 * 196 + 10 + 6)
	scroll.add_child(grid)
	_fighters_content.add_child(scroll)
	_fighters_content.add_child(_back_button(show_title))


func _fighter_tile(fighter: FighterData) -> Button:
	var owned := Save.is_unlocked(fighter)
	var selected := String(fighter.id) == Save.selected_fighter
	var rarity_color: Color = Chests.RARITY_COLORS.get(fighter.rarity, Color.WHITE)
	var tile := _button("", 16)
	tile.custom_minimum_size = Vector2(196, 196)
	UiStyle.paint_button(tile, fighter.body_color.lerp(PAPER, 0.6) if owned else Color(0.45, 0.42, 0.5))
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_top = 6
	stack.offset_bottom = -12
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge := UiStyle.game_label(Chests.RARITY_NAMES.get(fighter.rarity, "Common"), 15, true)
	badge.add_theme_color_override("font_color", rarity_color)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(badge)
	var portrait_box := CenterContainer.new()
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := Portrait.make(fighter, 1, 96.0)
	if not owned:
		portrait.modulate = Color(0.15, 0.13, 0.2)
	portrait_box.add_child(portrait)
	stack.add_child(portrait_box)
	stack.add_child(UiStyle.ink_label(fighter.short_name if owned else "???", 20, true))
	var level := Save.fighter_level(String(fighter.id))
	var owned_text := ("Owned  ·  Lv %d" % level) if level > 0 else "Owned"
	var status := UiStyle.ink_label("✔ Your fighter" if selected else (owned_text if owned else "Find in chests"), 14)
	status.add_theme_color_override("font_color", UiStyle.GREEN.darkened(0.35) if selected else INK.lightened(0.2))
	stack.add_child(status)
	tile.add_child(stack)
	if selected:
		var ring := UiStyle.flat(Color(0, 0, 0, 0), 16, 4)
		ring.border_color = rarity_color
		var frame := Panel.new()
		frame.add_theme_stylebox_override("panel", ring)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.offset_left = -4
		frame.offset_top = -4
		frame.offset_right = 4
		frame.offset_bottom = 0
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(frame)
	if owned:
		tile.pressed.connect(func() -> void:
			Save.selected_fighter = String(fighter.id)
			Save.save_progress()
			_fill_fighters())
	else:
		tile.tooltip_text = "%s: find it in a chest" % Chests.RARITY_NAMES.get(fighter.rarity, "Common")
	return tile


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
	header.add_child(UiStyle.ink_label("Win matches to earn coins. Open chests and pick your colours.", 18))
	_shop_content.add_child(header)

	_shop_content.add_child(UiStyle.ink_label("Each chest holds one fighter. Duplicates turn into coins.", 18))
	_shop_content.add_child(_chest_row())
	_shop_content.add_child(_cosmetic_row("Ink", "ink", Save.INKS, Save.ink))
	_shop_content.add_child(_cosmetic_row("Trail", "trail", Save.TRAILS, Save.trail))
	_shop_content.add_child(_back_button(show_title))


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


## A coaching tip for the first match, shown above the bottom of the screen until the
## next throw.
func show_tip(text: String) -> void:
	var label: Label = _tip.get_meta("label")
	label.text = text
	_tip.show()
	_tip.modulate.a = 0.0
	_tip.create_tween().tween_property(_tip, "modulate:a", 1.0, 0.3)


func hide_tip() -> void:
	_tip.hide()


## Turns the time-stop tint on or off: violet for Star Platina, black and white for
## The Warld.
func set_time_stop(on: bool, violet: bool = true) -> void:
	if _time_stop == null or on == _time_stop.visible:
		return
	var grey: ShaderMaterial = _time_stop.material
	if on:
		grey.set_shader_parameter("purple", 1.0 if violet else 0.0)
		_time_stop.show()
		grey.set_shader_parameter("amount", 0.0)
		create_tween().tween_method(func(a: float) -> void: grey.set_shader_parameter("amount", a), 0.0, 1.0, 0.4)
	else:
		_time_stop.hide()


func time_stopped() -> bool:
	return _time_stop != null and _time_stop.visible


## Patch notes: every version's changes, newest first, in a scrolling card.
func _build_patch_notes() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry: Dictionary in PatchNotes.NOTES:
		var heading := UiStyle.game_label("%s  —  %s" % [entry["version"], entry["title"]], 26, true)
		heading.add_theme_color_override("font_color", UiStyle.PURPLE)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(heading)
		for note: String in entry["notes"]:
			var label := UiStyle.ink_label("•  " + note, 18)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = 720
			list.add_child(label)
		list.add_child(_spacer(8))
	scroll.add_child(list)
	content.add_child(scroll)
	content.add_child(_back_button(show_title))
	return _card_screen("PATCH NOTES", UiStyle.PURPLE, content)


# --- mastery ---

## Shows the Colours button only for a fighter of yours with more than one scheme unlocked.
func _refresh_skin_button() -> void:
	if _skin_button == null:
		return
	var picked: FighterData = _picks[_select_step]
	var mine := _select_step == 0 or _select_mode in [MatchController.Mode.LOCAL_2P, MatchController.Mode.TAG, MatchController.Mode.TAG_2P]
	var count := Mastery.skin_count(Save.mastery_level(String(picked.id))) if picked != null else 1
	_skin_button.visible = mine and count > 1 and Save.is_unlocked(picked)
	if _skin_button.visible:
		(_skin_button.get_meta("label") as Label).text = Mastery.SKIN_NAMES[Save.skin(String(picked.id))]


func _next_skin() -> void:
	var picked: FighterData = _picks[_select_step]
	var id := String(picked.id)
	var count := Mastery.skin_count(Save.mastery_level(id))
	Save.skins[id] = (Save.skin(id) + 1) % count
	Save.save_progress()
	Audio.play("click", -4.0)
	_refresh_select()


# --- fatality gallery ---

var _gallery_screen: Control
var _gallery_grid: GridContainer
var _gallery_count: Label


func _build_gallery() -> Control:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_gallery_count = UiStyle.ink_label("", 20, true)
	_gallery_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_gallery_count)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1060, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_gallery_grid = GridContainer.new()
	_gallery_grid.columns = 6
	_gallery_grid.add_theme_constant_override("h_separation", 10)
	_gallery_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_gallery_grid)
	content.add_child(scroll)
	var back := _icon_button(&"back", "Back", UiStyle.GREY, Vector2(170, 64), 22)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(show_title)
	content.add_child(back)
	return _card_screen("FATALITY GALLERY", UiStyle.RED, content)


## Opens the gallery: every fatality you have landed can be replayed; the rest stay hidden.
func open_gallery() -> void:
	if _gallery_screen == null:
		_gallery_screen = _build_gallery()
	_in_match = false
	_top_bar.hide()
	_hint.hide()
	_pause_button.hide()
	for child in _gallery_grid.get_children():
		_gallery_grid.remove_child(child)
		child.queue_free()
	var seen := 0
	for data in _roster:
		var unlocked := Save.fatalities.has(String(data.id))
		seen += 1 if unlocked else 0
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(166, 150)
		tile.add_theme_stylebox_override("normal", UiStyle.candy(data.body_color.lerp(PAPER, 0.6) if unlocked else Color(0.25, 0.22, 0.3)))
		tile.add_theme_stylebox_override("hover", UiStyle.candy(data.body_color.lerp(PAPER, 0.4) if unlocked else Color(0.25, 0.22, 0.3)))
		tile.add_theme_stylebox_override("pressed", UiStyle.candy(data.body_color, true))
		tile.disabled = not unlocked
		var stack := VBoxContainer.new()
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := CenterContainer.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := Portrait.make(data, 1, 64.0)
		if not unlocked:
			portrait.modulate = Color(0.2, 0.18, 0.25)
		face.add_child(portrait)
		stack.add_child(face)
		var name := UiStyle.ink_label(data.short_name if unlocked else "???", 17, true)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stack.add_child(name)
		var caption := UiStyle.ink_label(String(Fatality.NAMES.get(data.id, "FINISHED!")) if unlocked else "Not yet landed", 13)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stack.add_child(caption)
		tile.add_child(stack)
		tile.pressed.connect(func() -> void: gallery_requested.emit(data))
		_gallery_grid.add_child(tile)
	_gallery_count.text = "%d / %d fatalities landed  ·  land one in a match to add it here" % [seen, _roster.size()]
	_show_screen(_gallery_screen)


## While a gallery fatality plays: no match HUD, no menus.
func gallery_playback() -> void:
	_in_match = false
	_top_bar.hide()
	_hint.hide()
	_pause_button.hide()
	_show_screen(null)


# --- 2v2 ---

## The partner each side has waiting (empty text: none, as outside 2v2).
func set_partners(texts: Array) -> void:
	if _partner_labels.is_empty():
		for i in 2:
			var label := UiStyle.game_label("", 18, true)
			label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if i == 1 else HORIZONTAL_ALIGNMENT_LEFT
			_names[i].get_parent().add_child(label)
			_partner_labels.append(label)
	for i in 2:
		_partner_labels[i].text = texts[i]
		_partner_labels[i].visible = texts[i] != ""


var _tag_choice_screen: Control
var _survival_button: Button


## 2v2: play the AI, or a friend on this device.
func _open_tag_choice() -> void:
	if _tag_choice_screen == null:
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 16)
		var ai := _mode_button(&"sword", "Vs AI", "You pick two, the AI brings two", UiStyle.ORANGE)
		ai.custom_minimum_size.x = 460
		ai.pressed.connect(_open_select.bind(MatchController.Mode.TAG))
		content.add_child(ai)
		var friend := _mode_button(&"duo", "Vs Friend", "Each player picks two, on one device", UiStyle.BLUE)
		friend.custom_minimum_size.x = 460
		friend.pressed.connect(_open_select.bind(MatchController.Mode.TAG_2P))
		content.add_child(friend)
		var back := _icon_button(&"back", "Back", UiStyle.GREY, Vector2(170, 64), 22)
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(show_title)
		content.add_child(back)
		_tag_choice_screen = _card_screen("2V2 TAG", UiStyle.ORANGE, content)
	_show_screen(_tag_choice_screen)
