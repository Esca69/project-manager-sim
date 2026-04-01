extends Control

# === FINANCIAL REPORTS TAB — FULL REDESIGN ===
# CEO-level dashboard: sliding windows, tooltips, new KPIs, new charts.

const COLOR_BLUE      = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN     = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED       = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE    = Color(1.0, 0.55, 0.0, 1)
const COLOR_GRAY      = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK      = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE     = Color(1, 1, 1, 1)
const COLOR_SALARIES  = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_PM_SAL    = Color(1.0, 0.55, 0.0, 1)
const COLOR_PENALTIES = Color(0.7, 0.1, 0.1, 1)
const COLOR_OFFICE    = Color(0.9, 0.5, 0.1, 1)
const COLOR_SERVICES  = Color(0.3, 0.5, 0.9, 1)

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

var _kpi_row1 : HBoxContainer
var _kpi_row2 : HBoxContainer

var _cash_flow_graph     : Control
var _cumul_profit_graph  : Control
var _income_bar          : Control
var _expense_bar         : Control
var _expense_trend_chart : Control
var _daily_bars_chart    : Control

var _pnl_vbox        : VBoxContainer
var _pnl_month_index : int = 0
var _pnl_prev_btn    : Button
var _pnl_next_btn    : Button
var _pnl_month_label : Label

var _roi_chart       : Control
var _roi_scroll      : ScrollContainer
var _roi_count_label : Label

var _tooltip_panel : PanelContainer
var _tooltip_label : Label

var _cf_agg  : Array              = []
var _cf_pts  : PackedVector2Array = []
var _cp_agg  : Array              = []
var _cp_pts  : PackedVector2Array = []
var _income_segs     : Array = []
var _expense_segs    : Array = []
var _trend_col_segs  : Array = []
var _daily_bars_data : Array = []
var _roi_bars_data   : Array = []

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
	vbox.add_child(_build_kpi_card())
	vbox.add_child(_build_cash_flow_card())
	vbox.add_child(_build_cumulative_profit_card())
	vbox.add_child(_build_structure_card())
	vbox.add_child(_build_expense_trend_card())
	vbox.add_child(_build_daily_bars_card())
	vbox.add_child(_build_pnl_card())
	vbox.add_child(_build_roi_card())
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
	var periods = [[tr("REPORTS_PERIOD_7D"), PERIOD_7D], [tr("REPORTS_PERIOD_30D"), PERIOD_30D], [tr("REPORTS_PERIOD_90D"), PERIOD_90D], [tr("REPORTS_PERIOD_ALL_SHORT"), PERIOD_ALL]]
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

func _on_period_selected(code: int):
	_selected_period = code
	_period_offset = 0
	for entry in _period_buttons:
		_style_period_btn(entry["btn"], entry["code"] == code)
	_update_period_range_label()
	_refresh_all_charts()

func _on_period_nav_prev():
	_period_offset += 1
	_update_period_range_label()
	_refresh_all_charts()

func _on_period_nav_next():
	if _period_offset > 0:
		_period_offset -= 1
		_update_period_range_label()
		_refresh_all_charts()

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
	var all = FinancialHistory.daily_records
	if all.is_empty(): return []
	var b = _get_period_bounds()
	var result = []
	for r in all:
		var d = int(r.get("day", 0))
		if d >= b[0] and d <= b[1]:
			result.append(r)
	return result

func _get_prev_period_records() -> Array:
	if _selected_period == PERIOD_ALL: return []
	var all = FinancialHistory.daily_records
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

func _aggregate_records(records: Array) -> Array:
	match _selected_period:
		PERIOD_90D:
			var weeks: Dictionary = {}
			for r in records:
				var d  = int(r.get("day", 0))
				var wn = GameTime.get_week_number(d)
				if not weeks.has(wn):
					weeks[wn] = {
						"income": 0, "expenses": 0, "balance": 0,
						"salary_total": 0, "pm_salary": 0, "penalties": 0,
						"office_costs": 0, "service_costs": 0,
						"day": GameTime.get_week_start_day(wn),
						"label": "W%d" % wn, "_lb": 0
					}
				weeks[wn]["income"]        += int(r.get("income", 0))
				weeks[wn]["expenses"]      += int(r.get("expenses", 0))
				weeks[wn]["salary_total"]  += int(r.get("salary_total", 0))
				weeks[wn]["pm_salary"]     += int(r.get("pm_salary", 0))
				weeks[wn]["penalties"]     += int(r.get("penalties", 0))
				weeks[wn]["office_costs"]  += int(r.get("office_costs", 0))
				weeks[wn]["service_costs"] += int(r.get("service_costs", 0))
				weeks[wn]["_lb"]            = int(r.get("balance", 0))
			var keys = weeks.keys(); keys.sort()
			var res = []
			for k in keys:
				var g = weeks[k]; g["balance"] = g["_lb"]; res.append(g)
			return res
		PERIOD_ALL:
			var months: Dictionary = {}
			for r in records:
				var d  = int(r.get("day", 0))
				var mn = GameTime.get_month(d)
				if not months.has(mn):
					months[mn] = {
						"income": 0, "expenses": 0, "balance": 0,
						"salary_total": 0, "pm_salary": 0, "penalties": 0,
						"office_costs": 0, "service_costs": 0,
						"day": GameTime.get_month_start_day(mn),
						"label": "M%d" % mn, "_lb": 0
					}
				months[mn]["income"]        += int(r.get("income", 0))
				months[mn]["expenses"]      += int(r.get("expenses", 0))
				months[mn]["salary_total"]  += int(r.get("salary_total", 0))
				months[mn]["pm_salary"]     += int(r.get("pm_salary", 0))
				months[mn]["penalties"]     += int(r.get("penalties", 0))
				months[mn]["office_costs"]  += int(r.get("office_costs", 0))
				months[mn]["service_costs"] += int(r.get("service_costs", 0))
				months[mn]["_lb"]            = int(r.get("balance", 0))
			var keys = months.keys(); keys.sort()
			var res = []
			for k in keys:
				var g = months[k]; g["balance"] = g["_lb"]; res.append(g)
			return res
	var labeled = []
	for r in records:
		var rc = r.duplicate()
		rc["label"] = "D%d" % int(r.get("day", 0))
		labeled.append(rc)
	return labeled

func _refresh_all_charts():
	_refresh_kpi()
	_refresh_cash_flow()
	_refresh_cumulative_profit()
	_refresh_structure()
	_refresh_expense_trend()
	_refresh_daily_bars()
	_refresh_roi()

func refresh():
	_update_period_range_label()
	_refresh_all_charts()
	_refresh_pnl()

# =====================================================================
#  WIDGET 0: KPI CARDS (2 rows)
# =====================================================================

