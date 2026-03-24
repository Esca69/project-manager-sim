extends Control

# === FINANCIAL REPORTS TAB ===
# Contains 5 financial widgets displayed in a scrollable VBox

const COLOR_BLUE   = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_GREEN  = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_RED    = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_ORANGE = Color(1.0, 0.55, 0.0, 1)
const COLOR_GRAY   = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK   = Color(0.2, 0.2, 0.2, 1)
const COLOR_WHITE  = Color(1, 1, 1, 1)

# Period selector state shared across widgets 1-3
var _selected_period: int = 30   # days (7 / 30 / 90 / 360 / 0=all)

# Cash Flow graph node
var _cash_flow_graph: Control
# Income/Expense bar graph nodes (separate for income and expense)
var _income_bar: Control
var _expense_bar: Control
# Daily bars node
var _daily_bars_chart: Control
var _daily_bars_legend: HBoxContainer
# P&L table container
var _pnl_vbox: VBoxContainer
var _pnl_month_index: int = 0   # which month to show (0 = current)
# ROI bars
var _roi_chart: Control
var _roi_scroll: ScrollContainer

# Period buttons for widgets 1-3
var _period_buttons: Array = []

# P&L month buttons
var _pnl_prev_btn: Button
var _pnl_next_btn: Button
var _pnl_month_label: Label

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

	# --- Period selector (shared for widgets 1-3) ---
	var period_panel = _build_period_selector()
	vbox.add_child(period_panel)

	# --- Widget 1: Cash Flow ---
	vbox.add_child(_build_cash_flow_card())

	# --- Widget 2: Income / Expense structure bars ---
	vbox.add_child(_build_structure_card())

	# --- Widget 3: Income vs Expenses daily bars ---
	vbox.add_child(_build_daily_bars_card())

	# --- Widget 4: P&L table ---
	vbox.add_child(_build_pnl_card())

	# --- Widget 5: Project ROI ---
	vbox.add_child(_build_roi_card())

func refresh():
	_on_period_selected(_selected_period)
	_refresh_pnl()
	_refresh_roi()

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
	lbl.text = tr("REPORTS_CASH_FLOW") + ":"
	lbl.add_theme_color_override("font_color", COLOR_GRAY)
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "semibold")
	hbox.add_child(lbl)

	var periods = [
		[tr("REPORTS_PERIOD_WEEK"), 7],
		[tr("REPORTS_PERIOD_MONTH"), 30],
		[tr("REPORTS_PERIOD_QUARTER"), 90],
		[tr("REPORTS_PERIOD_YEAR"), 360],
		[tr("REPORTS_PERIOD_ALL"), 0],
	]

	_period_buttons.clear()
	for p in periods:
		var btn = Button.new()
		btn.text = p[0]
		btn.custom_minimum_size = Vector2(90, 28)
		btn.focus_mode = Control.FOCUS_NONE
		var days = p[1]
		btn.pressed.connect(func(): _on_period_selected(days))
		_period_buttons.append({"btn": btn, "days": days})
		_style_period_btn(btn, days == _selected_period)
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

func _on_period_selected(days: int):
	_selected_period = days
	for entry in _period_buttons:
		_style_period_btn(entry["btn"], entry["days"] == days)
	_refresh_cash_flow()
	_refresh_structure()
	_refresh_daily_bars()

func _get_filtered_records() -> Array:
	var all = FinancialHistory.daily_records
	if _selected_period == 0 or all.is_empty():
		return all.duplicate()

	var current_day = GameTime.day
	var cutoff_day = current_day - _selected_period

	var result = []
	for r in all:
		if int(r.get("day", 0)) > cutoff_day:
			result.append(r)
	return result

# =========================================================
#  WIDGET 1: CASH FLOW
# =========================================================

func _build_cash_flow_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title = _make_title("📈 " + tr("REPORTS_CASH_FLOW"))
	vbox.add_child(title)

	_cash_flow_graph = Control.new()
	_cash_flow_graph.custom_minimum_size = Vector2(0, 250)
	_cash_flow_graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cash_flow_graph.draw.connect(_draw_cash_flow.bind(_cash_flow_graph))
	vbox.add_child(_cash_flow_graph)

	return card

func _refresh_cash_flow():
	if _cash_flow_graph:
		_cash_flow_graph.queue_redraw()

