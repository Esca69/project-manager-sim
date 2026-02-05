extends StaticBody2D

func interact():
	print("1. Стол HR: Нажата кнопка E (функция interact вызвана)")
	
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		print("2. HUD найден: ", hud.name)
		
		# Пытаемся найти меню по имени
		var menu = hud.get_node_or_null("HiringMenu") 
		if menu:
			print("3. Меню найдено! Открываю...")
			menu.open_hiring_menu()
		else:
			print("ОШИБКА: Меню 'HiringMenu' не найдено внутри HUD!")
			print("Список детей HUD: ", hud.get_children()) # Покажет, что там реально лежит
	else:
		print("ОШИБКА: Не найден HUD (группа 'ui')!")
