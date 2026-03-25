extends Control

# === PEOPLE REPORTS TAB ===
# Contains employee analytics widgets displayed in a scrollable VBox

const COLOR_BLUE   = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN  = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED    = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE = Color(1.0, 0.55, 0.0, 1)
const COLOR_GRAY   = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK   = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE  = Color(1, 1, 1, 1)

const PERIOD_WEEK    = 1
const PERIOD_MONTH   = 2
const PERIOD_QUARTER = 3
const PERIOD_YEAR    = 4
const PERIOD_ALL     = 5

var _selected_period: int = PERIOD_WEEK
var _period_buttons: Array = []

# Employee selector dropdown
var _employee_dropdown: OptionButton
# Current employee name selected ("" = whole team)
var _selected_employee: String = ""

# Team summary KPI container
var _kpi_container: HBoxContainer

# Salary vs Output table container
var _svo_filter_btn: OptionButton
var _svo_table_vbox: VBoxContainer

# Health timeline chart
var _health_graph: Control

# Leaderboard containers
var _leaderboard_vbox: VBoxContainer

# Employee card container
var _card_vbox: VBoxContainer
var _card_graph: Control
# Wrapper card for the card section
var _card_section: PanelContainer
# Wrapper card for the team sections
var _team_sections: VBoxContainer

func _ready():
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_build_ui()

func _build_ui():
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# Period selector
	vbox.add_child(_build_period_selector())

	# Employee selector dropdown
	vbox.add_child(_build_employee_selector())

	# === Team-level sections ===
	_team_sections = VBoxContainer.new()
	_team_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_sections.add_theme_constant_override("separation", 16)
	vbox.add_child(_team_sections)

	_team_sections.add_child(_build_summary_card())
	_team_sections.add_child(_build_svo_card())
	_team_sections.add_child(_build_health_card())
	_team_sections.add_child(_build_leaderboard_card())

	# === Employee card section ===
	_card_section = _build_employee_card()
	_card_section.visible = false
	vbox.add_child(_card_section)

func refresh():
	_populate_employee_dropdown()
	_on_period_selected(_selected_period)

# =========================================================
#  PERIOD SELECTOR
# =========================================================

func _build_period_selector() -> Control:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var lbl = Label.new()
	lbl.text = tr("REPORTS_PEOPLE_PERIOD")
	lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	hbox.add_child(lbl)

	var periods = [
		[tr("REPORTS_PERIOD_WEEK"),    PERIOD_WEEK],
		[tr("REPORTS_PERIOD_MONTH"),   PERIOD_MONTH],
		[tr("REPORTS_PERIOD_QUARTER"), PERIOD_QUARTER],
		[tr("REPORTS_PERIOD_YEAR"),    PERIOD_YEAR],
		[tr("REPORTS_PERIOD_ALL"),     PERIOD_ALL],
	]

	_period_buttons.clear()
	for p in periods:
		var btn = Button.new()
		btn.text = p[0]
		btn.custom_minimum_size = Vector2(90, 28)
		btn.focus_mode = Control.FOCUS_NONE
		var code = p[1]
		btn.pressed.connect(func(): _on_period_selected(code))
		_period_buttons.append({"btn": btn, "code": code})
		_style_period_btn(btn, code == _selected_period)
		if UITheme: UITheme.apply_font(btn, "semibold")
		hbox.add_child(btn)

	return margin

func _style_period_btn(btn: Button, active: bool):
	var s = StyleBoxFlat.new()
	s.bg_color = COLOR_BLUE if active else Color(1, 1, 1, 1)
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.border_color = COLOR_BLUE
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6; s.corner_radius_bottom_left = 6
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_color_override("font_color", COLOR_WHITE if active else COLOR_BLUE)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE if active else COLOR_BLUE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE if active else COLOR_BLUE)

func _on_period_selected(code: int):
	_selected_period = code
	for entry in _period_buttons:
		_style_period_btn(entry["btn"], entry["code"] == code)
	_refresh_all()

# =========================================================
#  EMPLOYEE SELECTOR DROPDOWN
# =========================================================

func _build_employee_selector() -> Control:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var lbl = Label.new()
	lbl.text = tr("REPORTS_PEOPLE_TEAM_VIEW") + ":"
	lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	hbox.add_child(lbl)

	_employee_dropdown = OptionButton.new()
	_employee_dropdown.custom_minimum_size = Vector2(240, 32)
	_employee_dropdown.focus_mode = Control.FOCUS_NONE
	_style_option_button(_employee_dropdown)
	_employee_dropdown.item_selected.connect(_on_employee_selected)
	hbox.add_child(_employee_dropdown)

	return margin

func _populate_employee_dropdown():
	if not _employee_dropdown:
		return
	_employee_dropdown.clear()
	_employee_dropdown.add_item(tr("REPORTS_PEOPLE_TEAM_VIEW"), 0)
	var npcs = get_tree().get_nodes_in_group("npc")
	var idx = 1
	for npc in npcs:
		if not npc.data:
			continue
		var name_str = npc.data.get_display_name() if npc.data.has_method("get_display_name") else str(npc.data.employee_name)
		_employee_dropdown.add_item(name_str, idx)
		idx += 1
	# Restore selection if possible
	if _selected_employee == "":
		_employee_dropdown.selected = 0
	else:
		var found = false
		for i in range(_employee_dropdown.item_count):
			if _employee_dropdown.get_item_text(i) == _selected_employee:
				_employee_dropdown.selected = i
				found = true
				break
		if not found:
			_selected_employee = ""
			_employee_dropdown.selected = 0

func _on_employee_selected(index: int):
	if index == 0:
		_selected_employee = ""
	else:
		_selected_employee = _employee_dropdown.get_item_text(index)
	_update_view_mode()

func _update_view_mode():
	var team_mode = (_selected_employee == "")
	_team_sections.visible = team_mode
	_card_section.visible = not team_mode
	if not team_mode:
		_refresh_employee_card()

# =========================================================
#  PERIOD HELPERS
# =========================================================

func _get_period_bounds(period_code: int, ref_day: int) -> Array:
	match period_code:
		PERIOD_WEEK:
			var wn = GameTime.get_week_number(ref_day)
			return [GameTime.get_week_start_day(wn), GameTime.get_week_end_day(wn)]
		PERIOD_MONTH:
			var mn = GameTime.get_month(ref_day)
			return [GameTime.get_month_start_day(mn), GameTime.get_month_end_day(mn)]
		PERIOD_QUARTER:
			var qn = GameTime.get_quarter(ref_day)
			return [GameTime.get_quarter_start_day(qn), GameTime.get_quarter_end_day(qn)]
		PERIOD_YEAR:
			var yn = GameTime.get_year(ref_day)
			return [GameTime.get_year_start_day(yn), GameTime.get_year_end_day(yn)]
		PERIOD_ALL:
			return [1, ref_day]
	return [1, ref_day]

