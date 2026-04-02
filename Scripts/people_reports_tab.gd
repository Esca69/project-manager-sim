extends Control

# === PEOPLE REPORTS TAB — FULL REDESIGN ===

const COLOR_BLUE      = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN     = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED       = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE    = Color(1.0, 0.55, 0.0, 1)
const COLOR_GRAY      = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK      = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE     = Color(1, 1, 1, 1)
const COLOR_YELLOW    = Color(1.0, 0.85, 0.0, 1)

const PERIOD_7D  = 1
const PERIOD_30D = 2
const PERIOD_90D = 3
const PERIOD_ALL = 4

var _selected_period : int = PERIOD_7D
var _period_offset   : int = 0

var _period_range_label : Label
var _period_nav_prev    : Button
var _period_nav_next    : Button
var _period_buttons     : Array = []

var _team_sections  : VBoxContainer

var _kpi_row1 : HBoxContainer
var _kpi_row2 : HBoxContainer

var _scatter_graph   : Control
var _bars_graph      : Control
var _multiline_graph : Control
var _util_graph      : Control
var _health_graph    : Control

var _table_vbox : VBoxContainer

var _scatter_filter   : OptionButton
var _bars_filter      : OptionButton
var _multiline_filter : OptionButton
var _util_filter      : OptionButton
var _table_filter     : OptionButton
var _metric_selector  : OptionButton

var _tooltip_panel : PanelContainer
var _tooltip_label : Label

var _scatter_pts    : Array = []
var _bars_data      : Array = []
var _util_bars      : Array = []
var _health_pts     : Array = []
var _multiline_data : Array = []
var _multiline_legend_container : HFlowContainer
var _multiline_hidden : Dictionary = {}

# =====================================================================
#  READY / BUILD
# =====================================================================

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
	vbox.add_child(_build_period_selector())
	_team_sections = VBoxContainer.new()
	_team_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_team_sections.add_theme_constant_override("separation", 16)
	vbox.add_child(_team_sections)
	_team_sections.add_child(_build_kpi_card())
	_team_sections.add_child(_build_scatter_card())
	_team_sections.add_child(_build_bars_card())
	_team_sections.add_child(_build_multiline_card())
	_team_sections.add_child(_build_util_card())
	_team_sections.add_child(_build_table_card())
	_team_sections.add_child(_build_health_card())
	_build_tooltip()

	# =====================================================================
	#  TOOLTIP
	# =====================================================================

func _build_tooltip():
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.z_index = 100
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	var sty = StyleBoxFlat.new()
	sty.bg_color = Color(0.15, 0.15, 0.15, 0.92)
	sty.corner_radius_top_left     = 6
	sty.corner_radius_top_right    = 6
	sty.corner_radius_bottom_right = 6
	sty.corner_radius_bottom_left  = 6
	sty.content_margin_left   = 8
	sty.content_margin_top    = 4
	sty.content_margin_right  = 8
	sty.content_margin_bottom = 4
	_tooltip_panel.add_theme_stylebox_override("panel", sty)
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_color_override("font_color", COLOR_WHITE)
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(_tooltip_label, "regular")
	_tooltip_panel.add_child(_tooltip_label)
	add_child(_tooltip_panel)

func _show_tooltip_at(text: String, chart: Control, chart_local: Vector2):
	if not _tooltip_panel or not _tooltip_label: return
	_tooltip_label.text = text
	var gp = chart.get_global_transform() * chart_local
	var lp = get_global_transform().affine_inverse() * gp
	_tooltip_panel.position = lp + Vector2(14, -44)
	_tooltip_panel.visible = true

func _hide_tooltip():
	if _tooltip_panel: _tooltip_panel.visible = false

# =====================================================================
#  PERIOD SELECTOR
# =====================================================================

func _build_period_selector() -> Control:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	vbox.add_child(row1)
	var plbl = Label.new()
	plbl.text = tr("REPORTS_PERIOD_LABEL")
	plbl.add_theme_color_override("font_color", COLOR_GRAY)
	plbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(plbl, "semibold")
	row1.add_child(plbl)
	var periods = [
		[tr("REPORTS_PERIOD_7D"), PERIOD_7D],
		[tr("REPORTS_PERIOD_30D"), PERIOD_30D],
		[tr("REPORTS_PERIOD_90D"), PERIOD_90D],
		[tr("REPORTS_PERIOD_ALL_SHORT"), PERIOD_ALL]
	]
	_period_buttons.clear()
	for p in periods:
		var btn = Button.new()
		btn.text = p[0]
		btn.custom_minimum_size = Vector2(60, 28)
		btn.focus_mode = Control.FOCUS_NONE
		var code = p[1]
		btn.pressed.connect(func(): _on_period_selected(code))
		_period_buttons.append({"btn": btn, "code": code})
		_style_period_btn(btn, code == _selected_period)
		if UITheme: UITheme.apply_font(btn, "semibold")
		row1.add_child(btn)
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	vbox.add_child(row2)
	_period_nav_prev = Button.new()
	_period_nav_prev.text = "◀"
	_period_nav_prev.custom_minimum_size = Vector2(30, 26)
	_period_nav_prev.focus_mode = Control.FOCUS_NONE
	_period_nav_prev.pressed.connect(_on_period_nav_prev)
	_style_small_btn(_period_nav_prev)
	row2.add_child(_period_nav_prev)
	_period_range_label = Label.new()
	_period_range_label.text = ""
	_period_range_label.add_theme_color_override("font_color", COLOR_DARK)
	_period_range_label.add_theme_font_size_override("font_size", 12)
	_period_range_label.custom_minimum_size = Vector2(200, 0)
	_period_range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_period_range_label, "regular")
	row2.add_child(_period_range_label)
	_period_nav_next = Button.new()
	_period_nav_next.text = "▶"
	_period_nav_next.custom_minimum_size = Vector2(30, 26)
	_period_nav_next.focus_mode = Control.FOCUS_NONE
	_period_nav_next.pressed.connect(_on_period_nav_next)
	_style_small_btn(_period_nav_next)
	row2.add_child(_period_nav_next)
	return card

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

func _style_small_btn(btn: Button):
	var s = StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 1)
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.border_color = COLOR_BLUE
	s.corner_radius_top_left = 5; s.corner_radius_top_right = 5
	s.corner_radius_bottom_right = 5; s.corner_radius_bottom_left = 5
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_color_override("font_color", COLOR_BLUE)
	btn.add_theme_color_override("font_hover_color", COLOR_BLUE)
	btn.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(btn, "semibold")

func _style_option_button(ob: OptionButton):
	var s = StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 1)
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.border_color = COLOR_BLUE
	s.corner_radius_top_left = 6; s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6; s.corner_radius_bottom_left = 6
	s.content_margin_left = 8; s.content_margin_right = 8
	s.content_margin_top = 4; s.content_margin_bottom = 4
	ob.add_theme_stylebox_override("normal", s)
	ob.add_theme_stylebox_override("hover", s)
	ob.add_theme_stylebox_override("pressed", s)
	ob.add_theme_stylebox_override("focus", s)
	ob.add_theme_color_override("font_color", COLOR_DARK)
	ob.add_theme_color_override("font_hover_color", COLOR_DARK)
	ob.add_theme_color_override("font_pressed_color", COLOR_DARK)
	ob.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(ob, "regular")
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 1)
	ps.border_width_left = 1; ps.border_width_top = 1
	ps.border_width_right = 1; ps.border_width_bottom = 1
	ps.border_color = COLOR_BLUE
	ps.corner_radius_top_left = 4; ps.corner_radius_top_right = 4
	ps.corner_radius_bottom_right = 4; ps.corner_radius_bottom_left = 4
	ps.content_margin_left = 6; ps.content_margin_right = 6
	ps.content_margin_top = 4; ps.content_margin_bottom = 4
	ob.get_popup().add_theme_stylebox_override("panel", ps)
	ob.get_popup().add_theme_color_override("font_color", COLOR_DARK)
	ob.get_popup().add_theme_color_override("font_hover_color", COLOR_BLUE)

