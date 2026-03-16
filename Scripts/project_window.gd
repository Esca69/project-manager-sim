extends Control

signal closed

@onready var title_label = $MainLayout/HeaderPanel/TitleLabel
@onready var close_window_btn = $MainLayout/HeaderPanel/CloseButton
@onready var deadline_label = $MainLayout/ContentWrapper/Body/InfoRow/DeadlineLabel
@onready var budget_label = $MainLayout/ContentWrapper/Body/InfoRow/BudgetLabel
@onready var timeline_header = $MainLayout/ContentWrapper/Body/TableHeader/TimelineHeader
@onready var tracks_container = $MainLayout/ContentWrapper/Body/TracksContainer
@onready var start_btn = $MainLayout/ContentWrapper/Body/Footer/StartButton

@export var track_scene: PackedScene

var project: ProjectData
var selector_ref
var current_selecting_track_index: int = -1

const GANTT_VIEW_WIDTH = 900.0
const MIN_TIMELINE_DAYS = 7.0

# === CRUNCH TIME: UI элементы ===
var _crunch_btn: Button = null
var _crunch_help_btn: Button = null
var _crunch_tooltip_ref: Array = [null]
const COLOR_CRUNCH = Color(0.17254902, 0.30980393, 0.5686275, 1)  # Стандартный синий цвет UI

var current_time_line: ColorRect
var soft_deadline_line: ColorRect
var hard_deadline_line: ColorRect
var _bg_overlay: ColorRect

# Красивый зелёный цвет для кнопки СТАРТ
var color_green_main = Color(0.29803923, 0.6862745, 0.3137255, 1)

func _get_origin_time() -> float:
	return float(project.created_at_day) + float(GameTime.START_HOUR) / 24.0

func setup(data: ProjectData, selector_node):
	project = data
	selector_ref = selector_node

	var cat_label = project.get_category_label()
	var client_prefix = ""
	if project.client_id != "":
		var client = project.get_client()
		if client:
			# ИСПРАВЛЕНИЕ: Используем get_display_name()
			client_prefix = client.get_display_name() + "  —  "
	
	# ИСПРАВЛЕНИЕ: Используем get_display_title()
	title_label.text = client_prefix + cat_label + " " + project.get_display_title()

	var deadline_date = GameTime.get_date_short(project.deadline_day)
	var days_left = project.deadline_day - GameTime.day
	var soft_date = GameTime.get_date_short(project.soft_deadline_day)
	var soft_left = project.soft_deadline_day - GameTime.day
	
	deadline_label.text = tr("PROJ_WIN_DEADLINE_COMBINED") % [
		soft_date, soft_left, project.soft_deadline_penalty_percent, deadline_date, days_left
	]

	var is_failed = (project.state == ProjectData.State.FAILED)
	var is_readonly = (project.state == ProjectData.State.FINISHED or is_failed)

	for child in tracks_container.get_children():
		tracks_container.remove_child(child)
		child.queue_free()

	for i in range(project.stages.size()):
		var stage = project.stages[i]
		_migrate_stage(stage)
		if not stage.has("plan_start"): stage["plan_start"] = 0.0
		if not stage.has("plan_duration"): stage["plan_duration"] = 0.0
		if not stage.has("actual_start"): stage["actual_start"] = -1.0
		if not stage.has("actual_end"): stage["actual_end"] = -1.0
		if not stage.has("is_completed"): stage["is_completed"] = false

		var stage_readonly = is_readonly or stage.get("is_completed", false)

		if is_failed and not stage.get("is_completed", false):
			stage_readonly = true
			stage["is_completed"] = true
			if stage.get("actual_start", -1.0) != -1.0 and stage.get("actual_end", -1.0) == -1.0:
				stage["actual_end"] = project.elapsed_days

		var new_track = track_scene.instantiate()
		tracks_container.add_child(new_track)
		new_track.setup(i, stage, stage_readonly)

		new_track.assignment_requested.connect(_on_track_assignment_requested)
		new_track.worker_removed.connect(_on_worker_removed)

	if not selector_ref.employee_selected.is_connected(_on_employee_chosen):
		selector_ref.employee_selected.connect(_on_employee_chosen)

	update_buttons_visibility()
	create_time_line_if_needed()
	call_deferred("recalculate_schedule_preview")
	
	_update_budget_display()