func _build_kpi_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	vbox.add_child(_make_title(tr("REPORTS_KPI_TITLE")))
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
	for c in _kpi_row2.get_children(): c.queue_free()
	var records = _get_filtered_records()
	var prev_r  = _get_prev_period_records()
	var cur_inc = 0; var cur_exp = 0; var cur_done = 0; var cur_fail = 0
	var bal_first = INF; var bal_last = 0
	for r in records:
		cur_inc  += int(r.get("income", 0))
		cur_exp  += int(r.get("expenses", 0))
		cur_done += int(r.get("projects_completed", 0))
		cur_fail += int(r.get("projects_failed", 0))
		var b = int(r.get("balance", 0))
		if bal_first == INF: bal_first = b
		bal_last = b
	if bal_first == INF: bal_first = 0
	var cur_profit = cur_inc - cur_exp
	var cur_margin = 0.0
	if cur_inc > 0: cur_margin = float(cur_profit) / float(cur_inc) * 100.0
	var days_n = max(1, records.size())
	var cur_burn = float(cur_exp) / float(days_n)
	var balance_now = 0
	if GameState: balance_now = GameState.company_balance
	var runway = 0
	if cur_burn > 0.001: runway = int(float(balance_now) / cur_burn)
	var bal_delta = bal_last - int(bal_first)
	var prev_inc = 0; var prev_exp = 0; var prev_done = 0; var prev_fail = 0
	var pbf = INF; var pbl = 0
	for r in prev_r:
		prev_inc  += int(r.get("income", 0))
		prev_exp  += int(r.get("expenses", 0))
		prev_done += int(r.get("projects_completed", 0))
		prev_fail += int(r.get("projects_failed", 0))
		var b = int(r.get("balance", 0))
		if pbf == INF: pbf = b
		pbl = b
	if pbf == INF: pbf = 0
	var prev_profit = prev_inc - prev_exp
	var prev_margin = 0.0
	if prev_inc > 0: prev_margin = float(prev_profit) / float(prev_inc) * 100.0
	var prev_days = max(1, prev_r.size())
	var prev_burn = float(prev_exp) / float(prev_days)
	var prev_bal_delta = pbl - int(pbf)
	_kpi_row1.add_child(_kpi_balance(balance_now, bal_delta, prev_bal_delta))
	_kpi_row1.add_child(_kpi_money("💰", tr("REPORTS_KPI_INCOME"),   cur_inc,    prev_inc,    false))
	_kpi_row1.add_child(_kpi_money("💸", tr("REPORTS_KPI_EXPENSES"), cur_exp,    prev_exp,    false))
	_kpi_row1.add_child(_kpi_money("📈", tr("REPORTS_KPI_PROFIT"),   cur_profit, prev_profit, true))
	_kpi_row1.add_child(_kpi_margin(cur_margin, prev_margin))
	_kpi_row2.add_child(_kpi_burn_rate(cur_burn, prev_burn))
	_kpi_row2.add_child(_kpi_runway(runway))
	_kpi_row2.add_child(_kpi_count("✅", tr("REPORTS_KPI_PROJECTS_DONE"),   cur_done, prev_done))
	_kpi_row2.add_child(_kpi_count("❌", tr("REPORTS_KPI_PROJECTS_FAILED"), cur_fail, prev_fail))
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kpi_row2.add_child(sp)

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

func _kpi_balance(balance: int, delta: int, prev_delta: int) -> PanelContainer:
	var p = _kpi_panel(); var vb = _kpi_inner(p)
	_kpi_head(vb, "💵", tr("REPORTS_KPI_BALANCE"))
	_kpi_val(vb, "$" + _format_money(balance), COLOR_DARK)
	var s = "+" if delta >= 0 else ""
	_kpi_delta(vb, s + "$" + _format_money(delta) + " " + tr("REPORTS_PERIOD_CHANGE"), COLOR_GREEN if delta >= 0 else COLOR_RED)
	return p

func _kpi_money(icon: String, lbl: String, value: int, prev: int, signed: bool) -> PanelContainer:
	var p = _kpi_panel(); var vb = _kpi_inner(p)
	_kpi_head(vb, icon, lbl)
	var vt = "$" + _format_money(value)
	var vc = COLOR_DARK
	if signed:
		vt = ("+" if value >= 0 else "-") + "$" + _format_money(abs(value))
		vc = COLOR_GREEN if value >= 0 else COLOR_RED
	_kpi_val(vb, vt, vc)
	var d = _kpi_pct(value, prev, not signed or value >= 0)
	_kpi_delta(vb, d[0], d[1])
	return p

func _kpi_margin(margin: float, prev_margin: float) -> PanelContainer:
	var p = _kpi_panel(); var vb = _kpi_inner(p)
	_kpi_head(vb, "📊", tr("REPORTS_KPI_MARGIN_PCT"))
	_kpi_val(vb, "%.1f%%" % margin, COLOR_GREEN if margin >= 0 else COLOR_RED)
	var pp = margin - prev_margin
	var s = "+" if pp >= 0 else ""
	_kpi_delta(vb, s + "%.1fpp " % pp + tr("REPORTS_VS_PREV"), COLOR_GREEN if pp >= 0 else COLOR_RED)
	return p

func _kpi_burn_rate(burn: float, prev_burn: float) -> PanelContainer:
	var p = _kpi_panel(); var vb = _kpi_inner(p)
	_kpi_head(vb, "📉", tr("REPORTS_KPI_BURN_RATE"))
	_kpi_val(vb, "$%s/%s" % [_format_money(int(burn)), tr("REPORTS_DAY")], COLOR_DARK)
	if prev_burn < 0.001:
		_kpi_delta(vb, tr("REPORTS_VS_PREV"), COLOR_GRAY)
	else:
		var diff = burn - prev_burn
		var pct  = int(round(diff / abs(prev_burn) * 100.0))
		var s = "+" if pct >= 0 else ""
		_kpi_delta(vb, s + str(pct) + "% " + tr("REPORTS_VS_PREV"), COLOR_RED if pct > 0 else COLOR_GREEN)
	return p

func _kpi_runway(runway_days: int) -> PanelContainer:
	var p = _kpi_panel(); var vb = _kpi_inner(p)
	_kpi_head(vb, "🏦", tr("REPORTS_KPI_RUNWAY"))
	var rc = COLOR_GREEN if runway_days > 30 else (COLOR_ORANGE if runway_days > 7 else COLOR_RED)
	_kpi_val(vb, str(runway_days) + " " + tr("REPORTS_DAYS"), rc)
	_kpi_delta(vb, tr("REPORTS_DAYS_UNTIL_BANKRUPTCY"), COLOR_GRAY)
	return p

func _kpi_count(icon: String, lbl: String, value: int, prev: int) -> PanelContainer:
	var p = _kpi_panel(); var vb = _kpi_inner(p)
	_kpi_head(vb, icon, lbl)
	_kpi_val(vb, str(value), COLOR_DARK)
	var d = _kpi_pct(value, prev, true)
	_kpi_delta(vb, d[0], d[1])
	return p

# =====================================================================
#  WIDGET 1: CASH FLOW
# =====================================================================

