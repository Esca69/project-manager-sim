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
const AVG_PROGRESS_DAYS = 7

var stage_index: int = -1
var stage_data: Dictionary = {}
var is_readonly: bool = false
var is_stage_completed: bool = false

var _buttons_container: VBoxContainer = null

# Цвета для нового дизайна
var color_main_text = Color(0.17254902, 0.30980393, 0.5686275, 1) # Тот самый темно-синий
var color_hover_bg = Color(0.17254902, 0.30980393, 0.5686275, 1)

# === НОВЫЕ КОЛОНКИ ===
var _efficiency_labels: Array = []      # Label для каждого worker
var _avg_progress_labels: Array = []    # Label для каждого worker
var _efficiency_wrapper: VBoxContainer = null
var _avg_progress_wrapper: VBoxContainer = null
var _vs_avg: VSeparator = null          # Разделитель перед колонкой среднего прогресса
var _vs_progress: VSeparator = null     # Разделитель перед колонкой прогресса

# === ССЫЛКА НА project_window И ШИРИНЫ КОЛОНОК ===
var project_window_ref: Control = null
var col_widths: Dictionary = {}

var _avg_progress_cache: Dictionary = {}   # worker_name -> cached avg value
var _avg_progress_cache_day: int = -1       # day when cache was last computed

func setup(index: int, data: Dictionary, readonly: bool = false):
	stage_index = index
	stage_data = data
	is_readonly = readonly
	is_stage_completed = data.get("is_completed", false)
	
	# ИСПРАВЛЕНИЕ: Используем короткие ключи (BA, DEV, QA), чтобы они влезали в интерфейс
	role_label.text = tr("STAGE_SHORT_" + data.type)
	
	progress_label.text = "%d / %d" % [int(data.progress), int(data.amount)]

	if UITheme:
		UITheme.apply_font(role_label, "semibold")
		UITheme.apply_font(progress_label, "semibold")

	# Убираем старую дефолтную кнопку навсегда
	if original_btn:
		original_btn.visible = false
		original_btn.queue_free()

	rebuild_worker_buttons()

	visual_bar.visible = false
	progress_bar.visible = false

	call_deferred("_build_extra_columns")

func _ready():
	# ИСПРАВЛЕНИЕ: Пытаемся найти заголовки столбцов (если они лежат выше в иерархии или в самом треке)
	# Обычно они находятся в шапке таблицы, но на всякий случай проверяем локальные ноды:
	var role_title = find_child("TitleRole", true, false)
	if role_title and role_title is Label:
		role_title.text = tr("TRACK_COL_ROLE")
		
	var assign_title = find_child("TitleAssignee", true, false)
	if assign_title and assign_title is Label:
		assign_title.text = tr("TRACK_COL_ASSIGNEE")
		
	var progress_title = find_child("TitleProgress", true, false)
	if progress_title and progress_title is Label:
		progress_title.text = tr("TRACK_COL_PROGRESS")

# === СОЗДАНИЕ КНОПКИ "?" (стиль employee_roster) ===
func _get_tooltip_parent() -> Node:
	return project_window_ref if project_window_ref != null else get_tree().current_scene

func _clamp_tooltip_to_viewport(tp: PanelContainer) -> void:
	var vp_size = get_viewport().get_visible_rect().size
	tp.global_position.x = min(tp.global_position.x, vp_size.x - tp.size.x - 10)
	tp.global_position.y = max(tp.global_position.y, 10)

