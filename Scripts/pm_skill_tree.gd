extends Control

# === ЦВЕТА ===
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_GRAY = Color(0.7, 0.7, 0.7, 1)
const COLOR_LOCKED = Color(0.85, 0.85, 0.85, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_DARK = Color(0.2, 0.2, 0.2, 1)
const COLOR_TEAL = Color(0.0, 0.6, 0.65, 1)

# === РАЗМЕРЫ ===
const NODE_SIZE = Vector2(180, 80)
const NODE_SPACING_X = 220
const NODE_SPACING_Y = 130
const CENTER_NODE_SIZE = Vector2(100, 100)

# === НОДЫ ===
@onready var close_btn = find_child("CloseButton", true, false)

var _scroll: ScrollContainer
var _canvas: Control
var _xp_label: Label
var _sp_label: Label
var _tooltip_panel: PanelContainer = null
var _skill_nodes: Dictionary = {}
var _initialized: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if close_btn:
		close_btn.pressed.connect(func():
			if UITheme:
				UITheme.fade_out(self, 0.15)
			else:
				visible = false
		)
		if UITheme: UITheme.apply_font(close_btn, "semibold")

	call_deferred("_deferred_init")

func _deferred_init():
	if PMData == null:
		get_tree().create_timer(0.1).timeout.connect(_deferred_init)
		return

	if not PMData.xp_changed.is_connected(_update_header):
		PMData.xp_changed.connect(_update_header)
	if not PMData.skill_unlocked.is_connected(_on_skill_unlocked_rebuild):
		PMData.skill_unlocked.connect(_on_skill_unlocked_rebuild)

	_build_ui()
	_initialized = true

func _on_skill_unlocked_rebuild(_id):
	_rebuild_tree()

func open():
	if not _initialized:
		return
	_rebuild_tree()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _build_ui():
	var window = get_node_or_null("Window")
	if not window:
		return

	var main_vbox = window.get_node_or_null("MainVBox")
	if not main_vbox:
		return

	var header = main_vbox.get_node_or_null("Header")
	if header:
		var header_margin = header.get_node_or_null("MarginContainer")
		if not header_margin:
			header_margin = header

		var hbox = null
		for child in header_margin.get_children():
			if child is HBoxContainer:
				hbox = child
				break

		if not hbox:
			hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 20)
			header_margin.add_child(hbox)

		_xp_label = Label.new()
		_xp_label.add_theme_color_override("font_color", COLOR_BLUE)
		_xp_label.add_theme_font_size_override("font_size", 14)
		if UITheme: UITheme.apply_font(_xp_label, "semibold")
		hbox.add_child(_xp_label)

		_sp_label = Label.new()
		_sp_label.add_theme_color_override("font_color", COLOR_GREEN)
		_sp_label.add_theme_font_size_override("font_size", 14)
		if UITheme: UITheme.apply_font(_sp_label, "bold")
		hbox.add_child(_sp_label)

	var scroll_path = "CardsMargin/ScrollContainer"
	_scroll = main_vbox.get_node_or_null(scroll_path)
	if not _scroll:
		for child in main_vbox.get_children():
			if child is MarginContainer:
				for sub in child.get_children():
					if sub is ScrollContainer:
						_scroll = sub
						break

	if _scroll:
		for child in _scroll.get_children():
			child.queue_free()

		_canvas = Control.new()
		_canvas.custom_minimum_size = Vector2(1600, 850)
		_scroll.add_child(_canvas)

	_update_header()

func _update_header():
	if PMData == null:
		return
	if _xp_label:
		var next_threshold = _get_next_threshold()
		if next_threshold > 0:
			_xp_label.text = "XP: %d / %d" % [PMData.xp, next_threshold]
		else:
			_xp_label.text = "XP: %d (MAX)" % PMData.xp
	if _sp_label:
		_sp_label.text = "🧠 Очков навыков: %d" % PMData.skill_points

func _get_next_threshold() -> int:
	if PMData == null:
		return -1
	var idx = PMData._last_threshold_index + 1
	if idx < PMData.XP_THRESHOLDS.size():
		return PMData.XP_THRESHOLDS[idx]
	return -1

