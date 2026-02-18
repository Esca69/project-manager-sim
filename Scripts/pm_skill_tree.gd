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
const NODE_H_GAP = 30         # Горизонтальный отступ между нодами в цепочке
const ROW_V_GAP = 20          # Вертикальный отступ между рядами (цепочками)
const CATEGORY_GAP = 30       # Отступ между категориями
const LEFT_MARGIN = 40        # Отступ слева
const TOP_MARGIN = 20         # Отступ сверху

# === НОДЫ ===
@onready var close_btn = find_child("CloseButton", true, false)

var _scroll: ScrollContainer
var _canvas: Control
var _xp_label: Label
var _sp_label: Label
var _tooltip_panel: PanelContainer = null
var _skill_nodes: Dictionary = {}
var _initialized: bool = false

# === ОПРЕДЕЛЕНИЕ КАТЕГОРИЙ И ИХ ПОРЯДКА ===
const CATEGORIES = [
	{
		"id": "projects",
		"label": "📋 ПРОЕКТЫ",
		"color": COLOR_BLUE,
		"branches": ["estimate_work", "estimate_budget", "project_limit", "boss_meeting_speed"],
	},
	{
		"id": "people",
		"label": "👥 ЛЮДИ",
		"color": COLOR_BLUE,
		"branches": ["read_traits", "read_skills", "candidate_count", "hr_search_speed"],
	},
	{
		"id": "analytics",
		"label": "📊 АНАЛИТИКА",
		"color": COLOR_TEAL,
		"branches": ["report_expenses", "report_projects", "report_productivity"],
	},
]

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
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		for child in _scroll.get_children():
			child.queue_free()

		_canvas = Control.new()
		_canvas.custom_minimum_size = Vector2(800, 600)
		_scroll.add_child(_canvas)

	_update_header()

func _update_header(_new_xp = 0, _new_sp = 0):
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

	var cursor_y = TOP_MARGIN

	for cat_data in CATEGORIES:
		var cat_id = cat_data["id"]
		var cat_label = cat_data["label"]
		var cat_color = cat_data["color"]
		var cat_branches = cat_data["branches"]

		# --- Заголовок категории ---
		var cat_lbl = Label.new()
		cat_lbl.text = cat_label
		cat_lbl.add_theme_font_size_override("font_size", 18)
		cat_lbl.add_theme_color_override("font_color", Color(cat_color, 0.6))
		if UITheme: UITheme.apply_font(cat_lbl, "bold")
		cat_lbl.position = Vector2(LEFT_MARGIN, cursor_y)
		_canvas.add_child(cat_lbl)
		cursor_y += 32

		# --- Ряды навыков внутри категории ---
		var is_analytics = (cat_id == "analytics")

		if is_analytics:
			# Аналитика: все 3 навыка в одну горизонтальную линию без стрелок
			var x = LEFT_MARGIN
			for branch_id in cat_branches:
				var branch_skills = _get_branch_skills(branch_id)
				for skill_entry in branch_skills:
					var skill_id = skill_entry["id"]
					var node = _create_skill_node(skill_id, COLOR_TEAL)
					node.position = Vector2(x, cursor_y)
					_canvas.add_child(node)
					_skill_nodes[skill_id] = node
					x += NODE_SIZE.x + NODE_H_GAP
			cursor_y += NODE_SIZE.y + ROW_V_GAP
		else:
			# Обычные ветки: каждая ветка — горизонтальный ряд со стрелками
			for branch_id in cat_branches:
				var branch_skills = _get_branch_skills(branch_id)
				if branch_skills.is_empty():
					continue

				var x = LEFT_MARGIN
				var prev_skill_id = ""

				for skill_entry in branch_skills:
					var skill_id = skill_entry["id"]
					var node = _create_skill_node(skill_id, cat_color)
					node.position = Vector2(x, cursor_y)
					_canvas.add_child(node)
					_skill_nodes[skill_id] = node

					# Стрелка от предыдущего навыка
					if prev_skill_id != "":
						var prev_node = _skill_nodes[prev_skill_id]
						var from_pos = prev_node.position + Vector2(NODE_SIZE.x, NODE_SIZE.y / 2.0)
						var to_pos = node.position + Vector2(0, NODE_SIZE.y / 2.0)
						var is_unlocked = PMData.has_skill(skill_id)
						var prereq_ok = PMData.has_skill(prev_skill_id)
						var line_color: Color
						if is_unlocked:
							line_color = COLOR_GREEN
						elif prereq_ok:
							line_color = cat_color
						else:
							line_color = COLOR_GRAY
						var is_locked = not is_unlocked and not prereq_ok
						_draw_arrow_line(from_pos, to_pos, line_color, is_locked)

					prev_skill_id = skill_id
					x += NODE_SIZE.x + NODE_H_GAP

				cursor_y += NODE_SIZE.y + ROW_V_GAP

		# --- Разделитель между категориями ---
		cursor_y += CATEGORY_GAP
		var sep = ColorRect.new()
		sep.color = Color(0.85, 0.85, 0.85, 0.5)
		sep.position = Vector2(LEFT_MARGIN, cursor_y - CATEGORY_GAP / 2.0)
		sep.size = Vector2(700, 1)
		_canvas.add_child(sep)

	# Обновляем размер канваса
	_canvas.custom_minimum_size = Vector2(800, cursor_y + 40)

func _get_branch_skills(branch_id: String) -> Array:
	var result = []
	for skill_id in PMData.SKILL_TREE:
		var skill = PMData.SKILL_TREE[skill_id]
		if skill["branch"] == branch_id:
			result.append({"id": skill_id, "order": skill["branch_order"]})
	result.sort_custom(func(a, b): return a["order"] < b["order"])
	return result

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

# === СТРЕЛКИ ===
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
	var arrow_tip = to - direction * 5
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