func _create_help_button_track() -> Button:
	var btn = Button.new()
	btn.text = "?"
	btn.custom_minimum_size = Vector2(22, 22)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", color_main_text)
	var bstyle = StyleBoxFlat.new()
	bstyle.bg_color = Color(1, 1, 1, 1)
	bstyle.border_width_left = 2
	bstyle.border_width_top = 2
	bstyle.border_width_right = 2
	bstyle.border_width_bottom = 2
	bstyle.border_color = color_main_text
	bstyle.corner_radius_top_left = 11
	bstyle.corner_radius_top_right = 11
	bstyle.corner_radius_bottom_right = 11
	bstyle.corner_radius_bottom_left = 11
	btn.add_theme_stylebox_override("normal", bstyle)
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.92, 0.94, 1.0, 1)
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = color_main_text
	hover_style.corner_radius_top_left = 11
	hover_style.corner_radius_top_right = 11
	hover_style.corner_radius_bottom_right = 11
	hover_style.corner_radius_bottom_left = 11
	btn.add_theme_stylebox_override("hover", hover_style)
	return btn

func _apply_locked_style_track(btn: Button) -> void:
	var gray_bstyle = StyleBoxFlat.new()
	gray_bstyle.bg_color = Color(0.93, 0.93, 0.93, 1)
	gray_bstyle.border_width_left = 2
	gray_bstyle.border_width_top = 2
	gray_bstyle.border_width_right = 2
	gray_bstyle.border_width_bottom = 2
	gray_bstyle.border_color = Color(0.6, 0.6, 0.6, 1)
	gray_bstyle.corner_radius_top_left = 11
	gray_bstyle.corner_radius_top_right = 11
	gray_bstyle.corner_radius_bottom_right = 11
	gray_bstyle.corner_radius_bottom_left = 11
	btn.add_theme_stylebox_override("normal", gray_bstyle)
	btn.add_theme_stylebox_override("hover", gray_bstyle)
	btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))

func _get_avg_progress_for_worker(worker_name: String, worker_id: String = "", worker_ref = null) -> float:
	if not PeopleHistory:
		return -1.0
	var records = PeopleHistory.daily_records
	var n = min(records.size(), AVG_PROGRESS_DAYS)
	var current_progress = 0.0
	if worker_ref != null:
		current_progress = float(worker_ref.get_meta("daily_progress", 0.0))
	if n == 0:
		# No history yet — fall back to today's live progress
		if current_progress > 0.0:
			return current_progress
		return -1.0
	var total = 0.0
	var count = 0
	for i in range(records.size() - n, records.size()):
		var rec = records[i]
		for emp in rec.get("employees", []):
			var emp_name = emp.get("name", "")
			var emp_id = emp.get("employee_id", "")
			if emp_name == worker_name or (worker_id != "" and (emp_id == worker_id or emp_name == worker_id)):
				total += emp.get("progress", 0.0)
				count += 1
				break
	if count == 0:
		# Worker not found in history — fall back to today's live progress
		if current_progress > 0.0:
			return current_progress
		return -1.0
	# Include today's not-yet-recorded progress as an additional data point (only if non-zero)
	if current_progress > 0.0:
		total += current_progress
		count += 1
	return total / float(count)

