## Persistent, device-neutral action bindings.  Defaults stay in project.godot;
## only user overrides are written to the profile so upgrading defaults is safe.
class_name InputBindingStore
extends RefCounted

const ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"shape_cube", &"shape_pyramid", &"shape_sphere",
	&"pause_game", &"restart_run", &"ui_accept", &"ui_cancel",
]

var _defaults: Dictionary = {}


func capture_defaults() -> void:
	_defaults.clear()
	for action: StringName in ACTIONS:
		_defaults[action] = _clone_events(InputMap.action_get_events(action))


func restore(profile: ProfileStore) -> void:
	if _defaults.is_empty():
		capture_defaults()
	var saved: Dictionary = profile.input_bindings
	for action: StringName in ACTIONS:
		var events: Array[InputEvent] = []
		if saved.has(String(action)) and saved[String(action)] is Array:
			for encoded: Variant in saved[String(action)]:
				var event := event_from_data(encoded)
				if event != null:
					events.append(event)
		if events.is_empty():
			events = _clone_events(_defaults.get(action, []))
		_apply_events(action, events)
	ensure_recovery(profile)


func save(profile: ProfileStore) -> void:
	var saved := {}
	for action: StringName in ACTIONS:
		var encoded: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			var data := event_to_data(event)
			if not data.is_empty():
				encoded.append(data)
		saved[String(action)] = encoded
	profile.input_bindings = saved
	profile.save_profile()


func reset_defaults(profile: ProfileStore, persist := true) -> void:
	if _defaults.is_empty():
		capture_defaults()
	for action: StringName in ACTIONS:
		_apply_events(action, _clone_events(_defaults.get(action, [])))
	profile.input_bindings = {}
	if persist:
		profile.save_profile()


func bind(action: StringName, event: InputEvent, profile: ProfileStore, swap_conflict := true, persist := true) -> Dictionary:
	if not ACTIONS.has(action) or event == null:
		return {"ok": false, "reason": "invalid"}
	var conflicts := conflicts_for(action, event)
	if not conflicts.is_empty() and not swap_conflict:
		return {"ok": false, "reason": "conflict", "actions": conflicts}
	var incoming := event.duplicate()
	var target_events := _clone_events(InputMap.action_get_events(action))
	var displaced: InputEvent = target_events[0].duplicate() if not target_events.is_empty() else null
	# A real swap moves the target's primary event away; retaining it on the target
	# would merely trade the incoming conflict for a new duplicate.
	if displaced != null:
		target_events = target_events.filter(func(candidate: InputEvent) -> bool: return not events_match(candidate, displaced))
	target_events = target_events.filter(func(candidate: InputEvent) -> bool: return not events_match(candidate, incoming))
	for conflict_index: int in conflicts.size():
		var other: StringName = conflicts[conflict_index]
		var other_events := _clone_events(InputMap.action_get_events(other))
		other_events = other_events.filter(func(candidate: InputEvent) -> bool: return not events_match(candidate, incoming))
		if conflict_index == 0 and displaced != null and not other_events.any(func(candidate: InputEvent) -> bool: return events_match(candidate, displaced)):
			other_events.push_front(displaced.duplicate())
		_apply_events(other, other_events)
	target_events.push_front(incoming)
	_apply_events(action, target_events)
	ensure_recovery(profile)
	if persist:
		save(profile)
	return {"ok": true, "swapped": conflicts}


func conflicts_for(action: StringName, event: InputEvent) -> Array[StringName]:
	var conflicts: Array[StringName] = []
	for candidate_action: StringName in ACTIONS:
		if candidate_action == action:
			continue
		for existing: InputEvent in InputMap.action_get_events(candidate_action):
			if events_match(existing, event):
				conflicts.append(candidate_action)
				break
	return conflicts


func readable_binding(action: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "UNBOUND"
	var keyboard := ""
	var controller := ""
	for event: InputEvent in events:
		if keyboard.is_empty() and event is InputEventKey:
			keyboard = event.as_text().replace(" (Physical)", "")
		elif controller.is_empty() and event is InputEventJoypadButton:
			controller = _joy_button_label(event.button_index)
		elif controller.is_empty() and event is InputEventJoypadMotion:
			controller = _joy_axis_label(event.axis, event.axis_value)
	var labels: Array[String] = []
	if not keyboard.is_empty():
		labels.append(keyboard)
	if not controller.is_empty():
		labels.append(controller)
	return " / ".join(labels) if not labels.is_empty() else events[0].as_text()


static func _joy_button_label(button: int) -> String:
	const NAMES := {
		0: "PAD A / SOUTH", 1: "PAD B / EAST", 2: "PAD X / WEST", 3: "PAD Y / NORTH",
		4: "PAD BACK", 6: "PAD START", 9: "PAD L1", 10: "PAD R1",
		11: "DPAD UP", 12: "DPAD DOWN", 13: "DPAD LEFT", 14: "DPAD RIGHT",
	}
	return NAMES.get(button, "PAD BUTTON %d" % button)


static func _joy_axis_label(axis: int, value: float) -> String:
	if axis == JOY_AXIS_LEFT_X:
		return "LEFT STICK %s" % ("LEFT" if value < 0.0 else "RIGHT")
	return "PAD AXIS %d %s" % [axis, "-" if value < 0.0 else "+"]


func ensure_recovery(profile: ProfileStore) -> void:
	if _defaults.is_empty():
		capture_defaults()
	for action: StringName in ACTIONS:
		if InputMap.action_get_events(action).is_empty():
			_apply_events(action, _clone_events(_defaults.get(action, [])))


static func events_match(a: InputEvent, b: InputEvent) -> bool:
	return event_to_data(a) == event_to_data(b)


static func event_to_data(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"kind": "key", "keycode": event.keycode, "physical": event.physical_keycode, "shift": event.shift_pressed, "alt": event.alt_pressed, "ctrl": event.ctrl_pressed, "meta": event.meta_pressed}
	if event is InputEventJoypadButton:
		return {"kind": "button", "button": event.button_index}
	if event is InputEventJoypadMotion:
		return {"kind": "axis", "axis": event.axis, "value": signf(event.axis_value)}
	return {}


static func event_from_data(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	match String(data.get("kind", "")):
		"key":
			var key := InputEventKey.new()
			key.keycode = int(data.get("keycode", 0))
			key.physical_keycode = int(data.get("physical", 0))
			key.shift_pressed = bool(data.get("shift", false))
			key.alt_pressed = bool(data.get("alt", false))
			key.ctrl_pressed = bool(data.get("ctrl", false))
			key.meta_pressed = bool(data.get("meta", false))
			return key
		"button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(data.get("button", 0))
			return button
		"axis":
			var axis := InputEventJoypadMotion.new()
			axis.axis = int(data.get("axis", 0))
			axis.axis_value = float(data.get("value", 1.0))
			return axis
	return null


func _apply_events(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


func _clone_events(events: Array) -> Array[InputEvent]:
	var cloned: Array[InputEvent] = []
	for event: InputEvent in events:
		cloned.append(event.duplicate())
	return cloned
