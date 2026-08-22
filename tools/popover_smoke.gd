## Deterministic layout/style contract for the reusable centered popover system.
## Run: Godot --headless --path . --script res://tools/popover_smoke.gd
extends SceneTree

const HUD_SCRIPT := preload("res://src/ui/hud_controller.gd")
const PROFILE_SCRIPT := preload("res://src/core/profile_store.gd")
const BINDINGS_SCRIPT := preload("res://src/core/input_binding_store.gd")
const POPOVER_SCENE := preload("res://scenes/ui/neon_popover.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		printerr("[FAIL] %s" % label)


func _run() -> void:
	# Exercise the compact 16:9 floor even when the shipping project uses 4:3.
	# This prevents the 960px-tall authoring viewport from masking overflow.
	var reference_viewport := SubViewport.new()
	reference_viewport.size = Vector2i(1280, 720)
	get_root().add_child(reference_viewport)
	var authored_hud := HUD_SCENE.instantiate() as CanvasLayer
	_expect(authored_hud != null, "editor-openable HUD scene instantiates as CanvasLayer")
	if authored_hud != null:
		_expect(authored_hud.popover_scene == POPOVER_SCENE, "HUD scene references the editable popover PackedScene")
		_expect(authored_hud.popover_theme != null and authored_hud.popover_theme.resource_path == "res://assets/ui/neon_popover_theme.tres", "HUD scene references the editable neon theme")
		authored_hud.queue_free()
	var authored := POPOVER_SCENE.instantiate() as PanelContainer
	_expect(authored != null, "popover shell instantiates as an editor-openable PanelContainer")
	if authored != null:
		_expect(authored.get_node_or_null("%Title") is Label, "popover shell exposes stable Title node")
		_expect(authored.get_node_or_null("%Subtitle") is Label, "popover shell exposes stable Subtitle node")
		_expect(authored.get_node_or_null("%Content") is VBoxContainer, "popover shell exposes stable Content node")
		_expect(authored.get_node_or_null("FrameStack/TopAccent/CyanRail") is ColorRect, "popover shell exposes cyan edge rail")
		_expect(authored.get_node_or_null("FrameStack/BottomAccent/MagentaRail") is ColorRect, "popover shell exposes magenta edge rail")
		authored.queue_free()

	var profile := PROFILE_SCRIPT.new()
	var bindings := BINDINGS_SCRIPT.new()
	bindings.capture_defaults()
	var hud := HUD_SCRIPT.new()
	hud.name = "PopoverSmokeHUD"
	reference_viewport.add_child(hud)
	hud.setup(profile, bindings)
	await process_frame
	await process_frame

	var panels: Array[PanelContainer] = [hud.ready_panel, hud.pause_panel, hud.results_panel, hud.settings_panel, hud.controls_panel]
	for active: PanelContainer in panels:
		for panel: PanelContainer in panels:
			panel.visible = panel == active
		await process_frame
		_expect(is_equal_approx(active.anchor_left, 0.5) and is_equal_approx(active.anchor_right, 0.5), "%s is horizontally center-anchored" % active.name)
		_expect(is_equal_approx(active.anchor_top, 0.5) and is_equal_approx(active.anchor_bottom, 0.5), "%s is vertically center-anchored" % active.name)
		var viewport_center := reference_viewport.get_visible_rect().size * 0.5
		_expect(active.get_global_rect().get_center().distance_to(viewport_center) <= 0.5, "%s remains pixel-centered" % active.name)
		_expect(active.size.x <= 680.0 and active.size.y <= 700.0, "%s fits the 1280x720 reference viewport with a safe visual margin" % active.name)
		print("[METRIC] popover=%s size=%s center=%s" % [active.name, str(active.size), str(active.get_global_rect().get_center())])
		var title := active.get_node("%Title") as Label
		var subtitle := active.get_node("%Subtitle") as Label
		_expect(title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s title is centered" % active.name)
		_expect(subtitle.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s copy is centered" % active.name)
		var panel_style := active.get_theme_stylebox("panel") as StyleBoxFlat
		_expect(panel_style != null and panel_style.bg_color.a >= 0.9, "%s uses opaque-enough dark glass" % active.name)
		_expect(panel_style != null and panel_style.border_color.b > panel_style.border_color.r, "%s uses a cyan panel edge" % active.name)
		for candidate: Node in active.find_children("*", "Button", true, false):
			var button := candidate as Button
			_expect(button.alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s/%s text is centered" % [active.name, button.name])
			_expect(button.focus_mode == Control.FOCUS_ALL, "%s/%s is controller-focusable" % [active.name, button.name])
			_expect(button.custom_minimum_size.y >= 36.0, "%s/%s meets the compact touch target contract" % [active.name, button.name])
			var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
			var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
			_expect(normal != null and focus != null and not normal.border_color.is_equal_approx(focus.border_color), "%s/%s has a distinct focus state" % [active.name, button.name])
		for candidate: Node in active.find_children("*", "HBoxContainer", true, false):
			var row := candidate as HBoxContainer
			if row.has_meta("centered_popover_row"):
				_expect(row.alignment == BoxContainer.ALIGNMENT_CENTER, "%s/%s row is centered" % [active.name, row.name])
				_expect(row.size_flags_horizontal == Control.SIZE_SHRINK_CENTER, "%s/%s row shrinks symmetrically" % [active.name, row.name])

	_expect(hud.score_card.get_parent() == hud, "active score HUD remains independent from modal theme")
	_expect(hud.popover_scrim.mouse_filter == Control.MOUSE_FILTER_IGNORE, "popover scrim never steals touch/controller input")
	hud.queue_free()
	await process_frame
	reference_viewport.queue_free()
	if _failures.is_empty():
		print("POPOVER_SMOKE_PASS checks=%d panels=%d" % [_checks, panels.size()])
		quit(0)
		return
	printerr("POPOVER_SMOKE_FAIL checks=%d failures=%d" % [_checks, _failures.size()])
	quit(1)
