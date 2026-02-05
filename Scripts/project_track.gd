extends Control

signal assignment_requested(track_index)

@onready var role_label = $Layout/RoleLabel
@onready var assign_btn = $Layout/AssignWrapper/AssignButton
@onready var progress_label = $Layout/ProgressLabel
@onready var visual_bar = $Layout/GanttArea/VisualBar
@onready var progress_bar = $Layout/GanttArea/ProgressBar
# Ссылка на зону Ганта (нужна для красной линии)
@onready var gantt_area = $Layout/GanttArea

const BAR_HEIGHT = 24.0 

var stage_index: int = -1
var stage_data: Dictionary = {}

func setup(index: int, data: Dictionary):
	stage_index = index
	stage_data = data
	role_label.text = data.type
	progress_label.text = "%d / %d" % [int(data.progress), int(data.amount)]
	update_button_visuals()
	
	# Скрываем до отрисовки
	visual_bar.visible = false
	progress_bar.visible = false

func update_button_visuals():
	if stage_data.worker:
		assign_btn.text = stage_data.worker.employee_name
		assign_btn.modulate = Color(0.8, 0.9, 1.0) 
	else:
		assign_btn.text = "+ Назначить"
		assign_btn.modulate = Color.WHITE

# --- ГЛАВНАЯ ФУНКЦИЯ ОТРИСОВКИ (ДИНАМИКА) ---
# Используется, когда проект ЗАПУЩЕН
func update_visuals_dynamic(px_per_day: float, current_project_time: float, color: Color):
	if not stage_data.worker:
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
	
	# --- ПРИМЕНЯЕМ ЦВЕТ ---
	var style = visual_bar.get_theme_stylebox("panel")
	if style:
		style = style.duplicate()
		style.bg_color = color # Красим в синий/оранжевый/зеленый
		visual_bar.add_theme_stylebox_override("panel", style)
	
	# Делаем полупрозрачным
	visual_bar.modulate.a = 0.4
	
	# 2. РИСУЕМ ФАКТ (ЯРКИЙ)
	var act_start = stage_data.get("actual_start", -1.0)
	var act_end = stage_data.get("actual_end", -1.0)
	
	if act_start != -1.0:
		progress_bar.visible = true
		
		# Факт рисуем чуть уже
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
		
		# Важно: Сбрасываем прозрачность для факта, чтобы он был ярким
		# Но так как progress_bar не дочерний к visual_bar, он и так непрозрачный.
		# Можно покрасить его в тот же цвет, но ярче, или оставить зеленым (progress style).
		# Если хочешь, чтобы факт был того же цвета (например синий), добавь такой же код со стилем сюда.
		# Пока оставим его зеленым (как настроено в редакторе).
		
	else:
		progress_bar.visible = false
# --- ФУНКЦИЯ ПРЕВЬЮ (ДРАФТ) ---
# Используется, когда проект ЕЩЕ НЕ ЗАПУЩЕН (она у тебя потерялась)
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

# Хелпер для красной линии
func get_gantt_offset() -> float:
	return gantt_area.position.x

func _ready():
	assign_btn.pressed.connect(func(): emit_signal("assignment_requested", stage_index))