func _get_filtered_records() -> Array:
	var all = PeopleHistory.daily_records
	if all.is_empty():
		return []
	var bounds = _get_period_bounds(_selected_period, GameTime.day)
	var start_day = bounds[0]
	var end_day   = min(bounds[1], GameTime.day)
	var result = []
	for r in all:
		var d = int(r.get("day", 0))
		if d >= start_day and d <= end_day:
			result.append(r)
	return result

# =========================================================
#  REFRESH ALL
# =========================================================

func _refresh_all():
	_refresh_summary()
	_refresh_svo()
	if _health_graph:
		_health_graph.queue_redraw()
	_refresh_leaderboard()
	if not (_selected_employee == ""):
		_refresh_employee_card()

# =========================================================
#  BLOCK 1: TEAM SUMMARY
# =========================================================

func _build_summary_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_SUMMARY_TITLE")))
	_kpi_container = HBoxContainer.new()
	_kpi_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kpi_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_kpi_container)
	return card

func _refresh_summary():
	if not _kpi_container:
		return
	for c in _kpi_container.get_children():
		c.queue_free()

	var npcs = get_tree().get_nodes_in_group("npc")
	var total = 0
	var contractors = 0
	var freelancers = 0
	var payroll = 0
	var total_mood = 0.0
	var total_burnout = 0.0
	var total_tenure = 0

	var role_counts: Dictionary = {}
	var role_salary: Dictionary = {}

	for npc in npcs:
		if not npc.data:
			continue
		var d = npc.data
		total += 1
		payroll += int(d.monthly_salary)
		total_mood    += float(d.mood)
		total_burnout += float(d.burnout_level)
		total_tenure  += int(d.days_in_company)

		var et = str(d.employment_type)
		if et == "contractor":
			contractors += 1
		elif et == "freelancer":
			freelancers += 1

		var jt = str(d.job_title)
		role_counts[jt] = role_counts.get(jt, 0) + 1
		if not role_salary.has(jt):
			role_salary[jt] = []
		role_salary[jt].append(int(d.monthly_salary))

	var count = max(total, 1)
	var avg_mood    = total_mood    / count
	var avg_burnout = total_burnout / count
	var avg_tenure  = float(total_tenure) / count

	var mood_color    = COLOR_GREEN if avg_mood    > 60 else (COLOR_ORANGE if avg_mood    >= 40 else COLOR_RED)
	var burnout_color = COLOR_GREEN if avg_burnout < 20 else (COLOR_ORANGE if avg_burnout <= 50 else COLOR_RED)

	# Role counts string
	var role_str = ""
	for role in role_counts:
		if role_str != "":
			role_str += " / "
		var short = _shorten_role(role)
		role_str += "%s: %d" % [short, role_counts[role]]
	if role_str == "":
		role_str = "—"

	# Avg salary per role
	var avg_sal_str = ""
	for role in role_salary:
		var sals = role_salary[role]
		var avg_s = 0.0
		for s in sals:
			avg_s += s
		avg_s /= max(sals.size(), 1)
		if avg_sal_str != "":
			avg_sal_str += "\n"
		var short = _shorten_role(role)
		avg_sal_str += "%s: $%s" % [short, _format_money(int(avg_s))]
	if avg_sal_str == "":
		avg_sal_str = "—"

	var kpis = [
		{"icon": "👥", "label": tr("REPORTS_PEOPLE_TOTAL"),      "value": str(total),        "color": COLOR_DARK},
		{"icon": "📊", "label": tr("REPORTS_PEOPLE_AVG_SALARY"), "value": avg_sal_str,        "color": COLOR_BLUE},
		{"icon": "💼", "label": tr("REPORTS_PEOPLE_CONTRACTORS"),"value": str(contractors),   "color": COLOR_DARK},
		{"icon": "🧑‍💻","label": tr("REPORTS_PEOPLE_FREELANCERS"), "value": str(freelancers),   "color": COLOR_DARK},
		{"icon": "💰", "label": tr("REPORTS_PEOPLE_PAYROLL"),    "value": "$" + _format_money(payroll), "color": COLOR_BLUE},
		{"icon": "😊", "label": tr("REPORTS_PEOPLE_AVG_MOOD"),   "value": "%.0f" % avg_mood,  "color": mood_color},
		{"icon": "🔥", "label": tr("REPORTS_PEOPLE_AVG_BURNOUT"),"value": "%.0f" % avg_burnout,"color": burnout_color},
		{"icon": "📅", "label": tr("REPORTS_PEOPLE_AVG_TENURE"), "value": "%.0f" % avg_tenure,"color": COLOR_DARK},
	]

	for kpi in kpis:
		_kpi_container.add_child(_build_kpi_item(kpi))

func _shorten_role(role: String) -> String:
	if "Developer" in role or "Backend" in role or "developer" in role:
		return "Dev"
	if "Designer" in role or "designer" in role:
		return "Des"
	if "QA" in role or "Tester" in role or "tester" in role:
		return "QA"
	if "Analyst" in role or "analyst" in role:
		return "BA"
	return role.substr(0, min(role.length(), 6))

func _build_kpi_item(kpi: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.border_width_left = 1; style.border_width_top = 1
	style.border_width_right = 1; style.border_width_bottom = 1
	style.border_color = Color(0.88, 0.88, 0.88, 1)
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8; style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)

	var inner = MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 10)
	inner.add_theme_constant_override("margin_top", 8)
	inner.add_theme_constant_override("margin_right", 10)
	inner.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(inner)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	inner.add_child(vbox)

	var head_lbl = Label.new()
	head_lbl.text = kpi["icon"] + " " + kpi["label"]
	head_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	head_lbl.add_theme_font_size_override("font_size", 11)
	if UITheme: UITheme.apply_font(head_lbl, "regular")
	vbox.add_child(head_lbl)

	var val_lbl = Label.new()
	val_lbl.text = str(kpi["value"])
	val_lbl.add_theme_color_override("font_color", kpi["color"])
	val_lbl.add_theme_font_size_override("font_size", 14)
	if UITheme: UITheme.apply_font(val_lbl, "semibold")
	vbox.add_child(val_lbl)

	return panel

# =========================================================
#  BLOCK 2: SALARY VS OUTPUT
# =========================================================

