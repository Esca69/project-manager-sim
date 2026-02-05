extends Panel

# Сигнал: "Я выбрал вот этого человека"
signal employee_selected(data: EmployeeData)

@onready var item_list = $VBoxContainer/ItemList

func _ready():
	visible = false # Скрыт по умолчанию

# Эту функцию мы вызовем снаружи, чтобы открыть окно
func open_list():
	item_list.clear()
	visible = true
	
	# 1. Ищем всех NPC в сцене (по группе "npc", которую мы создали раньше)
	var npcs = get_tree().get_nodes_in_group("npc")
	
	for npc in npcs:
		# Проверяем, есть ли у NPC данные (паспорт)
		if npc.data:
			# 2. Добавляем строчку в список
			# add_item возвращает номер строки (индекс)
			var index = item_list.add_item(npc.data.employee_name + " (" + npc.data.job_title + ")")
			
			# 3. Самое важное: Прячем ссылку на данные ВНУТРИ строки
			# Metadata - это скрытый карман, куда можно положить любой объект
			item_list.set_item_metadata(index, npc.data)

# Когда нажали на кнопку "Отмена"
func _on_cancel_button_pressed():
	visible = false

# Когда кликнули по элементу списка (подключи этот сигнал через Node!)
func _on_item_list_item_activated(index):
	# Достаем данные из "скрытого кармана" выбранной строки
	var data = item_list.get_item_metadata(index)
	
	# Кричим: "Выбрали вот его!"
	emit_signal("employee_selected", data)
	visible = false

func _on_button_pressed():
	pass # Replace with function body.