func _on_period_selected(code: int):
	_selected_period = code
	_period_offset = 0
	for entry in _period_buttons:
		_style_period_btn(entry["btn"], entry["code"] == code)
	_update_period_range_label()
	_refresh_all()

func _on_period_nav_prev():
	if _selected_period == PERIOD_ALL: return
	_period_offset += 1
	_update_period_range_label()
	_refresh_all()

func _on_period_nav_next():
	if _period_offset > 0:
		_period_offset -= 1
		_update_period_range_label()
		_refresh_all()

func _update_period_range_label():
	if not _period_range_label: return
	var b = _get_period_bounds()
	if _selected_period == PERIOD_ALL:
		_period_range_label.text = tr("REPORTS_PERIOD_RANGE_ALL") % b[1]
	else:
		_period_range_label.text = tr("REPORTS_PERIOD_RANGE") % [b[0], b[1]]
	if _period_nav_next: _period_nav_next.disabled = (_period_offset == 0)
	if _period_nav_prev: _period_nav_prev.disabled = (_selected_period == PERIOD_ALL)

# =====================================================================
#  PERIOD DATA HELPERS
# =====================================================================

func _get_period_bounds() -> Array:
	var cur = GameTime.day
	match _selected_period:
		PERIOD_7D:
			var e = max(1, cur - _period_offset * 7)
			return [max(1, e - 6), e]
		PERIOD_30D:
			var e = max(1, cur - _period_offset * 30)
			return [max(1, e - 29), e]
		PERIOD_90D:
			var e = max(1, cur - _period_offset * 90)
			return [max(1, e - 89), e]
		PERIOD_ALL:
			return [1, cur]
	return [1, cur]

func _get_filtered_records() -> Array:
	var all = PeopleHistory.daily_records
	if all.is_empty(): return []
	var b = _get_period_bounds()
	var result = []
	for r in all:
		var d = int(r.get("day", 0))
		if d >= b[0] and d <= b[1]: result.append(r)
	return result

func _get_prev_period_records() -> Array:
	if _selected_period == PERIOD_ALL: return []
	var all = PeopleHistory.daily_records
	if all.is_empty(): return []
	var cb = _get_period_bounds()
	var pe = cb[0] - 1
	if pe < 1: return []
	var ps = 1
	match _selected_period:
		PERIOD_7D:  ps = max(1, pe - 6)
		PERIOD_30D: ps = max(1, pe - 29)
		PERIOD_90D: ps = max(1, pe - 89)
	var result = []
	for r in all:
		var d = int(r.get("day", 0))
		if d >= ps and d <= pe: result.append(r)
	return result

func _aggregate_health_records(records: Array) -> Array:
	match _selected_period:
		PERIOD_90D:
			var weeks = {}
			for r in records:
				var d = int(r.get("day", 0))
				var wn = GameTime.get_week_number(d)
				if not weeks.has(wn):
					weeks[wn] = {"day": GameTime.get_week_start_day(wn), "label": "W%d" % wn,
							 "_mood": 0.0, "_energy": 0.0, "_burnout": 0.0, "_n": 0}
				weeks[wn]["_mood"]    += float(r.get("avg_mood", 0))
				weeks[wn]["_energy"]  += float(r.get("avg_energy", 0))
				weeks[wn]["_burnout"] += float(r.get("avg_burnout", 0))
				weeks[wn]["_n"]       += 1
			var keys = weeks.keys(); keys.sort()
			var res = []
			for k in keys:
				var g = weeks[k]; var n = max(g["_n"], 1)
				g["avg_mood"]    = g["_mood"] / n
				g["avg_energy"]  = g["_energy"] / n
				g["avg_burnout"] = g["_burnout"] / n
				res.append(g)
			return res
		PERIOD_ALL:
			var months = {}
			for r2 in records:
				var d = int(r2.get("day", 0))
				var mn = GameTime.get_month(d)
				if not months.has(mn):
					months[mn] = {"day": GameTime.get_month_start_day(mn), "label": "M%d" % mn,
							  "_mood": 0.0, "_energy": 0.0, "_burnout": 0.0, "_n": 0}
				months[mn]["_mood"]    += float(r2.get("avg_mood", 0))
				months[mn]["_energy"]  += float(r2.get("avg_energy", 0))
				months[mn]["_burnout"] += float(r2.get("avg_burnout", 0))
				months[mn]["_n"]       += 1
			var keys = months.keys(); keys.sort()
			var res = []
			for k2 in keys:
				var g = months[k2]; var n = max(g["_n"], 1)
				g["avg_mood"]    = g["_mood"] / n
				g["avg_energy"]  = g["_energy"] / n
				g["avg_burnout"] = g["_burnout"] / n
				res.append(g)
			return res
	var res = []
	for rec in records:
		var rc = rec.duplicate()
		rc["label"] = "D%d" % int(rec.get("day", 0))
		res.append(rc)
	return res

func _get_emp_stats(records: Array) -> Dictionary:
	var emp_stats = {}
	for r in records:
		for emp in r.get("employees", []):
			var ename = str(emp.get("name", ""))
			if ename.is_empty(): continue
			if not emp_stats.has(ename):
				emp_stats[ename] = {
					"job_title": str(emp.get("job_title", "")),
					"daily_salary": float(emp.get("daily_salary", 0.0)),
					"monthly_salary": int(emp.get("monthly_salary", 0)),
					"total_work_min": 0.0,
					"assigned_days": 0,
					"total_mood": 0.0,
					"total_energy": 0.0,
					"total_burnout": 0.0,
					"total_progress": 0.0,
					"days": 0,
				}
			var s = emp_stats[ename]
			s["total_work_min"] += float(emp.get("work_minutes", 0.0))
			var assigned = emp.get("is_assigned", float(emp.get("work_minutes", 0.0)) > 0)
			if assigned: s["assigned_days"] += 1
			s["total_mood"]    += float(emp.get("mood", 0.0))
			s["total_energy"]  += float(emp.get("energy", 0.0))
			s["total_burnout"] += float(emp.get("burnout", 0.0))
			s["total_progress"] += float(emp.get("progress", 0.0))
			s["days"] += 1
	return emp_stats

# =====================================================================
#  KPI HELPERS
# =====================================================================

func _kpi_panel() -> PanelContainer:
	var p = PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s = StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 1)
	s.border_width_left = 1; s.border_width_top = 1
	s.border_width_right = 1; s.border_width_bottom = 1
	s.border_color = Color(0.88, 0.88, 0.88, 1)
	s.corner_radius_top_left = 8; s.corner_radius_top_right = 8
	s.corner_radius_bottom_right = 8; s.corner_radius_bottom_left = 8
	p.add_theme_stylebox_override("panel", s)
	return p

func _kpi_inner(panel: PanelContainer) -> VBoxContainer:
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10); m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_right", 10); m.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(m)
	var vb = VBoxContainer.new(); vb.add_theme_constant_override("separation", 4)
	m.add_child(vb); return vb

func _kpi_head(vb: VBoxContainer, icon: String, lbl_text: String):
	var l = Label.new(); l.text = icon + " " + lbl_text
	l.add_theme_color_override("font_color", COLOR_GRAY)
	l.add_theme_font_size_override("font_size", 11)
	if UITheme: UITheme.apply_font(l, "regular")
	vb.add_child(l)

