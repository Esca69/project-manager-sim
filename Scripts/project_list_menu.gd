extends Control

signal project_opened(proj: ProjectData)

@onready var cards_container = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer
@onready var close_btn = find_child("CloseButton", true, false)
@onready var empty_label = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer/EmptyLabel

var card_style_normal: StyleBoxFlat
var card_style_finished: StyleBoxFlat
var btn_style: StyleBoxFlat

func _ready():
	visible = false
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	
	card_style_normal = StyleBoxFlat.new()
	card_style_normal.bg_color = Color(1, 1, 1, 1)
	card_style_normal.border_width_left = 3
	card_style_normal.border_width_top = 3
	card_style_normal.border_width_right = 3
	card_style_normal.border_width_bottom = 3
	card_style_normal.border_color = Color(0.8784314, 0.8784314, 0.8784314, 1)
	card_style_normal.corner_radius_top_left = 20
	card_style_normal.corner_radius_top_right = 20
	card_style_normal.corner_radius_bottom_right = 20
	card_style_normal.corner_radius_bottom_left = 20
	
	card_style_finished = StyleBoxFlat.new()
	card_style_finished.bg_color = Color(0.9, 0.95, 0.9, 1)
	card_style_finished.border_width_left = 3
	card_style_finished.border_width_top = 3
	card_style_finished.border_width_right = 3
	card_style_finished.border_width_bottom = 3
	card_style_finished.border_color = Color(0.29803923, 0.6862745, 0.3137255, 1)
	card_style_finished.corner_radius_top_left = 20
	card_style_finished.corner_radius_top_right = 20
	card_style_finished.corner_radius_bottom_right = 20
	card_style_finished.corner_radius_bottom_left = 20
	
	btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1, 1, 1, 1)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	btn_style.corner_radius_top_left = 20
	btn_style.corner_radius_top_right = 20
	btn_style.corner_radius_bottom_right = 20
	btn_style.corner_radius_bottom_left = 20

func open_menu():
	_rebuild_cards()
	visible = true

func _on_close_pressed():
	visible = false

func _rebuild_cards():
	for child in cards_container.get_children():
		if child == empty_label:
			continue
		cards_container.remove_child(child)
		child.queue_free()
	
	if ProjectManager.active_projects.is_empty():
		empty_label.visible = true
		return
	
	empty_label.visible = false
	
	for i in range(ProjectManager.active_projects.size()):
		var proj = ProjectManager.active_projects[i]
		var card = _create_card(proj, i)
		cards_container.add_child(card)

func _create_card(proj: ProjectData, index: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(1400, 0)
	
	if proj.state == ProjectData.State.FINISHED:
		card.add_theme_stylebox_override("panel", card_style_finished)
	else:
		card.add_theme_stylebox_override("panel", card_style_normal)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	var top_hbox = HBoxContainer.new()
	vbox.add_child(top_hbox)
	
	var left_info = VBoxContainer.new()
	top_hbox.add_child(left_info)
	
	var title_text = proj.title
	if proj.state == ProjectData.State.FINISHED:
		title_text = "✅ " + proj.title
	
	var name_lbl = Label.new()
	name_lbl.text = title_text
	name_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	left_info.add_child(name_lbl)
	
	var status_lbl = Label.new()
	match proj.state:
		ProjectData.State.DRAFTING:
			status_lbl.text = "📝 Черновик — назначьте людей и нажмите Ст��рт"
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
		ProjectData.State.IN_PROGRESS:
			var stage_name = _get_current_stage_name(proj)
			status_lbl.text = "🔧 В работе — этап: " + stage_name
			status_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		ProjectData.State.FINISHED:
			status_lbl.text = "✅ Завершён"
			status_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
		ProjectData.State.FAILED:
			status_lbl.text = "❌ Провален"
			status_lbl.add_theme_color_override("font_color", Color(0.8980392, 0.22352941, 0.20784314, 1))
	left_info.add_child(status_lbl)
	
	if proj.state == ProjectData.State.IN_PROGRESS:
		var progress_text = _get_progress_text(proj)
		var progress_lbl = Label.new()
		progress_lbl.text = progress_text
		progress_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
		left_info.add_child(progress_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)
	
	var right_info = VBoxContainer.new()
	top_hbox.add_child(right_info)
	
	var budget_lbl = Label.new()
	budget_lbl.text = "Бюджет $" + str(proj.budget)
	budget_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
	budget_lbl.add_theme_font_size_override("font_size", 20)
	budget_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_info.add_child(budget_lbl)
	
	var open_btn = Button.new()
	open_btn.text = "Открыть"
	open_btn.custom_minimum_size = Vector2(180, 40)
	open_btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	open_btn.add_theme_stylebox_override("normal", btn_style)
	open_btn.pressed.connect(_on_open_pressed.bind(index))
	right_info.add_child(open_btn)
	
	# --- [ИЗМЕНЕНИЕ] Дедлайны в новом формате с да��ами ---
	var deadlines_hbox = HBoxContainer.new()
	deadlines_hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(deadlines_hbox)
	
	var soft_days = proj.soft_deadline_day - GameTime.day
	var hard_days = proj.deadline_day - GameTime.day
	var soft_date = GameTime.get_date_short(proj.soft_deadline_day)
	var hard_date = GameTime.get_date_short(proj.deadline_day)
	
	var soft_lbl = Label.new()
	soft_lbl.text = "Софт: %s (ост. %d дн.)" % [soft_date, soft_days]
	soft_lbl.add_theme_color_override("font_color", Color(0.8980392, 0.22352941, 0.20784314, 1))
	deadlines_hbox.add_child(soft_lbl)
	
	var hard_lbl = Label.new()
	hard_lbl.text = "Хард: %s (ост. %d дн.)" % [hard_date, hard_days]
	hard_lbl.add_theme_color_override("font_color", Color(0.8980392, 0.22352941, 0.20784314, 1))
	deadlines_hbox.add_child(hard_lbl)
	
	return card

func _on_open_pressed(index: int):
	if index < 0 or index >= ProjectManager.active_projects.size():
		return
	var proj = ProjectManager.active_projects[index]
	emit_signal("project_opened", proj)
	visible = false

# --- ВСПОМОГАТЕЛЬНЫЕ ---
func _get_current_stage_name(proj: ProjectData) -> String:
	for i in range(proj.stages.size()):
		var stage = proj.stages[i]
		if stage.get("is_completed", false):
			continue
		var prev_ok = true
		if i > 0:
			prev_ok = proj.stages[i - 1].get("is_completed", false)
		if prev_ok:
			match stage.type:
				"BA": return "Бизнес-анализ"
				"DEV": return "Разработка"
				"QA": return "Тестирование"
			return stage.type
	return "—"

func _get_progress_text(proj: ProjectData) -> String:
	for i in range(proj.stages.size()):
		var stage = proj.stages[i]
		if stage.get("is_completed", false):
			continue
		var prev_ok = true
		if i > 0:
			prev_ok = proj.stages[i - 1].get("is_completed", false)
		if prev_ok:
			var pct = 0.0
			if stage.amount > 0:
				pct = (float(stage.progress) / float(stage.amount)) * 100.0
			return "Прогресс: %d%%" % int(pct)
	return ""
