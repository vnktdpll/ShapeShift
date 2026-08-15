class_name HUDController
extends CanvasLayer

signal restart_requested
signal pause_requested(paused: bool)
signal settings_changed
signal gameplay_action_requested(action: StringName)

const SAFE_EDGE := 28.0
const TOP_EDGE := 22.0
const REMAP_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"shape_cube", &"shape_pyramid", &"shape_sphere", &"pause_game", &"restart_run", &"ui_accept", &"ui_cancel"]
const REMAP_NAMES := {&"move_left": "LANE LEFT", &"move_right": "LANE RIGHT", &"shape_cube": "CUBE", &"shape_pyramid": "PYRAMID", &"shape_sphere": "SPHERE", &"pause_game": "PAUSE", &"restart_run": "RESTART", &"ui_accept": "MENU ACCEPT", &"ui_cancel": "MENU BACK"}
const TOUCH_FORM_ACTIONS: Array[StringName] = [&"shape_pyramid", &"shape_sphere"]
const TOUCH_NEUTRAL_FORM: StringName = &"shape_cube"

class TouchTarget extends Control:
	var action: StringName
	var glyph_kind := 0
	signal activated(action: StringName)
	signal deactivated(action: StringName)
	func _init(input_action: StringName, kind: int) -> void:
		action = input_action
		glyph_kind = kind
		mouse_filter = Control.MOUSE_FILTER_STOP
		custom_minimum_size = Vector2(76, 76)
	func _draw() -> void:
		var r := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		draw_style_box(_style(), r)
		var c := Color(0.45, 0.96, 1.0, 0.92)
		var center := size * 0.5
		match glyph_kind:
			0: draw_colored_polygon(PackedVector2Array([center + Vector2(-16, 0), center + Vector2(10, -17), center + Vector2(10, 17)]), c)
			1: draw_colored_polygon(PackedVector2Array([center + Vector2(16, 0), center + Vector2(-10, -17), center + Vector2(-10, 17)]), c)
			2: draw_rect(Rect2(center - Vector2(14, 14), Vector2(28, 28)), c, false, 4.0)
			3: draw_colored_polygon(PackedVector2Array([center + Vector2(0, -18), center + Vector2(-18, 15), center + Vector2(18, 15)]), c)
			4: draw_arc(center, 17, 0.0, TAU, 24, c, 4.0, true)
			5:
				draw_rect(Rect2(center - Vector2(13, 15), Vector2(8, 30)), c)
				draw_rect(Rect2(center + Vector2(5, -15), Vector2(8, 30)), c)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				activated.emit(action)
			else:
				deactivated.emit(action)
			accept_event()
		elif event is InputEventScreenTouch:
			if event.pressed:
				activated.emit(action)
			else:
				deactivated.emit(action)
			accept_event()
	func _style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.015, 0.045, 0.12, 0.72)
		style.border_color = Color(0.18, 0.88, 1.0, 0.8)
		style.set_border_width_all(2)
		style.set_corner_radius_all(18)
		return style

var score_label: Label
var score_card: PanelContainer
var feedback: ColorRect
var ready_panel: PanelContainer
var pause_panel: PanelContainer
var results_panel: PanelContainer
var settings_panel: PanelContainer
var controls_panel: PanelContainer
var results_score: Label
var results_best: Label
var profile: ProfileStore
var bindings: InputBindingStore
var _touch_controls: Array[Control] = []
var _capture_action: StringName
var _pending_event: InputEvent
var _pending_conflicts: Array[StringName] = []
var _capture_label: Label
var _binding_rows: Dictionary = {}
var _flash_tween: Tween
var _controls_return_panel: Control
var _settings_return_panel: Control
var _touch_by_action: Dictionary = {}
var _held_touch_shapes: Array[StringName] = []


func setup(value: ProfileStore, binding_store: InputBindingStore) -> void:
	profile = value
	bindings = binding_store
	layer = 20
	_build_play_hud()
	_build_ready()
	_build_pause()
	_build_results()
	_build_settings()
	_build_controls()
	get_viewport().size_changed.connect(_layout_play_controls)
	_layout_play_controls()
	show_ready()