func _kpi_val(vb: VBoxContainer, text: String, color: Color):
	var l = Label.new(); l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(l, "semibold")
	vb.add_child(l)

func _kpi_delta(vb: VBoxContainer, text: String, color: Color):
	var l = Label.new(); l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 11)
	if UITheme: UITheme.apply_font(l, "regular")
	vb.add_child(l)

func _kpi_pct(cur: int, prev: int, higher_good: bool) -> Array:
	if prev == 0: return [tr("REPORTS_VS_PREV"), COLOR_GRAY]
	var diff = cur - prev
	var pct  = int(round(float(diff) / float(abs(prev)) * 100.0))
	var s = "+" if pct >= 0 else ""
	var good = (pct >= 0) == higher_good
	return [s + str(pct) + "% " + tr("REPORTS_VS_PREV"), COLOR_GREEN if good else COLOR_RED]

func _kpi_simple(icon: String, lbl_text: String, val_text: String, val_color: Color) -> PanelContainer:
	var p = _kpi_panel(); var vb = _kpi_inner(p)
	_kpi_head(vb, icon, lbl_text)
	_kpi_val(vb, val_text, val_color)
	return p

func _kpi_with_delta(icon: String, lbl_text: String, val_text: String, cur: int, prev: int, higher_good: bool, val_color: Color) -> PanelContainer:
	var p = _kpi_panel(); var vb = _kpi_inner(p)
	_kpi_head(vb, icon, lbl_text)
	_kpi_val(vb, val_text, val_color)
	var d = _kpi_pct(cur, prev, higher_good)
	_kpi_delta(vb, d[0], d[1])
	return p

# =====================================================================
#  BLOCK 1: KPI DASHBOARD
# =====================================================================

func _build_kpi_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_KPI_TITLE")))
	_kpi_row1 = HBoxContainer.new()
	_kpi_row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kpi_row1.add_theme_constant_override("separation", 8)
	vbox.add_child(_kpi_row1)
	_kpi_row2 = HBoxContainer.new()
	_kpi_row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kpi_row2.add_theme_constant_override("separation", 8)
	vbox.add_child(_kpi_row2)
	return card

func _refresh_kpi():
	if not _kpi_row1 or not _kpi_row2: return
	for c in _kpi_row1.get_children(): c.queue_free()
	for c2 in _kpi_row2.get_children(): c2.queue_free()
	var npcs = get_tree().get_nodes_in_group("npc")
	var headcount = 0; var payroll = 0; var contractors = 0; var freelancers = 0
	for npc in npcs:
		if not is_instance_valid(npc) or not npc.data: continue
		var d = npc.data
		headcount += 1; payroll += int(d.monthly_salary)
		var et = str(d.employment_type)
		if et == "contractor": contractors += 1
		elif et == "freelancer": freelancers += 1
	var avg_salary = float(payroll) / max(headcount, 1)
	var records  = _get_filtered_records()
	var prev_r   = _get_prev_period_records()
	var emp_stats  = _get_emp_stats(records)
	var prev_stats = _get_emp_stats(prev_r)
	var total_days = 0; var assigned_days = 0; var total_work_min = 0.0
	var total_mood = 0.0; var total_burnout = 0.0; var total_energy = 0.0; var mood_count = 0
	var total_progress_sum = 0.0
	for ename in emp_stats:
		var s = emp_stats[ename]
		total_days     += s["days"];        assigned_days  += s["assigned_days"]
		total_work_min += s["total_work_min"]
		total_mood     += s["total_mood"];  total_burnout  += s["total_burnout"]
		total_energy   += s["total_energy"]; mood_count    += s["days"]
		total_progress_sum += s.get("total_progress", 0.0)
	var util_pct = 0.0
	if mood_count > 0: util_pct = (total_work_min / (float(mood_count) * 480.0)) * 100.0
	var avg_hours = 0.0
	if mood_count > 0: avg_hours = (total_work_min / float(mood_count)) / 60.0
	var avg_mood    = total_mood    / max(mood_count, 1)
	var avg_burnout = total_burnout / max(mood_count, 1)
	var total_tenure = 0
	for npc2 in npcs:
		if not is_instance_valid(npc2) or not npc2.data: continue
		total_tenure += int(npc2.data.days_in_company)
	var avg_tenure = float(total_tenure) / max(headcount, 1)
	var prev_total_days = 0; var prev_assigned = 0; var prev_work_min = 0.0
	var prev_mood_sum = 0.0; var prev_burnout_sum = 0.0; var prev_mc = 0
	var prev_progress_sum = 0.0
	for en5 in prev_stats:
		var s = prev_stats[en5]
		prev_total_days += s["days"]; prev_assigned += s["assigned_days"]
		prev_work_min   += s["total_work_min"]
		prev_mood_sum += s["total_mood"]; prev_burnout_sum += s["total_burnout"]; prev_mc += s["days"]
		prev_progress_sum += s.get("total_progress", 0.0)
	var prev_util = 0.0
	if prev_mc > 0: prev_util = (prev_work_min / (float(prev_mc) * 480.0)) * 100.0
	var prev_avg_hours = 0.0
	if prev_mc > 0: prev_avg_hours = (prev_work_min / float(prev_mc)) / 60.0
	var prev_avg_mood    = prev_mood_sum    / max(prev_mc, 1)
	var prev_avg_burnout = prev_burnout_sum / max(prev_mc, 1)
	var prev_avg_progress = prev_progress_sum / max(prev_mc, 1)
	_kpi_row1.add_child(_kpi_simple("👥", tr("REPORTS_PEOPLE_HEADCOUNT"),    str(headcount),             COLOR_DARK))
	_kpi_row1.add_child(_kpi_simple("💰", tr("REPORTS_PEOPLE_PAYROLL"),       "$" + _format_money(payroll), COLOR_DARK))
	_kpi_row1.add_child(_kpi_simple("📊", tr("REPORTS_PEOPLE_AVG_SALARY"),    "$%d" % int(avg_salary),    COLOR_DARK))
	_kpi_row1.add_child(_kpi_simple("💼", tr("REPORTS_PEOPLE_CONTRACTORS"),   str(contractors),           COLOR_DARK))
	_kpi_row1.add_child(_kpi_simple("🧑", tr("REPORTS_PEOPLE_FREELANCERS"),   str(freelancers),           COLOR_DARK))
	var util_color = COLOR_BLUE if util_pct >= 60 else (COLOR_ORANGE if util_pct >= 30 else COLOR_RED)
	var mood_color = COLOR_GREEN if avg_mood > 60 else (COLOR_ORANGE if avg_mood >= 40 else COLOR_RED)
	var burn_color = COLOR_GREEN if avg_burnout < 20 else (COLOR_ORANGE if avg_burnout <= 50 else COLOR_RED)
	var avg_progress = total_progress_sum / max(mood_count, 1)
	var total_progress_val = total_progress_sum
	_kpi_row1.add_child(_kpi_simple("📈", tr("REPORTS_PEOPLE_KPI_TOTAL_PROGRESS"), "%.0f pts" % total_progress_val, COLOR_DARK))
	_kpi_row2.add_child(_kpi_with_delta("⚡", tr("REPORTS_PEOPLE_UTILIZATION"), "%.0f%%" % util_pct,    int(util_pct * 10), int(prev_util * 10),      true,  util_color))
	_kpi_row2.add_child(_kpi_with_delta("⏱",  tr("REPORTS_PEOPLE_AVG_HOURS"),  "%.1f h" % avg_hours,   int(avg_hours * 10), int(prev_avg_hours * 10), true,  COLOR_DARK))
	_kpi_row2.add_child(_kpi_with_delta("😊", tr("REPORTS_PEOPLE_HEALTH_MOOD"), "%.0f" % avg_mood,      int(avg_mood),       int(prev_avg_mood),       true,  mood_color))
	_kpi_row2.add_child(_kpi_with_delta("🔥", tr("REPORTS_PEOPLE_HEALTH_BURNOUT"), "%.0f" % avg_burnout, int(avg_burnout),   int(prev_avg_burnout),    false, burn_color))
	_kpi_row2.add_child(_kpi_with_delta("🎯", tr("REPORTS_PEOPLE_KPI_AVG_PROGRESS"), "%.1f pts" % avg_progress, int(avg_progress * 10), int(prev_avg_progress * 10), true, COLOR_BLUE))
	_kpi_row2.add_child(_kpi_simple("📅", tr("REPORTS_PEOPLE_AVG_TENURE"), "%.0f " % avg_tenure + tr("REPORTS_DAYS"), COLOR_DARK))