func _build_cash_flow_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title("📈 " + tr("REPORTS_CASH_FLOW")))
	_cash_flow_graph = Control.new()
	_cash_flow_graph.custom_minimum_size = Vector2(0, 250)
	_cash_flow_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cash_flow_graph.mouse_filter = Control.MOUSE_FILTER_STOP
	_cash_flow_graph.draw.connect(_draw_cash_flow.bind(_cash_flow_graph))
	_cash_flow_graph.gui_input.connect(_on_cf_gui_input)
	_cash_flow_graph.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_cash_flow_graph)
	return card

func _refresh_cash_flow():
	if _cash_flow_graph: _cash_flow_graph.queue_redraw()

func _draw_cash_flow(ctrl: Control):
	var records = _get_filtered_records()
	var agg = _aggregate_records(records)
	_cf_agg = agg; _cf_pts.clear()
	var w = ctrl.size.x; var h = ctrl.size.y
	const PL = 80.0; const PR = 20.0; const PT = 20.0; const PB = 40.0
	var gw = w - PL - PR; var gh = h - PT - PB
	if agg.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w*0.5-40, h*0.5), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var values: Array = []
	for r in agg: values.append(int(r.get("balance", 0)))
	var mn = values.min(); var mx = values.max()
	if mn == mx: mn -= 1000; mx += 1000
	var pad = max(float(mx - mn) * 0.1, 100.0)
	var cmin = mn - pad; var cmax = mx + pad; var crange = float(cmax - cmin)
	var gc = Color(0.88, 0.88, 0.88, 1); var last_l = ""
	for i in range(6):
		var frac = float(i) / 5.0; var gy = PT + frac * gh
		ctrl.draw_line(Vector2(PL, gy), Vector2(PL + gw, gy), gc, 1)
		var v = int(cmax - frac * crange); var ls = _format_money_axis(v)
		if ls != last_l:
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy+5), ls, HORIZONTAL_ALIGNMENT_LEFT, PL-4, 11, COLOR_GRAY)
			last_l = ls
	if cmin < 0 and cmax > 0:
		var zy = PT + gh * (1.0 - (0 - cmin) / crange)
		ctrl.draw_line(Vector2(PL, zy), Vector2(PL+gw, zy), Color(0.9, 0.3, 0.3, 0.6), 1.5)
	var n = values.size()
	var pts: PackedVector2Array = []
	for i in range(n):
		var px = PL + (float(i) / max(n-1, 1)) * gw
		var py = PT + gh * (1.0 - (values[i] - cmin) / crange)
		pts.append(Vector2(px, py))
	_cf_pts = pts
	var base_y = clampf(PT + gh * (1.0 - (0 - cmin) / crange), PT, PT+gh)
	var fp: PackedVector2Array = []
	fp.append(Vector2(pts[0].x, base_y)); for p in pts: fp.append(p); fp.append(Vector2(pts[n-1].x, base_y))
	ctrl.draw_colored_polygon(fp, Color(COLOR_BLUE.r, COLOR_BLUE.g, COLOR_BLUE.b, 0.15))
	if cmin < 0:
		var rp: PackedVector2Array = []
		rp.append(Vector2(pts[0].x, base_y))
		for i in range(n):
			if values[i] < 0:
				rp.append(pts[i])
			elif i > 0 and values[i-1] < 0:
				var t = float(-values[i-1]) / float(values[i] - values[i-1])
				rp.append(Vector2(pts[i-1].x + t*(pts[i].x - pts[i-1].x), base_y))
		if rp.size() > 2:
			rp.append(Vector2(rp[rp.size()-1].x, base_y))
			ctrl.draw_colored_polygon(rp, Color(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.2))
	if pts.size() >= 2: ctrl.draw_polyline(pts, COLOR_BLUE, 2.0, true)
	for p in pts: ctrl.draw_circle(p, 3.5, COLOR_BLUE)
	var step = _x_step(n)
	for i in range(0, n, step):
		var px = PL + (float(i) / max(n-1, 1)) * gw
		var xl = agg[i].get("label", "D%d" % int(agg[i].get("day", i+1)))
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px-12, h-8), xl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_GRAY)

func _on_cf_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	if _cf_pts.is_empty() or _cf_agg.is_empty(): return
	var bd = 21.0; var bi = -1
	for i in range(_cf_pts.size()):
		var d = mp.distance_to(_cf_pts[i])
		if d < bd: bd = d; bi = i
	if bi >= 0:
		var r = _cf_agg[bi]
		var xl = r.get("label", "D%d" % int(r.get("day", 0)))
		_show_tooltip_at("%s: $%s" % [xl, _format_money(int(r.get("balance", 0)))], _cash_flow_graph, mp)
	else: _hide_tooltip()

# =====================================================================
#  WIDGET 2: CUMULATIVE PROFIT (NEW)
# =====================================================================

func _build_cumulative_profit_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title("📉 " + tr("REPORTS_CUMULATIVE_PROFIT")))
	_cumul_profit_graph = Control.new()
	_cumul_profit_graph.custom_minimum_size = Vector2(0, 200)
	_cumul_profit_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cumul_profit_graph.mouse_filter = Control.MOUSE_FILTER_STOP
	_cumul_profit_graph.draw.connect(_draw_cumulative_profit.bind(_cumul_profit_graph))
	_cumul_profit_graph.gui_input.connect(_on_cp_gui_input)
	_cumul_profit_graph.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_cumul_profit_graph)
	return card

func _refresh_cumulative_profit():
	if _cumul_profit_graph: _cumul_profit_graph.queue_redraw()

func _draw_cumulative_profit(ctrl: Control):
	var records = _get_filtered_records()
	_cp_agg = records; _cp_pts.clear()
	var w = ctrl.size.x; var h = ctrl.size.y
	const PL = 80.0; const PR = 20.0; const PT = 20.0; const PB = 40.0
	var gw = w - PL - PR; var gh = h - PT - PB
	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w*0.5-40, h*0.5), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var cum: Array = []; var running = 0
	for r in records:
		running += int(r.get("income", 0)) - int(r.get("expenses", 0))
		cum.append(running)
	var mn = cum.min(); var mx = cum.max()
	if mn == mx: mn -= 1000; mx += 1000
	var pad = max(float(mx - mn) * 0.1, 100.0)
	var cmin = mn - pad; var cmax = mx + pad; var crange = float(cmax - cmin)
	var last_v = cum[cum.size()-1]
	var lc = COLOR_GREEN if last_v >= 0 else COLOR_RED
	var gc = Color(0.88, 0.88, 0.88, 1); var last_l = ""
	for i in range(6):
		var frac = float(i) / 5.0; var gy = PT + frac * gh
		ctrl.draw_line(Vector2(PL, gy), Vector2(PL+gw, gy), gc, 1)
		var v = int(cmax - frac * crange); var ls = _format_money_axis(v)
		if ls != last_l:
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy+5), ls, HORIZONTAL_ALIGNMENT_LEFT, PL-4, 11, COLOR_GRAY)
			last_l = ls
	if cmin < 0 and cmax > 0:
		var zy = PT + gh * (1.0 - (0 - cmin) / crange)
		ctrl.draw_line(Vector2(PL, zy), Vector2(PL+gw, zy), Color(0.5, 0.5, 0.5, 0.5), 1.5)
	var n = cum.size()
	var pts: PackedVector2Array = []
	for i in range(n):
		var px = PL + (float(i) / max(n-1, 1)) * gw
		var py = PT + gh * (1.0 - (cum[i] - cmin) / crange)
		pts.append(Vector2(px, py))
	_cp_pts = pts
	var base_y = clampf(PT + gh * (1.0 - (0 - cmin) / crange), PT, PT+gh)
	var fp: PackedVector2Array = []
	fp.append(Vector2(pts[0].x, base_y)); for p in pts: fp.append(p); fp.append(Vector2(pts[n-1].x, base_y))
	ctrl.draw_colored_polygon(fp, Color(lc.r, lc.g, lc.b, 0.15))
	if pts.size() >= 2: ctrl.draw_polyline(pts, lc, 2.0, true)
	for p in pts: ctrl.draw_circle(p, 3.0, lc)
	var step = _x_step(n)
	for i in range(0, n, step):
		var px = PL + (float(i) / max(n-1, 1)) * gw
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px-12, h-8),
			"D%d" % int(records[i].get("day", i+1)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_GRAY)

