extends StaticBody2D

var _exclamation: Label = null

func _ready():
	_build_exclamation_mark()

func _process(_delta):
	if _exclamation:
		_exclamation.visible = BossManager.should_show_quest() or BossManager.should_show_report()

func _build_exclamation_mark():
	_exclamation = Label.new()
	_exclamation.text = "❗"
	_exclamation.add_theme_font_size_override("font_size", 28)
	_exclamation.position = Vector2(0, -50)
	_exclamation.visible = false
	add_child(_exclamation)

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