# =====================================================================
#  BLOCK 2: SALARY VS WORK HOURS (SCATTER)
# =====================================================================

func _build_scatter_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_SCATTER_TITLE")))
	var frow = HBoxContainer.new(); frow.add_theme_constant_override("separation", 8); vbox.add_child(frow)
	var flbl = Label.new(); flbl.text = tr("REPORTS_PEOPLE_FILTER_ROLE")
	flbl.add_theme_color_override("font_color", COLOR_GRAY); flbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(flbl, "regular"); frow.add_child(flbl)
	_scatter_filter = OptionButton.new()
	_scatter_filter.custom_minimum_size = Vector2(140, 0)
	_scatter_filter.focus_mode = Control.FOCUS_NONE
	_style_option_button(_scatter_filter)
	_scatter_filter.add_item(tr("REPORTS_PEOPLE_ALL_ROLES"))
	_scatter_filter.item_selected.connect(func(_i): _refresh_scatter())
	frow.add_child(_scatter_filter)
	_scatter_graph = Control.new()
	_scatter_graph.custom_minimum_size = Vector2(0, 220)
	_scatter_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scatter_graph.mouse_filter = Control.MOUSE_FILTER_STOP
	_scatter_graph.draw.connect(_draw_scatter.bind(_scatter_graph))
	_scatter_graph.gui_input.connect(_on_scatter_gui_input)
	_scatter_graph.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_scatter_graph)
	return card

func _refresh_scatter():
	if _scatter_graph: _scatter_graph.queue_redraw()

func _draw_scatter(ctrl: Control):
	var records = _get_filtered_records()
	_scatter_pts.clear()
	var w = ctrl.size.x; var h = ctrl.size.y
	const PL = 60.0; const PR = 20.0; const PT = 20.0; const PB = 40.0
	var gw = w - PL - PR; var gh = h - PT - PB
	if gw <= 0 or gh <= 0: return
	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var emp_stats = _get_emp_stats(records)
	if emp_stats.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var filter_role = ""
	if _scatter_filter and _scatter_filter.selected > 0: filter_role = _scatter_filter.get_item_text(_scatter_filter.selected)
	var pts_data = []
	for ename in emp_stats:
		var s = emp_stats[ename]
		if filter_role != "" and s["job_title"] != filter_role: continue
		var days = max(s["days"], 1)
		var avg_progress = s.get("total_progress", 0.0) / float(days)
		var efficiency = avg_progress / max(s["daily_salary"], 0.01)
		pts_data.append({"name": ename, "daily_sal": s["daily_salary"], "avg_progress": avg_progress, "efficiency": efficiency, "role": s["job_title"]})
	if pts_data.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var max_sal = 0.0; var max_prog = 0.0
	for p in pts_data:
		max_sal = max(max_sal, p["daily_sal"])
		max_prog = max(max_prog, p["avg_progress"])
	if max_sal < 0.01: max_sal = 1.0
	if max_prog < 0.01: max_prog = 1.0
	max_sal *= 1.1; max_prog *= 1.1
	var gc = Color(0.88, 0.88, 0.88, 1)
	for i in range(5):
		var frac = float(i) / 4.0
		var gy = PT + frac * gh
		ctrl.draw_line(Vector2(PL, gy), Vector2(PL + gw, gy), gc, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 4), "%.1f" % ((1.0 - frac) * max_prog), HORIZONTAL_ALIGNMENT_LEFT, PL - 4, 10, COLOR_GRAY)
		var gx = PL + frac * gw
		ctrl.draw_line(Vector2(gx, PT), Vector2(gx, PT + gh), gc, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(gx - 12, PT + gh + 14), "$%d" % int(frac * max_sal), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRAY)
	# Axes drawn as part of grid (i=0 → left/bottom edge, i=4 → right/top edge)
	for p3 in pts_data:
		var px = PL + (p3["daily_sal"] / max_sal) * gw
		var py = PT + (1.0 - p3["avg_progress"] / max_prog) * gh
		var col = _role_color(p3["role"])
		ctrl.draw_circle(Vector2(px, py), 6.0, col)
		_scatter_pts.append({"pos": Vector2(px, py), "name": p3["name"], "daily_sal": p3["daily_sal"], "avg_progress": p3["avg_progress"], "efficiency": p3["efficiency"], "role": p3["role"]})
	ctrl.draw_string(ThemeDB.fallback_font, Vector2(PL + gw / 2 - 20, PT + gh + 28), "$/" + tr("REPORTS_DAY"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_GRAY)

func _on_scatter_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	var bd = 15.0; var bi = -1
	for i in range(_scatter_pts.size()):
		var d = mp.distance_to(_scatter_pts[i]["pos"])
		if d < bd: bd = d; bi = i
	if bi >= 0:
		var p = _scatter_pts[bi]
		_show_tooltip_at(tr("REPORTS_PEOPLE_SCATTER_TOOLTIP") % [p["name"], p["daily_sal"], p["avg_progress"], p["efficiency"]], _scatter_graph, mp)
	else: _hide_tooltip()

# =====================================================================
#  BLOCK 3: WORK HOURS BY PERSON (BAR CHART)
# =====================================================================

func _build_bars_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_BARS_TITLE")))
	var frow = HBoxContainer.new(); frow.add_theme_constant_override("separation", 8); vbox.add_child(frow)
	var flbl = Label.new(); flbl.text = tr("REPORTS_PEOPLE_FILTER_ROLE")
	flbl.add_theme_color_override("font_color", COLOR_GRAY); flbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(flbl, "regular"); frow.add_child(flbl)
	_bars_filter = OptionButton.new()
	_bars_filter.custom_minimum_size = Vector2(140, 0)
	_bars_filter.focus_mode = Control.FOCUS_NONE
	_style_option_button(_bars_filter)
	_bars_filter.add_item(tr("REPORTS_PEOPLE_ALL_ROLES"))
	_bars_filter.item_selected.connect(func(_i): _refresh_bars())
	frow.add_child(_bars_filter)
	_bars_graph = Control.new()
	_bars_graph.custom_minimum_size = Vector2(0, 250)
	_bars_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bars_graph.mouse_filter = Control.MOUSE_FILTER_STOP
	_bars_graph.draw.connect(_draw_bars.bind(_bars_graph))
	_bars_graph.gui_input.connect(_on_bars_gui_input)
	_bars_graph.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_bars_graph)
	return card

func _refresh_bars():
	if _bars_graph: _bars_graph.queue_redraw()