func _on_cp_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	if _cp_pts.is_empty() or _cp_agg.is_empty(): return
	var bd = 21.0; var bi = -1
	for i in range(_cp_pts.size()):
		var d = mp.distance_to(_cp_pts[i])
		if d < bd: bd = d; bi = i
	if bi >= 0:
		var cum = 0
		for j in range(bi + 1):
			cum += int(_cp_agg[j].get("income", 0)) - int(_cp_agg[j].get("expenses", 0))
		var dn = int(_cp_agg[bi].get("day", 0))
		var s = "+" if cum >= 0 else "-"
		_show_tooltip_at(tr("REPORTS_CUMUL_PROFIT_TOOLTIP") % [dn, s, _format_money(abs(cum))], _cumul_profit_graph, mp)
	else: _hide_tooltip()

# =====================================================================
#  WIDGET 3: INCOME / EXPENSE STRUCTURE
# =====================================================================

func _build_structure_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 6); margin.add_child(vbox)
	vbox.add_child(_make_title("💰 " + tr("REPORTS_INCOME_STRUCTURE") + " / " + tr("REPORTS_EXPENSE_STRUCTURE")))
	var il = Label.new(); il.text = tr("REPORTS_INCOME_STRUCTURE")
	il.add_theme_color_override("font_color", COLOR_GREEN); il.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(il, "semibold"); vbox.add_child(il)
	_income_bar = Control.new()
	_income_bar.custom_minimum_size = Vector2(0, 32)
	_income_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_income_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_income_bar.draw.connect(_draw_income_bar.bind(_income_bar))
	_income_bar.gui_input.connect(_on_income_bar_input)
	_income_bar.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_income_bar)
	var el = Label.new(); el.text = tr("REPORTS_EXPENSE_STRUCTURE")
	el.add_theme_color_override("font_color", COLOR_RED); el.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(el, "semibold"); vbox.add_child(el)
	_expense_bar = Control.new()
	_expense_bar.custom_minimum_size = Vector2(0, 32)
	_expense_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expense_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_expense_bar.draw.connect(_draw_expense_bar.bind(_expense_bar))
	_expense_bar.gui_input.connect(_on_expense_bar_input)
	_expense_bar.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_expense_bar)
	var legend = HBoxContainer.new(); legend.add_theme_constant_override("separation", 16); vbox.add_child(legend)
	var sd_list = [
		["REPORTS_PROJECT_INCOME", COLOR_GREEN], ["REPORTS_SALARIES", COLOR_SALARIES],
		["REPORTS_PM_SALARY", COLOR_PM_SAL], ["REPORTS_PENALTIES", COLOR_PENALTIES],
		["REPORTS_OFFICE", COLOR_OFFICE], ["REPORTS_SERVICES", COLOR_SERVICES],
	]
	for sd in sd_list:
		var item = HBoxContainer.new(); item.add_theme_constant_override("separation", 4)
		var rect = ColorRect.new(); rect.custom_minimum_size = Vector2(12, 12); rect.color = sd[1]; item.add_child(rect)
		var lbl = Label.new(); lbl.text = tr(sd[0])
		lbl.add_theme_color_override("font_color", COLOR_DARK); lbl.add_theme_font_size_override("font_size", 11)
		if UITheme: UITheme.apply_font(lbl, "regular"); item.add_child(lbl); legend.add_child(item)
	return card

func _refresh_structure():
	if _income_bar:  _income_bar.queue_redraw()
	if _expense_bar: _expense_bar.queue_redraw()

func _draw_income_bar(ctrl: Control):
	_income_segs.clear()
	var records = _get_filtered_records(); var w = ctrl.size.x; var h = ctrl.size.y
	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, 20), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GRAY)
		return
	var total = 0; for r in records: total += int(r.get("income", 0))
	_draw_stacked_bar_labeled(ctrl, [{"label": tr("REPORTS_PROJECT_INCOME"), "value": total, "color": COLOR_GREEN}], max(total, 1), 0.0, 0.0, w, h, _income_segs)

func _draw_expense_bar(ctrl: Control):
	_expense_segs.clear()
	var records = _get_filtered_records(); var w = ctrl.size.x; var h = ctrl.size.y
	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, 20), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GRAY)
		return
	var sal = 0; var pm = 0; var pen = 0; var off = 0; var svc = 0
	for r in records:
		sal += int(r.get("salary_total", 0)) - int(r.get("pm_salary", 0))
		pm  += int(r.get("pm_salary", 0))
		pen += int(r.get("penalties", 0))
		off += int(r.get("office_costs", 0))
		svc += int(r.get("service_costs", 0))
	var total = sal + pm + pen + off + svc
	_draw_stacked_bar_labeled(ctrl, [
		{"label": tr("REPORTS_SALARIES"),  "value": sal, "color": COLOR_SALARIES},
		{"label": tr("REPORTS_PM_SALARY"), "value": pm,  "color": COLOR_PM_SAL},
		{"label": tr("REPORTS_PENALTIES"), "value": pen, "color": COLOR_PENALTIES},
		{"label": tr("REPORTS_OFFICE"),    "value": off, "color": COLOR_OFFICE},
		{"label": tr("REPORTS_SERVICES"),  "value": svc, "color": COLOR_SERVICES},
	], max(total, 1), 0.0, 0.0, w, h, _expense_segs)

func _draw_stacked_bar_labeled(ctrl: Control, segs: Array, total: float,
		x: float, y: float, w: float, h: float, out_rects: Array):
	if total <= 0: ctrl.draw_rect(Rect2(x, y, w, h), Color(0.92, 0.92, 0.92, 1)); return
	var cx = x
	for seg in segs:
		var val = float(seg.get("value", 0))
		if val <= 0: continue
		var sw = (val / total) * w
		var rect = Rect2(cx, y, sw, h)
		ctrl.draw_rect(rect, seg["color"])
		out_rects.append({"rect": rect, "label": seg["label"], "value": int(val), "total": int(total)})
		if sw >= 60:
			var pct = int(round(val / total * 100.0))
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(cx+4, y+h*0.5+5),
				"$%s (%d%%)" % [_format_money_short(int(val)), pct], HORIZONTAL_ALIGNMENT_LEFT, sw-8, 11, COLOR_WHITE)
		cx += sw