func _label(value: String, font_size: int, tint := Color.WHITE) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", tint)
	result.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	result.add_theme_constant_override("shadow_offset_x", 2)
	result.add_theme_constant_override("shadow_offset_y", 2)
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return result


func _style(accent := Color(0.15, 0.88, 1.0), alpha := 0.90, radius := 16) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(0.01, 0.025, 0.075, alpha)
	result.border_color = Color(accent.r, accent.g, accent.b, 0.72)
	result.set_border_width_all(2)
	result.set_corner_radius_all(radius)
	result.content_margin_left = 18
	result.content_margin_right = 18
	result.content_margin_top = 12
	result.content_margin_bottom = 12
	return result


func _button(caption: String) -> Button:
	var result := Button.new()
	result.text = caption
	result.custom_minimum_size = Vector2(340, 48)
	result.focus_mode = Control.FOCUS_ALL
	result.add_theme_font_size_override("font_size", 16)
	result.add_theme_stylebox_override("normal", _style(Color(0.16, 0.72, 1.0), 0.90, 10))
	result.add_theme_stylebox_override("hover", _style(Color(0.40, 1.0, 0.92), 0.96, 10))
	result.add_theme_stylebox_override("focus", _style(Color(1.0, 0.34, 0.76), 0.98, 10))
	return result


func _center_panel(accent := Color(0.15, 0.88, 1.0), wide := false) -> Array:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(accent, 0.96, 22))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var half_width := 325.0 if wide else 245.0
	panel.offset_left = -half_width
	panel.offset_right = half_width
	panel.offset_top = -250
	panel.offset_bottom = 250
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	return [panel, stack]


func _build_play_hud() -> void:
	score_card = PanelContainer.new()
	score_card.add_theme_stylebox_override("panel", _style())
	score_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	score_card.position = Vector2(SAFE_EDGE, TOP_EDGE)
	score_card.size = Vector2(184, 62)
	add_child(score_card)
	score_label = _label("000000", 30)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_card.add_child(score_label)

	feedback = ColorRect.new()
	feedback.color = Color(0.95, 0.08, 0.42, 0.0)
	feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feedback)

	_add_touch(&"move_left", 0, Control.PRESET_BOTTOM_LEFT, Vector2(SAFE_EDGE, -SAFE_EDGE - 88))
	_add_touch(&"move_right", 1, Control.PRESET_BOTTOM_LEFT, Vector2(SAFE_EDGE + 98, -SAFE_EDGE - 88))
	# Cube is the neutral touch form. Holding either visible form overrides it;
	# releasing the last held form returns to cube without a third HUD button.
	_add_touch(&"shape_pyramid", 3, Control.PRESET_BOTTOM_RIGHT, Vector2(-SAFE_EDGE - 164, -SAFE_EDGE - 88))
	_add_touch(&"shape_sphere", 4, Control.PRESET_BOTTOM_RIGHT, Vector2(-SAFE_EDGE - 76, -SAFE_EDGE - 88))
	_add_touch(&"pause_game", 5, Control.PRESET_TOP_RIGHT, Vector2(-SAFE_EDGE - 64, TOP_EDGE), Vector2(64, 64))


func _add_touch(action: StringName, kind: int, preset: int, position: Vector2, target_size := Vector2(88, 88)) -> void:
	var target := TouchTarget.new(action, kind)
	target.custom_minimum_size = target_size
	target.size = target_size
	target.set_anchors_preset(preset)
	target.position = position
	target.activated.connect(_on_touch_activated)
	target.deactivated.connect(_on_touch_deactivated)
	add_child(target)
	_touch_controls.append(target)
	_touch_by_action[action] = target


func _on_touch_activated(action: StringName) -> void:
	if action in TOUCH_FORM_ACTIONS:
		_held_touch_shapes.erase(action)
		_held_touch_shapes.append(action)
	gameplay_action_requested.emit(action)


func _on_touch_deactivated(action: StringName) -> void:
	if action not in TOUCH_FORM_ACTIONS:
		return
	_held_touch_shapes.erase(action)
	gameplay_action_requested.emit(_held_touch_shapes[-1] if not _held_touch_shapes.is_empty() else TOUCH_NEUTRAL_FORM)