func _force_fullscreen_size():
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_fullscreen_size()
	timeline_header.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW

	# === Overlay: дочерний элемент, позади MainLayout ===
	_bg_overlay = ColorRect.new()
	_bg_overlay.color = Color(0, 0, 0, 0.45)
	_bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg_overlay)
	move_child(_bg_overlay, 0)

	# === ИСПРАВЛЕНИЕ: Переводим хардкодные заголовки столбцов ===
	var col_role = $MainLayout/ContentWrapper/Body/TableHeader/Label
	var col_assignee = $MainLayout/ContentWrapper/Body/TableHeader/Label2
	var col_progress = $MainLayout/ContentWrapper/Body/TableHeader/Label3
	
	if col_role: col_role.text = tr("TRACK_COL_ROLE")
	if col_assignee: col_assignee.text = tr("TRACK_COL_ASSIGNEE")
	if col_progress: col_progress.text = tr("TRACK_COL_PROGRESS")
	
	var cancel_node = $MainLayout/ContentWrapper/Body/Footer/CancelButton
	if cancel_node:
		cancel_node.queue_free()

	start_btn.pressed.connect(_on_start_pressed)
	start_btn.text = tr("PROJ_WIN_BTN_START")
	
	close_window_btn.pressed.connect(close)

	var start_style_normal = StyleBoxFlat.new()
	start_style_normal.bg_color = Color(1, 1, 1, 1)
	start_style_normal.border_width_left = 2
	start_style_normal.border_width_top = 2
	start_style_normal.border_width_right = 2
	start_style_normal.border_width_bottom = 2
	start_style_normal.border_color = color_green_main
	start_style_normal.corner_radius_top_left = 20
	start_style_normal.corner_radius_top_right = 20
	start_style_normal.corner_radius_bottom_right = 20
	start_style_normal.corner_radius_bottom_left = 20

	var start_style_hover = StyleBoxFlat.new()
	start_style_hover.bg_color = color_green_main
	start_style_hover.border_width_left = 2
	start_style_hover.border_width_top = 2
	start_style_hover.border_width_right = 2
	start_style_hover.border_width_bottom = 2
	start_style_hover.border_color = color_green_main
	start_style_hover.corner_radius_top_left = 20
	start_style_hover.corner_radius_top_right = 20
	start_style_hover.corner_radius_bottom_right = 20
	start_style_hover.corner_radius_bottom_left = 20

	start_btn.add_theme_stylebox_override("normal", start_style_normal)
	start_btn.add_theme_stylebox_override("hover", start_style_hover)
	start_btn.add_theme_stylebox_override("pressed", start_style_hover)
	
	start_btn.add_theme_color_override("font_color", color_green_main)
	start_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	start_btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.93, 0.93, 0.93, 1) 
	disabled_style.border_width_left = 2
	disabled_style.border_width_top = 2
	disabled_style.border_width_right = 2
	disabled_style.border_width_bottom = 2
	disabled_style.border_color = Color(0.8, 0.8, 0.8, 1)
	disabled_style.corner_radius_top_left = 20
	disabled_style.corner_radius_top_right = 20
	disabled_style.corner_radius_bottom_right = 20
	disabled_style.corner_radius_bottom_left = 20
	start_btn.add_theme_stylebox_override("disabled", disabled_style)
	start_btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 1))

	# === CRUNCH TIME: Создаём кнопку кранча в футере ===
	_build_crunch_row()

	if UITheme:
		UITheme.apply_font(title_label, "bold")
		UITheme.apply_font(deadline_label, "regular")
		UITheme.apply_font(budget_label, "bold")
		UITheme.apply_font(start_btn, "semibold")
		UITheme.apply_font(close_window_btn, "semibold")
		
		# Применяем шрифты к нашим заголовкам тоже
		if col_role: UITheme.apply_font(col_role, "semibold")
		if col_assignee: UITheme.apply_font(col_assignee, "semibold")
		if col_progress: UITheme.apply_font(col_progress, "semibold")