func _build_svo_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_SALARY_VS_OUTPUT")))

	# Role filter
	var filter_hbox = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(filter_hbox)
	var filter_lbl = Label.new()
	filter_lbl.text = tr("REPORTS_PEOPLE_COL_ROLE") + ":"
	filter_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	filter_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(filter_lbl, "regular")
	filter_hbox.add_child(filter_lbl)

	_svo_filter_btn = OptionButton.new()
	_svo_filter_btn.custom_minimum_size = Vector2(160, 28)
	_svo_filter_btn.focus_mode = Control.FOCUS_NONE
	_svo_filter_btn.add_item(tr("REPORTS_PEOPLE_FILTER_ALL"), 0)
	_style_option_button(_svo_filter_btn)
	_svo_filter_btn.item_selected.connect(func(_i): _refresh_svo())
	filter_hbox.add_child(_svo_filter_btn)

	_svo_table_vbox = VBoxContainer.new()
	_svo_table_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_svo_table_vbox.add_theme_constant_override("separation", 0)
	vbox.add_child(_svo_table_vbox)

	return card

func _refresh_svo():
	if not _svo_table_vbox:
		return
	for c in _svo_table_vbox.get_children():
		c.queue_free()

	var records = _get_filtered_records()

	# Gather all unique roles from current npcs to populate filter
	var all_roles: Array = []
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if not npc.data:
			continue
		var jt = str(npc.data.job_title)
		if not jt in all_roles:
			all_roles.append(jt)

	# Populate filter dropdown if needed
	if _svo_filter_btn and _svo_filter_btn.item_count == 1:
		for role in all_roles:
			_svo_filter_btn.add_item(role)

	var filter_role = ""
	if _svo_filter_btn and _svo_filter_btn.selected > 0:
		filter_role = _svo_filter_btn.get_item_text(_svo_filter_btn.selected)

	# Per-employee stats from history
	var emp_stats: Dictionary = {}
	for r in records:
		for emp in r.get("employees", []):
			var ename = str(emp.get("name", ""))
			if filter_role != "" and str(emp.get("job_title", "")) != filter_role:
				continue
			if not emp_stats.has(ename):
				emp_stats[ename] = {
					"job_title": str(emp.get("job_title", "")),
					"daily_salary": float(emp.get("daily_salary", 0.0)),
					"total_progress": 0.0,
					"total_work_minutes": 0.0,
					"days": 0,
				}
			emp_stats[ename]["total_progress"]     += float(emp.get("progress", 0.0))
			emp_stats[ename]["total_work_minutes"]  += float(emp.get("work_minutes", 0.0))
			emp_stats[ename]["days"] += 1

	if emp_stats.is_empty():
		_svo_table_vbox.add_child(_make_no_data_label())
		return

	# Build sorted rows
	var rows: Array = []
	for ename in emp_stats:
		var s = emp_stats[ename]
		var days = max(s["days"], 1)
		var avg_progress = s["total_progress"] / days
		var avg_hours    = (s["total_work_minutes"] / days) / 60.0
		var daily_sal    = s["daily_salary"]
		var efficiency   = avg_progress / max(daily_sal, 0.01)
		rows.append({
			"name": ename,
			"job_title": s["job_title"],
			"daily_salary": daily_sal,
			"avg_progress": avg_progress,
			"avg_hours": avg_hours,
			"efficiency": efficiency,
		})

	rows.sort_custom(func(a, b): return a["efficiency"] > b["efficiency"])

	# Determine ROI tiers
	var n = rows.size()
	var top_n    = max(1, int(ceil(float(n) / 3.0)))
	var bottom_n = max(1, int(ceil(float(n) / 3.0)))

	# Header row
	_svo_table_vbox.add_child(_build_svo_header())

	for i in range(rows.size()):
		var row = rows[i]
		var roi_color: Color
		if i < top_n:
			roi_color = COLOR_GREEN
		elif i >= n - bottom_n:
			roi_color = COLOR_RED
		else:
			roi_color = COLOR_ORANGE
		var is_even = (i % 2 == 0)
		_svo_table_vbox.add_child(_build_svo_row(i + 1, row, roi_color, is_even))

func _build_svo_header() -> HBoxContainer:
	var hbox = _make_table_row(Color(COLOR_BLUE.r, COLOR_BLUE.g, COLOR_BLUE.b, 0.1))
	var cols = [
		tr("REPORTS_PEOPLE_COL_RANK"),
		tr("REPORTS_PEOPLE_COL_NAME"),
		tr("REPORTS_PEOPLE_COL_ROLE"),
		tr("REPORTS_PEOPLE_COL_SALARY_DAY"),
		tr("REPORTS_PEOPLE_COL_PROGRESS_DAY"),
		tr("REPORTS_PEOPLE_COL_HOURS_DAY"),
		tr("REPORTS_PEOPLE_COL_EFFICIENCY"),
		tr("REPORTS_PEOPLE_COL_ROI"),
	]
	var widths = [30, 160, 120, 80, 100, 90, 90, 50]
	for ci in range(cols.size()):
		var lbl = Label.new()
		lbl.text = cols[ci]
		lbl.add_theme_color_override("font_color", COLOR_BLUE)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.custom_minimum_size = Vector2(widths[ci], 0)
		if UITheme: UITheme.apply_font(lbl, "bold")
		hbox.add_child(lbl)
	return hbox

func _build_svo_row(rank: int, row: Dictionary, roi_color: Color, is_even: bool) -> HBoxContainer:
	var bg_color = Color(1, 1, 1, 1) if is_even else Color(0.96, 0.97, 0.99, 1)
	var hbox = _make_table_row(bg_color)
	var values = [
		str(rank),
		str(row["name"]),
		str(row["job_title"]),
		"$%.2f" % row["daily_salary"],
		"%.1f" % row["avg_progress"],
		"%.1f" % row["avg_hours"],
		"%.3f" % row["efficiency"],
		"●",
	]
	var colors = [COLOR_GRAY, COLOR_DARK, COLOR_GRAY, COLOR_DARK, COLOR_GREEN, COLOR_BLUE, COLOR_DARK, roi_color]
	var widths = [30, 160, 120, 80, 100, 90, 90, 50]
	for ci in range(values.size()):
		var lbl = Label.new()
		lbl.text = values[ci]
		lbl.add_theme_color_override("font_color", colors[ci])
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.custom_minimum_size = Vector2(widths[ci], 0)
		if UITheme: UITheme.apply_font(lbl, "regular" if ci > 0 else "semibold")
		hbox.add_child(lbl)
	return hbox

func _make_table_row(bg: Color) -> HBoxContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	panel.add_theme_stylebox_override("panel", s)
	var inner = MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 8)
	inner.add_theme_constant_override("margin_top", 4)
	inner.add_theme_constant_override("margin_right", 8)
	inner.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(inner)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	inner.add_child(hbox)
	return hbox