static func scaled_safe_insets(viewport_size: Vector2, display_size: Vector2i, safe_rect: Rect2i) -> Vector4:
	if display_size.x <= 0 or display_size.y <= 0 or safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return Vector4.ZERO
	var scale := Vector2(viewport_size.x / float(display_size.x), viewport_size.y / float(display_size.y))
	return Vector4(
		float(safe_rect.position.x) * scale.x,
		float(safe_rect.position.y) * scale.y,
		float(display_size.x - safe_rect.end.x) * scale.x,
		float(display_size.y - safe_rect.end.y) * scale.y
	)


func _layout_play_controls() -> void:
	if score_card == null or _touch_by_action.is_empty():
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var insets := Vector4.ZERO
	# Desktop safe/work areas may be reported in a different coordinate space
	# than a scaled game window. Mobile display and viewport coordinates share the
	# physical screen contract, which is where cutout insets must be applied.
	if OS.has_feature("mobile"):
		var screen := DisplayServer.window_get_current_screen()
		var display_size := DisplayServer.screen_get_size(screen)
		var safe := DisplayServer.get_display_safe_area()
		insets = scaled_safe_insets(viewport_size, display_size, safe)
	var left := maxf(SAFE_EDGE, insets.x + 12.0)
	var top := maxf(TOP_EDGE, insets.y + 12.0)
	var right := maxf(SAFE_EDGE, insets.z + 12.0)
	var bottom := maxf(SAFE_EDGE, insets.w + 12.0)
	_set_offsets(score_card, left, top, 184.0, 62.0)
	_set_offsets(_touch_by_action[&"move_left"], left, -bottom - 88.0, 88.0, 88.0)
	_set_offsets(_touch_by_action[&"move_right"], left + 98.0, -bottom - 88.0, 88.0, 88.0)
	_set_offsets(_touch_by_action[&"shape_pyramid"], -right - 164.0, -bottom - 88.0, 88.0, 88.0)
	_set_offsets(_touch_by_action[&"shape_sphere"], -right - 76.0, -bottom - 88.0, 88.0, 88.0)
	_set_offsets(_touch_by_action[&"pause_game"], -right - 64.0, top, 64.0, 64.0)


func _set_offsets(control: Control, left: float, top: float, width: float, height: float) -> void:
	control.offset_left = left
	control.offset_top = top
	control.offset_right = left + width
	control.offset_bottom = top + height


func _build_ready() -> void:
	var pieces := _center_panel()
	ready_panel = pieces[0]
	var stack: VBoxContainer = pieces[1]
	var title := _label("SHAPESHIFT", 48, Color(0.30, 1.0, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label("MATCH THE TARGET", 16, Color(0.7, 0.85, 1.0))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	var start := _button("PLAY")
	start.pressed.connect(func() -> void: gameplay_action_requested.emit(&"shape_cube"))
	stack.add_child(start)
	var controls := _button("CONTROLS")
	controls.pressed.connect(_open_controls)
	stack.add_child(controls)


func _build_pause() -> void:
	var pieces := _center_panel()
	pause_panel = pieces[0]
	var stack: VBoxContainer = pieces[1]
	var title := _label("PAUSED", 36, Color(0.30, 1.0, 0.95))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var resume := _button("RESUME")
	resume.pressed.connect(func() -> void: pause_requested.emit(false))
	stack.add_child(resume)
	var restart := _button("RESTART")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	stack.add_child(restart)
	var controls := _button("CONTROLS")
	controls.pressed.connect(_open_controls)
	stack.add_child(controls)
	var settings := _button("SETTINGS")
	settings.pressed.connect(_open_settings)
	stack.add_child(settings)


func _build_results() -> void:
	var pieces := _center_panel(Color(1.0, 0.27, 0.62))
	results_panel = pieces[0]
	var stack: VBoxContainer = pieces[1]
	var title := _label("RUN OVER", 34, Color(1.0, 0.35, 0.70))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	results_score = _label("SCORE 000000", 25)
	results_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(results_score)
	results_best = _label("BEST 000000", 16, Color(0.35, 0.9, 1.0))
	results_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(results_best)
	var restart := _button("RESTART")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	stack.add_child(restart)
	var controls := _button("CONTROLS")
	controls.pressed.connect(_open_controls)
	stack.add_child(controls)


func _build_settings() -> void:
	var pieces := _center_panel(Color(1.0, 0.32, 0.76), true)
	settings_panel = pieces[0]
	var stack: VBoxContainer = pieces[1]
	var title := _label("SETTINGS", 30, Color(1.0, 0.40, 0.78))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	for setting: Array in [["MUSIC", "music_volume"], ["EFFECTS", "sfx_volume"]]:
		var row := HBoxContainer.new()
		row.add_child(_label(setting[0], 15, Color(0.75, 0.86, 1.0)))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = profile.get(setting[1])
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value: float, key: String = setting[1]) -> void: profile.set(key, value))
		row.add_child(slider)
		stack.add_child(row)
	var motion := CheckButton.new()
	motion.text = "REDUCED MOTION"
	motion.button_pressed = profile.reduced_motion
	motion.toggled.connect(func(value: bool) -> void: profile.reduced_motion = value)
	stack.add_child(motion)
	var flash := CheckButton.new()
	flash.text = "REDUCED FLASH"
	flash.button_pressed = profile.reduced_flash
	flash.toggled.connect(func(value: bool) -> void: profile.reduced_flash = value)
	stack.add_child(flash)
	var close := _button("APPLY & CLOSE")
	close.pressed.connect(_close_settings)
	stack.add_child(close)


