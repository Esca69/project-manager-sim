extends StaticBody2D

const HR_PROXIMITY_RADIUS: float = 300.0
var _is_player_in_radius: bool = false

# === ВОСКЛИЦАТЕЛЬНЫЙ ЗНАК ===
var _exclamation_bubble: Node2D = null

# === ПРОГРЕСС-БАР ФОНОВОГО ПОИСКА ===
var _search_bar: Node2D = null
var _search_progress: ProgressBar = null
var _search_timer_label: Label = null

func _ready():
	add_to_group("hr_desk")
	add_to_group("desk")
	_build_exclamation_mark()
	_build_search_bar()

func _process(_delta):
	_check_proximity()
	if _exclamation_bubble:
		var hud = get_tree().get_first_node_in_group("ui")
		if hud and hud.has_method("is_hr_results_ready"):
			_exclamation_bubble.visible = hud.is_hr_results_ready()
		else:
			_exclamation_bubble.visible = false

func _check_proximity():
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dist = global_position.distance_to(player.global_position)
	if dist <= HR_PROXIMITY_RADIUS:
		if not _is_player_in_radius:
			_is_player_in_radius = true
			TutorialManager.notify_player_near_hr()
	else:
		_is_player_in_radius = false

func _build_exclamation_mark():
	_exclamation_bubble = Node2D.new()
	_exclamation_bubble.position = Vector2(0, -225)
	_exclamation_bubble.z_index = 100
	_exclamation_bubble.visible = false
	add_child(_exclamation_bubble)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(72, 72)
	panel.size = Vector2(72, 72)
	panel.position = Vector2(-36, -36)
	_exclamation_bubble.add_child(panel)

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

	var label = Label.new()
	label.custom_minimum_size = Vector2(72, 72)
	label.size = Vector2(72, 72)
	label.position = Vector2.ZERO
	label.text = "❗"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_settings = LabelSettings.new()
	label_settings.font_size = 42
	label.label_settings = label_settings
	panel.add_child(label)

func _build_search_bar():
	_search_bar = Node2D.new()
	_search_bar.position = Vector2(0, -160)
	_search_bar.z_index = 99
	_search_bar.visible = false
	add_child(_search_bar)

	var panel = PanelContainer.new()
	panel.position = Vector2(-65, -30)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(1, 1, 1, 0.92)
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = Color(0.17, 0.31, 0.57, 1)
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.15)
	panel_style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", panel_style)
	_search_bar.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var search_label = Label.new()
	search_label.text = tr("HR_DESK_SEARCHING")
	search_label.add_theme_color_override("font_color", Color(0.17, 0.31, 0.57, 1))
	search_label.add_theme_font_size_override("font_size", 11)
	search_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(search_label)

	_search_timer_label = Label.new()
	_search_timer_label.text = ""
	_search_timer_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	_search_timer_label.add_theme_font_size_override("font_size", 10)
	_search_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_search_timer_label)

	_search_progress = ProgressBar.new()
	_search_progress.custom_minimum_size = Vector2(110, 10)
	_search_progress.show_percentage = false
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.17, 0.31, 0.57, 1)
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	_search_progress.add_theme_stylebox_override("fill", fill_style)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.8, 0.8, 0.8, 1)
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	_search_progress.add_theme_stylebox_override("background", bg_style)
	vbox.add_child(_search_progress)

func show_search_progress(total_minutes: float):
	if _search_progress:
		_search_progress.max_value = total_minutes
		_search_progress.value = 0
	if _search_timer_label:
		var hours = int(total_minutes) / 60
		var mins = int(total_minutes) % 60
		_search_timer_label.text = "🔍 %d:%02d" % [hours, mins]
	if _search_bar:
		_search_bar.visible = true

func update_search_progress(elapsed: float, remaining: float):
	if _search_progress:
		_search_progress.value = elapsed
	if _search_timer_label:
		var hours = int(remaining) / 60
		var mins = int(remaining) % 60
		_search_timer_label.text = "🔍 %d:%02d" % [hours, mins]

func hide_search_progress():
	if _search_bar:
		_search_bar.visible = false

func interact():
	# === ТУТОРИАЛ: блокировка на не-HR шагах ===
	if TutorialManager.is_active():
		if TutorialManager.current_step != TutorialManager.Step.STEP_5_HIRE_BA:
			return

	var hud = get_tree().get_first_node_in_group("ui")
	if not hud:
		print("ОШИБКА: Не найден HUD (группа 'ui')!")
		return

	# Если HR-специалист нанят — новая механика
	if GameState.office_upgrades.get("hr_specialist", false):
		if hud.has_method("is_hr_results_ready") and hud.is_hr_results_ready():
			# Кандидаты готовы — показать результаты
			if hud.has_method("show_hr_results"):
				hud.show_hr_results()
		elif hud.has_method("is_hr_searching") and hud.is_hr_searching():
			# Поиск уже идёт
			EventLog.add(tr("HR_SEARCH_IN_PROGRESS"), EventLog.LogType.ROUTINE)
		else:
			# Запустить новый фоновый поиск
			if hud.has_method("open_hr_search"):
				hud.open_hr_search()
		return

	# Старая механика (PM стоит и ждёт)
	if hud.has_method("open_hr_search"):
		hud.open_hr_search()