# === CRUNCH TIME: Создаём ряд с кнопкой кранча в футере ===
func _build_crunch_row():
	var footer = $MainLayout/ContentWrapper/Body/Footer
	if not footer:
		return

	var crunch_hbox = HBoxContainer.new()
	crunch_hbox.name = "CrunchRow"
	crunch_hbox.add_theme_constant_override("separation", 8)
	crunch_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_child(crunch_hbox)

	_crunch_btn = Button.new()
	_crunch_btn.text = tr("CRUNCH_TIME_BUTTON")
	_crunch_btn.custom_minimum_size = Vector2(160, 40)
	_crunch_btn.visible = false
	_crunch_btn.focus_mode = Control.FOCUS_NONE

	var crunch_style_normal = StyleBoxFlat.new()
	crunch_style_normal.bg_color = Color(1, 1, 1, 1)
	crunch_style_normal.border_width_left = 2
	crunch_style_normal.border_width_top = 2
	crunch_style_normal.border_width_right = 2
	crunch_style_normal.border_width_bottom = 2
	crunch_style_normal.border_color = COLOR_CRUNCH
	crunch_style_normal.corner_radius_top_left = 20
	crunch_style_normal.corner_radius_top_right = 20
	crunch_style_normal.corner_radius_bottom_right = 20
	crunch_style_normal.corner_radius_bottom_left = 20

	var crunch_style_hover = StyleBoxFlat.new()
	crunch_style_hover.bg_color = COLOR_CRUNCH
	crunch_style_hover.border_width_left = 2
	crunch_style_hover.border_width_top = 2
	crunch_style_hover.border_width_right = 2
	crunch_style_hover.border_width_bottom = 2
	crunch_style_hover.border_color = COLOR_CRUNCH
	crunch_style_hover.corner_radius_top_left = 20
	crunch_style_hover.corner_radius_top_right = 20
	crunch_style_hover.corner_radius_bottom_right = 20
	crunch_style_hover.corner_radius_bottom_left = 20

	var crunch_style_disabled = StyleBoxFlat.new()
	crunch_style_disabled.bg_color = Color(0.93, 0.93, 0.93, 1)
	crunch_style_disabled.border_width_left = 2
	crunch_style_disabled.border_width_top = 2
	crunch_style_disabled.border_width_right = 2
	crunch_style_disabled.border_width_bottom = 2
	crunch_style_disabled.border_color = Color(0.8, 0.8, 0.8, 1)
	crunch_style_disabled.corner_radius_top_left = 20
	crunch_style_disabled.corner_radius_top_right = 20
	crunch_style_disabled.corner_radius_bottom_right = 20
	crunch_style_disabled.corner_radius_bottom_left = 20

	_crunch_btn.add_theme_stylebox_override("normal", crunch_style_normal)
	_crunch_btn.add_theme_stylebox_override("hover", crunch_style_hover)
	_crunch_btn.add_theme_stylebox_override("pressed", crunch_style_hover)
	_crunch_btn.add_theme_stylebox_override("disabled", crunch_style_disabled)
	_crunch_btn.add_theme_color_override("font_color", COLOR_CRUNCH)
	_crunch_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_crunch_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	_crunch_btn.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 1))

	if UITheme:
		UITheme.apply_font(_crunch_btn, "semibold")

	_crunch_btn.pressed.connect(_on_crunch_pressed)
	crunch_hbox.add_child(_crunch_btn)

	# Иконка помощи (?) — стиль как _create_help_button() в employee_roster.gd
	_crunch_help_btn = Button.new()
	_crunch_help_btn.text = "?"
	_crunch_help_btn.custom_minimum_size = Vector2(22, 22)
	_crunch_help_btn.flat = false
	_crunch_help_btn.visible = false
	_crunch_help_btn.focus_mode = Control.FOCUS_NONE
	_crunch_help_btn.add_theme_font_size_override("font_size", 11)
	_crunch_help_btn.add_theme_color_override("font_color", COLOR_CRUNCH)

	var help_style_normal = StyleBoxFlat.new()
	help_style_normal.bg_color = Color(1, 1, 1, 1)
	help_style_normal.border_width_left = 2
	help_style_normal.border_width_top = 2
	help_style_normal.border_width_right = 2
	help_style_normal.border_width_bottom = 2
	help_style_normal.border_color = COLOR_CRUNCH
	help_style_normal.corner_radius_top_left = 11
	help_style_normal.corner_radius_top_right = 11
	help_style_normal.corner_radius_bottom_right = 11
	help_style_normal.corner_radius_bottom_left = 11
	_crunch_help_btn.add_theme_stylebox_override("normal", help_style_normal)

	var help_style_hover = StyleBoxFlat.new()
	help_style_hover.bg_color = Color(0.92, 0.94, 1.0, 1)
	help_style_hover.border_width_left = 2
	help_style_hover.border_width_top = 2
	help_style_hover.border_width_right = 2
	help_style_hover.border_width_bottom = 2
	help_style_hover.border_color = COLOR_CRUNCH
	help_style_hover.corner_radius_top_left = 11
	help_style_hover.corner_radius_top_right = 11
	help_style_hover.corner_radius_bottom_right = 11
	help_style_hover.corner_radius_bottom_left = 11
	_crunch_help_btn.add_theme_stylebox_override("hover", help_style_hover)

	if UITheme:
		UITheme.apply_font(_crunch_help_btn, "semibold")

	crunch_hbox.add_child(_crunch_help_btn)

	# Тултип при наведении
	_crunch_help_btn.mouse_entered.connect(_on_crunch_help_hover)
	_crunch_help_btn.mouse_exited.connect(_on_crunch_help_exit)

	# === Сбрасываем disabled при начале нового рабочего дня ===
	GameTime.work_started.connect(func(): _update_crunch_btn())