# =========================================================
#  BLOCK 3: TEAM HEALTH TIMELINE
# =========================================================

func _build_health_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_HEALTH_TITLE")))

	_health_graph = Control.new()
	_health_graph.custom_minimum_size = Vector2(0, 200)
	_health_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_graph.draw.connect(_draw_health_graph.bind(_health_graph))
	vbox.add_child(_health_graph)

	# Legend
	var legend_items = [
		{"label": tr("REPORTS_PEOPLE_HEALTH_MOOD"),    "color": COLOR_BLUE},
		{"label": tr("REPORTS_PEOPLE_HEALTH_BURNOUT"), "color": COLOR_RED},
	]
	vbox.add_child(_make_legend(legend_items))

	return card

func _draw_health_graph(ctrl: Control):
	var records = _get_filtered_records()
	var w = ctrl.size.x
	var h = ctrl.size.y
	var pad_left   = 40.0
	var pad_right  = 20.0
	var pad_top    = 16.0
	var pad_bottom = 30.0
	var gw = w - pad_left - pad_right
	var gh = h - pad_top - pad_bottom

	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 60, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_GRAY)
		return

	# Grid lines 0..100
	var grid_color = Color(0.88, 0.88, 0.88, 1)
	var n_lines = 5
	for i in range(n_lines + 1):
		var frac = float(i) / float(n_lines)
		var gy = pad_top + frac * gh
		ctrl.draw_line(Vector2(pad_left, gy), Vector2(pad_left + gw, gy), grid_color, 1)
		var val_at = int(100.0 - frac * 100.0)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 5), str(val_at), HORIZONTAL_ALIGNMENT_LEFT, pad_left - 4, 10, COLOR_GRAY)

	var n = records.size()

	# Helper to build points for a metric
	var _build_pts = func(key: String) -> PackedVector2Array:
		var pts: PackedVector2Array = []
		for i in range(n):
			var val = clampf(float(records[i].get(key, 0.0)), 0.0, 100.0)
			var px = pad_left + (float(i) / max(n - 1, 1)) * gw
			var py = pad_top + gh * (1.0 - val / 100.0)
			pts.append(Vector2(px, py))
		return pts

	var mood_pts    = _build_pts.call("avg_mood")
	var burnout_pts = _build_pts.call("avg_burnout")

	ctrl.draw_polyline(mood_pts,    COLOR_BLUE,  2.0, true)
	ctrl.draw_polyline(burnout_pts, COLOR_RED,   2.0, true)

	for p in mood_pts:    ctrl.draw_circle(p, 3.0, COLOR_BLUE)
	for p in burnout_pts: ctrl.draw_circle(p, 3.0, COLOR_RED)

	# X-axis labels
	var step = max(1, int(ceil(float(n) / 10.0)))
	for i in range(0, n, step):
		var px = pad_left + (float(i) / max(n - 1, 1)) * gw
		var day_num = int(records[i].get("day", i + 1))
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px - 8, h - 6), str(day_num), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRAY)

# =========================================================
#  BLOCK 4: LEADERBOARD
# =========================================================

func _build_leaderboard_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_LEADERBOARD_TITLE")))

	_leaderboard_vbox = VBoxContainer.new()
	_leaderboard_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_leaderboard_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_leaderboard_vbox)

	return card

func _refresh_leaderboard():
	if not _leaderboard_vbox:
		return
	for c in _leaderboard_vbox.get_children():
		c.queue_free()

	var records = _get_filtered_records()

	# Aggregate per employee
	var emp_stats: Dictionary = {}
	for r in records:
		for emp in r.get("employees", []):
			var ename = str(emp.get("name", ""))
			if not emp_stats.has(ename):
				emp_stats[ename] = {"total_progress": 0.0, "total_work_minutes": 0.0, "total_mood": 0.0, "days": 0}
			emp_stats[ename]["total_progress"]     += float(emp.get("progress", 0.0))
			emp_stats[ename]["total_work_minutes"]  += float(emp.get("work_minutes", 0.0))
			emp_stats[ename]["total_mood"]          += float(emp.get("mood", 0.0))
			emp_stats[ename]["days"] += 1

	if emp_stats.is_empty():
		_leaderboard_vbox.add_child(_make_no_data_label())
		return

	# Build sorted list
	var sorted_names = emp_stats.keys()
	sorted_names.sort_custom(func(a, b): return emp_stats[a]["total_progress"] > emp_stats[b]["total_progress"])

	var n = sorted_names.size()

	# Determine split sizes
	var top_n: int
	var bot_n: int
	if n == 1:
		top_n = 0; bot_n = 0
	elif n == 2:
		top_n = 1; bot_n = 1
	elif n <= 5:
		top_n = int(ceil(float(n) / 2.0))
		bot_n = n - top_n
	else:
		top_n = min(3, n)
		bot_n = min(3, n)

	if n == 1:
		# Show single list
		var all_lbl = _make_title(tr("REPORTS_PEOPLE_ALL_EMPLOYEES"))
		_leaderboard_vbox.add_child(all_lbl)
		_leaderboard_vbox.add_child(_build_leaderboard_header())
		for i in range(n):
			var ename = sorted_names[i]
			var s = emp_stats[ename]
			var avg_mood = s["total_mood"] / max(s["days"], 1)
			_leaderboard_vbox.add_child(_build_leaderboard_row(i + 1, ename, s["total_progress"], s["total_work_minutes"] / 60.0, avg_mood, Color(0.9, 0.98, 0.9, 1)))
		return

	# Top performers
	var top_lbl = _make_title(tr("REPORTS_PEOPLE_TOP_PERFORMERS"))
	top_lbl.add_theme_color_override("font_color", COLOR_GREEN)
	_leaderboard_vbox.add_child(top_lbl)
	_leaderboard_vbox.add_child(_build_leaderboard_header())
	for i in range(top_n):
		var ename = sorted_names[i]
		var s = emp_stats[ename]
		var avg_mood = s["total_mood"] / max(s["days"], 1)
		_leaderboard_vbox.add_child(_build_leaderboard_row(i + 1, ename, s["total_progress"], s["total_work_minutes"] / 60.0, avg_mood, Color(0.9, 1.0, 0.9, 1)))

	# Red flags
	var red_lbl = _make_title(tr("REPORTS_PEOPLE_RED_FLAGS"))
	red_lbl.add_theme_color_override("font_color", COLOR_RED)
	_leaderboard_vbox.add_child(red_lbl)
	_leaderboard_vbox.add_child(_build_leaderboard_header())
	for i in range(bot_n):
		var idx = n - bot_n + i
		var ename = sorted_names[idx]
		var s = emp_stats[ename]
		var avg_mood = s["total_mood"] / max(s["days"], 1)
		_leaderboard_vbox.add_child(_build_leaderboard_row(idx + 1, ename, s["total_progress"], s["total_work_minutes"] / 60.0, avg_mood, Color(1.0, 0.92, 0.92, 1)))