func _draw_bars(ctrl: Control):
	var records = _get_filtered_records()
	_bars_data.clear()
	var w = ctrl.size.x; var h = ctrl.size.y
	const PL = 50.0; const PR = 20.0; const PT = 20.0; const PB = 50.0
	var gw = w - PL - PR; var gh = h - PT - PB
	if gw <= 0 or gh <= 0: return
	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var emp_stats = _get_emp_stats(records)
	var filter_role = ""
	if _bars_filter and _bars_filter.selected > 0: filter_role = _bars_filter.get_item_text(_bars_filter.selected)
	var names = []; var progresses = []; var salaries = []; var roles = []
	for ename in emp_stats:
		var s = emp_stats[ename]
		if filter_role != "" and s["job_title"] != filter_role: continue
		var days = max(s["days"], 1)
		var avg_prog = s.get("total_progress", 0.0) / float(days)
		names.append(ename); progresses.append(avg_prog); salaries.append(s["daily_salary"]); roles.append(s["job_title"])
	if names.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var max_h = 0.0; for hv in progresses: max_h = max(max_h, hv)
	if max_h < 0.01: max_h = 1.0
	max_h *= 1.15
	var gc = Color(0.88, 0.88, 0.88, 1)
	for i in range(5):
		var frac = float(i) / 4.0; var gy = PT + frac * gh
		ctrl.draw_line(Vector2(PL, gy), Vector2(PL + gw, gy), gc, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 4), "%.1f" % ((1.0 - frac) * max_h), HORIZONTAL_ALIGNMENT_LEFT, PL - 4, 10, COLOR_GRAY)
	var n = names.size(); var slot_w = gw / float(n); var bar_w = max(4.0, slot_w * 0.6)
	for j in range(n):
		var bx = PL + (float(j) + 0.5) * slot_w; var bh = (progresses[j] / max_h) * gh
		var col = _role_color(roles[j])
		var rect = Rect2(bx - bar_w * 0.5, PT + gh - bh, bar_w, bh)
		ctrl.draw_rect(rect, col)
		_bars_data.append({"rect": rect, "name": names[j], "avg_progress": progresses[j], "salary": salaries[j], "role": roles[j]})
		var short_n = names[j].substr(0, min(names[j].length(), 8))
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(bx - slot_w * 0.4, h - 8), short_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_GRAY)

func _on_bars_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	for bd in _bars_data:
		if bd["rect"].has_point(mp):
			_show_tooltip_at(tr("REPORTS_PEOPLE_DAILY_BARS_TOOLTIP") % [bd["name"], bd["avg_progress"], _format_money(int(bd["salary"])), bd["role"]], _bars_graph, mp)
			return
	_hide_tooltip()

# =====================================================================
#  BLOCK 4: MULTI-LINE COMPARISON
# =====================================================================

func _build_multiline_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_MULTILINE_TITLE")))
	var frow = HBoxContainer.new(); frow.add_theme_constant_override("separation", 8); vbox.add_child(frow)
	var mlbl = Label.new(); mlbl.text = tr("REPORTS_PEOPLE_METRIC_LABEL")
	mlbl.add_theme_color_override("font_color", COLOR_GRAY); mlbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(mlbl, "regular"); frow.add_child(mlbl)
	_metric_selector = OptionButton.new()
	_metric_selector.custom_minimum_size = Vector2(130, 0)
	_metric_selector.focus_mode = Control.FOCUS_NONE
	_style_option_button(_metric_selector)
	_metric_selector.add_item(tr("REPORTS_PEOPLE_METRIC_MOOD"))
	_metric_selector.add_item(tr("REPORTS_PEOPLE_METRIC_BURNOUT"))
	_metric_selector.add_item(tr("REPORTS_PEOPLE_METRIC_ENERGY"))
	_metric_selector.add_item(tr("REPORTS_PEOPLE_METRIC_HOURS"))
	_metric_selector.add_item(tr("REPORTS_PEOPLE_METRIC_PROGRESS"))
	_metric_selector.item_selected.connect(func(_i): _refresh_multiline())
	frow.add_child(_metric_selector)
	var flbl = Label.new(); flbl.text = tr("REPORTS_PEOPLE_FILTER_ROLE")
	flbl.add_theme_color_override("font_color", COLOR_GRAY); flbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(flbl, "regular"); frow.add_child(flbl)
	_multiline_filter = OptionButton.new()
	_multiline_filter.custom_minimum_size = Vector2(140, 0)
	_multiline_filter.focus_mode = Control.FOCUS_NONE
	_style_option_button(_multiline_filter)
	_multiline_filter.add_item(tr("REPORTS_PEOPLE_ALL_ROLES"))
	_multiline_filter.item_selected.connect(func(_i): _refresh_multiline())
	frow.add_child(_multiline_filter)
	_multiline_graph = Control.new()
	_multiline_graph.custom_minimum_size = Vector2(0, 220)
	_multiline_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_multiline_graph.mouse_filter = Control.MOUSE_FILTER_STOP
	_multiline_graph.draw.connect(_draw_multiline.bind(_multiline_graph))
	_multiline_graph.gui_input.connect(_on_multiline_gui_input)
	_multiline_graph.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_multiline_graph)
	_multiline_legend_container = HFlowContainer.new()
	_multiline_legend_container.add_theme_constant_override("h_separation", 16)
	_multiline_legend_container.add_theme_constant_override("v_separation", 8)
	_multiline_legend_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_multiline_legend_container)
	return card

func _refresh_multiline():
	if _multiline_graph: _multiline_graph.queue_redraw()

func _draw_multiline(ctrl: Control):
	var records = _get_filtered_records()
	_multiline_data.clear()
	var w = ctrl.size.x; var h = ctrl.size.y
	const PL = 50.0; const PR = 20.0; const PT = 20.0; const PB = 30.0
	var gw = w - PL - PR; var gh = h - PT - PB
	if gw <= 0 or gh <= 0: return
	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var metric_idx = 0
	if _metric_selector: metric_idx = _metric_selector.selected
	var metric_key = ["mood", "burnout", "energy", "work_minutes", "progress"][metric_idx]
	var filter_role = ""
	if _multiline_filter and _multiline_filter.selected > 0: filter_role = _multiline_filter.get_item_text(_multiline_filter.selected)
	var emp_series: Dictionary = {}
	for r in records:
		var day = int(r.get("day", 0))
		for emp in r.get("employees", []):
			var ename = str(emp.get("name", ""))
			if ename.is_empty(): continue
			if filter_role != "" and str(emp.get("job_title", "")) != filter_role: continue
			if not emp_series.has(ename): emp_series[ename] = []
			var val = float(emp.get(metric_key, 0.0))
			if metric_key == "work_minutes": val = val / 60.0
			emp_series[ename].append({"day": day, "val": val})
	if emp_series.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var max_val = 0.0
	if metric_key in ["mood", "burnout", "energy"]:
		max_val = 100.0
	else:
		for ename2 in emp_series:
			for pt in emp_series[ename2]: max_val = max(max_val, pt["val"])
		max_val = max(max_val * 1.1, 0.1)
	var min_day = 999999; var max_day = 0
	for en6 in emp_series:
		for pt2 in emp_series[en6]:
			min_day = min(min_day, pt2["day"])
			max_day = max(max_day, pt2["day"])
	if max_day == min_day: max_day = min_day + 1
	var gc = Color(0.88, 0.88, 0.88, 1)
	for i in range(5):
		var frac = float(i) / 4.0; var gy = PT + frac * gh
		ctrl.draw_line(Vector2(PL, gy), Vector2(PL + gw, gy), gc, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 4), "%.0f" % ((1.0 - frac) * max_val), HORIZONTAL_ALIGNMENT_LEFT, PL - 4, 10, COLOR_GRAY)
	var emp_names = emp_series.keys()
	var palette = [COLOR_BLUE, COLOR_RED, COLOR_GREEN, COLOR_ORANGE, COLOR_GRAY, Color(0.6, 0.2, 0.8, 1), Color(0.8, 0.5, 0.1, 1)]
	for ei in range(emp_names.size()):
		var ename2 = emp_names[ei]
		var col = palette[ei % palette.size()]
		if _multiline_hidden.get(ename2, false): continue
		var series = emp_series[ename2]
		if series.is_empty(): continue
		var pts: PackedVector2Array = []
		for pt3 in series:
			var px = PL + (float(pt3["day"] - min_day) / float(max_day - min_day)) * gw
			var py = PT + gh * (1.0 - clampf(pt3["val"], 0.0, max_val) / max_val)
			pts.append(Vector2(px, py))
		if pts.size() >= 2: ctrl.draw_polyline(pts, col, 1.5, true)
		for p in pts: ctrl.draw_circle(p, 2.5, col)
		_multiline_data.append({"pts": pts, "name": ename2, "color": col, "series": series})
	var n_all = max_day - min_day + 1
	var step = max(1, int(ceil(float(n_all) / 8.0)))
	for dd in range(min_day, max_day + 1, step):
		var px = PL + (float(dd - min_day) / float(max_day - min_day)) * gw
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px - 8, h - 6), "D%d" % dd, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRAY)
	# Update legend (deferred to avoid modifying scene tree during draw)
	var legend_items = []
	for ei2 in range(emp_names.size()):
		legend_items.append({"name": emp_names[ei2], "color": palette[ei2 % palette.size()]})
	call_deferred("_update_multiline_legend", legend_items)