# === CRUNCH TIME: Обновить состояние кнопки кранча ===
func _update_crunch_btn():
	if not _crunch_btn or not project:
		return

	var is_in_progress = (project.state == ProjectData.State.IN_PROGRESS)
	var is_work_time = not GameTime.is_weekend() and GameTime.hour >= GameTime.START_HOUR and GameTime.hour < 20
	var should_show = is_in_progress and is_work_time

	_crunch_btn.visible = should_show
	if _crunch_help_btn:
		_crunch_help_btn.visible = should_show

	if should_show:
		if project.crunch_active:
			_crunch_btn.text = tr("CRUNCH_TIME_BUTTON_ON")
			_crunch_btn.disabled = true
		else:
			_crunch_btn.text = tr("CRUNCH_TIME_BUTTON")
			_crunch_btn.disabled = false

# === CRUNCH TIME: Активация кранча (только включить, выключить нельзя) ===
func _on_crunch_pressed():
	if not project or project.state != ProjectData.State.IN_PROGRESS:
		return
	project.crunch_active = true
	_update_crunch_btn()
	print("🔥 Кранч активирован для проекта: %s" % project.get_display_title())
	if Engine.has_singleton("EventLog"):
		var el = Engine.get_singleton("EventLog")
		el.add(tr("LOG_CRUNCH_ACTIVATED") % project.get_display_title(), 1)

# === CRUNCH TIME: Тултип при наведении на иконку ? ===
func _on_crunch_help_hover():
	if _crunch_tooltip_ref[0] != null and is_instance_valid(_crunch_tooltip_ref[0]):
		_crunch_tooltip_ref[0].queue_free()
	var tooltip_text = tr("CRUNCH_TIME_TOOLTIP")
	var tp = TraitUIHelper._create_tooltip(tooltip_text, COLOR_CRUNCH)
	add_child(tp)
	await get_tree().process_frame
	if not is_instance_valid(tp): return
	if _crunch_help_btn:
		var btn_global = _crunch_help_btn.global_position
		tp.global_position = Vector2(btn_global.x + 28, btn_global.y - 10)
	_crunch_tooltip_ref[0] = tp

func _on_crunch_help_exit():
	if _crunch_tooltip_ref[0] != null and is_instance_valid(_crunch_tooltip_ref[0]):
		_crunch_tooltip_ref[0].queue_free()
		_crunch_tooltip_ref[0] = null

# === Закрытие окна (кнопка X + ESC) ===
func close():
	# === CRUNCH TIME: Убираем тултип при закрытии окна ===
	_on_crunch_help_exit()
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false
	emit_signal("closed")