# === ПОСТРОЕНИЕ ДЕРЕВА ===

func _rebuild_tree():
	if PMData == null:
		return
	if not _canvas:
		return

	for child in _canvas.get_children():
		child.queue_free()
	_skill_nodes.clear()

	_update_header()

	var center = Vector2(_canvas.custom_minimum_size.x / 2.0, 240)

	var center_node = _create_center_node()
	center_node.position = center - CENTER_NODE_SIZE / 2.0
	_canvas.add_child(center_node)

	_place_branch("estimate_work", center, -1, 0)
	_place_branch("estimate_budget", center, -1, 1)
	_place_branch("read_traits", center, 1, 0)
	_place_branch("read_skills", center, 1, 1)

	_place_analytics_branch(center)
	_draw_connections(center)

	_add_zone_label("📋 ПРОЕКТЫ", center + Vector2(-NODE_SPACING_X * 2, -NODE_SPACING_Y - 50))
	_add_zone_label("👥 ЛЮДИ", center + Vector2(NODE_SPACING_X * 2, -NODE_SPACING_Y - 50))
	_add_zone_label("📊 АНАЛИТИКА", center + Vector2(0, NODE_SPACING_Y + 120), COLOR_TEAL)

	_add_branch_label("Оценка объёма", center, -1, 0)
	_add_branch_label("Оценка бюджета", center, -1, 1)
	_add_branch_label("Чтение людей", center, 1, 0)
	_add_branch_label("Оценка кадров", center, 1, 1)

func _place_branch(branch_id: String, center: Vector2, dir_x: int, branch_index: int):
	var y_offset = -NODE_SPACING_Y / 2.0 + branch_index * NODE_SPACING_Y

	var branch_skills = []
	for skill_id in PMData.SKILL_TREE:
		var skill = PMData.SKILL_TREE[skill_id]
		if skill["branch"] == branch_id:
			branch_skills.append({"id": skill_id, "order": skill["branch_order"]})
	branch_skills.sort_custom(func(a, b): return a["order"] < b["order"])

	for i in range(branch_skills.size()):
		var skill_id = branch_skills[i]["id"]
		var x = center.x + dir_x * NODE_SPACING_X * (i + 1) - NODE_SIZE.x / 2.0
		var y = center.y + y_offset - NODE_SIZE.y / 2.0

		var node = _create_skill_node(skill_id)
		node.position = Vector2(x, y)
		_canvas.add_child(node)
		_skill_nodes[skill_id] = node

func _place_analytics_branch(center: Vector2):
	var analytics_ids = ["report_expenses", "report_projects", "report_productivity"]
	var fan_x_offsets = [-NODE_SPACING_X, 0, NODE_SPACING_X]
	var y_pos = center.y + NODE_SPACING_Y * 1.3

	for i in range(analytics_ids.size()):
		var skill_id = analytics_ids[i]
		var x = center.x + fan_x_offsets[i] - NODE_SIZE.x / 2.0
		var y = y_pos - NODE_SIZE.y / 2.0

		var node = _create_skill_node(skill_id, COLOR_TEAL)
		node.position = Vector2(x, y)
		_canvas.add_child(node)
		_skill_nodes[skill_id] = node

func _add_branch_label(text: String, center: Vector2, dir_x: int, branch_index: int):
	var y_offset = -NODE_SPACING_Y / 2.0 + branch_index * NODE_SPACING_Y
	var x = center.x + dir_x * NODE_SPACING_X * 0.5
	var y = center.y + y_offset - NODE_SIZE.y / 2.0 - 18

	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(COLOR_BLUE, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(x - 50, y)
	if UITheme: UITheme.apply_font(lbl, "regular")
	_canvas.add_child(lbl)

func _create_center_node() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = CENTER_NODE_SIZE

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BLUE
	style.corner_radius_top_left = 50
	style.corner_radius_top_right = 50
	style.corner_radius_bottom_right = 50
	style.corner_radius_bottom_left = 50
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0, 0, 0, 0.3)
	if UITheme: UITheme.apply_shadow(style, false)
	panel.add_theme_stylebox_override("panel", style)

	var lbl = Label.new()
	lbl.text = "🧑‍💼\nPM"
	lbl.add_theme_color_override("font_color", COLOR_WHITE)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(lbl, "bold")
	panel.add_child(lbl)

	return panel

