extends Control

signal assignment_requested(track_index)
signal worker_removed(track_index, worker_index)

@onready var role_label = $Layout/RoleLabel
@onready var assign_wrapper = $Layout/AssignWrapper
@onready var original_btn = $Layout/AssignWrapper/AssignButton
@onready var progress_label = $Layout/ProgressLabel
@onready var visual_bar = $Layout/GanttArea/VisualBar
@onready var progress_bar = $Layout/GanttArea/ProgressBar
@onready var gantt_area = $Layout/GanttArea

const BAR_HEIGHT = 24.0
const BUTTON_HEIGHT = 30.0
const BASE_TRACK_HEIGHT = 60.0

var stage_index: int = -1
var stage_data: Dictionary = {}
var is_readonly: bool = false
var is_stage_completed: bool = false

var _btn_style: StyleBox = null
var _btn_font_color: Color = Color.WHITE
var _btn_min_size: Vector2 = Vector2(180, 40)

var _buttons_container: VBoxContainer = null

func setup(index: int, data: Dictionary, readonly: bool = false):
	stage_index = index
	stage_data = data
	is_readonly = readonly
	is_stage_completed = data.get("is_completed", false)
	role_label.text = data.type
	progress_label.text = "%d / %d" % [int(data.progress), int(data.amount)]

	if UITheme:
		UITheme.apply_font(role_label, "semibold")
		UITheme.apply_font(progress_label, "semibold")

	_capture_original_style()
	rebuild_worker_buttons()

	visual_bar.visible = false
	progress_bar.visible = false

func _ready():
	pass

func _capture_original_style():
	if original_btn:
		var style = original_btn.get_theme_stylebox("normal")
		if style:
			_btn_style = style.duplicate()
		_btn_font_color = original_btn.get_theme_color("font_color")
		_btn_min_size = original_btn.custom_minimum_size
		original_btn.visible = false

func _create_styled_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = _btn_min_size
	if _btn_style:
		btn.add_theme_stylebox_override("normal", _btn_style.duplicate())
	btn.add_theme_color_override("font_color", _btn_font_color)
	if UITheme: UITheme.apply_font(btn, "semibold")
	return btn

func _create_remove_button() -> Button:
	var btn = Button.new()
	btn.text = "−"
	btn.custom_minimum_size = Vector2(30, 30)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style.duplicate())
	btn.add_theme_stylebox_override("pressed", style.duplicate())
	btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	if UITheme: UITheme.apply_font(btn, "bold")
	return btn

func rebuild_worker_buttons():
	if _buttons_container:
		assign_wrapper.remove_child(_buttons_container)
		_buttons_container.queue_free()
		_buttons_container = null

	_buttons_container = VBoxContainer.new()
	_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_container.add_theme_constant_override("separation", 8)
	assign_wrapper.add_child(_buttons_container)

	if is_stage_completed:
		var completed_names = stage_data.get("completed_worker_names", [])
		if completed_names.is_empty():
			for w in stage_data.get("workers", []):
				completed_names.append(w.employee_name)

		for worker_name in completed_names:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.alignment = BoxContainer.ALIGNMENT_CENTER

			var check_lbl = Label.new()
			check_lbl.text = "✅ " + worker_name
			check_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
			check_lbl.custom_minimum_size = Vector2(140, 30)
			check_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			check_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if UITheme: UITheme.apply_font(check_lbl, "semibold")
			row.add_child(check_lbl)

			_buttons_container.add_child(row)

		_update_track_height(completed_names.size())
		return

	var workers = stage_data.get("workers", [])

	for i in range(workers.size()):
		var worker = workers[i]

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		if not is_readonly:
			var remove_btn = _create_remove_button()
			var worker_idx = i
			remove_btn.pressed.connect(func(): emit_signal("worker_removed", stage_index, worker_idx))
			row.add_child(remove_btn)

		var name_label = Label.new()
		name_label.text = "👤 " + worker.employee_name
		name_label.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		name_label.custom_minimum_size = Vector2(140, 30)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if UITheme: UITheme.apply_font(name_label, "regular")
		row.add_child(name_label)

		_buttons_container.add_child(row)

	if not is_readonly:
		var add_btn = _create_styled_button("+ Назначить")
		add_btn.modulate = Color.WHITE
		add_btn.pressed.connect(func(): emit_signal("assignment_requested", stage_index))
		_buttons_container.add_child(add_btn)

	_update_track_height(workers.size())

func _update_track_height(worker_count: int):
	var extra = 1 if (not is_readonly and not is_stage_completed) else 0
	var total_buttons = worker_count + extra
	var needed_height = max(BASE_TRACK_HEIGHT, total_buttons * (BUTTON_HEIGHT + 10) + 20)
	custom_minimum_size.y = needed_height

func update_button_visuals():
	rebuild_worker_buttons()

func update_visuals_dynamic(px_per_day: float, current_project_time: float, color: Color):
	update_visuals_dynamic_offset(px_per_day, current_project_time, color, 0.0)

func update_visuals_dynamic_offset(px_per_day: float, current_project_time: float, color: Color, start_offset: float):
	var has_workers = stage_data.get("workers", []).size() > 0
	var has_completed_names = stage_data.get("completed_worker_names", []).size() > 0

	if not has_workers and not has_completed_names:
		visual_bar.visible = false
		progress_bar.visible = false
		return

	visual_bar.visible = true
	var plan_start = stage_data.get("plan_start", 0.0)
	var plan_dur = stage_data.get("plan_duration", 0.0)
	visual_bar.position.x = (start_offset + plan_start) * px_per_day
	visual_bar.size.x = plan_dur * px_per_day
	visual_bar.size.y = BAR_HEIGHT
	visual_bar.position.y = (size.y - BAR_HEIGHT) / 2.0

	var style = visual_bar.get_theme_stylebox("panel")
	if style:
		style = style.duplicate()
		style.bg_color = color
		visual_bar.add_theme_stylebox_override("panel", style)
	visual_bar.modulate.a = 0.4

	var act_start = stage_data.get("actual_start", -1.0)
	var act_end = stage_data.get("actual_end", -1.0)

	if act_start != -1.0:
		progress_bar.visible = true
		var fact_height = BAR_HEIGHT * 0.6
		progress_bar.size.y = fact_height
		progress_bar.position.y = (size.y - fact_height) / 2.0
		progress_bar.position.x = (start_offset + act_start) * px_per_day

		var duration = 0.0
		if act_end != -1.0:
			duration = act_end - act_start
		else:
			duration = current_project_time - act_start
			if duration < 0: duration = 0

		progress_bar.size.x = duration * px_per_day
	else:
		progress_bar.visible = false

func update_bar_preview(start_px, width_px, color):
	visual_bar.visible = true
	progress_bar.visible = false
	var style = visual_bar.get_theme_stylebox("panel")
	if style:
		style = style.duplicate()
		style.bg_color = color
		visual_bar.add_theme_stylebox_override("panel", style)
	visual_bar.position.x = start_px
	visual_bar.size.x = width_px
	visual_bar.size.y = BAR_HEIGHT
	visual_bar.position.y = (size.y - BAR_HEIGHT) / 2.0

func update_progress(percent: float):
	var current_val = int(stage_data.amount * percent)
	progress_label.text = "%d / %d" % [current_val, stage_data.amount]
	if percent >= 1.0:
		progress_label.modulate = Color.GREEN
	else:
		progress_label.modulate = Color("d93636")

func get_gantt_offset() -> float:
	return gantt_area.position.x
