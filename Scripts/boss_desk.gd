extends StaticBody2D

func interact():
	var hud = get_tree().get_first_node_in_group("ui")
	if hud:
		hud.open_boss_menu()
