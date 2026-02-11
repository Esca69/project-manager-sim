extends Control

signal employee_fired(emp_data: EmployeeData)

@onready var cards_container = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer
@onready var close_btn = find_child("CloseButton", true, false)
@onready var empty_label = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer/EmptyLabel

var card_style: StyleBoxFlat
var fire_btn_style: StyleBoxFlat
var fire_btn_hover_style: StyleBoxFlat

var _dialog_layer: Control
var _confirm_label: Label
var _pending_fire_data: EmployeeData = null
var _pending_fire_node = null

var _body_texture: Texture2D
var _head_texture: Texture2D

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_body_texture = load("res://Sprites/body2.png")
	_head_texture = load("res://Sprites/head2.png")
	
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	
	card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(1, 1, 1, 1)
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3
	card_style.border_color = Color(0.8784314, 0.8784314, 0.8784314, 1)
	card_style.corner_radius_top_left = 20
	card_style.corner_radius_top_right = 20
	card_style.corner_radius_bottom_right = 20
	card_style.corner_radius_bottom_left = 20
	
	fire_btn_style = StyleBoxFlat.new()
	fire_btn_style.bg_color = Color(1, 1, 1, 1)
	fire_btn_style.border_width_left = 2
	fire_btn_style.border_width_top = 2
	fire_btn_style.border_width_right = 2
	fire_btn_style.border_width_bottom = 2
	fire_btn_style.border_color = Color(0.85, 0.25, 0.2, 1)
	fire_btn_style.corner_radius_top_left = 20
	fire_btn_style.corner_radius_top_right = 20
	fire_btn_style.corner_radius_bottom_right = 20
	fire_btn_style.corner_radius_bottom_left = 20
	
	fire_btn_hover_style = StyleBoxFlat.new()
	fire_btn_hover_style.bg_color = Color(0.85, 0.25, 0.2, 1)
	fire_btn_hover_style.border_width_left = 2
	fire_btn_hover_style.border_width_top = 2
	fire_btn_hover_style.border_width_right = 2
	fire_btn_hover_style.border_width_bottom = 2
	fire_btn_hover_style.border_color = Color(0.7, 0.15, 0.1, 1)
	fire_btn_hover_style.corner_radius_top_left = 20
	fire_btn_hover_style.corner_radius_top_right = 20
	fire_btn_hover_style.corner_radius_bottom_right = 20
	fire_btn_hover_style.corner_radius_bottom_left = 20
	
	_build_confirm_dialog()

func open():
	_rebuild_cards()
	visible = true

func _on_close_pressed():
	visible = false

func _process(_delta):
	if not visible: return
	_update_live_data()

func _update_live_data():
	for card in cards_container.get_children():
		if card == empty_label: continue
		if not card.has_meta("emp_data"): continue
		
		var emp_data = card.get_meta("emp_data")
		
		var energy_lbl = card.get_meta("energy_label") if card.has_meta("energy_label") else null
		var status_lbl = card.get_meta("status_label") if card.has_meta("status_label") else null
		var eff_lbl = card.get_meta("eff_label") if card.has_meta("eff_label") else null
		
		if energy_lbl:
			var energy_pct = int(emp_data.current_energy)
			energy_lbl.text = "Энергия: %d%%" % energy_pct
			if energy_pct >= 70:
				energy_lbl.add_theme_color_override("font_color", Color(0.29, 0.69, 0.31, 1))
			elif energy_pct >= 40:
				energy_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1, 1))
			else:
				energy_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
		
		if eff_lbl:
			eff_lbl.text = "Эффект.: x%.1f" % emp_data.get_efficiency_multiplier()
		
		if status_lbl:
			var npc_node = _find_npc_node(emp_data)
			if npc_node:
				status_lbl.text = _get_status_text(npc_node)
				status_lbl.add_theme_color_override("font_color", _get_status_color(npc_node))