func _build_leaderboard_header() -> HBoxContainer:
	var hbox = _make_table_row(Color(COLOR_BLUE.r, COLOR_BLUE.g, COLOR_BLUE.b, 0.1))
	var cols = [
		tr("REPORTS_PEOPLE_COL_RANK"),
		tr("REPORTS_PEOPLE_COL_NAME"),
		tr("REPORTS_PEOPLE_COL_PROGRESS_TOTAL"),
		tr("REPORTS_PEOPLE_COL_HOURS_TOTAL"),
		tr("REPORTS_PEOPLE_COL_AVG_MOOD"),
	]
	var widths = [30, 200, 150, 120, 100]
	for ci in range(cols.size()):
		var lbl = Label.new()
		lbl.text = cols[ci]
		lbl.add_theme_color_override("font_color", COLOR_BLUE)
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.custom_minimum_size = Vector2(widths[ci], 0)
		if UITheme: UITheme.apply_font(lbl, "bold")
		hbox.add_child(lbl)
	return hbox

func _build_leaderboard_row(rank: int, name: String, progress: float, hours: float, avg_mood: float, bg: Color) -> HBoxContainer:
	var hbox = _make_table_row(bg)
	var values = [
		str(rank),
		name,
		"%.1f" % progress,
		"%.1f" % hours,
		"%.0f" % avg_mood,
	]
	var colors = [COLOR_GRAY, COLOR_DARK, COLOR_GREEN, COLOR_BLUE, COLOR_DARK]
	var widths = [30, 200, 150, 120, 100]
	for ci in range(values.size()):
		var lbl = Label.new()
		lbl.text = values[ci]
		lbl.add_theme_color_override("font_color", colors[ci])
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.custom_minimum_size = Vector2(widths[ci], 0)
		if UITheme: UITheme.apply_font(lbl, "regular")
		hbox.add_child(lbl)
	return hbox

# =========================================================
#  BLOCK 6: EMPLOYEE CARD
# =========================================================

func _build_employee_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)

	_card_vbox = VBoxContainer.new()
	_card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(_card_vbox)

	_card_vbox.add_child(_make_title(tr("REPORTS_PEOPLE_EMPLOYEE_CARD")))

	# Placeholder content — populated by _refresh_employee_card
	return card