func _create_skill_node(skill_id: String, accent_color: Color = COLOR_BLUE) -> PanelContainer:
	var skill = PMData.SKILL_TREE[skill_id]
	var is_unlocked = PMData.has_skill(skill_id)
	var can_unlock = PMData.can_unlock(skill_id)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = NODE_SIZE

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3

	if is_unlocked:
		style.bg_color = Color(0.92, 0.97, 0.92, 1)
		style.border_color = COLOR_GREEN
	elif can_unlock:
		style.bg_color = Color(0.95, 0.97, 1.0, 1)
		style.border_color = accent_color
	else:
		style.bg_color = COLOR_LOCKED
		style.border_color = Color(0.6, 0.6, 0.6, 1)

	if UITheme: UITheme.apply_shadow(style)
	panel.add_theme_stylebox_override("panel", style)

	# Hover — подсветка рамки
	var style_hover = style.duplicate()
	if is_unlocked:
		style_hover.border_color = Color(0.2, 0.6, 0.25, 1)
		style_hover.bg_color = Color(0.88, 0.95, 0.88, 1)
	elif can_unlock:
		style_hover.border_color = Color(accent_color.r * 0.8, accent_color.g * 0.8, accent_color.b * 1.2, 1)
		style_hover.bg_color = Color(0.92, 0.95, 1.0, 1)
	else:
		style_hover.border_color = Color(0.5, 0.5, 0.5, 1)
		style_hover.bg_color = Color(0.82, 0.82, 0.82, 1)
	if UITheme: UITheme.apply_shadow(style_hover, false)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_entered.connect(func():
		panel.add_theme_stylebox_override("panel", style_hover)
	)
	panel.mouse_exited.connect(func():
		panel.add_theme_stylebox_override("panel", style)
	)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var title_lbl = Label.new()
	title_lbl.text = skill["name"]
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if is_unlocked:
		title_lbl.add_theme_color_override("font_color", COLOR_GREEN)
		title_lbl.text = "✅ " + title_lbl.text
	elif can_unlock:
		title_lbl.add_theme_color_override("font_color", accent_color)
	else:
		title_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))

	if UITheme: UITheme.apply_font(title_lbl, "semibold")
	vbox.add_child(title_lbl)

	if not is_unlocked:
		var cost_lbl = Label.new()
		cost_lbl.text = "🧠 " + str(skill["cost"]) + " очк."
		cost_lbl.add_theme_font_size_override("font_size", 11)
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		if UITheme: UITheme.apply_font(cost_lbl, "regular")
		vbox.add_child(cost_lbl)

	if can_unlock:
		var btn = Button.new()
		btn.text = "Изучить"
		btn.custom_minimum_size = Vector2(120, 28)
		btn.focus_mode = Control.FOCUS_NONE

		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = accent_color
		btn_style.corner_radius_top_left = 10
		btn_style.corner_radius_top_right = 10
		btn_style.corner_radius_bottom_right = 10
		btn_style.corner_radius_bottom_left = 10

		var btn_style_hover = btn_style.duplicate()
		btn_style_hover.bg_color = Color(accent_color.r * 0.85, accent_color.g * 0.85, accent_color.b * 0.85, 1)

		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_style_hover)
		btn.add_theme_stylebox_override("pressed", btn_style_hover)
		btn.add_theme_color_override("font_color", COLOR_WHITE)
		btn.add_theme_font_size_override("font_size", 12)
		if UITheme: UITheme.apply_font(btn, "semibold")
		btn.pressed.connect(_on_skill_pressed.bind(skill_id))
		vbox.add_child(btn)

	panel.mouse_entered.connect(_show_tooltip.bind(skill_id, panel))
	panel.mouse_exited.connect(_hide_tooltip)

	return panel