func _on_income_bar_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	for sd in _income_segs:
		if sd["rect"].has_point(mp):
			var pct = int(round(float(sd["value"]) / float(max(sd["total"], 1)) * 100.0))
			_show_tooltip_at("%s: $%s (%d%%)" % [sd["label"], _format_money(sd["value"]), pct], _income_bar, mp); return
	_hide_tooltip()

func _on_expense_bar_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	for sd in _expense_segs:
		if sd["rect"].has_point(mp):
			var pct = int(round(float(sd["value"]) / float(max(sd["total"], 1)) * 100.0))
			_show_tooltip_at("%s: $%s (%d%%)" % [sd["label"], _format_money(sd["value"]), pct], _expense_bar, mp); return
	_hide_tooltip()

# =====================================================================
#  WIDGET 4: EXPENSE BREAKDOWN TREND (NEW)
# =====================================================================

func _build_expense_trend_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title("📊 " + tr("REPORTS_EXPENSE_BREAKDOWN_TREND")))
	_expense_trend_chart = Control.new()
	_expense_trend_chart.custom_minimum_size = Vector2(0, 200)
	_expense_trend_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expense_trend_chart.mouse_filter = Control.MOUSE_FILTER_STOP
	_expense_trend_chart.draw.connect(_draw_expense_trend.bind(_expense_trend_chart))
	_expense_trend_chart.gui_input.connect(_on_exp_trend_gui_input)
	_expense_trend_chart.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_expense_trend_chart)
	var legend = HBoxContainer.new(); legend.add_theme_constant_override("separation", 12); vbox.add_child(legend)
	var sd_list = [
		["REPORTS_SALARIES", COLOR_SALARIES], ["REPORTS_PM_SALARY", COLOR_PM_SAL],
		["REPORTS_PENALTIES", COLOR_PENALTIES], ["REPORTS_OFFICE", COLOR_OFFICE],
		["REPORTS_SERVICES", COLOR_SERVICES],
	]
	for sd in sd_list:
		var item = HBoxContainer.new(); item.add_theme_constant_override("separation", 4)
		var rect = ColorRect.new(); rect.custom_minimum_size = Vector2(12, 12); rect.color = sd[1]; item.add_child(rect)
		var lbl = Label.new(); lbl.text = tr(sd[0])
		lbl.add_theme_color_override("font_color", COLOR_DARK); lbl.add_theme_font_size_override("font_size", 11)
		if UITheme: UITheme.apply_font(lbl, "regular"); item.add_child(lbl); legend.add_child(item)
	return card

func _refresh_expense_trend():
	if _expense_trend_chart: _expense_trend_chart.queue_redraw()

func _draw_expense_trend(ctrl: Control):
	var records = _get_filtered_records()
	var groups  = _aggregate_records(records)
	_trend_col_segs.clear()
	var w = ctrl.size.x; var h = ctrl.size.y
	const PL = 80.0; const PR = 10.0; const PT = 16.0; const PB = 30.0
	var gw = w - PL - PR; var gh = h - PT - PB
	if groups.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w*0.5-40, h*0.5), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var max_exp = 1
	for g in groups:
		var t = (int(g.get("salary_total", 0)) - int(g.get("pm_salary", 0))) + int(g.get("pm_salary", 0)) + int(g.get("penalties", 0)) + int(g.get("office_costs", 0)) + int(g.get("service_costs", 0))
		max_exp = max(max_exp, t)
	var gc = Color(0.88, 0.88, 0.88, 1)
	for i in range(5):
		var frac = float(i) / 4.0; var gy = PT + frac * gh
		ctrl.draw_line(Vector2(PL, gy), Vector2(PL+gw, gy), gc, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy+5),
			"$%s" % _format_money_short(int(max_exp * (1.0-frac))), HORIZONTAL_ALIGNMENT_LEFT, PL-4, 10, COLOR_GRAY)
	var n = groups.size(); var slot_w = gw / float(n)
	var bar_m = slot_w * 0.1; var bar_w = slot_w - bar_m * 2
	for i in range(n):
		var g   = groups[i]
		var sal = int(g.get("salary_total", 0)) - int(g.get("pm_salary", 0))
		var pm  = int(g.get("pm_salary", 0))
		var pen = int(g.get("penalties", 0))
		var off = int(g.get("office_costs", 0))
		var svc = int(g.get("service_costs", 0))
		var tot = sal + pm + pen + off + svc
		var xl  = g.get("label", "D%d" % int(g.get("day", i+1)))
		var segs = [
			{"label": tr("REPORTS_SALARIES"),  "value": sal, "color": COLOR_SALARIES},
			{"label": tr("REPORTS_PM_SALARY"), "value": pm,  "color": COLOR_PM_SAL},
			{"label": tr("REPORTS_PENALTIES"), "value": pen, "color": COLOR_PENALTIES},
			{"label": tr("REPORTS_OFFICE"),    "value": off, "color": COLOR_OFFICE},
			{"label": tr("REPORTS_SERVICES"),  "value": svc, "color": COLOR_SERVICES},
		]
		var bx = PL + float(i) * slot_w + bar_m
		var bot = PT + gh; var col = []
		for seg in segs:
			var v = int(seg["value"])
			if v <= 0: continue
			var sh = (float(v) / float(max_exp)) * gh
			var rect = Rect2(bx, bot - sh, bar_w, sh)
			ctrl.draw_rect(rect, seg["color"])
			col.append({"rect": rect, "label": seg["label"], "value": v, "total": tot, "x_label": xl})
			bot -= sh
		_trend_col_segs.append(col)
		if i % max(1, _x_step(n)) == 0:
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(bx-4, h-6), xl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRAY)

func _on_exp_trend_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	for col in _trend_col_segs:
		for sd in col:
			if sd["rect"].has_point(mp):
				var xl = sd.get("x_label", ""); var tot = int(sd["total"])
				var lines = ["%s (Total: $%s)" % [xl, _format_money(tot)]]
				for other in col:
					var mk = "> " if other["label"] == sd["label"] else "  "
					lines.append("%s%s: $%s" % [mk, other["label"], _format_money(other["value"])])
				_show_tooltip_at("\n".join(lines), _expense_trend_chart, mp); return
	_hide_tooltip()

# =====================================================================
#  WIDGET 5: INCOME vs EXPENSES BARS
# =====================================================================