func _draw_cash_flow(ctrl: Control):
	var records = _get_filtered_records()
	var w = ctrl.size.x
	var h = ctrl.size.y
	var pad_left = 80.0
	var pad_right = 20.0
	var pad_top = 20.0
	var pad_bottom = 40.0
	var gw = w - pad_left - pad_right
	var gh = h - pad_top - pad_bottom

	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return

	# Gather balance data
	var values: Array = []
	for r in records:
		values.append(int(r.get("balance", 0)))

	var min_val = values.min()
	var max_val = values.max()
	if min_val == max_val:
		min_val -= 1000
		max_val += 1000
	var range_val = float(max_val - min_val)

	# Add ~10% padding so data doesn't press against chart edges
	const MIN_CHART_PADDING = 100  # minimum pixel-value padding to keep the line off the edges
	var padding = range_val * 0.1
	if padding < MIN_CHART_PADDING: padding = MIN_CHART_PADDING
	var chart_min = min_val - padding
	var chart_max = max_val + padding
	var chart_range = float(chart_max - chart_min)

	# Grid lines with unique labels
	var grid_color = Color(0.88, 0.88, 0.88, 1)
	var zero_y = pad_top + gh * (1.0 - (0 - chart_min) / chart_range)
	var n_lines = 5
	var last_label = ""
	for i in range(n_lines + 1):
		var frac = float(i) / float(n_lines)
		var gy = pad_top + frac * gh
		ctrl.draw_line(Vector2(pad_left, gy), Vector2(pad_left + gw, gy), grid_color, 1)
		var val_at_line = int(chart_max - frac * chart_range)
		var label_str = _format_money_axis(val_at_line)
		if label_str != last_label:
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 5), label_str, HORIZONTAL_ALIGNMENT_LEFT, pad_left - 4, 11, COLOR_GRAY)
			last_label = label_str

	# Zero line (if in range)
	if chart_min < 0 and chart_max > 0:
		ctrl.draw_line(Vector2(pad_left, zero_y), Vector2(pad_left + gw, zero_y), Color(0.9, 0.3, 0.3, 0.6), 1.5)

	# Build points
	var pts: PackedVector2Array = []
	var n = values.size()
	for i in range(n):
		var px = pad_left + (float(i) / max(n - 1, 1)) * gw
		var py = pad_top + gh * (1.0 - (values[i] - chart_min) / chart_range)
		pts.append(Vector2(px, py))

	# Blue fill area (above zero or above min)
	var fill_poly: PackedVector2Array = []
	var baseline_y = clampf(pad_top + gh * (1.0 - (0 - chart_min) / chart_range), pad_top, pad_top + gh)
	fill_poly.append(Vector2(pts[0].x, baseline_y))
	for p in pts:
		fill_poly.append(p)
	fill_poly.append(Vector2(pts[n - 1].x, baseline_y))
	ctrl.draw_colored_polygon(fill_poly, Color(COLOR_BLUE.r, COLOR_BLUE.g, COLOR_BLUE.b, 0.15))

	# Red fill for negative area
	if chart_min < 0:
		var red_poly: PackedVector2Array = []
		red_poly.append(Vector2(pts[0].x, baseline_y))
		for i in range(n):
			if values[i] < 0:
				red_poly.append(pts[i])
			else:
				# Interpolate to zero crossing
				if i > 0 and values[i - 1] < 0:
					var t = float(-values[i - 1]) / float(values[i] - values[i - 1])
					var cross_x = pts[i - 1].x + t * (pts[i].x - pts[i - 1].x)
					red_poly.append(Vector2(cross_x, baseline_y))
		if red_poly.size() > 2:
			red_poly.append(Vector2(red_poly[red_poly.size() - 1].x, baseline_y))
			ctrl.draw_colored_polygon(red_poly, Color(COLOR_RED.r, COLOR_RED.g, COLOR_RED.b, 0.2))

	# Line
	ctrl.draw_polyline(pts, COLOR_BLUE, 2.0, true)

	# Dots
	for p in pts:
		ctrl.draw_circle(p, 3.5, COLOR_BLUE)

	# X-axis labels
	var step = max(1, int(ceil(float(n) / 10.0)))
	for i in range(0, n, step):
		var px = pad_left + (float(i) / max(n - 1, 1)) * gw
		var day_num = int(records[i].get("day", i + 1))
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(px - 10, h - 8), str(day_num), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COLOR_GRAY)