func _refresh_employee_card():
	if not _card_vbox:
		return
	# Clear everything except the title
	var children = _card_vbox.get_children()
	for i in range(1, children.size()):
		children[i].queue_free()

	if _selected_employee == "":
		return

	# Find NPC
	var emp_npc = null
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if not npc.data:
			continue
		var dname = npc.data.get_display_name() if npc.data.has_method("get_display_name") else str(npc.data.employee_name)
		if dname == _selected_employee:
			emp_npc = npc
			break

	if not emp_npc:
		_card_vbox.add_child(_make_no_data_label())
		return

	var d = emp_npc.data

	# === Header ===
	var name_lbl = Label.new()
	name_lbl.text = _selected_employee
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	_card_vbox.add_child(name_lbl)

	var meta_hbox = HBoxContainer.new()
	meta_hbox.add_theme_constant_override("separation", 16)
	_card_vbox.add_child(meta_hbox)

	var role_lbl = Label.new()
	role_lbl.text = tr("REPORTS_PEOPLE_CARD_ROLE") + " " + str(d.job_title)
	role_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	role_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(role_lbl, "regular")
	meta_hbox.add_child(role_lbl)

	var grade_name = d.get_grade_name() if d.has_method("get_grade_name") else ""
	if grade_name != "":
		var grade_lbl = Label.new()
		grade_lbl.text = grade_name
		grade_lbl.add_theme_color_override("font_color", COLOR_BLUE)
		grade_lbl.add_theme_font_size_override("font_size", 12)
		if UITheme: UITheme.apply_font(grade_lbl, "semibold")
		meta_hbox.add_child(grade_lbl)

	var type_lbl = Label.new()
	type_lbl.text = tr("REPORTS_PEOPLE_CARD_TYPE") + " " + str(d.employment_type)
	type_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	type_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(type_lbl, "regular")
	meta_hbox.add_child(type_lbl)

	var tenure_lbl = Label.new()
	tenure_lbl.text = tr("REPORTS_PEOPLE_CARD_TENURE") + " %d %s" % [int(d.days_in_company), tr("REPORTS_PEOPLE_CARD_DAYS")]
	tenure_lbl.add_theme_color_override("font_color", COLOR_GRAY)
	tenure_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(tenure_lbl, "regular")
	meta_hbox.add_child(tenure_lbl)

	var salary_lbl = Label.new()
	salary_lbl.text = tr("REPORTS_PEOPLE_CARD_SALARY") + " $%s%s" % [_format_money(int(d.monthly_salary)), tr("REPORTS_PEOPLE_CARD_PER_MONTH")]
	salary_lbl.add_theme_color_override("font_color", COLOR_DARK)
	salary_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(salary_lbl, "semibold")
	meta_hbox.add_child(salary_lbl)

	# === Current Stats ===
	var cur_title = Label.new()
	cur_title.text = tr("REPORTS_PEOPLE_CARD_CURRENT")
	cur_title.add_theme_font_size_override("font_size", 14)
	cur_title.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(cur_title, "semibold")
	_card_vbox.add_child(cur_title)

	var stats = [
		{"label": "😊 " + tr("REPORTS_PEOPLE_HEALTH_MOOD"),    "value": d.mood,          "color_low": COLOR_RED,   "color_high": COLOR_GREEN},
		{"label": "🔥 " + tr("REPORTS_PEOPLE_HEALTH_BURNOUT"), "value": d.burnout_level, "color_low": COLOR_GREEN, "color_high": COLOR_RED},
	]
	for stat in stats:
		_card_vbox.add_child(_build_stat_bar(stat))

	# === Period Dynamics Graph ===
	var dyn_title = Label.new()
	dyn_title.text = tr("REPORTS_PEOPLE_CARD_DYNAMICS")
	dyn_title.add_theme_font_size_override("font_size", 14)
	dyn_title.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(dyn_title, "semibold")
	_card_vbox.add_child(dyn_title)

	_card_graph = Control.new()
	_card_graph.custom_minimum_size = Vector2(0, 160)
	_card_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var emp_name_capture = _selected_employee
	_card_graph.draw.connect(func(): _draw_employee_graph(_card_graph, emp_name_capture))
	_card_vbox.add_child(_card_graph)
	_card_vbox.add_child(_make_legend([
		{"label": tr("REPORTS_PEOPLE_HEALTH_MOOD"),    "color": COLOR_BLUE},
		{"label": tr("REPORTS_PEOPLE_HEALTH_BURNOUT"), "color": COLOR_RED},
	]))

	# === Cost vs Output ===
	var cvo_title = Label.new()
	cvo_title.text = tr("REPORTS_PEOPLE_CARD_COST_VS_OUTPUT")
	cvo_title.add_theme_font_size_override("font_size", 14)
	cvo_title.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(cvo_title, "semibold")
	_card_vbox.add_child(cvo_title)

	var records = _get_filtered_records()
	var total_progress = 0.0
	var total_work_min  = 0.0
	var days = 0
	var daily_sal = float(d.monthly_salary) / 22.0
	for r in records:
		for emp in r.get("employees", []):
			if str(emp.get("name", "")) == _selected_employee:
				total_progress += float(emp.get("progress", 0.0))
				total_work_min  += float(emp.get("work_minutes", 0.0))
				days += 1
	var avg_progress = total_progress / max(days, 1)
	var avg_hours    = (total_work_min / max(days, 1)) / 60.0
	var efficiency   = avg_progress / max(daily_sal, 0.01)

	var cvo_grid = GridContainer.new()
	cvo_grid.columns = 2
	cvo_grid.add_theme_constant_override("h_separation", 16)
	cvo_grid.add_theme_constant_override("v_separation", 4)
	_card_vbox.add_child(cvo_grid)

	var cvo_rows = [
		[tr("REPORTS_PEOPLE_CARD_AVG_SALARY_DAY"),   "$%.2f" % daily_sal],
		[tr("REPORTS_PEOPLE_CARD_AVG_PROGRESS_DAY"), "%.1f" % avg_progress],
		[tr("REPORTS_PEOPLE_CARD_AVG_HOURS_DAY"),    "%.1f h" % avg_hours],
		[tr("REPORTS_PEOPLE_CARD_EFFICIENCY"),        "%.3f" % efficiency],
	]
	for row in cvo_rows:
		var k_lbl = Label.new()
		k_lbl.text = str(row[0])
		k_lbl.add_theme_color_override("font_color", COLOR_GRAY)
		k_lbl.add_theme_font_size_override("font_size", 12)
		if UITheme: UITheme.apply_font(k_lbl, "regular")
		cvo_grid.add_child(k_lbl)

		var v_lbl = Label.new()
		v_lbl.text = str(row[1])
		v_lbl.add_theme_color_override("font_color", COLOR_DARK)
		v_lbl.add_theme_font_size_override("font_size", 12)
		if UITheme: UITheme.apply_font(v_lbl, "semibold")
		cvo_grid.add_child(v_lbl)

	# === Work Hours Graph ===
	var wh_title = Label.new()
	wh_title.text = tr("REPORTS_PEOPLE_CARD_WORK_HOURS")
	wh_title.add_theme_font_size_override("font_size", 14)
	wh_title.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(wh_title, "semibold")
	_card_vbox.add_child(wh_title)

	var wh_graph = Control.new()
	wh_graph.custom_minimum_size = Vector2(0, 140)
	wh_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var emp_wh_capture = _selected_employee
	wh_graph.draw.connect(func(): _draw_work_hours_graph(wh_graph, emp_wh_capture))
	_card_vbox.add_child(wh_graph)
	_card_vbox.add_child(_make_legend([
		{"label": tr("REPORTS_PEOPLE_CARD_WORK_HOURS"), "color": COLOR_BLUE},
	]))

	# === Progress Points Graph ===
	var pp_title = Label.new()
	pp_title.text = tr("REPORTS_PEOPLE_CARD_PROGRESS_POINTS")
	pp_title.add_theme_font_size_override("font_size", 14)
	pp_title.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(pp_title, "semibold")
	_card_vbox.add_child(pp_title)

	var pp_graph = Control.new()
	pp_graph.custom_minimum_size = Vector2(0, 140)
	pp_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var emp_pp_capture = _selected_employee
	pp_graph.draw.connect(func(): _draw_progress_points_graph(pp_graph, emp_pp_capture))
	_card_vbox.add_child(pp_graph)
	_card_vbox.add_child(_make_legend([
		{"label": tr("REPORTS_PEOPLE_CARD_PROGRESS_POINTS"), "color": COLOR_GREEN},
	]))

	# === Efficiency Graph ===
	var eff_title = Label.new()
	eff_title.text = tr("REPORTS_PEOPLE_CARD_EFFICIENCY_GRAPH")
	eff_title.add_theme_font_size_override("font_size", 14)
	eff_title.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(eff_title, "semibold")
	_card_vbox.add_child(eff_title)

	var eff_graph = Control.new()
	eff_graph.custom_minimum_size = Vector2(0, 140)
	eff_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var emp_eff_capture = _selected_employee
	eff_graph.draw.connect(func(): _draw_efficiency_graph(eff_graph, emp_eff_capture))
	_card_vbox.add_child(eff_graph)
	_card_vbox.add_child(_make_legend([
		{"label": tr("REPORTS_PEOPLE_CARD_EFFICIENCY_GRAPH"), "color": COLOR_ORANGE},
	]))

	var eff_desc = Label.new()
	eff_desc.text = tr("REPORTS_PEOPLE_CARD_EFFICIENCY_DESC")
	eff_desc.add_theme_color_override("font_color", COLOR_GRAY)
	eff_desc.add_theme_font_size_override("font_size", 11)
	eff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme: UITheme.apply_font(eff_desc, "regular")
	_card_vbox.add_child(eff_desc)

func _build_stat_bar(stat: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl = Label.new()
	lbl.text = str(stat["label"])
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(lbl, "regular")
	hbox.add_child(lbl)

	var val = clampf(float(stat["value"]), 0.0, 100.0)
	var frac = val / 100.0
	var color: Color = stat["color_low"].lerp(stat["color_high"], frac)

	var bar_bg = PanelContainer.new()
	bar_bg.custom_minimum_size = Vector2(300, 14)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.9, 0.9, 0.9, 1)
	bg_style.corner_radius_top_left = 4; bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_right = 4; bg_style.corner_radius_bottom_left = 4
	bar_bg.add_theme_stylebox_override("panel", bg_style)
	hbox.add_child(bar_bg)

	var bar_fill = ColorRect.new()
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.size_flags_horizontal = Control.SIZE_FILL
	bar_fill.color = color
	bar_fill.size = Vector2(frac * 300, 14)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_top_left = 4; fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_right = 4; fill_style.corner_radius_bottom_left = 4
	bar_bg.add_child(bar_fill)

	var val_lbl = Label.new()
	val_lbl.text = "%.0f/100" % val
	val_lbl.custom_minimum_size = Vector2(60, 0)
	val_lbl.add_theme_color_override("font_color", COLOR_DARK)
	val_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(val_lbl, "regular")
	hbox.add_child(val_lbl)

	return hbox