func _build_daily_bars_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	vbox.add_child(_make_title("📊 " + tr("REPORTS_INCOME_VS_EXPENSE")))
	_daily_bars_chart = Control.new()
	_daily_bars_chart.custom_minimum_size = Vector2(0, 200)
	_daily_bars_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_bars_chart.mouse_filter = Control.MOUSE_FILTER_STOP
	_daily_bars_chart.draw.connect(_draw_daily_bars.bind(_daily_bars_chart))
	_daily_bars_chart.gui_input.connect(_on_daily_bars_gui_input)
	_daily_bars_chart.mouse_exited.connect(_hide_tooltip)
	vbox.add_child(_daily_bars_chart)
	var legend = HBoxContainer.new(); legend.add_theme_constant_override("separation", 20)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER; vbox.add_child(legend)
	for id in [[COLOR_GREEN, tr("REPORTS_PROJECT_INCOME")], [COLOR_RED, tr("REPORTS_EXPENSE_STRUCTURE")]]:
		var item = HBoxContainer.new(); item.add_theme_constant_override("separation", 4)
		var rect = ColorRect.new(); rect.custom_minimum_size = Vector2(12, 12); rect.color = id[0]; item.add_child(rect)
		var lbl = Label.new(); lbl.text = id[1]
		lbl.add_theme_color_override("font_color", COLOR_DARK); lbl.add_theme_font_size_override("font_size", 11)
		if UITheme: UITheme.apply_font(lbl, "regular"); item.add_child(lbl); legend.add_child(item)
	return card

func _refresh_daily_bars():
	if _daily_bars_chart: _daily_bars_chart.queue_redraw()

func _draw_daily_bars(ctrl: Control):
	var records = _get_filtered_records()
	var groups  = _aggregate_records(records)
	_daily_bars_data.clear()
	var w = ctrl.size.x; var h = ctrl.size.y
	const PL = 80.0; const PR = 10.0; const PT = 16.0; const PB = 30.0
	var gw = w - PL - PR; var gh = h - PT - PB
	if groups.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w*0.5-40, h*0.5), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var max_val = 1
	for g in groups:
		max_val = max(max_val, int(g.get("income", 0))); max_val = max(max_val, int(g.get("expenses", 0)))
	var gc = Color(0.88, 0.88, 0.88, 1)
	for i in range(5):
		var frac = float(i) / 4.0; var gy = PT + frac * gh
		ctrl.draw_line(Vector2(PL, gy), Vector2(PL+gw, gy), gc, 1)
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy+5),
			"$%s" % _format_money_short(int(max_val * (1.0-frac))), HORIZONTAL_ALIGNMENT_LEFT, PL-4, 10, COLOR_GRAY)
	var n = groups.size(); var slot_w = gw / float(n); var bar_w = slot_w * 0.35
	for i in range(n):
		var g = groups[i]; var cx = PL + float(i) * slot_w + slot_w * 0.5
		var inc = int(g.get("income", 0)); var exp = int(g.get("expenses", 0))
		var ih = (float(inc) / float(max_val)) * gh; var eh = (float(exp) / float(max_val)) * gh
		var ir = Rect2(cx - bar_w - 1, PT+gh-ih, bar_w, ih)
		var er = Rect2(cx + 1,         PT+gh-eh, bar_w, eh)
		ctrl.draw_rect(ir, COLOR_GREEN); ctrl.draw_rect(er, COLOR_RED)
		_daily_bars_data.append({"inc_rect": ir, "exp_rect": er, "group": g})
		if i % max(1, _x_step(n)) == 0:
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(cx-12, h-6),
				g.get("label", str(int(g.get("day", i+1)))), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRAY)

func _on_daily_bars_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	for bd in _daily_bars_data:
		if bd["inc_rect"].has_point(mp) or bd["exp_rect"].has_point(mp):
			var g = bd["group"]; var xl = g.get("label", "D%d" % int(g.get("day", 0)))
			var inc = int(g.get("income", 0)); var exp = int(g.get("expenses", 0))
			var profit = inc - exp; var s = "+" if profit >= 0 else "-"
			_show_tooltip_at("%s  Income: $%s | Exp: $%s | Profit: %s$%s" % [xl, _format_money(inc), _format_money(exp), s, _format_money(abs(profit))], _daily_bars_chart, mp); return
	_hide_tooltip()

# =====================================================================
#  WIDGET 6: P&L TABLE
# =====================================================================

func _build_pnl_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	var header = HBoxContainer.new(); header.add_theme_constant_override("separation", 12); vbox.add_child(header)
	header.add_child(_make_title("📋 " + tr("REPORTS_PNL")))
	var sp = Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(sp)
	_pnl_prev_btn = Button.new(); _pnl_prev_btn.text = "<"
	_pnl_prev_btn.custom_minimum_size = Vector2(30, 26); _pnl_prev_btn.focus_mode = Control.FOCUS_NONE
	_pnl_prev_btn.pressed.connect(_on_pnl_prev); _style_small_btn(_pnl_prev_btn); header.add_child(_pnl_prev_btn)
	_pnl_month_label = Label.new(); _pnl_month_label.text = ""
	_pnl_month_label.add_theme_font_size_override("font_size", 13)
	_pnl_month_label.add_theme_color_override("font_color", COLOR_DARK)
	_pnl_month_label.custom_minimum_size = Vector2(120, 0)
	_pnl_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_pnl_month_label, "semibold"); header.add_child(_pnl_month_label)
	_pnl_next_btn = Button.new(); _pnl_next_btn.text = ">"
	_pnl_next_btn.custom_minimum_size = Vector2(30, 26); _pnl_next_btn.focus_mode = Control.FOCUS_NONE
	_pnl_next_btn.pressed.connect(_on_pnl_next); _style_small_btn(_pnl_next_btn); header.add_child(_pnl_next_btn)
	_pnl_vbox = VBoxContainer.new(); _pnl_vbox.add_theme_constant_override("separation", 0)
	_pnl_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vbox.add_child(_pnl_vbox)
	return card

func _on_pnl_prev():
	_pnl_month_index = max(0, _pnl_month_index - 1); _refresh_pnl()

func _on_pnl_next():
	_pnl_month_index = min(_get_max_pnl_month_index(), _pnl_month_index + 1); _refresh_pnl()

func _get_max_pnl_month_index() -> int:
	var records = FinancialHistory.daily_records
	if records.is_empty(): return 0
	var seen = {}; for r in records: seen[_day_to_month(int(r.get("day", 1)))] = true
	return max(0, seen.size() - 1)

func _day_to_month(day: int) -> int:
	return max(1, int(ceil(float(day) / float(GameTime.DAYS_IN_MONTH))))

func _get_pnl_month_records(month_index: int) -> Array:
	var all = FinancialHistory.daily_records
	if all.is_empty(): return []
	var mlist: Array = []; var seen = {}
	for r in all:
		var m = _day_to_month(int(r.get("day", 1)))
		if not seen.has(m): seen[m] = true; mlist.append(m)
	mlist.sort()
	if month_index >= mlist.size(): return []
	var target = mlist[month_index]; var result = []
	for r in all:
		if _day_to_month(int(r.get("day", 1))) == target: result.append(r)
	return result

