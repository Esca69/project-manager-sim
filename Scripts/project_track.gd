extends Control

signal assignment_requested(track_index)

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

# Сохранённый стиль оригинальной кнопки
var _btn_style: StyleBox = null
var _btn_font_color: Color = Color.WHITE
var _btn_min_size: Vector2 = Vector2(180, 40)

# Контейнер для динамических кнопок
var _buttons_container: VBoxContainer = null

func setup(index: int, data: Dictionary):
	stage_index = index
	stage_data = data
	role_label.text = data.type
	progress_label.text = "%d / %d" % [int(data.progress), int(data.amount)]
	
	_capture_original_style()
	rebuild_worker_buttons()
	
	# Скрываем до отрисовки
	visual_bar.visible = false
	progress_bar.visible = false

func _ready():
	pass

# --- Запоминаем стиль оригинальной кнопки ---
func _capture_original_style():
	if original_btn:
		# Копируем стиль
		var style = original_btn.get_theme_stylebox("normal")
		if style:
			_btn_style = style.duplicate()
		
		# Копируем цвет шрифта
		_btn_font_color = original_btn.get_theme_color("font_color")
		
		# Копируем размер
		_btn_min_size = original_btn.custom_minimum_size
		
		# Прячем оригинальную кнопку навсегда
		original_btn.visible = false

# --- Создаём стилизованную кнопку (копия стиля оригинала) ---
func _create_styled_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = _btn_min_size
	
	if _btn_style:
		btn.add_theme_stylebox_override("normal", _btn_style.duplicate())
	
	btn.add_theme_color_override("font_color", _btn_font_color)
	
	return btn

# --- ДИНАМИЧЕСКИЕ КНОПКИ ---
func rebuild_worker_buttons():
	# 1. Удаляем старый контейнер (если был)
	if _buttons_container:
		assign_wrapper.remove_child(_buttons_container)
		_buttons_container.queue_free()
		_buttons_container = null
	
	# 2. Создаём новый VBoxContainer внутри AssignWrapper
	_buttons_container = VBoxContainer.new()
	_buttons_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_container.add_theme_constant_override("separation", 8)
	assign_wrapper.add_child(_buttons_container)
	
	var workers = stage_data.get("workers", [])
	
	# 3. Для каждого назначенного работника — кнопка с именем
	for i in range(workers.size()):
		var worker = workers[i]
		var btn = _create_styled_button("👤 " + worker.employee_name)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.modulate = Color(0.85, 0.92, 1.0)
		_buttons_container.add_child(btn)
	
	# 4. Кнопка "+ Назначить" (всегда внизу)
	var add_btn = _create_styled_button("+ Назначить")
	add_btn.modulate = Color.WHITE
	add_btn.pressed.connect(func(): emit_signal("assignment_requested", stage_index))
	_buttons_container.add_child(add_btn)
	
	# 5. Пересчитываем высоту трека
	_update_track_height(workers.size())

func _update_track_height(worker_count: int):
	var total_buttons = worker_count + 1
	var needed_height = max(BASE_TRACK_HEIGHT, total_buttons * (BUTTON_HEIGHT + 10) + 20)
	custom_minimum_size.y = needed_height

# Совместимость: вызывается из project_window после назначения
func update_button_visuals():
	rebuild_worker_buttons()

# --- ГЛАВНАЯ ФУНКЦИЯ ОТРИСОВКИ (ДИНАМИКА) ---
func update_visuals_dynamic(px_per_day: float, current_project_time: float, color: Color):
	var workers = stage_data.get("workers", [])
	if workers.size() == 0:
		visual_bar.visible = false
		progress_bar.visible = false
		return
	
	# 1. РИСУЕМ ПЛАН (ПОЛУПРОЗРАЧНЫЙ)
	visual_bar.visible = true
	var plan_start = stage_data.get("plan_start", 0.0)
	var plan_dur = stage_data.get("plan_duration", 0.0)
	
	visual_bar.position.x = plan_start * px_per_day
	visual_bar.size.x = plan_dur * px_per_day
	visual_bar.size.y = BAR_HEIGHT
	visual_bar.position.y = (size.y - BAR_HEIGHT) / 2.0
	
	var style = visual_bar.get_theme_stylebox("panel")
	if style:
		style = style.duplicate()
		style.bg_color = color
		visual_bar.add_theme_stylebox_override("panel", style)
	
	visual_bar.modulate.a = 0.4
	
	# 2. РИСУЕМ ФАКТ (ЯРКИЙ)
	var act_start = stage_data.get("actual_start", -1.0)
	var act_end = stage_data.get("actual_end", -1.0)
	
	if act_start != -1.0:
		progress_bar.visible = true
		
		var fact_height = BAR_HEIGHT * 0.6
		progress_bar.size.y = fact_height
		progress_bar.position.y = (size.y - fact_height) / 2.0
		progress_bar.position.x = act_start * px_per_day
		
		var duration = 0.0
		if act_end != -1.0:
			duration = act_end - act_start
		else:
			duration = current_project_time - act_start
			if duration < 0: duration = 0
			
		progress_bar.size.x = duration * px_per_day
		
	else:
		progress_bar.visible = false

# --- ФУНКЦИЯ ПРЕВЬЮ (ДРАФТ) ---
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