# =========================================================
#  WIDGET 2: INCOME / EXPENSE STRUCTURE
# =========================================================

func _build_structure_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	vbox.add_child(_make_title("💰 " + tr("REPORTS_INCOME_STRUCTURE") + " / " + tr("REPORTS_EXPENSE_STRUCTURE")))

	# Income subtitle label
	var income_lbl = Label.new()
	income_lbl.text = tr("REPORTS_INCOME_STRUCTURE")
	income_lbl.add_theme_color_override("font_color", COLOR_GREEN)
	income_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(income_lbl, "semibold")
	vbox.add_child(income_lbl)

	# Income bar
	_income_bar = Control.new()
	_income_bar.custom_minimum_size = Vector2(0, 28)
	_income_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_income_bar.draw.connect(_draw_income_bar.bind(_income_bar))
	vbox.add_child(_income_bar)

	# Expense subtitle label
	var expense_lbl = Label.new()
	expense_lbl.text = tr("REPORTS_EXPENSE_STRUCTURE")
	expense_lbl.add_theme_color_override("font_color", COLOR_RED)
	expense_lbl.add_theme_font_size_override("font_size", 12)
	if UITheme: UITheme.apply_font(expense_lbl, "semibold")
	vbox.add_child(expense_lbl)

	# Expense bar
	_expense_bar = Control.new()
	_expense_bar.custom_minimum_size = Vector2(0, 28)
	_expense_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expense_bar.draw.connect(_draw_expense_bar.bind(_expense_bar))
	vbox.add_child(_expense_bar)

	# Legend (Labels, not drawn)
	var legend_hbox = HBoxContainer.new()
	legend_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(legend_hbox)

	var exp_segs_info = [
		{"label": tr("REPORTS_SALARIES"),  "color": COLOR_RED},
		{"label": tr("REPORTS_PM_SALARY"), "color": COLOR_ORANGE},
		{"label": tr("REPORTS_PENALTIES"), "color": Color(0.7, 0.1, 0.1, 1)},
		{"label": tr("REPORTS_OFFICE"),    "color": Color(0.9, 0.5, 0.1, 1)},
	]
	for seg_info in exp_segs_info:
		var item = HBoxContainer.new()
		item.add_theme_constant_override("separation", 4)
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(12, 12)
		rect.color = seg_info["color"]
		item.add_child(rect)
		var lbl = Label.new()
		lbl.text = seg_info["label"]
		lbl.add_theme_color_override("font_color", COLOR_DARK)
		lbl.add_theme_font_size_override("font_size", 11)
		if UITheme: UITheme.apply_font(lbl, "regular")
		item.add_child(lbl)
		legend_hbox.add_child(item)

	return card

func _refresh_structure():
	if _income_bar:
		_income_bar.queue_redraw()
	if _expense_bar:
		_expense_bar.queue_redraw()

func _draw_income_bar(ctrl: Control):
	var records = _get_filtered_records()
	var w = ctrl.size.x
	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, 20), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GRAY)
		return
	var total_income = 0
	for r in records:
		total_income += int(r.get("income", 0))
	var income_segs = [
		{"value": total_income, "color": COLOR_GREEN},
	]
	_draw_stacked_bar(ctrl, income_segs, max(total_income, 1), 0, 0, w, ctrl.size.y)

func _draw_expense_bar(ctrl: Control):
	var records = _get_filtered_records()
	var w = ctrl.size.x
	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, 20), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_GRAY)
		return
	var total_salary = 0
	var total_pm_salary = 0
	var total_penalties = 0
	var total_office = 0
	for r in records:
		total_salary    += int(r.get("salary_total", 0)) - int(r.get("pm_salary", 0))
		total_pm_salary += int(r.get("pm_salary", 0))
		total_penalties += int(r.get("penalties", 0))
		total_office    += int(r.get("office_costs", 0))
	var total_exp = total_salary + total_pm_salary + total_penalties + total_office
	var exp_segs = [
		{"value": total_salary,    "color": COLOR_RED},
		{"value": total_pm_salary, "color": COLOR_ORANGE},
		{"value": total_penalties, "color": Color(0.7, 0.1, 0.1, 1)},
		{"value": total_office,    "color": Color(0.9, 0.5, 0.1, 1)},
	]
	_draw_stacked_bar(ctrl, exp_segs, max(total_exp, 1), 0, 0, w, ctrl.size.y)

