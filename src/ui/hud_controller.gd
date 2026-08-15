class_name HUDController
extends CanvasLayer

signal start_requested
signal restart_requested
signal pause_requested(paused: bool)
signal settings_changed

const SAFE_EDGE := 28.0
const TOP_EDGE := 22.0

var score_label: Label
var combo_label: Label
var speed_label: Label
var form_label: Label
var prompt_label: Label
var toast_label: Label
var center_title: Label
var center_subtitle: Label
var results_panel: PanelContainer
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var results_score: Label
var results_best: Label
var music_slider: HSlider
var sfx_slider: HSlider
var mute_check: CheckButton
var motion_check: CheckButton
var flash_check: CheckButton
var quality_option: OptionButton
var _top_items: Array[CanvasItem] = []
var profile: ProfileStore
var _toast_tween: Tween


func setup(value: ProfileStore) -> void:
	profile = value
	layer = 20
	_build_hud()
	_build_center_prompt()
	_build_pause_panel()
	_build_results_panel()
	_build_settings_panel()
	show_ready()


func _make_label(text_value: String, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.82))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _card_style(accent: Color = Color(0.14, 0.9, 1.0), alpha: float = 0.82, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.022, 0.07, alpha)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.62)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


func _panel_style(accent: Color = Color(0.12, 0.88, 1.0), alpha: float = 0.94) -> StyleBoxFlat:
	var style := _card_style(accent, alpha, 22)
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	return style


func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	return style


func _build_hud() -> void:
	# Each top metric owns a fixed safe-area offset instead of being positioned in camera space.
	var score_card := PanelContainer.new()
	score_card.add_theme_stylebox_override("panel", _card_style())
	score_card.anchor_left = 0.0
	score_card.anchor_top = 0.0
	score_card.anchor_right = 0.0
	score_card.anchor_bottom = 0.0
	score_card.offset_left = SAFE_EDGE
	score_card.offset_top = TOP_EDGE
	score_card.offset_right = SAFE_EDGE + 248.0
	score_card.offset_bottom = TOP_EDGE + 78.0
	add_child(score_card)
	_top_items.append(score_card)
	var score_stack := VBoxContainer.new()
	score_stack.add_theme_constant_override("separation", -3)
	score_card.add_child(score_stack)
	var score_caption := _make_label("SCORE", 12, Color(0.28, 0.88, 1.0))
	score_caption.add_theme_constant_override("outline_size", 0)
	score_stack.add_child(score_caption)
	score_label = _make_label("000000", 30, Color(0.96, 0.99, 1.0))
	score_label.clip_text = false
	score_stack.add_child(score_label)

	var form_card := PanelContainer.new()
	form_card.add_theme_stylebox_override("panel", _card_style(Color(0.25, 1.0, 0.88), 0.76, 999))
	form_card.anchor_left = 0.5
	form_card.anchor_right = 0.5
	form_card.anchor_top = 0.0
	form_card.anchor_bottom = 0.0
	form_card.offset_left = -146.0
	form_card.offset_right = 146.0
	form_card.offset_top = TOP_EDGE + 5.0
	form_card.offset_bottom = TOP_EDGE + 57.0
	add_child(form_card)
	_top_items.append(form_card)
	form_label = _make_label("□  CUBE", 20, Color(0.32, 1.0, 0.92))
	form_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	form_card.add_child(form_label)

	var metrics_card := PanelContainer.new()
	metrics_card.add_theme_stylebox_override("panel", _card_style(Color(1.0, 0.3, 0.72)))
	metrics_card.anchor_left = 1.0
	metrics_card.anchor_right = 1.0
	metrics_card.anchor_top = 0.0
	metrics_card.anchor_bottom = 0.0
	metrics_card.offset_left = -SAFE_EDGE - 278.0
	metrics_card.offset_right = -SAFE_EDGE
	metrics_card.offset_top = TOP_EDGE
	metrics_card.offset_bottom = TOP_EDGE + 78.0
	add_child(metrics_card)
	_top_items.append(metrics_card)
	var metrics := VBoxContainer.new()
	metrics.alignment = BoxContainer.ALIGNMENT_CENTER
	metrics.add_theme_constant_override("separation", -3)
	metrics_card.add_child(metrics)
	combo_label = _make_label("COMBO 0  ×1", 18, Color(1.0, 0.36, 0.75))
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.clip_text = false
	metrics.add_child(combo_label)
	speed_label = _make_label("1.00×  SPEED", 12, Color(0.67, 0.8, 1.0))
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metrics.add_child(speed_label)

	toast_label = _make_label("", 25, Color(0.35, 1.0, 0.8))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", _card_style(Color(0.35, 1.0, 0.8), 0.9, 999))
	toast_label.anchor_left = 0.5
	toast_label.anchor_right = 0.5
	toast_label.anchor_top = 0.5
	toast_label.anchor_bottom = 0.5
	toast_label.offset_left = -285.0
	toast_label.offset_right = 285.0
	toast_label.offset_top = -112.0
	toast_label.offset_bottom = -60.0
	toast_label.pivot_offset = Vector2(285.0, 26.0)
	toast_label.modulate.a = 0.0
	add_child(toast_label)

	prompt_label = _make_label("A / D  MOVE     1 / 2 / 3  SHAPE     P  PAUSE", 14, Color(0.72, 0.82, 1.0))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_stylebox_override("normal", _card_style(Color(0.3, 0.52, 1.0), 0.72, 999))
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_top = 1.0
	prompt_label.anchor_bottom = 1.0
	prompt_label.offset_left = -390.0
	prompt_label.offset_right = 390.0
	prompt_label.offset_top = -52.0
	prompt_label.offset_bottom = -18.0
	prompt_label.clip_text = false
	add_child(prompt_label)