func _refresh_pnl():
	if not _pnl_vbox: return
	for c in _pnl_vbox.get_children(): c.queue_free()
	var max_idx = _get_max_pnl_month_index()
	_pnl_month_index = clamp(_pnl_month_index, 0, max_idx)
	if _pnl_prev_btn: _pnl_prev_btn.disabled = (_pnl_month_index == 0)
	if _pnl_next_btn: _pnl_next_btn.disabled = (_pnl_month_index >= max_idx)
	if _pnl_month_label: _pnl_month_label.text = tr("REPORTS_PERIOD_MONTH") + " " + str(_pnl_month_index + 1)
	var records = _get_pnl_month_records(_pnl_month_index)
	if records.is_empty():
		var lbl = Label.new(); lbl.text = tr("REPORTS_NO_DATA")
		lbl.add_theme_color_override("font_color", COLOR_GRAY); lbl.add_theme_font_size_override("font_size", 14)
		_pnl_vbox.add_child(lbl); return
	var ci = 0; var cs = 0; var cp = 0; var cn = 0; var co = 0; var cv = 0
	for r in records:
		ci += int(r.get("income", 0))
		cs += int(r.get("salary_total", 0)) - int(r.get("pm_salary", 0))
		cp += int(r.get("pm_salary", 0)); cn += int(r.get("penalties", 0))
		co += int(r.get("office_costs", 0)); cv += int(r.get("service_costs", 0))
	var ce = cs + cp + cn + co + cv; var cnet = ci - ce
	var cmarg = 0.0; if ci > 0: cmarg = float(cnet) / float(ci) * 100.0
	var pi = 0; var ps = 0; var pp = 0; var pn = 0; var po = 0; var pv = 0
	if _pnl_month_index > 0:
		var pr = _get_pnl_month_records(_pnl_month_index - 1)
		for r in pr:
			pi += int(r.get("income", 0))
			ps += int(r.get("salary_total", 0)) - int(r.get("pm_salary", 0))
			pp += int(r.get("pm_salary", 0)); pn += int(r.get("penalties", 0))
			po += int(r.get("office_costs", 0)); pv += int(r.get("service_costs", 0))
	var pe = ps + pp + pn + po + pv; var pnet = pi - pe
	var pmarg = 0.0; if pi > 0: pmarg = float(pnet) / float(pi) * 100.0
	var team_size = 1
	if PeopleHistory and not PeopleHistory.daily_records.is_empty():
		var ld = 0; for r in records:
			var d = int(r.get("day", 0)); if d > ld: ld = d
		for pr in PeopleHistory.daily_records:
			if int(pr.get("day", 0)) == ld: team_size = max(1, int(pr.get("team_size", 1))); break
	_pnl_row(["", tr("REPORTS_PNL_VALUE"), tr("REPORTS_PNL_PCT_INCOME"), tr("REPORTS_PNL_VS_PREV")], true, [COLOR_GRAY, COLOR_GRAY, COLOR_GRAY, COLOR_GRAY])
	_pnl_sep()
	_pnl_row([tr("REPORTS_PROJECT_INCOME"), "+$"+_format_money(ci), "100%", _pcmp(ci, pi)],
		false, [COLOR_DARK, COLOR_GREEN, COLOR_GRAY, _pcmp_col(ci, pi, true)])
	_pnl_sep()
	var exp_data = [
		[tr("REPORTS_SALARIES"),  cs, ps], [tr("REPORTS_PM_SALARY"), cp, pp],
		[tr("REPORTS_PENALTIES"), cn, pn], [tr("REPORTS_OFFICE"),    co, po],
		[tr("REPORTS_SERVICES"),  cv, pv],
	]
	for ed in exp_data:
		var pcts = "-"; if ci > 0: pcts = "%.0f%%" % (float(ed[1]) / float(ci) * 100.0)
		_pnl_row([ed[0], "-$"+_format_money(int(ed[1])), pcts, _pcmp(int(ed[1]), int(ed[2]))],
			false, [COLOR_DARK, COLOR_RED, COLOR_GRAY, _pcmp_col(int(ed[1]), int(ed[2]), false)])
	_pnl_sep()
	var ns = "+" if cnet >= 0 else "-"
	_pnl_row([tr("REPORTS_TOTAL"), ns+"$"+_format_money(abs(cnet)), "", _pcmp(cnet, pnet)],
		true, [COLOR_DARK, COLOR_GREEN if cnet >= 0 else COLOR_RED, COLOR_GRAY, _pcmp_col(cnet, pnet, true)])
	var dpps = "+" if (cmarg - pmarg) >= 0 else ""
	_pnl_row([tr("REPORTS_MARGIN"), "%.1f%%" % cmarg, "", dpps+"%.1fpp" % (cmarg-pmarg)],
		true, [COLOR_DARK, COLOR_GREEN if cmarg >= 0 else COLOR_RED, COLOR_GRAY, COLOR_GREEN if (cmarg-pmarg) >= 0 else COLOR_RED])
	_pnl_sep()
	_pnl_row([tr("REPORTS_INCOME_PER_EMPLOYEE"), "$"+_format_money(int(float(ci)/float(team_size))), tr("REPORTS_PNL_TEAM_SIZE") % team_size, ""],
		false, [COLOR_DARK, COLOR_GREEN, COLOR_GRAY, COLOR_GRAY])
	_pnl_row([tr("REPORTS_EXPENSES_PER_EMPLOYEE"), "$"+_format_money(int(float(ce)/float(team_size))), "", ""],
		false, [COLOR_DARK, COLOR_RED, COLOR_GRAY, COLOR_GRAY])

func _pnl_row(cols: Array, bold: bool, colors: Array):
	var row = PanelContainer.new()
	var sty = StyleBoxFlat.new(); sty.bg_color = Color(0, 0, 0, 0)
	row.add_theme_stylebox_override("panel", sty); _pnl_vbox.add_child(row)
	var hb = HBoxContainer.new(); row.add_child(hb)
	var min_ws = [0, 140, 90, 110]
	for i in range(cols.size()):
		var lbl = Label.new(); lbl.text = cols[i]
		var col = colors[i] if i < colors.size() else COLOR_DARK
		lbl.add_theme_color_override("font_color", col)
		lbl.add_theme_font_size_override("font_size", 13)
		if i == 0:
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lbl.custom_minimum_size = Vector2(min_ws[i] if i < min_ws.size() else 80, 0)
		if bold: if UITheme: UITheme.apply_font(lbl, "semibold")
		else:    if UITheme: UITheme.apply_font(lbl, "regular")
		hb.add_child(lbl)

func _pnl_sep(): _pnl_vbox.add_child(HSeparator.new())

func _pcmp(cur: int, prev: int) -> String:
	if prev == 0: return "-"
	var diff = cur - prev
	var pct = int(round(float(diff) / float(abs(prev)) * 100.0))
	return ("+" if pct >= 0 else "") + str(pct) + "%"

func _pcmp_col(cur: int, prev: int, higher_good: bool) -> Color:
	if prev == 0: return COLOR_GRAY
	return COLOR_GREEN if ((cur >= prev) == higher_good) else COLOR_RED

# =====================================================================
#  WIDGET 7: PROJECT ROI (Top-5, filtered by period)
# =====================================================================