# === Обработка ESC ===
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		if selector_ref and selector_ref.visible:
			return
		close()
		get_viewport().set_input_as_handled()

func _update_budget_display():
	if not project: return
	var current_payout = project.budget
	var is_penalty = false
	var is_failed = false

	if project.state == ProjectData.State.FAILED:
		current_payout = 0
		is_failed = true
	elif project.state == ProjectData.State.FINISHED:
		var finish_day = project.created_at_day
		if project.start_global_time > 0:
			var last_end = 0.0
			for s in project.stages:
				if s.get("actual_end", -1.0) > last_end:
					last_end = s["actual_end"]
			finish_day = int(project.start_global_time + last_end)
		current_payout = project.get_final_payout(finish_day)
		if current_payout < project.budget:
			is_penalty = true
	else:
		current_payout = project.get_final_payout(GameTime.day)
		if current_payout < project.budget:
			is_penalty = true

	if is_failed:
		budget_label.text = tr("PROJ_LIST_BUDGET_FAILED")
		budget_label.add_theme_color_override("font_color", Color(0.85, 0.21, 0.21))
	elif is_penalty:
		budget_label.text = tr("PROJECT_BUDGET") % current_payout
		budget_label.add_theme_color_override("font_color", Color(0.9, 0.72, 0.04))
	else:
		budget_label.text = tr("PROJECT_BUDGET") % project.budget
		budget_label.add_theme_color_override("font_color", Color(0.3, 0.69, 0.31))

func _migrate_stage(stage: Dictionary):
	if stage.has("worker"):
		if not stage.has("workers"):
			stage["workers"] = []
		if stage["worker"] != null and stage["worker"] not in stage["workers"]:
			stage["workers"].append(stage["worker"])
		stage.erase("worker")
	if not stage.has("workers"):
		stage["workers"] = []

func update_buttons_visibility():
	if project.state == ProjectData.State.IN_PROGRESS or project.state == ProjectData.State.FINISHED or project.state == ProjectData.State.FAILED:
		start_btn.visible = false
	else:
		start_btn.visible = true
		_update_crunch_btn()

func get_current_global_time() -> float:
	var day_part = float(GameTime.hour) / 24.0
	var min_part = float(GameTime.minute) / (24.0 * 60.0)
	return float(GameTime.day) + day_part + min_part

func _on_start_pressed():
	freeze_plan()
	var now = get_current_global_time()
	project.start_global_time = now
	project.state = project.State.IN_PROGRESS
	# ИСПРАВЛЕНИЕ: Вывод переведенного имени проекта в лог
	print(tr("LOG_PROJECT_STARTED") % [project.get_display_title(), project.start_global_time])
	
	# === СИСТЕМА АДАПТАЦИИ: Выдаём штраф всем, кто назначен на проект при старте ===
	var proj_id = project.title
	for stage in project.stages:
		for worker in stage.workers:
			if worker is EmployeeData:
				if not worker.known_project_ids.has(proj_id):
					worker.known_project_ids.append(proj_id)
					worker.project_adapt_hours_left = 24.0
					# ИСПРАВЛЕНИЕ: Вывод переведенного имени сотрудника в лог
					print("📚 %s начинает новый проект. Штраф адаптации на 24 часа." % worker.get_display_name())
					if Engine.has_singleton("EventLog"):
						var el = Engine.get_singleton("EventLog")
						el.add(tr("LOG_PROJECT_ADAPTATION") % worker.get_display_name(), 2)
	
	update_buttons_visibility()