func _build_center_prompt() -> void:
	center_title = _make_label("SHAPESHIFT", 54, Color(0.25, 1.0, 0.95))
	center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_title.anchor_left = 0.5
	center_title.anchor_right = 0.5
	center_title.anchor_top = 0.5
	center_title.anchor_bottom = 0.5
	center_title.offset_left = -500.0
	center_title.offset_right = 500.0
	center_title.offset_top = -176.0
	center_title.offset_bottom = -96.0
	add_child(center_title)
	center_subtitle = _make_label("NEON GAUNTLET\n\nMATCH LANE + FORM\nPRESS ANY MOVE OR SHAPE INPUT", 18, Color(0.85, 0.91, 1.0))
	center_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_subtitle.anchor_left = 0.5
	center_subtitle.anchor_right = 0.5
	center_subtitle.anchor_top = 0.5
	center_subtitle.anchor_bottom = 0.5
	center_subtitle.offset_left = -420.0
	center_subtitle.offset_right = 420.0
	center_subtitle.offset_top = -74.0
	center_subtitle.offset_bottom = 108.0
	add_child(center_subtitle)


func _panel_with_stack(accent: Color = Color(0.12, 0.88, 1.0)) -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(accent))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -238.0
	panel.offset_right = 238.0
	panel.offset_top = -208.0
	panel.offset_bottom = 208.0
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	add_child(panel)
	return [panel, stack]


func _make_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(318.0, 46.0)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.035, 0.075, 0.16, 0.94), Color(0.15, 0.78, 1.0, 0.72)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.075, 0.19, 0.3, 0.98), Color(0.38, 1.0, 0.95, 0.98)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.12, 0.32, 0.4, 1.0), Color(0.65, 1.0, 0.9, 1.0)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.075, 0.19, 0.3, 0.98), Color(1.0, 0.42, 0.78, 1.0)))
	return button