func _draw_stacked_bar(ctrl: Control, segs: Array, total: float, x: float, y: float, w: float, h: float):
	if total <= 0:
		var empty_s = StyleBoxFlat.new()
		empty_s.bg_color = Color(0.92, 0.92, 0.92, 1)
		ctrl.draw_rect(Rect2(x, y, w, h), Color(0.92, 0.92, 0.92, 1))
		return
	var cx = x
	for seg in segs:
		var val = float(seg.get("value", 0))
		if val <= 0:
			continue
		var seg_w = (val / total) * w
		ctrl.draw_rect(Rect2(cx, y, seg_w, h), seg["color"])
		cx += seg_w

# =========================================================
#  WIDGET 3: INCOME vs EXPENSES DAILY BARS
# =========================================================

func _build_daily_bars_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	vbox.add_child(_make_title("📊 " + tr("REPORTS_INCOME_VS_EXPENSE")))

	_daily_bars_chart = Control.new()
	_daily_bars_chart.custom_minimum_size = Vector2(0, 200)
	_daily_bars_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_bars_chart.draw.connect(_draw_daily_bars.bind(_daily_bars_chart))
	vbox.add_child(_daily_bars_chart)

	# Legend below chart (as Label nodes, not drawn)
	_daily_bars_legend = HBoxContainer.new()
	_daily_bars_legend.add_theme_constant_override("separation", 20)
	_daily_bars_legend.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_daily_bars_legend)

	var green_item = HBoxContainer.new()
	green_item.add_theme_constant_override("separation", 4)
	var green_rect = ColorRect.new()
	green_rect.custom_minimum_size = Vector2(12, 12)
	green_rect.color = COLOR_GREEN
	green_item.add_child(green_rect)
	var green_lbl = Label.new()
	green_lbl.text = tr("REPORTS_PROJECT_INCOME")
	green_lbl.add_theme_color_override("font_color", COLOR_DARK)
	green_lbl.add_theme_font_size_override("font_size", 11)
	if UITheme: UITheme.apply_font(green_lbl, "regular")
	green_item.add_child(green_lbl)
	_daily_bars_legend.add_child(green_item)

	var red_item = HBoxContainer.new()
	red_item.add_theme_constant_override("separation", 4)
	var red_rect = ColorRect.new()
	red_rect.custom_minimum_size = Vector2(12, 12)
	red_rect.color = COLOR_RED
	red_item.add_child(red_rect)
	var red_lbl = Label.new()
	red_lbl.text = tr("REPORTS_EXPENSE_STRUCTURE")
	red_lbl.add_theme_color_override("font_color", COLOR_DARK)
	red_lbl.add_theme_font_size_override("font_size", 11)
	if UITheme: UITheme.apply_font(red_lbl, "regular")
	red_item.add_child(red_lbl)
	_daily_bars_legend.add_child(red_item)

	return card

func _refresh_daily_bars():
	if _daily_bars_chart:
		_daily_bars_chart.queue_redraw()

