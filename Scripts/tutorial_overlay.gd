extends Control

# ===================================================
# === TUTORIAL OVERLAY ==============================
# ===================================================
# Shows tutorial cards, task panel (top-right), and
# arrow marker pointing to the current target.
# Visual style matches tutorial.gd (COLOR_BLUE, etc.)

# === ЦВЕТА (как в проекте) ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_WINDOW_BORDER = Color(0, 0, 0, 1)

# Task panel
var _task_panel: PanelContainer
var _task_label: Label

# Arrow marker
var _arrow_label: Label

# Card window (reused for each step card)
var _card_overlay: ColorRect
var _card_window: PanelContainer
var _card_emoji: Label
var _card_text: RichTextLabel
var _card_btn: Button
var _card_visible: bool = false

# Target node for arrow
var _arrow_target: Node = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 95
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_build_task_panel()
	_build_arrow()
	_build_card_ui()

	TutorialManager.tutorial_step_changed.connect(_on_step_changed)
	TutorialManager.tutorial_completed.connect(_on_tutorial_completed)

func open():
	visible = true
	_update_for_step(TutorialManager.current_step)

func close():
	visible = false
	_hide_card()
	_task_panel.visible = false
	_arrow_label.visible = false

# ─── Task panel ────────────────────────────────────

func _build_task_panel():
	_task_panel = PanelContainer.new()
	_task_panel.custom_minimum_size = Vector2(300, 50)
	_task_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_task_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_task_panel.grow_vertical = Control.GROW_DIRECTION_END
	_task_panel.offset_left = -320
	_task_panel.offset_top = 65
	_task_panel.offset_right = -20
	_task_panel.offset_bottom = 115

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_WHITE
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = COLOR_BORDER
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.corner_radius_bottom_left = 20
	if UITheme:
		UITheme.apply_shadow(panel_style)
	_task_panel.add_theme_stylebox_override("panel", panel_style)
	_task_panel.visible = false
	add_child(_task_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	_task_panel.add_child(margin)

	_task_label = Label.new()
	_task_label.text = ""
	_task_label.add_theme_color_override("font_color", COLOR_DARK)
	_task_label.add_theme_font_size_override("font_size", 14)
	_task_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(_task_label, "semibold")
	margin.add_child(_task_label)

func _set_task_text(key: String):
	if _task_label:
		_task_label.text = tr(key)
	if _task_panel:
		_task_panel.visible = true

# ─── Arrow marker ──────────────────────────────────

func _build_arrow():
	_arrow_label = Label.new()
	_arrow_label.add_theme_font_size_override("font_size", 36)
	_arrow_label.add_theme_color_override("font_color", COLOR_BLUE)
	_arrow_label.z_index = 96
	_arrow_label.visible = false
	_arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arrow_label)

func _set_arrow_target(node: Node):
	_arrow_target = node
	_arrow_label.visible = (node != null)

func _process(_delta):
	if not visible:
		return
	_update_arrow()

func _update_arrow():
	if _arrow_target == null or not is_instance_valid(_arrow_target):
		_arrow_label.visible = false
		return
	if not _arrow_label.visible:
		return

	var target_pos: Vector2
	if _arrow_target is Node2D:
		target_pos = _arrow_target.global_position
	elif _arrow_target is Control:
		target_pos = _arrow_target.global_position + _arrow_target.size / 2
	else:
		_arrow_label.visible = false
		return

	var viewport = get_viewport()
	if not viewport:
		return
	var canvas_transform = viewport.get_canvas_transform()
	var screen_pos: Vector2 = canvas_transform * target_pos

	var viewport_size = viewport.get_visible_rect().size
	var margin := 40.0

	var target_on_screen = (
		screen_pos.x >= margin and screen_pos.x <= viewport_size.x - margin and
		screen_pos.y >= margin and screen_pos.y <= viewport_size.y - margin
	)

	if target_on_screen:
		# Arrow above target on screen
		_arrow_label.text = "▼"
		_arrow_label.position = screen_pos + Vector2(-18, -60)
	else:
		# Directional arrow at screen edge
		var center = viewport_size / 2.0
		var dir = (screen_pos - center).normalized()
		var angle = dir.angle()

		# Pick arrow character based on angle
		var deg = rad_to_deg(angle)
		if deg < -135 or deg > 135:
			_arrow_label.text = "◀"
		elif deg < -45:
			_arrow_label.text = "▲"
		elif deg > 45:
			_arrow_label.text = "▼"
		else:
			_arrow_label.text = "▶"

		# Clamp position to screen edges
		var edge_pos = _clamp_to_edge(screen_pos, viewport_size, margin)
		_arrow_label.position = edge_pos

func _clamp_to_edge(target: Vector2, vp_size: Vector2, margin: float) -> Vector2:
	var center = vp_size / 2.0
	var dir = (target - center)
	var scale_x = (vp_size.x / 2.0 - margin) / abs(dir.x) if abs(dir.x) > 0.001 else INF
	var scale_y = (vp_size.y / 2.0 - margin) / abs(dir.y) if abs(dir.y) > 0.001 else INF
	var scale = min(scale_x, scale_y)
	return center + dir * scale

