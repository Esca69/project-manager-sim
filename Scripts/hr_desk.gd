extends StaticBody2D

func interact():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		if hud.has_method("open_hr_search"):
			hud.open_hr_search()
		else:
			print("ОШИБКА: Метод open_hr_search не найден в HUD!")
	else:
		print("ОШИБКА: Не найден HUD (группа 'ui')!")