func _draw_daily_bars(ctrl: Control):
	var records = _get_filtered_records()
	var w = ctrl.size.x
	var h = ctrl.size.y
	var pad_left = 80.0
	var pad_right = 10.0
	var pad_top = 16.0
	var pad_bottom = 30.0
	var gw = w - pad_left - pad_right
	var gh = h - pad_top - pad_bottom

	if records.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(w * 0.5 - 40, h * 0.5), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return

	# Group by week if > 30 days
	var groups: Array = []
	if records.size() > 30:
		var week_size = 7
		var i = 0
		while i < records.size():
			var chunk = records.slice(i, min(i + week_size, records.size()))
			var inc = 0; var exp = 0; var day = int(chunk[0].get("day", 0))
			for r in chunk:
				inc += int(r.get("income", 0))
				exp += int(r.get("expenses", 0))
			groups.append({"income": inc, "expenses": exp, "day": day})
			i += week_size
	else:
		for r in records:
			groups.append({"income": int(r.get("income", 0)), "expenses": int(r.get("expenses", 0)), "day": int(r.get("day", 0))})

	var max_val = 1
	for g in groups:
		max_val = max(max_val, g["income"])
		max_val = max(max_val, g["expenses"])

	var n = groups.size()
	var slot_w = gw / float(n)
	var bar_w = slot_w * 0.35

	# Grid lines
	var grid_color = Color(0.88, 0.88, 0.88, 1)
	for i in range(5):
		var frac = float(i) / 4.0
		var gy = pad_top + frac * gh
		ctrl.draw_line(Vector2(pad_left, gy), Vector2(pad_left + gw, gy), grid_color, 1)
		var val = int(max_val * (1.0 - frac))
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, gy + 5), "$%s" % _format_money_short(val), HORIZONTAL_ALIGNMENT_LEFT, pad_left - 4, 10, COLOR_GRAY)

	# Bars
	for i in range(n):
		var g = groups[i]
		var slot_x = pad_left + float(i) * slot_w
		var cx = slot_x + slot_w * 0.5

		var inc_h = (float(g["income"]) / float(max_val)) * gh
		var exp_h = (float(g["expenses"]) / float(max_val)) * gh

		ctrl.draw_rect(Rect2(cx - bar_w - 1, pad_top + gh - inc_h, bar_w, inc_h), COLOR_GREEN)
		ctrl.draw_rect(Rect2(cx + 1, pad_top + gh - exp_h, bar_w, exp_h), COLOR_RED)

		if i % max(1, int(ceil(float(n) / 10.0))) == 0:
			ctrl.draw_string(ThemeDB.fallback_font, Vector2(cx - 12, h - 6), str(g["day"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COLOR_GRAY)

# =========================================================
#  WIDGET 4: P&L TABLE
# =========================================================

func _build_pnl_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Header row
	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(header_hbox)

	header_hbox.add_child(_make_title("📋 " + tr("REPORTS_PNL")))

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)

	_pnl_prev_btn = Button.new()
	_pnl_prev_btn.text = "◀"
	_pnl_prev_btn.custom_minimum_size = Vector2(30, 26)
	_pnl_prev_btn.focus_mode = Control.FOCUS_NONE
	_pnl_prev_btn.pressed.connect(_on_pnl_prev)
	_style_small_btn(_pnl_prev_btn)
	header_hbox.add_child(_pnl_prev_btn)

	_pnl_month_label = Label.new()
	_pnl_month_label.text = ""
	_pnl_month_label.add_theme_font_size_override("font_size", 13)
	_pnl_month_label.add_theme_color_override("font_color", COLOR_DARK)
	_pnl_month_label.custom_minimum_size = Vector2(120, 0)
	_pnl_month_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_pnl_month_label, "semibold")
	header_hbox.add_child(_pnl_month_label)

	_pnl_next_btn = Button.new()
	_pnl_next_btn.text = "▶"
	_pnl_next_btn.custom_minimum_size = Vector2(30, 26)
	_pnl_next_btn.focus_mode = Control.FOCUS_NONE
	_pnl_next_btn.pressed.connect(_on_pnl_next)
	_style_small_btn(_pnl_next_btn)
	header_hbox.add_child(_pnl_next_btn)

	_pnl_vbox = VBoxContainer.new()
	_pnl_vbox.add_theme_constant_override("separation", 0)
	_pnl_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_pnl_vbox)

	return card

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

func _on_pnl_prev():
	_pnl_month_index = max(0, _pnl_month_index - 1)
	_refresh_pnl()

func _on_pnl_next():
	var max_month = _get_max_pnl_month_index()
	_pnl_month_index = min(max_month, _pnl_month_index + 1)
	_refresh_pnl()

func _get_max_pnl_month_index() -> int:
	var records = FinancialHistory.daily_records
	if records.is_empty(): return 0
	var months_set = {}
	for r in records:
		var m = _day_to_month(int(r.get("day", 1)))
		months_set[m] = true
	return max(0, months_set.size() - 1)

func _day_to_month(day: int) -> int:
	return max(1, int(ceil(float(day) / float(GameTime.DAYS_IN_MONTH))))

func _get_pnl_month_records(month_index: int) -> Array:
	var all = FinancialHistory.daily_records
	if all.is_empty(): return []
	var months_list: Array = []
	var seen = {}
	for r in all:
		var m = _day_to_month(int(r.get("day", 1)))
		if not seen.has(m):
			seen[m] = true
			months_list.append(m)
	months_list.sort()
	if month_index >= months_list.size(): return []
	var target = months_list[month_index]
	var result = []
	for r in all:
		if _day_to_month(int(r.get("day", 1))) == target:
			result.append(r)
	return result

