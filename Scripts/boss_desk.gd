extends StaticBody2D

var _exclamation_bubble: Node2D = null

func _ready():
	_build_exclamation_mark()

func _process(_delta):
	if _exclamation_bubble:
		_exclamation_bubble.visible = BossManager.should_show_quest() or BossManager.should_show_report()

func _build_exclamation_mark():
	# Создаем корневой узел для бабла
	_exclamation_bubble = Node2D.new()
	# Поднимаем выше, чтобы рамка 72x72 не перекрывала босса
	_exclamation_bubble.position = Vector2(0, -225)
	_exclamation_bubble.z_index = 100 
	_exclamation_bubble.visible = false
	add_child(_exclamation_bubble)

	# Создаем фон (панель)
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(72, 72)
	panel.size = Vector2(72, 72)
	# Центрируем панель относительно Node2D
	panel.position = Vector2(-36, -36) 
	_exclamation_bubble.add_child(panel)

	# Настраиваем красивый стиль рамки как у сотрудников
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 1.0) 
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.2, 0.2, 0.2, 1.0) 
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.shadow_color = Color(0, 0, 0, 0.1) 
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)

	# Создаем текст с эмодзи
	var label = Label.new()
	label.custom_minimum_size = Vector2(72, 72)
	label.size = Vector2(72, 72)
	label.position = Vector2.ZERO
	label.text = "❗"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Настраиваем размер эмодзи
	var label_settings = LabelSettings.new()
	label_settings.font_size = 42
	label.label_settings = label_settings

	panel.add_child(label)


func interact():
	var hud = get_tree().get_first_node_in_group("ui")
	if not hud:
		return

	# Приоритет 1: Показать отчёт за прошлый месяц
	if BossManager.should_show_report():
		var last_report = BossManager.quest_history[BossManager.quest_history.size() - 1]
		hud.open_boss_report(last_report)
		return

	# Приоритет 2: Показать новый квест
	if BossManager.should_show_quest():
		var quest = BossManager.generate_quest_for_month(GameTime.get_month())
		hud.open_boss_quest(quest)
		return

	# Приоритет 3: Обычное меню проектов
	hud.open_boss_menu()