func _process(delta):
	if not project: return
	if not visible: return
	
	_update_budget_display()
	_update_crunch_btn()

	var origin_day = project.created_at_day
	var origin_time = _get_origin_time()
	var is_done = (project.state == ProjectData.State.FINISHED or project.state == ProjectData.State.FAILED)

	var line_height = timeline_header.size.y + tracks_container.size.y + 10

	if project.state == ProjectData.State.DRAFTING:
		var horizon_from_origin = float(project.deadline_day - origin_day) * 1.1
		if horizon_from_origin < MIN_TIMELINE_DAYS:
			horizon_from_origin = MIN_TIMELINE_DAYS
		var pixels_per_day = GANTT_VIEW_WIDTH / horizon_from_origin

		if current_time_line:
			var now_offset = get_current_global_time() - origin_time
			current_time_line.position.x = now_offset * pixels_per_day
			current_time_line.size.y = line_height
			current_time_line.visible = true

		if soft_deadline_line and project.soft_deadline_day > 0:
			var soft_offset = float(project.soft_deadline_day - origin_day)
			soft_deadline_line.position.x = soft_offset * pixels_per_day
			soft_deadline_line.size.y = line_height
			soft_deadline_line.visible = true

		if hard_deadline_line and project.deadline_day > 0:
			var hard_offset = float(project.deadline_day - origin_day)
			hard_deadline_line.position.x = hard_offset * pixels_per_day
			hard_deadline_line.size.y = line_height
			hard_deadline_line.visible = true

		draw_dynamic_header(pixels_per_day, horizon_from_origin, origin_day)
		return

	var now = get_current_global_time()
	if not is_done and project.start_global_time > 0.01:
		project.elapsed_days = now - project.start_global_time

	var horizon_from_origin = float(project.deadline_day - origin_day) * 1.1
	if not is_done:
		var elapsed_from_origin = now - origin_time
		if elapsed_from_origin + 2.0 > horizon_from_origin:
			horizon_from_origin = elapsed_from_origin + 2.0
	if horizon_from_origin < MIN_TIMELINE_DAYS:
		horizon_from_origin = MIN_TIMELINE_DAYS

	var pixels_per_day = GANTT_VIEW_WIDTH / horizon_from_origin
	var start_offset = project.start_global_time - origin_time

	for i in range(project.stages.size()):
		if i < tracks_container.get_child_count():
			var stage = project.stages[i]
			var track_node = tracks_container.get_child(i)
			var stage_color = get_color_for_stage(stage.type)
			track_node.update_visuals_dynamic_offset(pixels_per_day, project.elapsed_days, stage_color, start_offset)

			var percent = 0.0
			if stage.amount > 0:
				percent = float(stage.progress) / float(stage.amount)
			track_node.update_progress(percent)

	if current_time_line:
		if is_done:
			current_time_line.visible = false
		else:
			var now_offset = now - origin_time
			current_time_line.position.x = now_offset * pixels_per_day
			current_time_line.size.y = line_height
			current_time_line.visible = true

	if soft_deadline_line and project.soft_deadline_day > 0:
		var soft_offset = float(project.soft_deadline_day - origin_day)
		soft_deadline_line.position.x = soft_offset * pixels_per_day
		soft_deadline_line.size.y = line_height
		soft_deadline_line.visible = true

	if hard_deadline_line and project.deadline_day > 0:
		var hard_offset = float(project.deadline_day - origin_day)
		hard_deadline_line.position.x = hard_offset * pixels_per_day
		hard_deadline_line.size.y = line_height
		hard_deadline_line.visible = true

	draw_dynamic_header(pixels_per_day, horizon_from_origin, origin_day)

func create_time_line_if_needed():
	if not current_time_line:
		current_time_line = ColorRect.new()
		current_time_line.color = Color(0, 0.4, 1, 0.8)
		current_time_line.size = Vector2(2, 500)
		current_time_line.z_index = 5
		current_time_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timeline_header.add_child(current_time_line)

	if not soft_deadline_line:
		soft_deadline_line = ColorRect.new()
		soft_deadline_line.color = Color(1, 0.65, 0, 0.8)
		soft_deadline_line.size = Vector2(2, 500)
		soft_deadline_line.z_index = 4
		soft_deadline_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		soft_deadline_line.visible = false
		timeline_header.add_child(soft_deadline_line)

	if not hard_deadline_line:
		hard_deadline_line = ColorRect.new()
		hard_deadline_line.color = Color(1, 0, 0, 0.8)
		hard_deadline_line.size = Vector2(2, 500)
		hard_deadline_line.z_index = 4
		hard_deadline_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hard_deadline_line.visible = false
		timeline_header.add_child(hard_deadline_line)

