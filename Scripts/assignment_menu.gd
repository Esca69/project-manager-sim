extends Control

# Ссылка на стол, который сейчас ждет заселения
var target_desk = null

@onready var container = $Panel/ScrollContainer/VBoxContainer
@onready var close_btn = $Panel/CloseButton

func _ready():
	visible = false
	close_btn.pressed.connect(_on_close_pressed)

func _on_close_pressed():
	visible = false
	target_desk = null

# Эту функцию вызывает Стол
func open_assignment_list(desk_node):
	target_desk = desk_node # Запоминаем, какой стол открыл меню
	refresh_list()
	visible = true

func refresh_list():
	# 1. Очищаем старые кнопки
	for child in container.get_children():
		child.queue_free()
	
	# 2. Ищем всех сотрудников в игре (группа "npc")
	var all_npcs = get_tree().get_nodes_in_group("npc")
	
	var found_any = false
	
	for npc in all_npcs:
		# Проверяем, есть ли у NPC данные
		if npc.data:
			# ТУТ ХИТРОСТЬ: Нам нужно знать, занят ли он уже.
			# Пока у нас нет переменной "assigned_desk" внутри EmployeeData.
			# Но мы можем проверить это позже. Сейчас выведем ВСЕХ.
			
			create_button_for(npc)
			found_any = true
			
	if not found_any:
		var lbl = Label.new()
		lbl.text = "Нет сотрудников!"
		container.add_child(lbl)

# Создаем кнопку для конкретного человека
func create_button_for(npc_node):
	var btn = Button.new()
	btn.text = npc_node.data.employee_name + " (" + npc_node.data.job_title + ")"
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Подключаем нажатие. Передаем саму ноду NPC
	btn.pressed.connect(_on_employee_selected.bind(npc_node))
	
	container.add_child(btn)

func _on_employee_selected(npc_node):
	if target_desk:
		# 1. Привязываем данные к столу
		target_desk.assign_employee(npc_node.data)
		
		# 2. ДАЕМ КОМАНДУ ИДТИ (Вместо телепорта)
		# Мы передаем глобальные координаты точки стула
		npc_node.move_to_desk(target_desk.seat_point.global_position)
		
		print("Сотрудник получил приказ идти к столу!")
		
	visible = false