# ─── Card UI ───────────────────────────────────────

func _build_card_ui():
	# Overlay
	_card_overlay = ColorRect.new()
	_card_overlay.color = Color(0, 0, 0, 0.5)
	_card_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_overlay.visible = false
	add_child(_card_overlay)

	# Window: 620×420
	_card_window = PanelContainer.new()
	_card_window.custom_minimum_size = Vector2(620, 420)
	_card_window.set_anchors_preset(Control.PRESET_CENTER)
	_card_window.offset_left = -310
	_card_window.offset_top = -210
	_card_window.offset_right = 310
	_card_window.offset_bottom = 210
	_card_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card_window.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card_window.visible = false

	var window_style = StyleBoxFlat.new()
	window_style.bg_color = COLOR_WHITE
	window_style.border_width_left = 3
	window_style.border_width_top = 3
	window_style.border_width_right = 3
	window_style.border_width_bottom = 3
	window_style.border_color = COLOR_WINDOW_BORDER
	window_style.corner_radius_top_left = 22
	window_style.corner_radius_top_right = 22
	window_style.corner_radius_bottom_right = 20
	window_style.corner_radius_bottom_left = 20
	if UITheme:
		UITheme.apply_shadow(window_style, false)
	_card_window.add_theme_stylebox_override("panel", window_style)
	add_child(_card_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_card_window.add_child(main_vbox)

	# Header
	var header_panel = Panel.new()
	header_panel.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_BLUE
	header_style.border_color = COLOR_WINDOW_BORDER
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header_panel.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header_panel)

	var title_label = Label.new()
	title_label.text = tr("TUT_TITLE")
	title_label.set_anchors_preset(Control.PRESET_CENTER)
	title_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_label.offset_left = -150
	title_label.offset_top = -11.5
	title_label.offset_right = 150
	title_label.offset_bottom = 11.5
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COLOR_WHITE)
	title_label.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(title_label, "bold")
	header_panel.add_child(title_label)

	# Content
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 30)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_right", 30)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(content_margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 12)
	content_margin.add_child(content_vbox)

	# Boss emoji
	_card_emoji = Label.new()
	_card_emoji.text = "😤"
	_card_emoji.add_theme_font_size_override("font_size", 42)
	_card_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(_card_emoji)

	# Subtitle
	var boss_hint = Label.new()
	boss_hint.text = tr("TUT_BOSS_SAYS")
	boss_hint.add_theme_color_override("font_color", COLOR_GRAY)
	boss_hint.add_theme_font_size_override("font_size", 13)
	boss_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(boss_hint, "regular")
	content_vbox.add_child(boss_hint)

	# Card text
	_card_text = RichTextLabel.new()
	_card_text.bbcode_enabled = false
	_card_text.fit_content = true
	_card_text.scroll_active = false
	_card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_text.add_theme_color_override("default_color", COLOR_DARK)
	_card_text.add_theme_font_size_override("normal_font_size", 15)
	if UITheme:
		UITheme.apply_font(_card_text, "regular")
	content_vbox.add_child(_card_text)

	# Bottom: button
	var bottom_margin = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 30)
	bottom_margin.add_theme_constant_override("margin_right", 30)
	bottom_margin.add_theme_constant_override("margin_bottom", 20)
	bottom_margin.add_theme_constant_override("margin_top", 5)
	main_vbox.add_child(bottom_margin)

	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 10)
	bottom_margin.add_child(bottom_hbox)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	# "Got it" button
	_card_btn = Button.new()
	_card_btn.text = tr("TUT_BTN_UNDERSTOOD")
	_card_btn.custom_minimum_size = Vector2(200, 44)
	_card_btn.focus_mode = Control.FOCUS_NONE

	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = COLOR_WHITE
	btn_style_normal.border_width_left = 2
	btn_style_normal.border_width_top = 2
	btn_style_normal.border_width_right = 2
	btn_style_normal.border_width_bottom = 2
	btn_style_normal.border_color = COLOR_BLUE
	btn_style_normal.corner_radius_top_left = 20
	btn_style_normal.corner_radius_top_right = 20
	btn_style_normal.corner_radius_bottom_right = 20
	btn_style_normal.corner_radius_bottom_left = 20

	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = COLOR_BLUE
	btn_style_hover.border_width_left = 2
	btn_style_hover.border_width_top = 2
	btn_style_hover.border_width_right = 2
	btn_style_hover.border_width_bottom = 2
	btn_style_hover.border_color = COLOR_BLUE
	btn_style_hover.corner_radius_top_left = 20
	btn_style_hover.corner_radius_top_right = 20
	btn_style_hover.corner_radius_bottom_right = 20
	btn_style_hover.corner_radius_bottom_left = 20

	_card_btn.add_theme_stylebox_override("normal", btn_style_normal)
	_card_btn.add_theme_stylebox_override("hover", btn_style_hover)
	_card_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	_card_btn.add_theme_color_override("font_color", COLOR_BLUE)
	_card_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	_card_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	_card_btn.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(_card_btn, "bold")

	_card_btn.pressed.connect(_on_card_btn_pressed)
	bottom_hbox.add_child(_card_btn)