func freeze_plan():
	var current_time_offset_days = 0.0
	for stage in project.stages:
		stage["plan_start"] = current_time_offset_days
		var duration_days = 1.0
		var total_skill = get_total_skill_for_stage(stage)
		if total_skill > 0:
			var total_work_hours = float(stage.amount) / float(total_skill)
			duration_days = total_work_hours / 9.0
		stage["plan_duration"] = duration_days
		current_time_offset_days += duration_days

func draw_dynamic_header(px_per_day, horizon_days, origin_day: int = 0):
	for child in timeline_header.get_children():
		if child == current_time_line: continue
		if child == soft_deadline_line: continue
		if child == hard_deadline_line: continue
		child.queue_free()

	var line_height = timeline_header.size.y + tracks_container.size.y + 10
	var prev_month = -1

	for i in range(0, int(horizon_days) + 1):
		var abs_day = origin_day + i
		var day_in_month = GameTime.get_day_in_month(abs_day)
		var month_num = GameTime.get_month(abs_day)
		var weekday = GameTime.get_weekday_name(abs_day)
		var is_wknd = GameTime.is_weekend(abs_day)
		var x_pos = float(i) * px_per_day

		if is_wknd:
			var wknd_bg = ColorRect.new()
			wknd_bg.color = Color(0.0, 0.0, 0.0, 0.06)
			wknd_bg.size = Vector2(px_per_day, line_height)
			wknd_bg.position = Vector2(x_pos, 0)
			wknd_bg.z_index = -2
			wknd_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			timeline_header.add_child(wknd_bg)

		if month_num != prev_month:
			var month_lbl = Label.new()
			month_lbl.text = tr("PROJ_WIN_MONTH_SHORT") % month_num
			month_lbl.add_theme_font_size_override("font_size", 11)
			month_lbl.modulate = Color(0.17, 0.31, 0.57, 0.8)
			month_lbl.position = Vector2(x_pos + 2, -2)
			if UITheme: UITheme.apply_font(month_lbl, "semibold")
			timeline_header.add_child(month_lbl)
			if prev_month != -1:
				var month_line = ColorRect.new()
				month_line.color = Color(0.17, 0.31, 0.57, 0.4)
				month_line.size = Vector2(2, line_height)
				month_line.position = Vector2(x_pos, 0)
				month_line.z_index = -1
				month_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
				timeline_header.add_child(month_line)
			prev_month = month_num

		var day_lbl = Label.new()
		day_lbl.text = str(day_in_month)
		day_lbl.add_theme_font_size_override("font_size", 11)
		if is_wknd:
			day_lbl.modulate = Color(0.8, 0.3, 0.3, 0.7)
		else:
			day_lbl.modulate = Color(0, 0, 0, 0.5)
		day_lbl.position = Vector2(x_pos + 2, 12)
		if UITheme: UITheme.apply_font(day_lbl, "regular")
		timeline_header.add_child(day_lbl)

		if px_per_day > 25:
			var wd_lbl = Label.new()
			wd_lbl.text = weekday
			wd_lbl.add_theme_font_size_override("font_size", 9)
			wd_lbl.modulate = Color(0, 0, 0, 0.35)
			wd_lbl.position = Vector2(x_pos + 2, 24)
			if UITheme: UITheme.apply_font(wd_lbl, "regular")
			timeline_header.add_child(wd_lbl)

		var line = ColorRect.new()
		line.color = Color(0.0, 0.0, 0.0, 0.08)
		line.size = Vector2(1, line_height)
		line.position = Vector2(x_pos, 35)
		line.z_index = -1
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timeline_header.add_child(line)

func get_employee_node(data):
	if not data: return null
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data == data: return npc
	return null

func recalculate_schedule_preview():
	if project.state == ProjectData.State.IN_PROGRESS: return
	if project.state == ProjectData.State.FINISHED: return
	if project.state == ProjectData.State.FAILED: return

	var origin_day = project.created_at_day
	var horizon_from_origin = float(project.deadline_day - origin_day) * 1.1
	if horizon_from_origin < MIN_TIMELINE_DAYS:
		horizon_from_origin = MIN_TIMELINE_DAYS
	var preview_px_per_day = GANTT_VIEW_WIDTH / horizon_from_origin

	var current_offset = 0.0
	var any_assigned = false

	for i in range(project.stages.size()):
		var stage = project.stages[i]
		var track_node = tracks_container.get_child(i)
		if stage.workers.size() > 0:
			any_assigned = true
			var total_skill = get_total_skill_for_stage(stage)
			if total_skill < 1: total_skill = 1
			var duration_days = (float(stage.amount) / float(total_skill)) / 9.0
			var color = get_color_for_stage(stage.type)
			track_node.update_bar_preview(current_offset * preview_px_per_day, duration_days * preview_px_per_day, color)
			current_offset += duration_days
		else:
			track_node.update_bar_preview(0, 0, Color.WHITE)

	start_btn.disabled = not any_assigned