# === ПОСТРОЕНИЕ ДОПОЛНИТЕЛЬНЫХ КОЛОНОК ===
func _build_extra_columns():
	var layout = $Layout
	var vs2 = layout.get_node_or_null("VSeparator2")
	var progress_lbl_node = layout.get_node_or_null("ProgressLabel")

	if not layout or not vs2 or not progress_lbl_node:
		return

	# Очищаем старые если есть
	if _efficiency_wrapper and is_instance_valid(_efficiency_wrapper):
		_efficiency_wrapper.queue_free()
		_efficiency_wrapper = null
	if _vs_avg and is_instance_valid(_vs_avg):
		_vs_avg.queue_free()
		_vs_avg = null
	if _avg_progress_wrapper and is_instance_valid(_avg_progress_wrapper):
		_avg_progress_wrapper.queue_free()
		_avg_progress_wrapper = null
	if _vs_progress and is_instance_valid(_vs_progress):
		_vs_progress.queue_free()
		_vs_progress = null
	_efficiency_labels.clear()
	_avg_progress_labels.clear()

	var insert_idx = vs2.get_index() + 1
	var eff_w = col_widths.get("efficiency", 120)
	var avg_w = col_widths.get("avg_progress", 130)

	# === КОЛОНКА ЭФФЕКТИВНОСТЬ === (VSeparator2 уже есть — не добавляем _vs_eff, Bug 6)
	_efficiency_wrapper = VBoxContainer.new()
	_efficiency_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	_efficiency_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_efficiency_wrapper.add_theme_constant_override("separation", 8)
	_efficiency_wrapper.custom_minimum_size = Vector2(eff_w, 0)
	layout.add_child(_efficiency_wrapper)
	layout.move_child(_efficiency_wrapper, insert_idx)

	# === КОЛОНКА Ø ПРОГРЕСС/ДЕНЬ ===
	_vs_avg = VSeparator.new()
	_vs_avg.custom_minimum_size = Vector2(2, 0)
	_vs_avg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layout.add_child(_vs_avg)
	layout.move_child(_vs_avg, insert_idx + 1)

	_avg_progress_wrapper = VBoxContainer.new()
	_avg_progress_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	_avg_progress_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_avg_progress_wrapper.add_theme_constant_override("separation", 8)
	_avg_progress_wrapper.custom_minimum_size = Vector2(avg_w, 0)
	layout.add_child(_avg_progress_wrapper)
	layout.move_child(_avg_progress_wrapper, insert_idx + 2)

	# === РАЗДЕЛИТЕЛЬ ПЕРЕД ПРОГРЕССОМ (Bug 2) ===
	_vs_progress = VSeparator.new()
	_vs_progress.custom_minimum_size = Vector2(2, 0)
	_vs_progress.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	layout.add_child(_vs_progress)
	layout.move_child(_vs_progress, insert_idx + 3)

	if is_stage_completed:
		return

	var workers = stage_data.get("workers", [])
	var add_spacer = not is_readonly and not is_stage_completed

	for worker in workers:
		# --- Efficiency row ---
		var eff_row = HBoxContainer.new()
		eff_row.add_theme_constant_override("separation", 4)
		eff_row.custom_minimum_size = Vector2(0, 30)
		eff_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_efficiency_wrapper.add_child(eff_row)

		var eff_val = worker.get_efficiency_multiplier() if worker.has_method("get_efficiency_multiplier") else 1.0
		var eff_lbl = Label.new()
		if worker.has_method("get") and (worker.get("aura_bonus") > 0 or worker.get("motivation_bonus") > 0):
			eff_lbl.text = "x%.1f 🔥" % eff_val
			eff_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.1, 1))
		else:
			eff_lbl.text = "x%.1f" % eff_val
			eff_lbl.add_theme_color_override("font_color", color_main_text)
		eff_lbl.add_theme_font_size_override("font_size", 12)
		if UITheme: UITheme.apply_font(eff_lbl, "regular")
		eff_row.add_child(eff_lbl)
		_efficiency_labels.append(eff_lbl)

		var eff_help = _create_help_button_track()
		var eff_tooltip_ref: Array = [null]

		if not PMData.has_skill("read_efficiency"):
			_apply_locked_style_track(eff_help)
			eff_help.mouse_entered.connect(func():
				if eff_tooltip_ref[0] != null and is_instance_valid(eff_tooltip_ref[0]):
					eff_tooltip_ref[0].queue_free()
				var tp = TraitUIHelper.create_tooltip(tr("TRACK_LOCK_READ_EFFICIENCY"), Color(0.5, 0.5, 0.5, 1))
				_get_tooltip_parent().add_child(tp)
				tp.add_to_group("project_tooltip")
				await get_tree().process_frame
				if not is_instance_valid(tp): return
				var btn_global = eff_help.global_position
				tp.global_position = Vector2(btn_global.x + 28, btn_global.y - 10)
				_clamp_tooltip_to_viewport(tp)
				eff_tooltip_ref[0] = tp
			)
		else:
			var worker_ref = worker
			eff_help.mouse_entered.connect(func():
				if eff_tooltip_ref[0] != null and is_instance_valid(eff_tooltip_ref[0]):
					eff_tooltip_ref[0].queue_free()
				var bd_text = TraitUIHelper.build_efficiency_breakdown_text(worker_ref)
				var tp = TraitUIHelper.create_tooltip(bd_text, color_main_text)
				_get_tooltip_parent().add_child(tp)
				tp.add_to_group("project_tooltip")
				await get_tree().process_frame
				if not is_instance_valid(tp): return
				var btn_global = eff_help.global_position
				tp.global_position = Vector2(btn_global.x + 28, btn_global.y - 10)
				_clamp_tooltip_to_viewport(tp)
				eff_tooltip_ref[0] = tp
			)
		eff_help.mouse_exited.connect(func():
			if eff_tooltip_ref[0] != null and is_instance_valid(eff_tooltip_ref[0]):
				eff_tooltip_ref[0].queue_free()
			eff_tooltip_ref[0] = null
		)
		eff_row.add_child(eff_help)

		# --- Avg Progress row ---
		var avg_row = HBoxContainer.new()
		avg_row.add_theme_constant_override("separation", 4)
		avg_row.custom_minimum_size = Vector2(0, 30)
		avg_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_avg_progress_wrapper.add_child(avg_row)

		if not PMData.has_skill("report_people_tab"):
			var lock_lbl = Label.new()
			lock_lbl.text = "🔒"
			lock_lbl.add_theme_font_size_override("font_size", 14)
			avg_row.add_child(lock_lbl)

			var lock_tooltip_ref: Array = [null]
			lock_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
			lock_lbl.mouse_entered.connect(func():
				if lock_tooltip_ref[0] != null and is_instance_valid(lock_tooltip_ref[0]):
					lock_tooltip_ref[0].queue_free()
				var tp = TraitUIHelper.create_tooltip(tr("TRACK_LOCK_REPORT_PEOPLE"), Color(0.5, 0.5, 0.5, 1))
				_get_tooltip_parent().add_child(tp)
				tp.add_to_group("project_tooltip")
				await get_tree().process_frame
				if not is_instance_valid(tp): return
				var lbl_global = lock_lbl.global_position
				tp.global_position = Vector2(lbl_global.x + 20, lbl_global.y - 10)
				_clamp_tooltip_to_viewport(tp)
				lock_tooltip_ref[0] = tp
			)
			lock_lbl.mouse_exited.connect(func():
				if lock_tooltip_ref[0] != null and is_instance_valid(lock_tooltip_ref[0]):
					lock_tooltip_ref[0].queue_free()
				lock_tooltip_ref[0] = null
			)
			_avg_progress_labels.append(null)
		else:
			var avg_lbl = Label.new()
			var worker_name = worker.get_display_name()
			var worker_id = str(worker.employee_name)
			var avg_val = _get_avg_progress_for_worker(worker_name, worker_id, null)
			avg_lbl.text = "—" if avg_val < 0.0 else "%.1f" % avg_val
			avg_lbl.add_theme_color_override("font_color", color_main_text)
			avg_lbl.add_theme_font_size_override("font_size", 12)
			if UITheme: UITheme.apply_font(avg_lbl, "regular")
			avg_row.add_child(avg_lbl)
			_avg_progress_labels.append(avg_lbl)

	# Добавляем spacer под строки, чтобы выровнять с кнопкой "Назначить" (Bug 1)
	if add_spacer:
		var eff_spacer = Control.new()
		eff_spacer.custom_minimum_size = Vector2(0, 40)
		_efficiency_wrapper.add_child(eff_spacer)

		var avg_spacer = Control.new()
		avg_spacer.custom_minimum_size = Vector2(0, 40)
		_avg_progress_wrapper.add_child(avg_spacer)