func _add_zone_label(text: String, pos: Vector2, color: Color = COLOR_BLUE):
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(color, 0.4))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = pos - Vector2(80, 0)
	if UITheme: UITheme.apply_font(lbl, "bold")
	_canvas.add_child(lbl)

# === ЛИНИИ СВЯЗЕЙ С СТРЕЛКАМИ ===
func _draw_connections(center: Vector2):
	for skill_id in _skill_nodes:
		var skill = PMData.SKILL_TREE[skill_id]
		var node_ctrl = _skill_nodes[skill_id]
		var node_center = node_ctrl.position + NODE_SIZE / 2.0

		var from_pos: Vector2
		if skill["prerequisite"] == "":
			from_pos = center
		else:
			var prereq_ctrl = _skill_nodes.get(skill["prerequisite"])
			if prereq_ctrl:
				from_pos = prereq_ctrl.position + NODE_SIZE / 2.0
			else:
				from_pos = center

		var is_unlocked = PMData.has_skill(skill_id)
		var prereq_ok = skill["prerequisite"] == "" or PMData.has_skill(skill["prerequisite"])
		var is_analytics = skill["direction"] == "analytics_down"

		var line_color: Color
		if is_unlocked:
			line_color = COLOR_GREEN
		elif prereq_ok:
			line_color = COLOR_TEAL if is_analytics else COLOR_BLUE
		else:
			line_color = COLOR_GRAY

		var is_locked = not is_unlocked and not prereq_ok

		_draw_arrow_line(from_pos, node_center, line_color, is_locked)

func _draw_arrow_line(from: Vector2, to: Vector2, color: Color, dashed: bool = false):
	var direction = (to - from).normalized()
	var length = from.distance_to(to)

	if dashed:
		var dash_len = 12.0
		var gap_len = 8.0
		var current = 0.0
		while current < length:
			var seg_start = from + direction * current
			var seg_end_dist = min(current + dash_len, length)
			var seg_end = from + direction * seg_end_dist
			var seg = Line2D.new()
			seg.add_point(seg_start)
			seg.add_point(seg_end)
			seg.width = 2.0
			seg.default_color = Color(color, 0.4)
			seg.z_index = -1
			_canvas.add_child(seg)
			current += dash_len + gap_len
	else:
		var line = Line2D.new()
		line.add_point(from)
		line.add_point(to)
		line.width = 3.0
		line.default_color = color
		line.z_index = -1
		_canvas.add_child(line)

	# Стрелка на конце
	var arrow_size = 10.0
	var arrow_tip = to - direction * 20
	var perp = Vector2(-direction.y, direction.x)

	var p1 = arrow_tip
	var p2 = arrow_tip - direction * arrow_size + perp * arrow_size * 0.5
	var p3 = arrow_tip - direction * arrow_size - perp * arrow_size * 0.5

	var arrow_color = Color(color, 0.4) if dashed else color

	var arrow = Polygon2D.new()
	arrow.polygon = PackedVector2Array([p1, p2, p3])
	arrow.color = arrow_color
	arrow.z_index = -1
	_canvas.add_child(arrow)

# === КНОПКИ ===
func _on_skill_pressed(skill_id: String):
	if PMData == null:
		return
	PMData.unlock_skill(skill_id)

# === ТУЛТИП ===
func _show_tooltip(skill_id: String, anchor: Control):
	_hide_tooltip()

	if PMData == null:
		return

	var skill = PMData.SKILL_TREE[skill_id]

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.z_index = 300
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_WHITE
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BLUE
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	_tooltip_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_tooltip_panel.add_child(margin)

	var lbl = Label.new()
	lbl.text = skill["description"]
	lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(260, 0)
	if UITheme: UITheme.apply_font(lbl, "regular")
	margin.add_child(lbl)

	add_child(_tooltip_panel)
	_tooltip_panel.global_position = anchor.global_position + Vector2(0, -80)

func _hide_tooltip():
	if _tooltip_panel and is_instance_valid(_tooltip_panel):
		_tooltip_panel.queue_free()
	_tooltip_panel = null