func _on_multiline_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	var bd = 16.0; var best_line = -1; var best_pt = -1
	for li in range(_multiline_data.size()):
		var md = _multiline_data[li]
		for pi in range(md["pts"].size()):
			var d = mp.distance_to(md["pts"][pi])
			if d < bd: bd = d; best_line = li; best_pt = pi
	if best_line >= 0:
		var md2 = _multiline_data[best_line]
		var val = md2["series"][best_pt]["val"]
		var day = md2["series"][best_pt]["day"]
		_show_tooltip_at("Day %d: %s = %.1f" % [day, md2["name"], val], _multiline_graph, mp)
	else: _hide_tooltip()

func _update_multiline_legend(items: Array):
	if not _multiline_legend_container: return
	for c in _multiline_legend_container.get_children(): c.queue_free()
	for item in items:
		var ename = item["name"]
		var is_hidden = _multiline_hidden.get(ename, false)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(12, 12)
		rect.color = item["color"] if not is_hidden else COLOR_GRAY
		row.add_child(rect)
		var lbl = Label.new(); lbl.text = ename
		lbl.add_theme_color_override("font_color", COLOR_GRAY if is_hidden else COLOR_DARK)
		lbl.add_theme_font_size_override("font_size", 12)
		if UITheme: UITheme.apply_font(lbl, "regular")
		row.add_child(lbl)
		row.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_multiline_hidden[ename] = not _multiline_hidden.get(ename, false)
				_refresh_multiline()
				row.get_viewport().set_input_as_handled()
		)
		_multiline_legend_container.add_child(row)

# =====================================================================
#  BLOCK 5: UTILIZATION BAR CHART (HORIZONTAL)
# =====================================================================

func _build_util_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_UTILIZATION_TITLE")))
	var frow = HBoxContainer.new(); frow.add_theme_constant_override("separation", 8); vbox.add_child(frow)
	var flbl = Label.new(); flbl.text = tr("REPORTS_PEOPLE_FILTER_ROLE")
	flbl.add_theme_color_override("font_color", COLOR_GRAY); flbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(flbl, "regular"); frow.add_child(flbl)
	_util_filter = OptionButton.new()
	_util_filter.custom_minimum_size = Vector2(140, 0)
	_util_filter.focus_mode = Control.FOCUS_NONE
	_style_option_button(_util_filter)
	_util_filter.add_item(tr("REPORTS_PEOPLE_ALL_ROLES"))
	_util_filter.item_selected.connect(func(_i): _refresh_util())
	frow.add_child(_util_filter)
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 200)
	vbox.add_child(scroll)
	_util_graph = Control.new()
	_util_graph.custom_minimum_size = Vector2(0, 200)
	_util_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_util_graph.mouse_filter = Control.MOUSE_FILTER_STOP
	_util_graph.draw.connect(_draw_util.bind(_util_graph))
	_util_graph.gui_input.connect(_on_util_gui_input)
	_util_graph.mouse_exited.connect(_hide_tooltip)
	scroll.add_child(_util_graph)
	return card

func _refresh_util():
	var records = _get_filtered_records()
	var emp_stats = _get_emp_stats(records)
	var filter_role = ""
	if _util_filter and _util_filter.selected > 0: filter_role = _util_filter.get_item_text(_util_filter.selected)
	var count = 0
	for ename in emp_stats:
		if filter_role != "" and emp_stats[ename]["job_title"] != filter_role: continue
		count += 1
	if _util_graph:
		_util_graph.custom_minimum_size = Vector2(0, max(120.0, float(count) * 32.0 + 30.0))
		_util_graph.queue_redraw()

func _draw_util(ctrl: Control):
	var records = _get_filtered_records()
	_util_bars.clear()
	var w = ctrl.size.x; var h = ctrl.size.y
	const PL = 120.0; const PR = 60.0; const PT = 10.0; const PB = 10.0
	if w <= 0 or h <= 0: return
	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var emp_stats = _get_emp_stats(records)
	var filter_role = ""
	if _util_filter and _util_filter.selected > 0: filter_role = _util_filter.get_item_text(_util_filter.selected)
	var names = []; var utils = []; var working_d = []; var total_d = []
	for ename in emp_stats:
		var s = emp_stats[ename]
		if filter_role != "" and s["job_title"] != filter_role: continue
		var days = max(s["days"], 1)
		var util = (s["total_work_min"] / (float(days) * 480.0)) * 100.0
		names.append(ename); utils.append(util); working_d.append(s["assigned_days"]); total_d.append(days)
	if names.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var bar_h = 20.0; var row_h = 30.0
	var bw = w - PL - PR
	for i in range(names.size()):
		var by = PT + float(i) * row_h
		var util2 = utils[i]; var w_days = working_d[i]; var t_days = total_d[i]
		var working_w = (util2 / 100.0) * bw
		var idle_w = bw - working_w
		var wr = Rect2(PL, by, working_w, bar_h)
		var ir = Rect2(PL + working_w, by, idle_w, bar_h)
		ctrl.draw_rect(wr, COLOR_GREEN)
		ctrl.draw_rect(ir, Color(0.8, 0.8, 0.8, 1))
		var short = names[i].substr(0, min(names[i].length(), 14))
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, by + bar_h * 0.5 + 4), short, HORIZONTAL_ALIGNMENT_LEFT, PL - 4, 11, COLOR_DARK)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(PL + bw + 4, by + bar_h * 0.5 + 4), "%.0f%%" % util2, HORIZONTAL_ALIGNMENT_LEFT, PR - 4, 11, COLOR_DARK)
		_util_bars.append({"working_rect": wr, "idle_rect": ir, "name": names[i], "util_pct": util2, "working_days": w_days, "total_days": t_days})

func _on_util_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	for bd in _util_bars:
		if bd["working_rect"].has_point(mp) or bd["idle_rect"].has_point(mp):
			_show_tooltip_at(tr("REPORTS_PEOPLE_UTIL_TOOLTIP") % [bd["name"], bd["util_pct"], bd["working_days"], bd["total_days"]], _util_graph, mp)
			return
	_hide_tooltip()

# =====================================================================
#  BLOCK 6: PEOPLE TABLE
# =====================================================================