# === ОБНОВЛЕНИЕ ЭФФЕКТИВНОСТИ В РЕАЛЬНОМ ВРЕМЕНИ ===
func update_efficiency_live():
	if is_stage_completed:
		return
	var workers = stage_data.get("workers", [])
	for i in range(min(workers.size(), _efficiency_labels.size())):
		var worker = workers[i]
		var lbl = _efficiency_labels[i]
		if not lbl or not is_instance_valid(lbl):
			continue
		var eff_val = worker.get_efficiency_multiplier() if worker.has_method("get_efficiency_multiplier") else 1.0
		if worker.has_method("get") and (worker.get("aura_bonus") > 0 or worker.get("motivation_bonus") > 0):
			lbl.text = "x%.1f 🔥" % eff_val
			lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.1, 1))
		else:
			lbl.text = "x%.1f" % eff_val
			lbl.add_theme_color_override("font_color", color_main_text)

# === ОБНОВЛЕНИЕ СРЕДНЕГО ПРОГРЕССА В РЕАЛЬНОМ ВРЕМЕНИ ===
func update_avg_progress_live():
	if is_stage_completed:
		return
	if not PMData.has_skill("report_people_tab"):
		return
	# Recalculate cache once per day (when day changes)
	var current_day = GameTime.day
	if current_day != _avg_progress_cache_day:
		_avg_progress_cache.clear()
		_avg_progress_cache_day = current_day
		var workers_for_cache = stage_data.get("workers", [])
		for worker in workers_for_cache:
			var worker_name = worker.get_display_name()
			var worker_id = str(worker.employee_name)
			var avg_val = _get_avg_progress_for_worker(worker_name, worker_id, null)
			_avg_progress_cache[worker_name] = avg_val
	# Update labels from cache
	var workers = stage_data.get("workers", [])
	for i in range(min(workers.size(), _avg_progress_labels.size())):
		var lbl = _avg_progress_labels[i]
		if not lbl or not is_instance_valid(lbl):
			continue
		var worker = workers[i]
		var worker_name = worker.get_display_name()
		var avg_val = _avg_progress_cache.get(worker_name, -1.0)
		lbl.text = "—" if avg_val < 0.0 else "%.1f" % avg_val