func _draw_employee_graph(ctrl: Control, emp_name: String):
	var records = _get_filtered_records()
	var w = ctrl.size.x
	var h = ctrl.size.y
	var pad_left   = 36.0
	var pad_right  = 16.0
	var pad_top    = 12.0
	var pad_bottom = 26.0
	var gw = w - pad_left - pad_right
	var gh = h - pad_top - pad_bottom

	# Filter records for this employee
	var emp_records = []
	for r in records:
		for emp in r.get("employees", []):
			if str(emp.get("name", "")) == emp_name:
				emp_records.append({"day": r.get("day", 0), "mood": emp.get("mood", 50.0), "burnout": emp.get("burnout", 0.0)})
				break

	if emp_records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 60, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GRAY)
		return

	var grid_color = Color(0.88, 0.88, 0.88, 1)
	for i in range(6):
		var frac = float(i) / 5.0
		var gy = pad_top + frac * gh
		ctrl.draw_line(Vector2(pad_left, gy), Vector2(pad_left + gw, gy), grid_color, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 4), str(int(100 - frac * 100)), HORIZONTAL_ALIGNMENT_LEFT, pad_left - 2, 9, COLOR_GRAY)

	var n = emp_records.size()
	var mood_pts:    PackedVector2Array = []
	var burnout_pts: PackedVector2Array = []
	for i in range(n):
		var px = pad_left + (float(i) / max(n - 1, 1)) * gw
		mood_pts.append(   Vector2(px, pad_top + gh * (1.0 - clampf(float(emp_records[i]["mood"]),    0, 100) / 100.0)))
		burnout_pts.append(Vector2(px, pad_top + gh * (1.0 - clampf(float(emp_records[i]["burnout"]), 0, 100) / 100.0)))

	ctrl.draw_polyline(mood_pts,    COLOR_BLUE,  1.5, true)
	ctrl.draw_polyline(burnout_pts, COLOR_RED,   1.5, true)

	var step = max(1, int(ceil(float(n) / 8.0)))
	for i in range(0, n, step):
		var px = pad_left + (float(i) / max(n - 1, 1)) * gw
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px - 6, h - 4), str(int(emp_records[i]["day"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_GRAY)

func _draw_work_hours_graph(ctrl: Control, emp_name: String):
	var records = _get_filtered_records()
	var w = ctrl.size.x
	var h = ctrl.size.y
	var pad_left   = 40.0
	var pad_right  = 16.0
	var pad_top    = 12.0
	var pad_bottom = 26.0
	var gw = w - pad_left - pad_right
	var gh = h - pad_top - pad_bottom

	var hours_data = []
	for r in records:
		for emp in r.get("employees", []):
			if str(emp.get("name", "")) == emp_name:
				hours_data.append({"day": r.get("day", 0), "hours": float(emp.get("work_minutes", 0.0)) / 60.0})
				break

	if hours_data.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 60, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GRAY)
		return

	var max_hours = 8.0
	for item in hours_data:
		max_hours = max(max_hours, item["hours"] + 0.5)

	var grid_color = Color(0.88, 0.88, 0.88, 1)
	for i in range(6):
		var frac = float(i) / 5.0
		var gy = pad_top + frac * gh
		ctrl.draw_line(Vector2(pad_left, gy), Vector2(pad_left + gw, gy), grid_color, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 4), "%.0f" % (max_hours * (1.0 - frac)), HORIZONTAL_ALIGNMENT_LEFT, pad_left - 2, 9, COLOR_GRAY)

	var n = hours_data.size()
	var bar_w = max(4.0, (gw / max(n, 1)) - 2.0)
	var bar_color = Color(COLOR_BLUE.r, COLOR_BLUE.g, COLOR_BLUE.b, 0.75)
	for i in range(n):
		var px = pad_left + gw * 0.5 if n == 1 else pad_left + (float(i) / float(n - 1)) * gw
		var val = hours_data[i]["hours"]
		var bh = gh * (val / max_hours)
		ctrl.draw_rect(Rect2(px - bar_w * 0.5, pad_top + gh - bh, bar_w, bh), bar_color)

	var step = max(1, int(ceil(float(n) / 8.0)))
	for i in range(0, n, step):
		var px = pad_left + gw * 0.5 if n == 1 else pad_left + (float(i) / float(n - 1)) * gw
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px - 6, h - 4), str(int(hours_data[i]["day"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_GRAY)

func _draw_progress_points_graph(ctrl: Control, emp_name: String):
	var records = _get_filtered_records()
	var w = ctrl.size.x
	var h = ctrl.size.y
	var pad_left   = 40.0
	var pad_right  = 16.0
	var pad_top    = 12.0
	var pad_bottom = 26.0
	var gw = w - pad_left - pad_right
	var gh = h - pad_top - pad_bottom

	var prog_data = []
	for r in records:
		for emp in r.get("employees", []):
			if str(emp.get("name", "")) == emp_name:
				prog_data.append({"day": r.get("day", 0), "progress": float(emp.get("progress", 0.0))})
				break

	if prog_data.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 60, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GRAY)
		return

	var max_prog = 1.0
	for item in prog_data:
		max_prog = max(max_prog, item["progress"])
	max_prog = max_prog * 1.1

	var grid_color = Color(0.88, 0.88, 0.88, 1)
	for i in range(6):
		var frac = float(i) / 5.0
		var gy = pad_top + frac * gh
		ctrl.draw_line(Vector2(pad_left, gy), Vector2(pad_left + gw, gy), grid_color, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 4), "%.0f" % (max_prog * (1.0 - frac)), HORIZONTAL_ALIGNMENT_LEFT, pad_left - 2, 9, COLOR_GRAY)

	var n = prog_data.size()
	var pts: PackedVector2Array = []
	for i in range(n):
		var px = pad_left + gw * 0.5 if n == 1 else pad_left + (float(i) / float(n - 1)) * gw
		var py = pad_top + gh * (1.0 - prog_data[i]["progress"] / max_prog)
		pts.append(Vector2(px, py))

	ctrl.draw_polyline(pts, COLOR_GREEN, 2.0, true)
	for p in pts:
		ctrl.draw_circle(p, 3.0, COLOR_GREEN)

	var step = max(1, int(ceil(float(n) / 8.0)))
	for i in range(0, n, step):
		var px = pad_left + gw * 0.5 if n == 1 else pad_left + (float(i) / float(n - 1)) * gw
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px - 6, h - 4), str(int(prog_data[i]["day"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_GRAY)

func _draw_efficiency_graph(ctrl: Control, emp_name: String):
	var records = _get_filtered_records()
	var w = ctrl.size.x
	var h = ctrl.size.y
	var pad_left   = 40.0
	var pad_right  = 16.0
	var pad_top    = 12.0
	var pad_bottom = 26.0
	var gw = w - pad_left - pad_right
	var gh = h - pad_top - pad_bottom

	var eff_data = []
	for r in records:
		for emp in r.get("employees", []):
			if str(emp.get("name", "")) == emp_name:
				var daily_sal = float(emp.get("daily_salary", 0.0))
				var progress  = float(emp.get("progress", 0.0))
				eff_data.append({"day": r.get("day", 0), "efficiency": progress / max(daily_sal, 0.01)})
				break

	if eff_data.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 60, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GRAY)
		return

	var max_eff = 0.001
	for item in eff_data:
		max_eff = max(max_eff, item["efficiency"])
	max_eff = max_eff * 1.1

	var grid_color = Color(0.88, 0.88, 0.88, 1)
	for i in range(6):
		var frac = float(i) / 5.0
		var gy = pad_top + frac * gh
		ctrl.draw_line(Vector2(pad_left, gy), Vector2(pad_left + gw, gy), grid_color, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 4), "%.2f" % (max_eff * (1.0 - frac)), HORIZONTAL_ALIGNMENT_LEFT, pad_left - 2, 9, COLOR_GRAY)

	var n = eff_data.size()
	var pts: PackedVector2Array = []
	for i in range(n):
		var px = pad_left + gw * 0.5 if n == 1 else pad_left + (float(i) / float(n - 1)) * gw
		var py = pad_top + gh * (1.0 - eff_data[i]["efficiency"] / max_eff)
		pts.append(Vector2(px, py))

	ctrl.draw_polyline(pts, COLOR_ORANGE, 2.0, true)
	for p in pts:
		ctrl.draw_circle(p, 3.0, COLOR_ORANGE)

	var step = max(1, int(ceil(float(n) / 8.0)))
	for i in range(0, n, step):
		var px = pad_left + gw * 0.5 if n == 1 else pad_left + (float(i) / float(n - 1)) * gw
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px - 6, h - 4), str(int(eff_data[i]["day"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_GRAY)

# =========================================================
#  HELPERS
# =========================================================

func _make_legend(items: Array) -> HBoxContainer:
	var legend = HBoxContainer.new()
	legend.add_theme_constant_override("separation", 16)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	for item in items:
		var hb = HBoxContainer.new()
		hb.add_theme_constant_override("separation", 4)
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(12, 12)
		rect.color = item["color"]
		hb.add_child(rect)
		var lbl = Label.new()
		lbl.text = item["label"]
		lbl.add_theme_color_override("font_color", COLOR_DARK)
		lbl.add_theme_font_size_override("font_size", 11)
		if UITheme: UITheme.apply_font(lbl, "regular")
		hb.add_child(lbl)
		legend.add_child(hb)
	return legend

func _style_option_button(btn: OptionButton):
	var s = StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 1)
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.border_color = COLOR_BLUE
	s.corner_radius_top_left = 7; s.corner_radius_top_right = 7
	s.corner_radius_bottom_right = 7; s.corner_radius_bottom_left = 7
	s.content_margin_left = 8; s.content_margin_right = 8
	s.content_margin_top = 4; s.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", s)

	var s_hover = s.duplicate() as StyleBoxFlat
	s_hover.bg_color = Color(0.93, 0.95, 0.99, 1)
	btn.add_theme_stylebox_override("hover", s_hover)
	btn.add_theme_stylebox_override("pressed", s_hover)
	btn.add_theme_stylebox_override("focus", s)

	btn.add_theme_color_override("font_color",         COLOR_BLUE)
	btn.add_theme_color_override("font_hover_color",   COLOR_BLUE)
	btn.add_theme_color_override("font_pressed_color", COLOR_BLUE)
	btn.add_theme_color_override("font_focus_color",   COLOR_BLUE)

	var popup = btn.get_popup()
	if popup:
		var popup_style = StyleBoxFlat.new()
		popup_style.bg_color = Color(1, 1, 1, 1)
		popup_style.border_width_left = 1; popup_style.border_width_top = 1
		popup_style.border_width_right = 1; popup_style.border_width_bottom = 1
		popup_style.border_color = COLOR_BLUE
		popup_style.corner_radius_top_left = 6; popup_style.corner_radius_top_right = 6
		popup_style.corner_radius_bottom_right = 6; popup_style.corner_radius_bottom_left = 6
		popup.add_theme_stylebox_override("panel", popup_style)
		popup.add_theme_color_override("font_color",       COLOR_DARK)
		popup.add_theme_color_override("font_hover_color", COLOR_DARK)
		var hover_style = StyleBoxFlat.new()
		hover_style.bg_color = Color(0.85, 0.9, 0.98, 1)
		hover_style.corner_radius_top_left = 4; hover_style.corner_radius_top_right = 4
		hover_style.corner_radius_bottom_right = 4; hover_style.corner_radius_bottom_left = 4
		popup.add_theme_stylebox_override("hover", hover_style)

	if UITheme: UITheme.apply_font(btn, "semibold")

func _make_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UITheme:
		card.add_theme_stylebox_override("panel", UITheme.create_card_style())
	else:
		var s = StyleBoxFlat.new()
		s.bg_color = Color(1, 1, 1, 1)
		s.border_width_left = 1; s.border_width_top = 1
		s.border_width_right = 1; s.border_width_bottom = 1
		s.border_color = Color(0.88, 0.88, 0.88, 1)
		s.corner_radius_top_left = 8; s.corner_radius_top_right = 8
		s.corner_radius_bottom_right = 8; s.corner_radius_bottom_left = 8
		card.add_theme_stylebox_override("panel", s)
	return card

func _make_card_margin() -> MarginContainer:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	return margin

func _make_title(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	return lbl

func _make_no_data_label() -> Label:
	var lbl = Label.new()
	lbl.text = tr("REPORTS_PEOPLE_NO_DATA")
	lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "regular")
	return lbl

func _format_money(amount: int) -> String:
	var abs_amount = abs(amount)
	var s = str(abs_amount)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result