func _build_table_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_TABLE_TITLE")))
	var frow = HBoxContainer.new(); frow.add_theme_constant_override("separation", 8); vbox.add_child(frow)
	var flbl = Label.new(); flbl.text = tr("REPORTS_PEOPLE_FILTER_ROLE")
	flbl.add_theme_color_override("font_color", COLOR_GRAY); flbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(flbl, "regular"); frow.add_child(flbl)
	_table_filter = OptionButton.new()
	_table_filter.custom_minimum_size = Vector2(140, 0)
	_table_filter.focus_mode = Control.FOCUS_NONE
	_style_option_button(_table_filter)
	_table_filter.add_item(tr("REPORTS_PEOPLE_ALL_ROLES"))
	_table_filter.item_selected.connect(func(_i): _refresh_table())
	frow.add_child(_table_filter)
	_table_vbox = VBoxContainer.new()
	_table_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_table_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_table_vbox)
	var desc = Label.new()
	desc.text = tr("REPORTS_PEOPLE_TABLE_STATUS_DESC")
	desc.add_theme_color_override("font_color", COLOR_GRAY)
	desc.add_theme_font_size_override("font_size", 11)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if UITheme: UITheme.apply_font(desc, "regular")
	vbox.add_child(desc)
	return card

func _refresh_table():
	if not _table_vbox: return
	for c in _table_vbox.get_children(): c.queue_free()
	var records = _get_filtered_records()
	if records.is_empty(): _table_vbox.add_child(_make_no_data_label()); return
	var emp_stats = _get_emp_stats(records)
	var filter_role = ""
	if _table_filter and _table_filter.selected > 0: filter_role = _table_filter.get_item_text(_table_filter.selected)
	var rows = []
	for ename in emp_stats:
		var s = emp_stats[ename]
		if filter_role != "" and s["job_title"] != filter_role: continue
		var days = max(s["days"], 1)
		var avg_h = (s["total_work_min"] / float(days)) / 60.0
		var util  = (s["total_work_min"] / (float(days) * 480.0)) * 100.0
		var avg_mood    = s["total_mood"]    / float(days)
		var avg_burnout = s["total_burnout"] / float(days)
		var avg_progress = s.get("total_progress", 0.0) / float(days)
		var efficiency = avg_progress / max(s["daily_salary"], 0.01)
		var grade = 1
		for r in records:
			for emp in r.get("employees", []):
				if str(emp.get("name", "")) == ename: grade = int(emp.get("grade", 1))
		var status_score = 0
		if avg_mood > 60:    status_score += 1
		if avg_burnout < 30: status_score += 1
		if util > 40:        status_score += 1
		var status_dot = "🟢" if status_score == 3 else ("🟡" if status_score == 2 else "🔴")
		rows.append({"name": ename, "role": s["job_title"], "grade": grade, "salary": s["daily_salary"],
			"avg_hours": avg_h, "util": util, "mood": avg_mood, "burnout": avg_burnout, "status": status_dot,
			"avg_progress": avg_progress, "efficiency": efficiency})
	if rows.is_empty(): _table_vbox.add_child(_make_no_data_label()); return
	rows.sort_custom(func(a, b): return a["util"] > b["util"])
	_table_vbox.add_child(_build_table_header())
	for i in range(rows.size()):
		_table_vbox.add_child(_build_table_row(i + 1, rows[i], i % 2 == 0))

func _build_table_header() -> PanelContainer:
	var row = _make_table_row(Color(COLOR_BLUE.r, COLOR_BLUE.g, COLOR_BLUE.b, 0.1))
	var hbox = row[1] as HBoxContainer
	var cols = ["#", tr("REPORTS_PEOPLE_COL_NAME"), tr("REPORTS_PEOPLE_COL_ROLE"), tr("REPORTS_PEOPLE_COL_LVL"),
	tr("REPORTS_PEOPLE_COL_SALARY_DAY"), tr("REPORTS_PEOPLE_AVG_HOURS"), tr("REPORTS_PEOPLE_COL_UTIL"),
	tr("REPORTS_PEOPLE_COL_MOOD"), tr("REPORTS_PEOPLE_COL_BURNOUT"), tr("REPORTS_PEOPLE_COL_PTS_DAY"),
	tr("REPORTS_PEOPLE_COL_EFFICIENCY"), tr("REPORTS_PEOPLE_COL_STATUS")]
	var tooltips = ["", "", "", tr("REPORTS_PEOPLE_COL_LVL_TOOLTIP"), "", "", "", "", "", "", "", tr("REPORTS_PEOPLE_COL_STATUS_TOOLTIP")]
	var widths = [24, 120, 100, 40, 65, 65, 65, 55, 65, 60, 70, 45]
	for ci in range(cols.size()):
		var lbl = Label.new(); lbl.text = cols[ci]
		lbl.add_theme_color_override("font_color", COLOR_BLUE)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.custom_minimum_size = Vector2(widths[ci], 0)
		lbl.max_lines_visible = 1
		lbl.clip_text = true
		if UITheme: UITheme.apply_font(lbl, "bold")
		if tooltips[ci] != "": lbl.tooltip_text = tooltips[ci]
		hbox.add_child(lbl)
	return row[0] as PanelContainer       # ✅ return ПОСЛЕ цикла

func _build_table_row(rank: int, row: Dictionary, is_even: bool) -> PanelContainer:
	var bg = Color(1, 1, 1, 1) if is_even else Color(0.96, 0.97, 0.99, 1)
	var tr_row = _make_table_row(bg)
	var hbox = tr_row[1] as HBoxContainer
	var mood_c = COLOR_GREEN if row["mood"] > 60 else (COLOR_ORANGE if row["mood"] >= 40 else COLOR_RED)
	var burn_c = COLOR_GREEN if row["burnout"] < 20 else (COLOR_ORANGE if row["burnout"] <= 50 else COLOR_RED)
	var util_c = COLOR_GREEN if row["util"] >= 60 else (COLOR_ORANGE if row["util"] >= 30 else COLOR_RED)
	var vals = [str(rank), row["name"], row["role"], str(row["grade"]),
	"$%.0f" % row["salary"], "%.1f h" % row["avg_hours"], "%.0f%%" % row["util"],
	"%.0f" % row["mood"], "%.0f" % row["burnout"], "%.1f" % row.get("avg_progress", 0.0),
	"%.2f" % row.get("efficiency", 0.0), row["status"]]
	var colors = [COLOR_GRAY, COLOR_DARK, COLOR_GRAY, COLOR_DARK,
	COLOR_DARK, COLOR_DARK, util_c, mood_c, burn_c, COLOR_BLUE, COLOR_DARK, COLOR_DARK]
	var widths = [24, 120, 100, 40, 65, 65, 65, 55, 65, 60, 70, 45]
	for ci in range(vals.size()):
		var lbl = Label.new(); lbl.text = vals[ci]
		lbl.add_theme_color_override("font_color", colors[ci])
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.custom_minimum_size = Vector2(widths[ci], 0)
		lbl.max_lines_visible = 1
		lbl.clip_text = true
		if UITheme: UITheme.apply_font(lbl, "regular")
		hbox.add_child(lbl)
	return tr_row[0] as PanelContainer    # ✅ return ПОСЛЕ цикла

		# =====================================================================
		#  BLOCK 7: TEAM HEALTH TIMELINE
		# =====================================================================

func _build_health_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_PEOPLE_HEALTH_TITLE")))
	_health_graph = Control.new()
	_health_graph.custom_minimum_size = Vector2(0, 220)
	_health_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_graph.mouse_filter = Control.MOUSE_FILTER_STOP
	_health_graph.draw.connect(_draw_health_graph.bind(_health_graph))
	_health_graph.gui_input.connect(_on_health_gui_input)
	_health_graph.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_health_graph)
	vbox.add_child(_make_legend([
	{"label": tr("REPORTS_PEOPLE_HEALTH_MOOD"),    "color": COLOR_BLUE},
	{"label": tr("REPORTS_PEOPLE_HEALTH_BURNOUT"), "color": COLOR_RED},
	{"label": tr("REPORTS_PEOPLE_METRIC_ENERGY"),  "color": COLOR_GREEN},
	]))
	return card