# Кнопка "Назначить" с нужными скруглениями и ховером
func _create_styled_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 40)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(1, 1, 1, 1)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = color_main_text
	style_normal.corner_radius_top_left = 20
	style_normal.corner_radius_top_right = 20
	style_normal.corner_radius_bottom_right = 20
	style_normal.corner_radius_bottom_left = 20

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color_hover_bg
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = color_hover_bg
	style_hover.corner_radius_top_left = 20
	style_hover.corner_radius_top_right = 20
	style_hover.corner_radius_bottom_right = 20
	style_hover.corner_radius_bottom_left = 20

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	
	btn.add_theme_color_override("font_color", color_main_text)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	
	if UITheme: UITheme.apply_font(btn, "semibold")
	
	return btn

# Кнопка "Удалить" (минус) в том же стиле
func _create_remove_button() -> Button:
	var btn = Button.new()
	btn.text = "−"
	btn.custom_minimum_size = Vector2(30, 30)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(1, 1, 1, 1)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = color_main_text
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_right = 10
	style_normal.corner_radius_bottom_left = 10

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = color_hover_bg
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = color_hover_bg
	style_hover.corner_radius_top_left = 10
	style_hover.corner_radius_top_right = 10
	style_hover.corner_radius_bottom_right = 10
	style_hover.corner_radius_bottom_left = 10

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	
	btn.add_theme_color_override("font_color", color_main_text)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	
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
				# Если проект уже был завершен в старом сейве, тут останутся русские имена
				# Если в новом - сюда запишутся ID, но для вывода мы используем get_display_name ниже
				completed_names.append(w.employee_name)

		for worker_name in completed_names:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.alignment = BoxContainer.ALIGNMENT_CENTER

			var check_lbl = Label.new()
			# Пытаемся найти сотрудника, чтобы вывести его переведенное имя, 
			# но если его уволили, выведем то, что сохранилось в completed_worker_names
			var display_name = worker_name
			var found_emp = _find_employee_by_id(worker_name)
			if found_emp:
				display_name = found_emp.get_display_name()

			check_lbl.text = "✅ " + display_name
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
		
		# ИСПРАВЛЕНИЕ: Выводим локализованное имя сотрудника
		var display_name = worker.employee_name
		if worker.has_method("get_display_name"):
			display_name = worker.get_display_name()
			
		name_label.text = "👤 " + display_name
		name_label.add_theme_color_override("font_color", color_main_text)
		name_label.custom_minimum_size = Vector2(140, 30)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if UITheme: UITheme.apply_font(name_label, "regular")
		row.add_child(name_label)

		_buttons_container.add_child(row)

	if not is_readonly:
		# Используем локализованную кнопку
		var add_btn = _create_styled_button("+ " + tr("PROJECT_ASSIGN_WORKER_SHORT"))
		add_btn.pressed.connect(func(): emit_signal("assignment_requested", stage_index))
		_buttons_container.add_child(add_btn)

	_update_track_height(workers.size())