func _build_controls() -> void:
	var pieces := _center_panel(Color(0.36, 1.0, 0.88), true)
	controls_panel = pieces[0]
	var stack: VBoxContainer = pieces[1]
	# Nine remappable actions need more vertical room than the compact pause menu.
	# Keep the complete list on-screen at the 720p reference viewport.
	controls_panel.offset_top = -340.0
	controls_panel.offset_bottom = 340.0
	stack.add_theme_constant_override("separation", 4)
	var title := _label("CONTROLS", 30, Color(0.40, 1.0, 0.90))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	_capture_label = _label("SELECT AN ACTION TO REBIND", 13, Color(0.75, 0.86, 1.0))
	_capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_capture_label)
	for action: StringName in REMAP_ACTIONS:
		var row := HBoxContainer.new()
		var action_label := _label(REMAP_NAMES[action], 14, Color(0.76, 0.88, 1.0))
		action_label.custom_minimum_size.x = 138.0
		row.add_child(action_label)
		var bind_button := _button(bindings.readable_binding(action))
		bind_button.custom_minimum_size = Vector2(250, 38)
		bind_button.pressed.connect(func(selected: StringName = action) -> void: _begin_capture(selected))
		row.add_child(bind_button)
		stack.add_child(row)
		_binding_rows[action] = bind_button
	var defaults := _button("RESTORE DEFAULTS")
	defaults.pressed.connect(func() -> void: bindings.reset_defaults(profile); _refresh_bindings(); _capture_label.text = "DEFAULTS RESTORED")
	stack.add_child(defaults)
	var close := _button("BACK")
	close.pressed.connect(_close_controls)
	stack.add_child(close)


func _open_settings() -> void:
	_settings_return_panel = _visible_primary_panel()
	if _settings_return_panel != null:
		_settings_return_panel.visible = false
	settings_panel.visible = true
	settings_panel.move_to_front()
	call_deferred("_focus_first", settings_panel)


func _open_controls() -> void:
	_refresh_bindings()
	_controls_return_panel = _visible_primary_panel()
	if _controls_return_panel != null:
		_controls_return_panel.visible = false
	controls_panel.visible = true
	controls_panel.move_to_front()
	call_deferred("_focus_first", controls_panel)


func _close_settings() -> void:
	profile.save_profile()
	settings_panel.visible = false
	settings_changed.emit()
	_restore_panel(_settings_return_panel)
	_settings_return_panel = null


func _close_controls() -> void:
	_cancel_capture()
	controls_panel.visible = false
	_restore_panel(_controls_return_panel)
	_controls_return_panel = null


func _visible_primary_panel() -> Control:
	for panel: Control in [settings_panel, pause_panel, results_panel, ready_panel]:
		if panel != null and panel.visible:
			return panel
	return null


func _restore_panel(panel: Control) -> void:
	if panel == null:
		return
	panel.visible = true
	panel.move_to_front()
	call_deferred("_focus_first", panel)