func _draw_health_graph(ctrl: Control):
	var records = _get_filtered_records()
	var agg = _aggregate_health_records(records)
	_health_pts.clear()
	var w = ctrl.size.x; var h = ctrl.size.y
	const PL = 40.0; const PR = 20.0; const PT = 16.0; const PB = 30.0
	var gw = w - PL - PR; var gh = h - PT - PB
	if gw <= 0 or gh <= 0: return
	if agg.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 60, h * 0.5), tr("REPORTS_PEOPLE_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COLOR_GRAY)
		return
	var gc = Color(0.88, 0.88, 0.88, 1)
	for i in range(6):
		var frac = float(i) / 5.0; var gy = PT + frac * gh
		ctrl.draw_line(Vector2(PL, gy), Vector2(PL + gw, gy), gc, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 4), str(int(100 - frac * 100)), HORIZONTAL_ALIGNMENT_LEFT, PL - 4, 10, COLOR_GRAY)
	var n = agg.size()
	var mood_pts: PackedVector2Array = []; var burnout_pts: PackedVector2Array = []; var energy_pts: PackedVector2Array = []
	for j in range(n):
		var r = agg[j]
		var px = PL + (float(j) / max(n - 1, 1)) * gw
		var mood_v    = clampf(float(r.get("avg_mood", 0)), 0, 100)
		var burnout_v = clampf(float(r.get("avg_burnout", 0)), 0, 100)
		var energy_v  = clampf(float(r.get("avg_energy", 0)), 0, 100)
		mood_pts.append(   Vector2(px, PT + gh * (1.0 - mood_v / 100.0)))
		burnout_pts.append(Vector2(px, PT + gh * (1.0 - burnout_v / 100.0)))
		energy_pts.append( Vector2(px, PT + gh * (1.0 - energy_v / 100.0)))
		_health_pts.append({"pos": Vector2(px, PT + gh * 0.5), "day": r.get("day", j + 1),
		"label": r.get("label", "D%d" % r.get("day", j + 1)),
		"mood": mood_v, "burnout": burnout_v, "energy": energy_v})
	if mood_pts.size() >= 2:    ctrl.draw_polyline(mood_pts,    COLOR_BLUE,  2.0, true)
	if burnout_pts.size() >= 2: ctrl.draw_polyline(burnout_pts, COLOR_RED,   2.0, true)
	if energy_pts.size() >= 2:  ctrl.draw_polyline(energy_pts,  COLOR_GREEN, 2.0, true)
	for p in mood_pts:    ctrl.draw_circle(p, 3.0, COLOR_BLUE)
	for p2 in burnout_pts: ctrl.draw_circle(p2, 3.0, COLOR_RED)
	for p3 in energy_pts:  ctrl.draw_circle(p3, 3.0, COLOR_GREEN)
	var step = max(1, int(ceil(float(n) / 10.0)))
	for xi in range(0, n, step):
		var px = PL + (float(xi) / max(n - 1, 1)) * gw
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px - 8, h - 6), str(agg[xi].get("label", "D%d" % agg[xi].get("day", xi + 1))), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRAY)

func _on_health_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	var bd = 30.0; var bi = -1
	for i in range(_health_pts.size()):
		var d = abs(mp.x - _health_pts[i]["pos"].x)
		if d < bd: bd = d; bi = i
	if bi >= 0:
		var p = _health_pts[bi]
		_show_tooltip_at(tr("REPORTS_PEOPLE_HEALTH_TOOLTIP") % [p["day"], p["mood"], p["burnout"], p["energy"]], _health_graph, mp)
	else: _hide_tooltip()

# =====================================================================
# HELPERS
# =====================================================================

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
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left",   16); m.add_theme_constant_override("margin_top",    12)
	m.add_theme_constant_override("margin_right",  16); m.add_theme_constant_override("margin_bottom", 12)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	return m

func _make_title(text: String) -> Label:
	var lbl = Label.new(); lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	return lbl

func _make_table_row(bg_color: Color) -> Array:
	var pc = PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s = StyleBoxFlat.new(); s.bg_color = bg_color
	pc.add_theme_stylebox_override("panel", s)
	var m = MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8); m.add_theme_constant_override("margin_top", 3)
	m.add_theme_constant_override("margin_right", 8); m.add_theme_constant_override("margin_bottom", 3)
	pc.add_child(m)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	m.add_child(hbox)
	return [pc, hbox]

func _make_legend(items: Array) -> HBoxContainer:
	var hbox = HBoxContainer.new(); hbox.add_theme_constant_override("separation", 16)
	for item in items:
		var row = HBoxContainer.new(); row.add_theme_constant_override("separation", 4)
		var rect = ColorRect.new(); rect.custom_minimum_size = Vector2(12, 12); rect.color = item["color"]
		row.add_child(rect)
		var lbl = Label.new(); lbl.text = item["label"]
		lbl.add_theme_color_override("font_color", COLOR_DARK); lbl.add_theme_font_size_override("font_size", 11)
		if UITheme: UITheme.apply_font(lbl, "regular"); row.add_child(lbl)
		hbox.add_child(row)
	return hbox

func _make_no_data_label() -> Label:
	var lbl = Label.new(); lbl.text = tr("REPORTS_PEOPLE_NO_DATA")
	lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(lbl, "regular")
	return lbl

func _format_money(amount: int) -> String:
	var s = str(abs(amount)); var r = ""; var c = 0
	for i in range(s.length() - 1, -1, -1):
		if c > 0 and c % 3 == 0: r = "," + r
		r = s[i] + r; c += 1
	return r

func _shorten_role(role: String) -> String:
	if role.length() <= 12: return role
	return role.substr(0, 11) + "\u2026"

func _role_color(role: String) -> Color:
	var r = role.to_lower()
	if "dev" in r or "backend" in r or "frontend" in r: return COLOR_BLUE
	if "qa" in r or "test" in r: return COLOR_GREEN
	if "analyst" in r or " ba" in r: return COLOR_ORANGE
	if "designer" in r or "design" in r: return Color(0.7, 0.3, 0.8, 1)
	return COLOR_GRAY

func _populate_role_filters():
	var all_roles: Array = []
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if not is_instance_valid(npc) or not npc.data: continue
		var jt = str(npc.data.job_title)
		if jt != "" and not jt in all_roles: all_roles.append(jt)
	for r in PeopleHistory.daily_records:
		for emp in r.get("employees", []):
			var jt = str(emp.get("job_title", ""))
			if jt != "" and not jt in all_roles: all_roles.append(jt)
	all_roles.sort()
	var filters = [_scatter_filter, _bars_filter, _multiline_filter, _util_filter, _table_filter]
	for btn in filters:
		if not btn: continue
		var prev_role = ""
		if btn.selected > 0: prev_role = btn.get_item_text(btn.selected)
		btn.clear()
		btn.add_item(tr("REPORTS_PEOPLE_ALL_ROLES"))
		for role in all_roles: btn.add_item(role)
		if prev_role != "":
			for i in range(btn.item_count):
				if btn.get_item_text(i) == prev_role:
					btn.select(i)
					break

# =====================================================================
# REFRESH
# =====================================================================

func refresh():
	_update_period_range_label()
	_refresh_all()

func _refresh_all():
	_populate_role_filters()
	_refresh_kpi()
	_refresh_scatter()
	_refresh_bars()
	_refresh_multiline()
	_refresh_util()
	_refresh_table()
	if _health_graph: _health_graph.queue_redraw()