func _find_employee_by_id(emp_id: String):
	# Ищем сотрудника в мире, чтобы получить его переведенное имя для завершенных этапов
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if npc.data and npc.data.employee_name == emp_id:
			return npc.data
	return null

func _update_track_height(worker_count: int):
	var extra = 1 if (not is_readonly and not is_stage_completed) else 0
	var total_buttons = worker_count + extra
	var needed_height = max(BASE_TRACK_HEIGHT, total_buttons * (BUTTON_HEIGHT + 10) + 20)
	custom_minimum_size.y = needed_height

func update_button_visuals():
	rebuild_worker_buttons()
	_build_extra_columns()

func update_visuals_dynamic(px_per_day: float, current_project_time: float, color: Color):
	update_visuals_dynamic_offset(px_per_day, current_project_time, color, 0.0)

func update_visuals_dynamic_offset(px_per_day: float, current_project_time: float, color: Color, start_offset: float):
	var has_workers = stage_data.get("workers", []).size() > 0
	var has_completed_names = stage_data.get("completed_worker_names", []).size() > 0

	visual_bar.visible = false
	if not has_workers and not has_completed_names:
		progress_bar.visible = false
		return

	var act_start = stage_data.get("actual_start", -1.0)
	var act_end = stage_data.get("actual_end", -1.0)

	if act_start != -1.0:
		progress_bar.visible = true
		progress_bar.modulate = Color(1, 1, 1, 1)
		var style = progress_bar.get_theme_stylebox("panel")
		if style:
			style = style.duplicate()
			style.bg_color = color
			progress_bar.add_theme_stylebox_override("panel", style)
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

func update_bar_preview(_start_px, _width_px, _color):
	visual_bar.visible = false
	progress_bar.visible = false

func update_progress(percent: float):
	var current_val = int(stage_data.amount * percent)
	progress_label.text = "%d / %d" % [current_val, stage_data.amount]
	if percent >= 1.0:
		progress_label.modulate = Color.GREEN
	else:
		progress_label.modulate = Color("d93636")

func get_gantt_offset() -> float:
	return gantt_area.position.x

func update_day_lines(day_x_positions: Array) -> void:
	for child in gantt_area.get_children():
		if child.is_in_group("day_separator_line"):
			child.queue_free()
	var track_h = size.y if size.y > 0 else custom_minimum_size.y if custom_minimum_size.y > 0 else BASE_TRACK_HEIGHT
	for x_pos in day_x_positions:
		var line = ColorRect.new()
		line.color = Color(0.6, 0.6, 0.6, 0.25)
		line.size = Vector2(1, track_h)
		line.position = Vector2(x_pos, 0)
		line.z_index = -1
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_to_group("day_separator_line")
		gantt_area.add_child(line)