func _build_roi_card() -> PanelContainer:
	var card = _make_card(); var margin = _make_card_margin(); card.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 8); margin.add_child(vbox)
	var title_row = HBoxContainer.new(); title_row.add_theme_constant_override("separation", 12); vbox.add_child(title_row)
	title_row.add_child(_make_title("🎯 " + tr("REPORTS_PROJECT_ROI")))
	_roi_count_label = Label.new()
	_roi_count_label.add_theme_color_override("font_color", COLOR_GRAY)
	_roi_count_label.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(_roi_count_label, "regular"); title_row.add_child(_roi_count_label)
	_roi_scroll = ScrollContainer.new()
	_roi_scroll.custom_minimum_size = Vector2(0, 60)
	_roi_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roi_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_roi_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_roi_scroll.mouse_filter = Control.MOUSE_FILTER_STOP; vbox.add_child(_roi_scroll)
	_roi_chart = Control.new()
	_roi_chart.custom_minimum_size = Vector2(0, 60)
	_roi_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roi_chart.mouse_filter = Control.MOUSE_FILTER_STOP
	_roi_chart.draw.connect(_draw_roi_bars.bind(_roi_chart))
	_roi_chart.gui_input.connect(_on_roi_gui_input)
	_roi_chart.mouse_exited.connect(_hide_tooltip)
	_roi_scroll.add_child(_roi_chart)
	return card

func _refresh_roi():
	if not _roi_chart: return
	var projects = _get_period_projects()
	var all_count = _get_period_project_count()
	if _roi_count_label: _roi_count_label.text = tr("REPORTS_ROI_TOTAL_COMPLETED") % all_count
	const ROW_H = 36.0
	var chart_h = max(60.0, float(projects.size()) * ROW_H + 20.0)
	var scroll_h = min(chart_h, 5.0 * ROW_H + 20.0)
	_roi_chart.custom_minimum_size = Vector2(0, chart_h)
	if _roi_scroll: _roi_scroll.custom_minimum_size = Vector2(0, scroll_h)
	_roi_chart.queue_redraw()

func _get_period_project_count() -> int:
	var count = 0; var b = _get_period_bounds()
	for r in FinancialHistory.daily_records:
		var d = int(r.get("day", 0))
		if d >= b[0] and d <= b[1]: count += r.get("project_income_details", []).size()
	return count

func _get_period_projects() -> Array:
	var result = []; var b = _get_period_bounds()
	for r in FinancialHistory.daily_records:
		var d = int(r.get("day", 0))
		if d >= b[0] and d <= b[1]:
			for p in r.get("project_income_details", []): result.append(p)
	result.sort_custom(func(a, b): return abs(int(a.get("profit", 0))) > abs(int(b.get("profit", 0))))
	if result.size() > 5: result.resize(5)
	return result

func _draw_roi_bars(ctrl: Control):
	var projects = _get_period_projects()
	_roi_bars_data.clear()
	if projects.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(20, 30), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return
	var w = ctrl.size.x; const PL = 160.0; const PR = 130.0
	var bmaxw = w - PL - PR; const ROW_H = 36.0; const BAR_H = 22.0
	var max_abs = 1
	for p in projects: max_abs = max(max_abs, abs(int(p.get("profit", 0))))
	for i in range(projects.size()):
		var p = projects[i]; var profit = int(p.get("profit", 0))
		var payout = int(p.get("payout", 0)); var labor = int(p.get("labor_cost", 0))
		var title = str(p.get("title", "?"))
		var cy = float(i) * ROW_H + 10.0; var bar_y = cy + (ROW_H - BAR_H) * 0.5
		var roi_pct = 0.0; if labor > 0: roi_pct = float(profit) / float(labor) * 100.0
		var short = title.substr(0, 20) + ("..." if title.length() > 20 else "")
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, cy+BAR_H*0.5+5), short, HORIZONTAL_ALIGNMENT_LEFT, PL-8, 12, COLOR_DARK)
		var bw = (float(abs(profit)) / float(max_abs)) * bmaxw
		var col = COLOR_GREEN if profit >= 0 else COLOR_RED
		var rect = Rect2(PL, bar_y, bw, BAR_H)
		ctrl.draw_rect(rect, col)
		_roi_bars_data.append({"rect": rect, "project": p, "roi_pct": roi_pct})
		var sgn = "+" if profit >= 0 else "-"
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(PL+bw+6, cy+BAR_H*0.5+5),
			"%s$%s" % [sgn, _format_money(abs(profit))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		if labor > 0:
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(w-PR+4, cy+BAR_H*0.5+5),
				"ROI: %.0f%%" % roi_pct, HORIZONTAL_ALIGNMENT_LEFT, PR-4, 11, COLOR_GRAY)

func _on_roi_gui_input(event: InputEvent):
	if not event is InputEventMouseMotion: return
	var mp = (event as InputEventMouseMotion).position
	for bd in _roi_bars_data:
		if bd["rect"].has_point(mp):
			var p = bd["project"]; var profit = int(p.get("profit", 0))
			var payout = int(p.get("payout", 0)); var labor = int(p.get("labor_cost", 0))
			var s = "+" if profit >= 0 else "-"
			var roi_s = "N/A"; if labor > 0: roi_s = "%.0f%%" % (float(profit)/float(labor)*100.0)
			_show_tooltip_at("%s\nPayout: $%s | Cost: $%s | Profit: %s$%s | ROI: %s" % [
				str(p.get("title", "?")), _format_money(payout), _format_money(labor),
				s, _format_money(abs(profit)), roi_s], _roi_chart, mp); return
	_hide_tooltip()

# =====================================================================
#  HELPERS
# =====================================================================

func _x_step(n: int) -> int:
	match _selected_period:
		PERIOD_7D:  return 1
		PERIOD_30D: return 5
	return max(1, int(ceil(float(n) / 10.0)))

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
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL; m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return m

func _make_title(text: String) -> Label:
	var lbl = Label.new(); lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COLOR_DARK)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	return lbl

func _format_money(amount: int) -> String:
	var s = str(abs(amount)); var r = ""; var c = 0
	for i in range(s.length() - 1, -1, -1):
		if c > 0 and c % 3 == 0: r = "," + r
		r = s[i] + r; c += 1
	return r

func _format_money_short(amount: int) -> String:
	var av = abs(amount); var sg = "-" if amount < 0 else ""
	if av >= 1000000: return sg + "%.1fM" % (float(av) / 1000000.0)
	if av >= 1000:    return sg + "%.0fK" % (float(av) / 1000.0)
	return sg + str(av)

func _format_money_axis(amount: int) -> String:
	var sg = "-" if amount < 0 else ""; var av = abs(amount)
	if av >= 1000000: return "$" + sg + "%.1fM" % (float(av) / 1000000.0)
	if av >= 10000:   return "$" + sg + "%.0fK" % (float(av) / 1000.0)
	if av >= 1000:    return "$" + sg + "%.1fK" % (float(av) / 1000.0)
	return "$" + sg + str(av)