func _show_card(text_key: String, pause_game: bool = true):
	_card_text.text = tr(text_key)
	_card_overlay.visible = true
	_card_window.visible = true
	_card_visible = true
	if pause_game:
		GameTime.is_game_paused = true
	if UITheme:
		UITheme.fade_in(_card_window, 0.2)

func _hide_card():
	_card_overlay.visible = false
	_card_window.visible = false
	_card_visible = false

func _on_card_btn_pressed():
	_hide_card()
	GameTime.is_game_paused = false
	_after_card_closed()

# Called after the "Understood" button is pressed on a card
var _pending_after_card: Callable = Callable()

func _after_card_closed():
	if _pending_after_card.is_valid():
		_pending_after_card.call()
		_pending_after_card = Callable()

# ─── Step handling ─────────────────────────────────

func _on_step_changed(step: int):
	_update_for_step(step)

func _on_tutorial_completed():
	close()

func _update_for_step(step: int):
	match step:
		TutorialManager.Step.STEP_1_MOVE_TO_BOSS:
			_set_task_text("TUT_TASK_GO_TO_BOSS")
			var boss = get_tree().get_first_node_in_group("boss_desk")
			_set_arrow_target(boss)
			# Show opening card (game paused)
			_show_card("TUT_STEP1_CARD", true)
			# After understood → unpause at 1x
			_pending_after_card = func():
				GameTime.speed_1x()

		TutorialManager.Step.STEP_2_TAKE_PROJECT:
			_set_task_text("TUT_TASK_TAKE_PROJECT")
			var boss = get_tree().get_first_node_in_group("boss_desk")
			_set_arrow_target(boss)
			_show_card("TUT_STEP2_CARD", false)
			_pending_after_card = Callable()

		TutorialManager.Step.STEP_3_WAIT_MEETING:
			_set_task_text("TUT_TASK_WAIT_MEETING")
			_set_arrow_target(null)
			# auto-speed to 10x happens in hud.gd

		TutorialManager.Step.STEP_4_GO_TO_HR:
			_set_task_text("TUT_TASK_GO_TO_HR")
			var hr = get_tree().get_first_node_in_group("hr_desk")
			_set_arrow_target(hr)
			_show_card("TUT_STEP3_CARD", false)

		TutorialManager.Step.STEP_5_HIRE_BA:
			_set_task_text("TUT_TASK_PICK_BA")
			var hr = get_tree().get_first_node_in_group("hr_desk")
			_set_arrow_target(hr)
			_show_card("TUT_STEP4_CARD", false)

		TutorialManager.Step.STEP_6_SEAT_WORKER:
			_set_task_text("TUT_TASK_SEAT_WORKER")
			# Point to nearest free desk
			var free_desk = _find_free_desk()
			_set_arrow_target(free_desk)
			_show_card("TUT_STEP5_HIRE_DONE", false)

		TutorialManager.Step.STEP_7_ASSIGN_DESK:
			_set_task_text("TUT_TASK_SEAT_WORKER")
			var free_desk = _find_free_desk()
			_set_arrow_target(free_desk)
			_show_card("TUT_STEP7_DESK_HINT", false)

		TutorialManager.Step.STEP_8_GO_TO_PM_DESK:
			_set_task_text("TUT_TASK_GO_TO_PM_DESK")
			var pm_desk = get_tree().get_first_node_in_group("pm_desk")
			_set_arrow_target(pm_desk)
			_show_card("TUT_STEP8_CARD", false)

		TutorialManager.Step.STEP_9_START_PROJECT:
			_set_task_text("TUT_TASK_START_PROJECT")
			var pm_desk = get_tree().get_first_node_in_group("pm_desk")
			_set_arrow_target(pm_desk)
			_show_card("TUT_STEP9_CARD", false)

		TutorialManager.Step.STEP_10_END_DAY:
			_set_task_text("TUT_TASK_END_DAY")
			_set_arrow_target(null)
			# card shown after end day button click (from hud.gd)

func show_end_day_card():
	_show_card("TUT_STEP10_CARD", false)
	# After press — tutorial completed signal fires from TutorialManager
	_pending_after_card = Callable()

# ─── Helpers ───────────────────────────────────────

func _find_free_desk() -> Node:
	var desks = get_tree().get_nodes_in_group("desk")
	var player = get_tree().get_first_node_in_group("player")
	var best: Node = null
	var best_dist: float = INF
	for d in desks:
		# Skip computer desk (pm_desk group)
		if d.is_in_group("pm_desk"):
			continue
		if "assigned_employee" in d and d.assigned_employee == null:
			if player:
				var dist = player.global_position.distance_to(d.global_position)
				if dist < best_dist:
					best_dist = dist
					best = d
			else:
				return d
	return best