func _build_pause_panel() -> void:
	var pieces := _panel_with_stack()
	pause_panel = pieces[0] as PanelContainer
	var stack := pieces[1] as VBoxContainer
	var title := _make_label("PAUSED", 36, Color(0.25, 1.0, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _make_label("GAUNTLET HOLD", 13, Color(0.6, 0.76, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	var resume := _make_button("RESUME  [P]")
	resume.pressed.connect(func() -> void: pause_requested.emit(false))
	stack.add_child(resume)
	var restart := _make_button("RESTART RUN  [R]")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	stack.add_child(restart)
	var settings := _make_button("SETTINGS")
	settings.pressed.connect(func() -> void: settings_panel.visible = true)
	stack.add_child(settings)
	pause_panel.visible = false


func _build_results_panel() -> void:
	var pieces := _panel_with_stack(Color(1.0, 0.27, 0.62))
	results_panel = pieces[0] as PanelContainer
	var stack := pieces[1] as VBoxContainer
	var title := _make_label("SIGNAL LOST", 32, Color(1.0, 0.3, 0.67))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _make_label("RECALIBRATE. GO AGAIN.", 13, Color(0.7, 0.78, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	results_score = _make_label("SCORE 000000", 25)
	results_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(results_score)
	results_best = _make_label("BEST 000000", 16, Color(0.3, 0.9, 1.0))
	results_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(results_best)
	var restart := _make_button("INSTANT RESTART  [R]")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	stack.add_child(restart)
	var settings := _make_button("ACCESSIBILITY & AUDIO")
	settings.pressed.connect(func() -> void: settings_panel.visible = true)
	stack.add_child(settings)
	results_panel.visible = false


func _setting_row(caption: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _make_label(caption, 14, Color(0.76, 0.86, 1.0))
	label.custom_minimum_size.x = 170.0
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size.x = 180.0
	row.add_child(control)
	return row


func _build_settings_panel() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.32, 0.76), 0.97))
	settings_panel.anchor_left = 0.5
	settings_panel.anchor_right = 0.5
	settings_panel.anchor_top = 0.5
	settings_panel.anchor_bottom = 0.5
	settings_panel.offset_left = -258.0
	settings_panel.offset_right = 258.0
	settings_panel.offset_top = -254.0
	settings_panel.offset_bottom = 254.0
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	settings_panel.add_child(stack)
	add_child(settings_panel)
	var title := _make_label("SETTINGS", 29, Color(1.0, 0.34, 0.77))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _make_label("AUDIO · COMFORT · PERFORMANCE", 12, Color(0.7, 0.78, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.01
	music_slider.value = profile.music_volume
	stack.add_child(_setting_row("MUSIC", music_slider))
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.01
	sfx_slider.value = profile.sfx_volume
	stack.add_child(_setting_row("EFFECTS", sfx_slider))
	mute_check = CheckButton.new()
	mute_check.button_pressed = profile.muted
	stack.add_child(_setting_row("MUTE", mute_check))
	motion_check = CheckButton.new()
	motion_check.button_pressed = profile.reduced_motion
	stack.add_child(_setting_row("REDUCED MOTION", motion_check))
	flash_check = CheckButton.new()
	flash_check.button_pressed = profile.reduced_flash
	stack.add_child(_setting_row("REDUCED FLASH", flash_check))
	quality_option = OptionButton.new()
	quality_option.add_item("LOW", 0)
	quality_option.add_item("MEDIUM", 1)
	quality_option.add_item("HIGH", 2)
	quality_option.select(profile.quality)
	stack.add_child(_setting_row("QUALITY", quality_option))
	var close := _make_button("APPLY & CLOSE")
	close.pressed.connect(_apply_settings)
	stack.add_child(close)
	settings_panel.visible = false


func _apply_settings() -> void:
	profile.music_volume = float(music_slider.value)
	profile.sfx_volume = float(sfx_slider.value)
	profile.muted = mute_check.button_pressed
	profile.reduced_motion = motion_check.button_pressed
	profile.reduced_flash = flash_check.button_pressed
	profile.quality = quality_option.selected
	profile.save_profile()
	settings_panel.visible = false
	settings_changed.emit()


func show_ready() -> void:
	_set_top_bar_visible(true)
	center_title.visible = true
	center_subtitle.visible = true
	results_panel.visible = false
	pause_panel.visible = false
	prompt_label.visible = true


func show_running() -> void:
	_set_top_bar_visible(true)
	center_title.visible = false
	center_subtitle.visible = false
	results_panel.visible = false
	pause_panel.visible = false


func show_tutorial(message: String) -> void:
	center_title.visible = false
	center_subtitle.visible = false
	toast(message, Color(0.3, 0.95, 1.0), 1.6)


func show_paused(value: bool) -> void:
	pause_panel.visible = value
	if value:
		pause_panel.move_to_front()


func show_results(score: int, best: int, is_new_best: bool) -> void:
	_set_top_bar_visible(false)
	results_score.text = "SCORE %06d" % score
	results_best.text = ("NEW BEST  %06d" if is_new_best else "BEST  %06d") % best
	results_best.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25) if is_new_best else Color(0.3, 0.9, 1.0))
	results_panel.visible = true
	results_panel.move_to_front()
	prompt_label.visible = false


func update_score(score: int, combo: int, multiplier: int) -> void:
	score_label.text = "%06d" % score
	combo_label.text = "COMBO %d  ×%d" % [combo, multiplier]


func update_speed(speed_scale: float) -> void:
	speed_label.text = "%.2f×  SPEED" % speed_scale


func update_form(shape: GameEvents.ShapeKind) -> void:
	form_label.text = "%s  %s" % [GameEvents.shape_glyph(shape), GameEvents.shape_name(shape)]


func _set_top_bar_visible(value: bool) -> void:
	for item: CanvasItem in _top_items:
		item.visible = value


func toast(message: String, color: Color = Color.WHITE, duration: float = 0.8) -> void:
	if _toast_tween != null:
		_toast_tween.kill()
	toast_label.text = message
	toast_label.add_theme_color_override("font_color", color)
	toast_label.scale = Vector2(0.9, 0.9)
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(toast_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.22).set_delay(duration)