func _begin_capture(action: StringName) -> void:
	_capture_action = action
	_pending_event = null
	_pending_conflicts.clear()
	_capture_label.text = "PRESS A KEY OR CONTROLLER INPUT · BACK CANCELS"
	var button: Button = _binding_rows[action]
	button.grab_focus()


func capture_input(event: InputEvent) -> bool:
	if _capture_action.is_empty():
		if event.is_action_pressed(&"ui_cancel", false):
			if controls_panel.visible:
				_close_controls()
				return true
			if settings_panel.visible:
				_close_settings()
				return true
			if pause_panel.visible:
				pause_requested.emit(false)
				return true
		return false
	if event.is_action_pressed(&"ui_cancel", false):
		_cancel_capture()
		return true
	if not _is_capture_event(event):
		return true
	_pending_event = event.duplicate()
	_pending_conflicts = bindings.conflicts_for(_capture_action, _pending_event)
	if _pending_conflicts.is_empty():
		_commit_capture(true)
	else:
		_capture_label.text = "IN USE BY %s · PRESS ENTER TO SWAP · ESC CANCELS" % REMAP_NAMES[_pending_conflicts[0]]
		_capture_action = _capture_action # Keep modal capture alive for its explicit swap.
	return true


func _is_capture_event(event: InputEvent) -> bool:
	return (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.7)


func capture_confirm(event: InputEvent) -> bool:
	if _pending_event == null or _pending_conflicts.is_empty():
		return false
	if event.is_action_pressed(&"ui_accept", false):
		_commit_capture(true)
		return true
	return false


func _commit_capture(swap: bool) -> void:
	var result := bindings.bind(_capture_action, _pending_event, profile, swap)
	if result.get("ok", false):
		_capture_label.text = "SAVED" if _pending_conflicts.is_empty() else "SWAPPED & SAVED"
		_refresh_bindings()
	else:
		_capture_label.text = "BINDING NOT CHANGED"
	_capture_action = &""
	_pending_event = null
	_pending_conflicts.clear()


func _cancel_capture() -> void:
	_capture_action = &""
	_pending_event = null
	_pending_conflicts.clear()
	if _capture_label != null:
		_capture_label.text = "SELECT AN ACTION TO REBIND"


func _refresh_bindings() -> void:
	for action: StringName in REMAP_ACTIONS:
		if _binding_rows.has(action):
			(_binding_rows[action] as Button).text = bindings.readable_binding(action)


func show_ready() -> void:
	ready_panel.visible = true
	pause_panel.visible = false
	results_panel.visible = false
	settings_panel.visible = false
	controls_panel.visible = false
	_set_play_visible(false)
	call_deferred("_focus_first", ready_panel)


func show_running() -> void:
	ready_panel.visible = false
	pause_panel.visible = false
	results_panel.visible = false
	_set_play_visible(true)


func show_paused(value: bool) -> void:
	pause_panel.visible = value
	if value:
		pause_panel.move_to_front()
		call_deferred("_focus_first", pause_panel)
	_set_touch_visible(not value)


func show_results(score: int, best: int, is_new_best: bool) -> void:
	_set_play_visible(false)
	results_score.text = "SCORE %06d" % score
	results_best.text = ("NEW BEST %06d" if is_new_best else "BEST %06d") % best
	results_panel.visible = true
	results_panel.move_to_front()
	call_deferred("_focus_first", results_panel)


func _focus_first(root: Control) -> void:
	for candidate: Node in root.find_children("*", "Button", true, false):
		var button := candidate as Button
		if button != null and button.visible and not button.disabled:
			button.grab_focus()
			return


func update_score(score: int, _combo := 0, _multiplier := 1) -> void:
	score_label.text = "%06d" % score


func pulse_success() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	feedback.color = Color(0.15, 1.0, 0.70, 0.14)
	_flash_tween = create_tween()
	_flash_tween.tween_property(feedback, "color:a", 0.0, 0.17)


func _set_play_visible(value: bool) -> void:
	score_card.visible = value
	_set_touch_visible(value)


func _set_touch_visible(value: bool) -> void:
	if not value:
		_held_touch_shapes.clear()
	for target: Control in _touch_controls:
		target.visible = value
	if value:
		gameplay_action_requested.emit(TOUCH_NEUTRAL_FORM)