func _refresh_pnl():
	if not _pnl_vbox: return
	for c in _pnl_vbox.get_children():
		c.queue_free()

	var max_idx = _get_max_pnl_month_index()
	# Clamp month index
	_pnl_month_index = clamp(_pnl_month_index, 0, max_idx)

	# Update nav buttons
	if _pnl_prev_btn: _pnl_prev_btn.disabled = (_pnl_month_index == 0)
	if _pnl_next_btn: _pnl_next_btn.disabled = (_pnl_month_index >= max_idx)
	if _pnl_month_label:
		_pnl_month_label.text = tr("REPORTS_PERIOD_MONTH") + " " + str(_pnl_month_index + 1)

	var records = _get_pnl_month_records(_pnl_month_index)
	if records.is_empty():
		var lbl = Label.new()
		lbl.text = tr("REPORTS_NO_DATA")
		lbl.add_theme_color_override("font_color", COLOR_GRAY)
		lbl.add_theme_font_size_override("font_size", 14)
		_pnl_vbox.add_child(lbl)
		return

	var total_income = 0
	var total_salary = 0
	var total_pm_salary = 0
	var total_penalties = 0
	var total_office = 0
	for r in records:
		total_income    += int(r.get("income", 0))
		total_salary    += int(r.get("salary_total", 0)) - int(r.get("pm_salary", 0))
		total_pm_salary += int(r.get("pm_salary", 0))
		total_penalties += int(r.get("penalties", 0))
		total_office    += int(r.get("office_costs", 0))

	var total_expenses = total_salary + total_pm_salary + total_penalties + total_office
	var net = total_income - total_expenses

	var rows = [
		{"label": tr("REPORTS_PROJECT_INCOME"), "value": total_income, "is_income": true, "bold": false},
		{"label": "────────────────────────────────────────", "value": -999, "is_income": false, "bold": false},
		{"label": tr("REPORTS_SALARIES"),   "value": -total_salary,    "is_income": false, "bold": false},
		{"label": tr("REPORTS_PM_SALARY"),  "value": -total_pm_salary, "is_income": false, "bold": false},
		{"label": tr("REPORTS_PENALTIES"),  "value": -total_penalties, "is_income": false, "bold": false},
		{"label": tr("REPORTS_OFFICE"),     "value": -total_office,    "is_income": false, "bold": false},
		{"label": "────────────────────────────────────────", "value": -999, "is_income": false, "bold": false},
		{"label": tr("REPORTS_TOTAL"),      "value": net, "is_income": net >= 0, "bold": true},
	]

	for idx in range(rows.size()):
		var row = rows[idx]
		if row["value"] == -999:
			var sep = HSeparator.new()
			_pnl_vbox.add_child(sep)
			continue

		var bg_color = Color(0.97, 0.97, 0.97, 1) if idx % 2 == 0 else Color(1, 1, 1, 1)
		var row_panel = PanelContainer.new()
		var row_style = StyleBoxFlat.new()
		row_style.bg_color = bg_color
		row_panel.add_theme_stylebox_override("panel", row_style)
		_pnl_vbox.add_child(row_panel)

		var hbox = HBoxContainer.new()
		row_panel.add_child(hbox)

		var name_lbl = Label.new()
		name_lbl.text = row["label"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", COLOR_DARK)
		name_lbl.add_theme_font_size_override("font_size", 13)
		if row["bold"]:
			if UITheme: UITheme.apply_font(name_lbl, "semibold")
		else:
			if UITheme: UITheme.apply_font(name_lbl, "regular")
		hbox.add_child(name_lbl)

		var val_lbl = Label.new()
		var val = int(row["value"])
		if row["is_income"]:
			val_lbl.text = "+$%s" % _format_money(val)
			val_lbl.add_theme_color_override("font_color", COLOR_GREEN)
		else:
			val_lbl.text = "-$%s" % _format_money(abs(val))
			val_lbl.add_theme_color_override("font_color", COLOR_RED)
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.custom_minimum_size = Vector2(140, 0)
		if row["bold"]:
			if UITheme: UITheme.apply_font(val_lbl, "semibold")
		else:
			if UITheme: UITheme.apply_font(val_lbl, "regular")
		hbox.add_child(val_lbl)

# =========================================================
#  WIDGET 5: PROJECT ROI
# =========================================================

func _build_roi_card() -> PanelContainer:
	var card = _make_card()
	var margin = _make_card_margin()
	card.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	vbox.add_child(_make_title("🎯 " + tr("REPORTS_PROJECT_ROI")))

	_roi_scroll = ScrollContainer.new()
	_roi_scroll.custom_minimum_size = Vector2(0, 60)
	_roi_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roi_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_roi_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_roi_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(_roi_scroll)

	_roi_chart = Control.new()
	_roi_chart.custom_minimum_size = Vector2(0, 60)
	_roi_chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roi_chart.draw.connect(_draw_roi_bars.bind(_roi_chart))
	_roi_scroll.add_child(_roi_chart)

	return card

func _refresh_roi():
	if not _roi_chart: return
	var projects = _get_all_project_details()
	var max_visible = 10
	var row_h = 36.0
	var chart_h = projects.size() * row_h + 20.0
	var scroll_h = min(chart_h, max_visible * row_h + 20.0)
	_roi_chart.custom_minimum_size = Vector2(0, max(60.0, chart_h))
	if _roi_scroll:
		_roi_scroll.custom_minimum_size = Vector2(0, max(60.0, scroll_h))
	_roi_chart.queue_redraw()

func _get_all_project_details() -> Array:
	var result = []
	for r in FinancialHistory.daily_records:
		for p in r.get("project_income_details", []):
			result.append(p)
	# Sort by absolute profit descending
	result.sort_custom(func(a, b): return abs(int(a.get("profit", 0))) > abs(int(b.get("profit", 0))))
	return result

func _draw_roi_bars(ctrl: Control):
	var projects = _get_all_project_details()
	if projects.is_empty():
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(20, 30), tr("REPORTS_NO_DATA"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GRAY)
		return

	var w = ctrl.size.x
	var pad_left = 160.0
	var pad_right = 100.0
	var bar_max_w = w - pad_left - pad_right
	var row_h = 36.0
	var bar_h = 22.0

	var max_abs_profit = 1
	for p in projects:
		max_abs_profit = max(max_abs_profit, abs(int(p.get("profit", 0))))

	for i in range(projects.size()):
		var p = projects[i]
		var profit = int(p.get("profit", 0))
		var title = str(p.get("title", "?"))
		var cy = float(i) * row_h + 10.0
		var bar_y = cy + (row_h - bar_h) * 0.5

		# Project name (truncated)
		var short_title = title.substr(0, 18) + ("…" if title.length() > 18 else "")
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(0, cy + bar_h * 0.5 + 5), short_title, HORIZONTAL_ALIGNMENT_LEFT, pad_left - 8, 12, COLOR_DARK)

		# Bar
		var bar_w = (float(abs(profit)) / float(max_abs_profit)) * bar_max_w
		var color = COLOR_GREEN if profit >= 0 else COLOR_RED
		ctrl.draw_rect(Rect2(pad_left, bar_y, bar_w, bar_h), color)

		# Profit label
		var sign = "+" if profit >= 0 else ""
		ctrl.draw_string(ThemeDB.fallback_font, Vector2(pad_left + bar_w + 8, cy + bar_h * 0.5 + 5), sign + "$%s" % _format_money(profit), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

# =========================================================
#  HELPERS
# =========================================================

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

func _format_money_short(amount: int) -> String:
	var abs_v = abs(amount)
	var sign = "-" if amount < 0 else ""
	if abs_v >= 1000000:
		return sign + "%.1fM" % (float(abs_v) / 1000000.0)
	if abs_v >= 1000:
		return sign + "%.0fK" % (float(abs_v) / 1000.0)
	return sign + str(abs_v)

func _format_money_axis(amount: int) -> String:
	var sign = "-" if amount < 0 else ""
	var abs_v = abs(amount)
	if abs_v >= 1000000:
		return "$" + sign + "%.1fM" % (float(abs_v) / 1000000.0)
	elif abs_v >= 10000:
		return "$" + sign + "%.0fK" % (float(abs_v) / 1000.0)
	elif abs_v >= 1000:
		return "$" + sign + "%.1fK" % (float(abs_v) / 1000.0)
	else:
		return "$" + sign + str(abs_v)