func _rebuild_cards():
	for child in cards_container.get_children():
		if child == empty_label: continue
		cards_container.remove_child(child)
		child.queue_free()
	
	var npcs = get_tree().get_nodes_in_group("npc")
	
	if npcs.is_empty():
		empty_label.visible = true
		return
	
	empty_label.visible = false
	
	for npc in npcs:
		if not npc.data: continue
		var card = _create_card(npc)
		cards_container.add_child(card)

func _create_card(npc_node) -> PanelContainer:
	var emp = npc_node.data
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(1400, 0)
	card.add_theme_stylebox_override("panel", card_style)
	card.set_meta("emp_data", emp)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)
	
	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_hbox)
	
	var sprite_container = _create_employee_sprite(emp)
	main_hbox.add_child(sprite_container)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	main_hbox.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = emp.employee_name + "  —  " + emp.job_title
	name_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	name_lbl.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(name_lbl)
	
	var skills_lbl = Label.new()
	skills_lbl.text = "Навыки:  BA %d  |  DEV %d  |  QA %d" % [emp.skill_business_analysis, emp.skill_backend, emp.skill_qa]
	skills_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	skills_lbl.add_theme_font_size_override("font_size", 13)
	info_vbox.add_child(skills_lbl)
	
	var salary_lbl = Label.new()
	salary_lbl.text = "Зарплата: %d $/мес" % emp.monthly_salary
	salary_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
	salary_lbl.add_theme_font_size_override("font_size", 13)
	info_vbox.add_child(salary_lbl)
	
	# [ИЗМЕНЕНИЕ] Трейты в строку
	if not emp.traits.is_empty():
		var traits_row = TraitUIHelper.create_traits_row(emp, self)
		info_vbox.add_child(traits_row)
	
	# === ПРАВАЯ ЧАСТЬ ===
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 5)
	right_vbox.custom_minimum_size = Vector2(250, 0)
	main_hbox.add_child(right_vbox)
	
	var status_lbl = Label.new()
	status_lbl.text = _get_status_text(npc_node)
	status_lbl.add_theme_color_override("font_color", _get_status_color(npc_node))
	status_lbl.add_theme_font_size_override("font_size", 13)
	right_vbox.add_child(status_lbl)
	card.set_meta("status_label", status_lbl)
	
	var energy_lbl = Label.new()
	var energy_pct = int(emp.current_energy)
	energy_lbl.text = "Энергия: %d%%" % energy_pct
	energy_lbl.add_theme_font_size_override("font_size", 13)
	if energy_pct >= 70:
		energy_lbl.add_theme_color_override("font_color", Color(0.29, 0.69, 0.31, 1))
	elif energy_pct >= 40:
		energy_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1, 1))
	else:
		energy_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	right_vbox.add_child(energy_lbl)
	card.set_meta("energy_label", energy_lbl)
	
	var eff_lbl = Label.new()
	eff_lbl.text = "Эффект.: x%.1f" % emp.get_efficiency_multiplier()
	eff_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	eff_lbl.add_theme_font_size_override("font_size", 13)
	right_vbox.add_child(eff_lbl)
	card.set_meta("eff_label", eff_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(spacer)
	
	var fire_btn = Button.new()
	fire_btn.text = "Уволить"
	fire_btn.custom_minimum_size = Vector2(180, 40)
	fire_btn.focus_mode = Control.FOCUS_NONE
	fire_btn.add_theme_stylebox_override("normal", fire_btn_style)
	fire_btn.add_theme_stylebox_override("hover", fire_btn_hover_style)
	fire_btn.add_theme_stylebox_override("pressed", fire_btn_hover_style)
	fire_btn.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	fire_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	fire_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	fire_btn.pressed.connect(_on_fire_pressed.bind(emp, npc_node))
	right_vbox.add_child(fire_btn)
	
	return card

func _create_employee_sprite(emp: EmployeeData) -> CenterContainer:
	var center = CenterContainer.new()
	center.custom_minimum_size = Vector2(55, 70)
	
	var inner = Control.new()
	inner.custom_minimum_size = Vector2(40, 60)
	center.add_child(inner)
	
	var body_color = Color.WHITE
	match emp.job_title:
		"Backend Developer": body_color = Color(0.4, 0.4, 1.0)
		"Business Analyst": body_color = Color(1.0, 0.4, 0.4)
		"QA Engineer": body_color = Color(0.4, 1.0, 0.4)
	
	var body_tex = TextureRect.new()
	body_tex.texture = _body_texture
	body_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body_tex.custom_minimum_size = Vector2(40, 40)
	body_tex.size = Vector2(40, 40)
	body_tex.position = Vector2(0, 20)
	body_tex.self_modulate = body_color
	inner.add_child(body_tex)
	
	var head_tex = TextureRect.new()
	head_tex.texture = _head_texture
	head_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head_tex.custom_minimum_size = Vector2(28, 28)
	head_tex.size = Vector2(28, 28)
	head_tex.position = Vector2(6, -2)
	inner.add_child(head_tex)
	
	return center

func _get_status_text(npc_node) -> String:
	if not npc_node or not is_instance_valid(npc_node):
		return "—"
	var state = npc_node.current_state
	match state:
		0: return "💤 Простаивает"
		1: return "🚶 Идёт к столу"
		2:
			var proj_name = _get_working_project_name(npc_node.data)
			return "🔧 Работает (" + proj_name + ")"
		3: return "🏠 Идёт домой"
		4: return "🏠 Дома"
		5: return "☕ Идёт за кофе"
		6: return "☕ Кофе-брейк"
		7: return "🚽 Идёт в туалет"
		8: return "🚽 В туалете"
		9: return "🚶 Слоняется"
		10: return "🚶 Стоит, думает"
	return "—"

func _get_status_color(npc_node) -> Color:
	if not npc_node or not is_instance_valid(npc_node):
		return Color(0.5, 0.5, 0.5, 1)
	var state = npc_node.current_state
	match state:
		2: return Color(0.29, 0.69, 0.31, 1)
		4: return Color(0.5, 0.5, 0.5, 1)
		6: return Color(0.3, 0.7, 0.85, 1)
		8: return Color(0.6, 0.4, 0.7, 1)
		9, 10: return Color(0.75, 0.6, 0.4, 1)
	return Color(0.17254902, 0.30980393, 0.5686275, 1)

func _get_working_project_name(emp_data: EmployeeData) -> String:
	for project in ProjectManager.active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue
		for stage in project.stages:
			if stage.get("is_completed", false):
				continue
			for worker in stage.workers:
				if worker == emp_data:
					return project.title
	return "?"

func _find_npc_node(emp_data: EmployeeData):
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data == emp_data:
			return npc
	return null

# === УВОЛЬНЕНИЕ ===
func _on_fire_pressed(emp_data: EmployeeData, npc_node):
	_pending_fire_data = emp_data
	_pending_fire_node = npc_node
	
	var projects_list = _get_assigned_projects(emp_data)
	
	var text = "Уволить " + emp_data.employee_name + "?"
	if projects_list.size() > 0:
		var proj_names = []
		for p in projects_list:
			proj_names.append(p.title)
		text += "\n\n⚠️ Этот сотрудник назначен на проекты:\n" + ", ".join(proj_names)
		text += "\n\nОн будет снят со всех этапов!"
	
	_confirm_label.text = text
	_dialog_layer.visible = true

func _get_assigned_projects(emp_data: EmployeeData) -> Array:
	var result = []
	for project in ProjectManager.active_projects:
		if project.state == ProjectData.State.FINISHED:
			continue
		if project.state == ProjectData.State.FAILED:
			continue
		for stage in project.stages:
			for worker in stage.workers:
				if worker == emp_data:
					if project not in result:
						result.append(project)
	return result

func _confirm_fire():
	if not _pending_fire_data:
		_dialog_layer.visible = false
		return
	
	# 1. Снимаем со ВСЕХ проектов
	for project in ProjectManager.active_projects:
		for stage in project.stages:
			var idx = -1
			for i in range(stage.workers.size()):
				if stage.workers[i] == _pending_fire_data:
					idx = i
					break
			if idx != -1:
				stage.workers.remove_at(idx)
				print("❌ Снят с проекта: ", project.title, ", этап: ", stage.type)
	
	# [ИСПРАВЛЕНИЕ] 2. Освобождаем стол — только employee_desk, не computer_desk
	for desk in get_tree().get_nodes_in_group("desk"):
		# Проверяем что у объекта ЕСТЬ свойство assigned_employee
		if not desk.has_method("unassign_employee"):
			continue
		if not ("assigned_employee" in desk):
			continue
		if desk.assigned_employee == _pending_fire_data:
			desk.unassign_employee()
			print("🪑 Стол освобождён")
			break
	
	# 3. Освобождаем NPC + удаляем
	if _pending_fire_node and is_instance_valid(_pending_fire_node):
		_pending_fire_node.release_from_desk()
		_pending_fire_node.remove_from_group("npc")
		_pending_fire_node.queue_free()
		print("🔥 Уволен: ", _pending_fire_data.employee_name)
	
	emit_signal("employee_fired", _pending_fire_data)
	
	_pending_fire_data = null
	_pending_fire_node = null
	_dialog_layer.visible = false
	
	_rebuild_cards()

func _cancel_fire():
	_pending_fire_data = null
	_pending_fire_node = null
	_dialog_layer.visible = false

func _build_confirm_dialog():
	_dialog_layer = Control.new()
	_dialog_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.visible = false
	_dialog_layer.z_index = 200
	add_child(_dialog_layer)
	
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_layer.add_child(overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_layer.add_child(center)
	
	var dialog_panel = PanelContainer.new()
	dialog_panel.custom_minimum_size = Vector2(500, 0)
	
	var dialog_style = StyleBoxFlat.new()
	dialog_style.bg_color = Color(1, 1, 1, 1)
	dialog_style.border_width_left = 3
	dialog_style.border_width_top = 3
	dialog_style.border_width_right = 3
	dialog_style.border_width_bottom = 3
	dialog_style.border_color = Color(0.85, 0.25, 0.2, 1)
	dialog_style.corner_radius_top_left = 20
	dialog_style.corner_radius_top_right = 20
	dialog_style.corner_radius_bottom_right = 20
	dialog_style.corner_radius_bottom_left = 20
	dialog_panel.add_theme_stylebox_override("panel", dialog_style)
	center.add_child(dialog_panel)
	
	var dialog_margin = MarginContainer.new()
	dialog_margin.add_theme_constant_override("margin_left", 25)
	dialog_margin.add_theme_constant_override("margin_top", 20)
	dialog_margin.add_theme_constant_override("margin_right", 25)
	dialog_margin.add_theme_constant_override("margin_bottom", 20)
	dialog_panel.add_child(dialog_margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	dialog_margin.add_child(vbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "⚠️ Подтверждение увольнения"
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)
	
	_confirm_label = Label.new()
	_confirm_label.text = ""
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_confirm_label)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.custom_minimum_size = Vector2(180, 40)
	cancel_btn.focus_mode = Control.FOCUS_NONE
	var cancel_style = StyleBoxFlat.new()
	cancel_style.bg_color = Color(1, 1, 1, 1)
	cancel_style.border_width_left = 2
	cancel_style.border_width_top = 2
	cancel_style.border_width_right = 2
	cancel_style.border_width_bottom = 2
	cancel_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	cancel_style.corner_radius_top_left = 20
	cancel_style.corner_radius_top_right = 20
	cancel_style.corner_radius_bottom_right = 20
	cancel_style.corner_radius_bottom_left = 20
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	cancel_btn.pressed.connect(_cancel_fire)
	btn_hbox.add_child(cancel_btn)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Уволить"
	confirm_btn.custom_minimum_size = Vector2(180, 40)
	confirm_btn.focus_mode = Control.FOCUS_NONE
	confirm_btn.add_theme_stylebox_override("normal", fire_btn_hover_style)
	confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	confirm_btn.pressed.connect(_confirm_fire)
	btn_hbox.add_child(confirm_btn)