func get_total_skill_for_stage(stage: Dictionary) -> int:
	var total = 0
	for w in stage.workers:
		total += get_skill_for_stage(stage.type, w)
	return total

func get_skill_for_stage(type, worker):
	match type:
		"BA": return worker.skill_business_analysis
		"DEV": return worker.skill_backend
		"QA": return worker.skill_qa
	return 10

func get_color_for_stage(type):
	match type:
		"BA": return Color("FFA500")
		"DEV": return Color("6495ED")
		"QA": return Color("98FB98")
	return Color.GRAY

func _on_track_assignment_requested(index):
	if project.state == ProjectData.State.FINISHED or project.state == ProjectData.State.FAILED:
		return
	if project.stages[index].get("is_completed", false):
		return
	current_selecting_track_index = index
	var stage_type = project.stages[index].type
	selector_ref.open_list(stage_type)

func _on_employee_chosen(emp_data):
	if current_selecting_track_index == -1: return
	if project.state == ProjectData.State.FINISHED or project.state == ProjectData.State.FAILED:
		return
	var stage = project.stages[current_selecting_track_index]
	if stage.get("is_completed", false):
		return

	for existing_worker in stage.workers:
		if existing_worker == emp_data:
			print(tr("LOG_WARN_ALREADY_ASSIGNED"))
			return

	stage.workers.append(emp_data)
	# ИСПРАВЛЕНИЕ: Используем get_display_name()
	print(tr("LOG_EMP_ASSIGNED") % [emp_data.get_display_name(), tr("STAGE_SHORT_" + stage.type), stage.workers.size()])
	
	# === СИСТЕМА АДАПТАЦИИ: Если проект УЖЕ ИДЁТ, и мы докидываем человека — выдаём штраф ===
	if project.state == ProjectData.State.IN_PROGRESS:
		var proj_id = project.title
		if not emp_data.known_project_ids.has(proj_id):
			emp_data.known_project_ids.append(proj_id)
			emp_data.project_adapt_hours_left = 24.0
			# ИСПРАВЛЕНИЕ: Выводим переведенное имя в лог
			print("📚 %s присоединяется к идущему проекту. Штраф адаптации на 24 часа." % emp_data.get_display_name())
			if Engine.has_singleton("EventLog"):
				var el = Engine.get_singleton("EventLog")
				el.add(tr("LOG_PROJECT_ADAPTATION") % emp_data.get_display_name(), 2)
	
	var track_node = tracks_container.get_child(current_selecting_track_index)
	track_node.update_button_visuals()
	recalculate_schedule_preview()

func _on_worker_removed(stage_index: int, worker_index: int):
	if project.state == ProjectData.State.FINISHED or project.state == ProjectData.State.FAILED:
		return
	var stage = project.stages[stage_index]
	if stage.get("is_completed", false):
		return
	if worker_index < 0 or worker_index >= stage.workers.size():
		return
	
	var removed = stage.workers[worker_index]
	stage.workers.remove_at(worker_index)
	# ИСПРАВЛЕНИЕ: Используем get_display_name()
	print(tr("LOG_EMP_REMOVED") % [removed.get_display_name(), tr("STAGE_SHORT_" + stage.type), stage.workers.size()])
	
	# === СИСТЕМА АДАПТАЦИИ: Если человека сняли с проекта — обнуляем его штраф ===
	if removed is EmployeeData:
		removed.project_adapt_hours_left = 0.0
	
	var track_node = tracks_container.get_child(stage_index)
	track_node.update_button_visuals()
	recalculate_schedule_preview()
