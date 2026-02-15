extends Control

signal project_selected(data: ProjectData)

@onready var card1 = %Card1
@onready var card2 = %Card2
@onready var card3 = %Card3

@onready var close_btn = find_child("CloseButton", true, false)

@onready var cards = [card1, card2, card3]

var current_options = []
var _generated_for_week: int = -1

var _card_style_normal: StyleBoxFlat
var _card_style_hover: StyleBoxFlat

func _ready():
	visible = false

	_card_style_normal = _make_card_style(false)
	_card_style_hover = _make_card_style(true)

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		if UITheme: UITheme.apply_font(close_btn, "semibold")
	else:
		print("ОШИБКА: Не найдена кнопка CloseButton!")

	for i in range(cards.size()):
		var card = cards[i]
		var btn = find_node_by_name(card, "SelectButton")

		if btn:
			if not btn.is_connected("pressed", _on_select_pressed):
				btn.pressed.connect(_on_select_pressed.bind(i))
			if UITheme: UITheme.apply_font(btn, "semibold")
		else:
			print("ОШИБКА: Не найдена SelectButton в карточке ", i)

func _make_card_style(hover: bool) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 20
	style.corner_radius_bottom_left = 20
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	if hover:
		style.bg_color = Color(0.96, 0.97, 1.0, 1)
		style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	else:
		style.bg_color = Color(1, 1, 1, 1)
		style.border_color = Color(0.8784314, 0.8784314, 0.8784314, 1)
	if UITheme: UITheme.apply_shadow(style)
	return style

func _set_children_pass_filter(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_set_children_pass_filter(child)

func open_selection():
	var current_week = _get_current_week()

	if current_week != _generated_for_week:
		generate_new_projects()
		_generated_for_week = current_week

	update_ui()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _on_close_pressed():
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
		visible = false

func _get_current_week() -> int:
	return ((GameTime.day - 1) / GameTime.DAYS_IN_WEEK) + 1

func generate_new_projects():
	current_options.clear()
	for i in range(3):
		var proj = ProjectGenerator.generate_random_project(GameTime.day)
		current_options.append(proj)

func _on_card_hover_enter(card: PanelContainer):
	card.add_theme_stylebox_override("panel", _card_style_hover)

func _on_card_hover_exit(card: PanelContainer):
	card.add_theme_stylebox_override("panel", _card_style_normal)

func update_ui():
	for i in range(3):
		var card = cards[i]
		var data = current_options[i]

		var name_lbl = find_node_by_name(card, "NameLabel")
		var work_lbl = find_node_by_name(card, "WorkLabel")
		var budget_lbl = find_node_by_name(card, "BudgetLabel")
		var soft_lbl = find_node_by_name(card, "SoftDeadlineLabel")
		var hard_lbl = find_node_by_name(card, "HardDeadlineLabel")
		var btn = find_node_by_name(card, "SelectButton")

		if data != null:
			card.visible = true
			card.modulate = Color.WHITE
			if btn: btn.disabled = false

			# Hover
			if card is PanelContainer:
				card.add_theme_stylebox_override("panel", _card_style_normal)
				card.mouse_filter = Control.MOUSE_FILTER_STOP
				if card.mouse_entered.is_connected(_on_card_hover_enter):
					card.mouse_entered.disconnect(_on_card_hover_enter)
				if card.mouse_exited.is_connected(_on_card_hover_exit):
					card.mouse_exited.disconnect(_on_card_hover_exit)
				card.mouse_entered.connect(_on_card_hover_enter.bind(card))
				card.mouse_exited.connect(_on_card_hover_exit.bind(card))

			# Клиент + категория
			var cat_label = "[MICRO]" if data.category == "micro" else "[SIMPLE]"
			var client_text = ""
			if data.client_id != "":
				var client = data.get_client()
				if client:
					client_text = client.emoji + " " + client.client_name + "  —  "
			if name_lbl:
				name_lbl.text = client_text + cat_label + " " + data.title
				if UITheme: UITheme.apply_font(name_lbl, "bold")

			if work_lbl:
				var parts = []
				for stage in data.stages:
					parts.append(stage.type + " " + PMData.get_blurred_work(stage.amount))
				work_lbl.text = "Работы:  " + "    ".join(parts)
				if UITheme: UITheme.apply_font(work_lbl, "regular")

			if budget_lbl:
				var budget_text = "Бюджет " + PMData.get_blurred_budget(data.budget)
				# Показываем бонус лояльности если есть
				if data.client_id != "":
					var client = data.get_client()
					if client and client.get_budget_bonus_percent() > 0:
						budget_text += "  (❤+%d%%)" % client.get_budget_bonus_percent()
				budget_lbl.text = budget_text
				if UITheme: UITheme.apply_font(budget_lbl, "bold")

			var soft_days = data.soft_deadline_day - GameTime.day
			var hard_days = data.deadline_day - GameTime.day

			if soft_lbl:
				soft_lbl.text = "Софт: %d дн. (штраф -%d%%)" % [soft_days, data.soft_deadline_penalty_percent]
				if UITheme: UITheme.apply_font(soft_lbl, "regular")
			if hard_lbl:
				hard_lbl.text = "Хард: %d дн. (провал = $0)" % hard_days
				if UITheme: UITheme.apply_font(hard_lbl, "semibold")

			call_deferred("_set_children_pass_filter", card)

		else:
			card.visible = false

func _on_select_pressed(index):
	var selected = current_options[index]
	if selected == null: return

	print("Выбран проект: ", selected.title)
	emit_signal("project_selected", selected)

	current_options[index] = null

	# Анимация исчезновения карточки
	var card = cards[index]
	var tw = card.create_tween()
	tw.tween_property(card, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		card.visible = false
		card.modulate.a = 1.0
	)

func find_node_by_name(root, target_name):
	if root.name == target_name: return root
	for child in root.get_children():
		var found = find_node_by_name(child, target_name)
		if found: return found
	return null
