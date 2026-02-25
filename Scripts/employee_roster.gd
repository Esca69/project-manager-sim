extends Control

signal employee_fired(emp_data: EmployeeData)

@onready var cards_container = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer
@onready var close_btn = find_child("CloseButton", true, false)
@onready var empty_label = $Window/MainVBox/CardsMargin/ScrollContainer/CardsContainer/EmptyLabel

var card_style_normal: StyleBoxFlat
var card_style_hover: StyleBoxFlat
var fire_btn_style: StyleBoxFlat
var fire_btn_hover_style: StyleBoxFlat

var _dialog_layer: Control
var _confirm_label: Label
var _pending_fire_data: EmployeeData = null
var _pending_fire_node = null

var _body_texture: Texture2D
var _head_texture: Texture2D

var _overlay: ColorRect

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_force_fullscreen_size()

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	move_child(_overlay, 0)

	_body_texture = load("res://Sprites/body2.png")
	_head_texture = load("res://Sprites/head2.png")

	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
		if UITheme: UITheme.apply_font(close_btn, "semibold")

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
	if UITheme: UITheme.apply_shadow(card_style_normal)

	card_style_hover = StyleBoxFlat.new()
	card_style_hover.bg_color = Color(0.96, 0.97, 1.0, 1)
	card_style_hover.border_width_left = 3
	card_style_hover.border_width_top = 3
	card_style_hover.border_width_right = 3
	card_style_hover.border_width_bottom = 3
	card_style_hover.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	card_style_hover.corner_radius_top_left = 20
	card_style_hover.corner_radius_top_right = 20
	card_style_hover.corner_radius_bottom_right = 20
	card_style_hover.corner_radius_bottom_left = 20
	if UITheme: UITheme.apply_shadow(card_style_hover)

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

func _force_fullscreen_size():
	var vp_size = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vp_size

func _set_children_pass_filter(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
		_set_children_pass_filter(child)

func open():
	_force_fullscreen_size()
	_rebuild_cards()
	if UITheme:
		UITheme.fade_in(self, 0.2)
	else:
		visible = true

func _on_close_pressed():
	if UITheme:
		UITheme.fade_out(self, 0.15)
	else:
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
		var effect_lbl = card.get_meta("effect_label") if card.has_meta("effect_label") else null
		var mood_lbl = card.get_meta("mood_label") if card.has_meta("mood_label") else null
		var mood_bar = card.get_meta("mood_bar") if card.has_meta("mood_bar") else null

		if energy_lbl:
			var energy_pct = int(emp_data.current_energy)
			energy_lbl.text = tr("ROSTER_ENERGY") % energy_pct
			if energy_pct >= 70:
				energy_lbl.add_theme_color_override("font_color", Color(0.29, 0.69, 0.31, 1))
			elif energy_pct >= 40:
				energy_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1, 1))
			else:
				energy_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))

		if eff_lbl:
			var eff_val = emp_data.get_efficiency_multiplier()
			if emp_data.motivation_bonus > 0:
				eff_lbl.text = tr("ROSTER_EFFICIENCY_MOTIVATED") % eff_val
				eff_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.1, 1))
			else:
				eff_lbl.text = tr("ROSTER_EFFICIENCY") % eff_val
				eff_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))

		if status_lbl:
			var npc_node = _find_npc_node(emp_data)
			if npc_node:
				status_lbl.text = _get_status_text(npc_node)
				status_lbl.add_theme_color_override("font_color", _get_status_color(npc_node))

		if effect_lbl:
			var effect_text = _get_event_effect_text(emp_data)
			effect_lbl.text = effect_text
			effect_lbl.visible = effect_text != ""

		# === MOOD SYSTEM: обновляем mood в реальном времени ===
		if mood_lbl:
			var mood_val = emp_data.mood
			var zone_name = emp_data.get_mood_zone_name()
			mood_lbl.text = tr("ROSTER_MOOD") % [int(mood_val), zone_name]
			mood_lbl.add_theme_color_override("font_color", _get_mood_color(mood_val))
		if mood_bar:
			mood_bar.value = emp_data.mood
			var fill_style = mood_bar.get_theme_stylebox("fill") as StyleBoxFlat
			if fill_style:
				fill_style.bg_color = _get_mood_color(emp_data.mood)

		# === MOOD: live-обновление тултипа, пока он открыт ===
		var mood_tooltip_ref = card.get_meta("mood_tooltip_ref") if card.has_meta("mood_tooltip_ref") else null
		var mood_tooltip_label_ref = card.get_meta("mood_tooltip_label_ref") if card.has_meta("mood_tooltip_label_ref") else null
		if mood_tooltip_ref and mood_tooltip_label_ref:
			var tp = mood_tooltip_ref[0]
			var lbl = mood_tooltip_label_ref[0]
			if tp != null and is_instance_valid(tp) and lbl != null and is_instance_valid(lbl):
				lbl.text = _build_mood_breakdown_text(emp_data)

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
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", card_style_normal)
	card.set_meta("emp_data", emp)

	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_entered.connect(func():
		card.add_theme_stylebox_override("panel", card_style_hover)
	)
	card.mouse_exited.connect(func():
		card.add_theme_stylebox_override("panel", card_style_normal)
	)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)

	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_hbox)

	var sprite_container = _create_employee_sprite(npc_node)
	main_hbox.add_child(sprite_container)

	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	main_hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.text = emp.employee_name + "  —  " + emp.job_title
	name_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	name_lbl.add_theme_font_size_override("font_size", 16)
	if UITheme: UITheme.apply_font(name_lbl, "bold")
	info_vbox.add_child(name_lbl)

	var level_hbox = HBoxContainer.new()
	level_hbox.add_theme_constant_override("separation", 10)
	info_vbox.add_child(level_hbox)

	var grade = emp.get_grade_name()
	var grade_panel = PanelContainer.new()
	var grade_style = StyleBoxFlat.new()
	grade_style.corner_radius_top_left = 10
	grade_style.corner_radius_top_right = 10
	grade_style.corner_radius_bottom_right = 10
	grade_style.corner_radius_bottom_left = 10
	grade_style.border_width_left = 2
	grade_style.border_width_top = 2
	grade_style.border_width_right = 2
	grade_style.border_width_bottom = 2

	var grade_color: Color
	match emp.GRADE_NAMES.get(emp.employee_level, "GRADE_JUNIOR"):
		"GRADE_JUNIOR":
			grade_style.bg_color = Color(0.9, 0.95, 0.9, 1)
			grade_style.border_color = Color(0.29, 0.69, 0.31, 1)
			grade_color = Color(0.29, 0.69, 0.31, 1)
		"GRADE_MIDDLE":
			grade_style.bg_color = Color(0.93, 0.93, 1.0, 1)
			grade_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
			grade_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
		"GRADE_SENIOR":
			grade_style.bg_color = Color(1.0, 0.95, 0.88, 1)
			grade_style.border_color = Color(0.85, 0.55, 0.0, 1)
			grade_color = Color(0.85, 0.55, 0.0, 1)
		"GRADE_LEAD":
			grade_style.bg_color = Color(0.95, 0.9, 0.98, 1)
			grade_style.border_color = Color(0.6, 0.3, 0.7, 1)
			grade_color = Color(0.6, 0.3, 0.7, 1)
		_:
			grade_style.bg_color = Color(0.93, 0.93, 0.93, 1)
			grade_style.border_color = Color(0.5, 0.5, 0.5, 1)
			grade_color = Color(0.5, 0.5, 0.5, 1)

	grade_panel.add_theme_stylebox_override("panel", grade_style)

	var gm = MarginContainer.new()
	gm.add_theme_constant_override("margin_left", 8)
	gm.add_theme_constant_override("margin_top", 2)
	gm.add_theme_constant_override("margin_right", 8)
	gm.add_theme_constant_override("margin_bottom", 2)
	grade_panel.add_child(gm)

	var grade_lbl = Label.new()
	grade_lbl.text = tr("ROSTER_GRADE_LEVEL") % [grade, emp.employee_level]
	grade_lbl.add_theme_font_size_override("font_size", 12)
	grade_lbl.add_theme_color_override("font_color", grade_color)
	if UITheme: UITheme.apply_font(grade_lbl, "semibold")
	gm.add_child(grade_lbl)
	level_hbox.add_child(grade_panel)

	if emp.employee_level < EmployeeData.MAX_LEVEL:
		var xp_progress = emp.get_xp_progress()
		var xp_current = xp_progress[0]
		var xp_needed = xp_progress[1]

		var xp_vbox = VBoxContainer.new()
		xp_vbox.add_theme_constant_override("separation", 2)
		xp_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		level_hbox.add_child(xp_vbox)

		var xp_lbl = Label.new()
		xp_lbl.text = tr("UI_XP") % [xp_current, xp_needed]
		xp_lbl.add_theme_font_size_override("font_size", 11)
		xp_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		if UITheme: UITheme.apply_font(xp_lbl, "regular")
		xp_vbox.add_child(xp_lbl)

		var pbar = ProgressBar.new()
		pbar.custom_minimum_size = Vector2(120, 8)
		pbar.min_value = 0
		pbar.max_value = max(1, xp_needed)
		pbar.value = xp_current
		pbar.show_percentage = false

		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.88, 0.88, 0.88, 1)
		bg_style.corner_radius_top_left = 4
		bg_style.corner_radius_top_right = 4
		bg_style.corner_radius_bottom_right = 4
		bg_style.corner_radius_bottom_left = 4
		pbar.add_theme_stylebox_override("background", bg_style)

		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = grade_color
		fill_style.corner_radius_top_left = 4
		fill_style.corner_radius_top_right = 4
		fill_style.corner_radius_bottom_right = 4
		fill_style.corner_radius_bottom_left = 4
		pbar.add_theme_stylebox_override("fill", fill_style)

		xp_vbox.add_child(pbar)
	else:
		var max_lbl = Label.new()
		max_lbl.text = tr("ROSTER_MAX_LEVEL")
		max_lbl.add_theme_font_size_override("font_size", 11)
		max_lbl.add_theme_color_override("font_color", grade_color)
		if UITheme: UITheme.apply_font(max_lbl, "semibold")
		level_hbox.add_child(max_lbl)

	var skill_text = ""
	if emp.skill_business_analysis > 0:
		skill_text = "BA: " + PMData.get_blurred_skill(emp.skill_business_analysis)
	elif emp.skill_backend > 0:
		skill_text = "Backend: " + PMData.get_blurred_skill(emp.skill_backend)
	elif emp.skill_qa > 0:
		skill_text = "QA: " + PMData.get_blurred_skill(emp.skill_qa)

	var skills_lbl = Label.new()
	skills_lbl.text = tr("ROSTER_SKILL") % skill_text
	skills_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	skills_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(skills_lbl, "semibold")
	info_vbox.add_child(skills_lbl)

	var salary_lbl = Label.new()
	salary_lbl.text = tr("ROSTER_SALARY") % emp.monthly_salary
	salary_lbl.add_theme_color_override("font_color", Color(0.29803923, 0.6862745, 0.3137255, 1))
	salary_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(salary_lbl, "bold")
	info_vbox.add_child(salary_lbl)

	if not emp.traits.is_empty():
		var visible_count = PMData.get_visible_traits_count()

		if visible_count >= emp.traits.size():
			var traits_row = TraitUIHelper.create_traits_row(emp, self)
			info_vbox.add_child(traits_row)
		else:
			var flow = HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 12)
			flow.add_theme_constant_override("v_separation", 4)

			for t_idx in range(emp.traits.size()):
				if t_idx < visible_count:
					var trait_id = emp.traits[t_idx]
					var item = _create_visible_trait(trait_id, emp)
					flow.add_child(item)
				else:
					var item = _create_hidden_trait()
					flow.add_child(item)

			info_vbox.add_child(flow)

	# === ПРАВАЯ КОЛОНКА ===
	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 5)
	right_vbox.custom_minimum_size = Vector2(250, 0)
	main_hbox.add_child(right_vbox)

	var status_lbl = Label.new()
	status_lbl.text = _get_status_text(npc_node)
	status_lbl.add_theme_color_override("font_color", _get_status_color(npc_node))
	status_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(status_lbl, "semibold")
	right_vbox.add_child(status_lbl)
	card.set_meta("status_label", status_lbl)

	var effect_lbl = Label.new()
	effect_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(effect_lbl, "semibold")
	var effect_text = _get_event_effect_text(emp)
	effect_lbl.text = effect_text
	effect_lbl.visible = effect_text != ""
	right_vbox.add_child(effect_lbl)
	card.set_meta("effect_label", effect_lbl)

	# === MOOD SYSTEM: Настроение + "?" + мини-полоска ===
	var mood_hbox = HBoxContainer.new()
	mood_hbox.add_theme_constant_override("separation", 6)
	right_vbox.add_child(mood_hbox)

	var mood_lbl = Label.new()
	var mood_val = emp.mood
	var zone_name = emp.get_mood_zone_name()
	mood_lbl.text = tr("ROSTER_MOOD") % [int(mood_val), zone_name]
	mood_lbl.add_theme_color_override("font_color", _get_mood_color(mood_val))
	mood_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(mood_lbl, "semibold")
	mood_hbox.add_child(mood_lbl)
	card.set_meta("mood_label", mood_lbl)

	# Кнопка "?" — breakdown настроения
	var mood_help_btn = _create_help_button()
	var mood_tooltip_ref: Array = [null]
	var mood_tooltip_label_ref: Array = [null]
	var emp_ref = emp
	var parent_ref = self

	mood_help_btn.mouse_entered.connect(func():
		if mood_tooltip_ref[0] != null and is_instance_valid(mood_tooltip_ref[0]):
			mood_tooltip_ref[0].queue_free()
		var breakdown_text = _build_mood_breakdown_text(emp_ref)
		var tp = TraitUIHelper._create_tooltip(breakdown_text, Color(0.17254902, 0.30980393, 0.5686275, 1))
		parent_ref.add_child(tp)
		var btn_global = mood_help_btn.global_position
		tp.global_position = Vector2(btn_global.x + 28, btn_global.y - 10)
		mood_tooltip_ref[0] = tp
		# Находим Label внутри тултипа для live-обновления
		mood_tooltip_label_ref[0] = parent_ref._find_label_in_tooltip(tp)
	)
	mood_help_btn.mouse_exited.connect(func():
		if mood_tooltip_ref[0] != null and is_instance_valid(mood_tooltip_ref[0]):
			mood_tooltip_ref[0].queue_free()
		mood_tooltip_ref[0] = null
		mood_tooltip_label_ref[0] = null
	)
	mood_hbox.add_child(mood_help_btn)
	# Сохраняем ссылки в мету карточки для live-обновления
	card.set_meta("mood_tooltip_ref", mood_tooltip_ref)
	card.set_meta("mood_tooltip_label_ref", mood_tooltip_label_ref)

	# Мини-полоска настроения
	var mood_bar_container = VBoxContainer.new()
	mood_bar_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mood_hbox.add_child(mood_bar_container)

	var mood_bar = ProgressBar.new()
	mood_bar.custom_minimum_size = Vector2(60, 8)
	mood_bar.min_value = 0
	mood_bar.max_value = 100
	mood_bar.value = mood_val
	mood_bar.show_percentage = false

	var mood_bg_style = StyleBoxFlat.new()
	mood_bg_style.bg_color = Color(0.88, 0.88, 0.88, 1)
	mood_bg_style.corner_radius_top_left = 4
	mood_bg_style.corner_radius_top_right = 4
	mood_bg_style.corner_radius_bottom_right = 4
	mood_bg_style.corner_radius_bottom_left = 4
	mood_bar.add_theme_stylebox_override("background", mood_bg_style)

	var mood_fill_style = StyleBoxFlat.new()
	mood_fill_style.bg_color = _get_mood_color(mood_val)
	mood_fill_style.corner_radius_top_left = 4
	mood_fill_style.corner_radius_top_right = 4
	mood_fill_style.corner_radius_bottom_right = 4
	mood_fill_style.corner_radius_bottom_left = 4
	mood_bar.add_theme_stylebox_override("fill", mood_fill_style)

	mood_bar_container.add_child(mood_bar)
	card.set_meta("mood_bar", mood_bar)

	# === Энергия ===
	var energy_lbl = Label.new()
	var energy_pct = int(emp.current_energy)
	energy_lbl.text = tr("ROSTER_ENERGY") % energy_pct
	energy_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(energy_lbl, "semibold")
	if energy_pct >= 70:
		energy_lbl.add_theme_color_override("font_color", Color(0.29, 0.69, 0.31, 1))
	elif energy_pct >= 40:
		energy_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1, 1))
	else:
		energy_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	right_vbox.add_child(energy_lbl)
	card.set_meta("energy_label", energy_lbl)

	# === ЭФФЕКТИВНОСТЬ + КНОПКА "?" ===
	var eff_hbox = HBoxContainer.new()
	eff_hbox.add_theme_constant_override("separation", 6)
	right_vbox.add_child(eff_hbox)

	var eff_lbl = Label.new()
	var eff_val = emp.get_efficiency_multiplier()
	if emp.motivation_bonus > 0:
		eff_lbl.text = tr("ROSTER_EFFICIENCY_MOTIVATED") % eff_val
		eff_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.1, 1))
	else:
		eff_lbl.text = tr("ROSTER_EFFICIENCY") % eff_val
		eff_lbl.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	eff_lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(eff_lbl, "regular")
	eff_hbox.add_child(eff_lbl)
	card.set_meta("eff_label", eff_lbl)

	# Кнопка "?" — breakdown эффективности
	var eff_help_btn = _create_help_button()
	var eff_tooltip_ref: Array = [null]

	eff_help_btn.mouse_entered.connect(func():
		if eff_tooltip_ref[0] != null and is_instance_valid(eff_tooltip_ref[0]):
			eff_tooltip_ref[0].queue_free()
		var breakdown_text = _build_efficiency_breakdown_text(emp_ref)
		var tp = TraitUIHelper._create_tooltip(breakdown_text, Color(0.17254902, 0.30980393, 0.5686275, 1))
		parent_ref.add_child(tp)
		var btn_global = eff_help_btn.global_position
		tp.global_position = Vector2(btn_global.x + 28, btn_global.y - 10)
		eff_tooltip_ref[0] = tp
	)
	eff_help_btn.mouse_exited.connect(func():
		if eff_tooltip_ref[0] != null and is_instance_valid(eff_tooltip_ref[0]):
			eff_tooltip_ref[0].queue_free()
		eff_tooltip_ref[0] = null
	)
	eff_hbox.add_child(eff_help_btn)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(spacer)

	var fire_btn = Button.new()
	fire_btn.text = tr("ROSTER_FIRE_BTN")
	fire_btn.custom_minimum_size = Vector2(180, 40)
	fire_btn.focus_mode = Control.FOCUS_NONE
	fire_btn.add_theme_stylebox_override("normal", fire_btn_style)
	fire_btn.add_theme_stylebox_override("hover", fire_btn_hover_style)
	fire_btn.add_theme_stylebox_override("pressed", fire_btn_hover_style)
	fire_btn.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	fire_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	fire_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	if UITheme: UITheme.apply_font(fire_btn, "semibold")
	fire_btn.pressed.connect(_on_fire_pressed.bind(emp, npc_node))
	right_vbox.add_child(fire_btn)

	call_deferred("_set_children_pass_filter", card)

	return card

# === УНИВЕРСАЛЬНАЯ КНОПКА "?" (стиль как у трейтов) ===
func _create_help_button() -> Button:
	var btn = Button.new()
	btn.text = "?"
	btn.custom_minimum_size = Vector2(22, 22)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))

	var bstyle = StyleBoxFlat.new()
	bstyle.bg_color = Color(1, 1, 1, 1)
	bstyle.border_width_left = 2
	bstyle.border_width_top = 2
	bstyle.border_width_right = 2
	bstyle.border_width_bottom = 2
	bstyle.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	bstyle.corner_radius_top_left = 11
	bstyle.corner_radius_top_right = 11
	bstyle.corner_radius_bottom_right = 11
	bstyle.corner_radius_bottom_left = 11
	btn.add_theme_stylebox_override("normal", bstyle)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.92, 0.94, 1.0, 1)
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	hover_style.corner_radius_top_left = 11
	hover_style.corner_radius_top_right = 11
	hover_style.corner_radius_bottom_right = 11
	hover_style.corner_radius_bottom_left = 11
	btn.add_theme_stylebox_override("hover", hover_style)

	return btn

# === Рекурсивный поиск Label внутри тултипа для live-обновления ===
func _find_label_in_tooltip(tooltip_node: Control) -> Label:
	for child in tooltip_node.get_children():
		if child is Label:
			return child
		if child is Control:
			var found = _find_label_in_tooltip(child)
			if found:
				return found
	return null

# === MOOD SYSTEM v2: Текст breakdown'а настроения ===
func _build_mood_breakdown_text(emp: EmployeeData) -> String:
	var bd = emp.get_mood_breakdown()
	var lines: Array[String] = []

	lines.append(tr("ROSTER_MOOD_BREAKDOWN_TITLE"))
	lines.append(tr("ROSTER_MOOD_BREAKDOWN_BASE") % int(bd.base))

	# --- Постоянные модификаторы ---
	if bd.permanent_mods.size() > 0:
		lines.append("")
		lines.append(tr("ROSTER_MOOD_BREAKDOWN_PERMANENT"))
		for mod in bd.permanent_mods:
			var sign_str = "+" if mod.value > 0 else ""
			lines.append("  %s%d  %s" % [sign_str, int(mod.value), mod.name])

	# --- Временные модификаторы ---
	if bd.temp_mods.size() > 0:
		lines.append("")
		lines.append(tr("ROSTER_MOOD_BREAKDOWN_TEMPORARY"))
		for mod in bd.temp_mods:
			var sign_str = "+" if mod.value > 0 else ""
			var time_left = int(mod.minutes_left)
			var hours = time_left / 60
			var mins = time_left % 60
			var time_str = ""
			if hours > 0:
				time_str = "%dh %dm" % [hours, mins]
			else:
				time_str = "%dm" % mins
			lines.append("  %s%d  %s  (%s)" % [sign_str, int(mod.value), mod.name, time_str])

	lines.append("")
	lines.append(tr("ROSTER_MOOD_BREAKDOWN_CURRENT") % int(bd.current_mood))

	return "\n".join(lines)

# === Текст breakdown'а эффективности ===
func _build_efficiency_breakdown_text(emp: EmployeeData) -> String:
	var bd = emp.get_efficiency_breakdown()
	var lines: Array[String] = []

	lines.append(tr("ROSTER_EFF_BREAKDOWN_TITLE"))
	lines.append("")
	lines.append(tr("ROSTER_EFF_BREAKDOWN_MOOD") % [bd.mood_zone_name, int(bd.mood_value), _format_mult(bd.mood_mult)])
	lines.append(tr("ROSTER_EFF_BREAKDOWN_ENERGY") % [int(bd.energy_value), _format_mult(bd.energy_factor)])
	lines.append(tr("ROSTER_EFF_BREAKDOWN_TRAITS") % _format_mod(bd.trait_sum))
	lines.append(tr("ROSTER_EFF_BREAKDOWN_MOTIVATION") % _format_mod(bd.motivation_mod))
	lines.append(tr("ROSTER_EFF_BREAKDOWN_EVENTS") % _format_mod(bd.event_mod))
	lines.append("")
	lines.append(tr("ROSTER_EFF_BREAKDOWN_TOTAL") % _format_mult(bd.total))

	return "\n".join(lines)

func _format_mult(val: float) -> String:
	return "×%.2f" % val

func _format_mod(val: float) -> String:
	if val >= 0:
		return "+%d%%" % int(val * 100)
	else:
		return "%d%%" % int(val * 100)

# === MOOD SYSTEM: Цвет по уровню mood ===
func _get_mood_color(mood_val: float) -> Color:
	if mood_val >= 80.0:
		return Color(0.29, 0.69, 0.31, 1)
	elif mood_val >= 60.0:
		return Color(0.3, 0.6, 0.85, 1)
	elif mood_val >= 40.0:
		return Color(0.9, 0.7, 0.1, 1)
	elif mood_val >= 20.0:
		return Color(0.9, 0.45, 0.1, 1)
	else:
		return Color(0.85, 0.25, 0.2, 1)

func _create_visible_trait(trait_id: String, emp: EmployeeData) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var color = Color(0.8980392, 0.22352941, 0.20784314, 1)
	if emp.is_positive_trait(trait_id):
		color = Color(0.29803923, 0.6862745, 0.3137255, 1)

	var name_text = EmployeeData.TRAIT_NAMES.get(trait_id, trait_id)
	var lbl = Label.new()
	lbl.text = tr(name_text)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "regular")
	hbox.add_child(lbl)

	var help_btn = Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(22, 22)
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.add_theme_font_size_override("font_size", 11)
	help_btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))

	var bstyle = StyleBoxFlat.new()
	bstyle.bg_color = Color(1, 1, 1, 1)
	bstyle.border_width_left = 2
	bstyle.border_width_top = 2
	bstyle.border_width_right = 2
	bstyle.border_width_bottom = 2
	bstyle.border_color = Color(0.17254902, 0.30980393, 0.5686275, 1)
	bstyle.corner_radius_top_left = 11
	bstyle.corner_radius_top_right = 11
	bstyle.corner_radius_bottom_right = 11
	bstyle.corner_radius_bottom_left = 11
	help_btn.add_theme_stylebox_override("normal", bstyle)

	var description = emp.get_trait_description(trait_id)
	var tooltip_ref: Array = [null]

	help_btn.mouse_entered.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		var tp = TraitUIHelper._create_tooltip(description, color)
		self.add_child(tp)
		var btn_global = help_btn.global_position
		tp.global_position = Vector2(btn_global.x + 28, btn_global.y - 10)
		tooltip_ref[0] = tp
	)

	help_btn.mouse_exited.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		tooltip_ref[0] = null
	)

	hbox.add_child(help_btn)
	return hbox

func _create_hidden_trait() -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var lbl = Label.new()
	lbl.text = "???"
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	lbl.add_theme_font_size_override("font_size", 13)
	if UITheme: UITheme.apply_font(lbl, "regular")
	hbox.add_child(lbl)

	var help_btn = Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(22, 22)
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.add_theme_font_size_override("font_size", 11)
	help_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))

	var bstyle = StyleBoxFlat.new()
	bstyle.bg_color = Color(0.93, 0.93, 0.93, 1)
	bstyle.border_width_left = 2
	bstyle.border_width_top = 2
	bstyle.border_width_right = 2
	bstyle.border_width_bottom = 2
	bstyle.border_color = Color(0.7, 0.7, 0.7, 1)
	bstyle.corner_radius_top_left = 11
	bstyle.corner_radius_top_right = 11
	bstyle.corner_radius_bottom_right = 11
	bstyle.corner_radius_bottom_left = 11
	help_btn.add_theme_stylebox_override("normal", bstyle)

	var tooltip_ref: Array = [null]
	var gray_color = Color(0.5, 0.5, 0.5, 1)
	var parent_ref = self

	help_btn.mouse_entered.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		var tp = TraitUIHelper._create_tooltip(tr("ROSTER_HIDDEN_TRAIT_TOOLTIP"), gray_color)
		parent_ref.add_child(tp)
		var btn_global = help_btn.global_position
		tp.global_position = Vector2(btn_global.x + 28, btn_global.y - 10)
		tooltip_ref[0] = tp
	)

	help_btn.mouse_exited.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		tooltip_ref[0] = null
	)

	hbox.add_child(help_btn)
	return hbox

func _create_employee_sprite(npc_node) -> CenterContainer:
	var center = CenterContainer.new()
	center.custom_minimum_size = Vector2(55, 70)

	var inner = Control.new()
	inner.custom_minimum_size = Vector2(36, 54)
	center.add_child(inner)

	var body_color = Color.WHITE
	var head_color = Color.WHITE
	
	if npc_node:
		if "personal_color" in npc_node:
			body_color = npc_node.personal_color
		if "head_color" in npc_node:
			head_color = npc_node.head_color
		elif "skin_color" in npc_node:
			head_color = npc_node.skin_color

	var body_tex = TextureRect.new()
	body_tex.texture = _body_texture
	body_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
	body_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body_tex.custom_minimum_size = Vector2(36, 45)
	body_tex.size = Vector2(36, 45)
	body_tex.position = Vector2(0, 18)
	body_tex.self_modulate = body_color
	inner.add_child(body_tex)

	var head_tex = TextureRect.new()
	head_tex.texture = _head_texture
	head_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
	head_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head_tex.custom_minimum_size = Vector2(24, 24)
	head_tex.size = Vector2(24, 24)
	head_tex.position = Vector2(6, 0) 
	head_tex.self_modulate = head_color
	inner.add_child(head_tex)

	return center

func _get_status_text(npc_node) -> String:
	if not npc_node or not is_instance_valid(npc_node):
		return "—"
	var state = npc_node.current_state
	match state:
		0: return tr("ROSTER_STATUS_IDLE")
		1: return tr("ROSTER_STATUS_MOVING")
		2:
			var proj_name = _get_working_project_name(npc_node.data)
			return tr("ROSTER_STATUS_WORKING") % proj_name
		3: return tr("ROSTER_STATUS_GOING_HOME")
		4: return tr("ROSTER_STATUS_HOME")
		5: return tr("ROSTER_STATUS_GOING_COFFEE")
		6: return tr("ROSTER_STATUS_COFFEE_BREAK")
		7: return tr("ROSTER_STATUS_GOING_TOILET")
		8: return tr("ROSTER_STATUS_TOILET_BREAK")
		9: return tr("ROSTER_STATUS_WANDERING")
		10: return tr("ROSTER_STATUS_THINKING")
		11: return tr("ROSTER_STATUS_SICK") % npc_node.sick_days_left
		12: return tr("ROSTER_STATUS_DAYOFF")
		# === LUNCH SYSTEM ===
		13: return tr("ROSTER_STATUS_GOING_LUNCH")
		14: return tr("ROSTER_STATUS_LUNCH_FRIDGE")
		15: return tr("ROSTER_STATUS_GOING_LUNCH")
		16: return tr("ROSTER_STATUS_LUNCH_KITCHEN")
		17: return tr("ROSTER_STATUS_GOING_LUNCH")
		18: return tr("ROSTER_STATUS_LUNCH_EATING")
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
		11: return Color(0.85, 0.25, 0.2, 1)
		12: return Color(0.9, 0.6, 0.1, 1)
		# === LUNCH SYSTEM ===
		13, 14, 15, 16, 17, 18: return Color(0.9, 0.55, 0.2, 1)
	return Color(0.17254902, 0.30980393, 0.5686275, 1)

func _get_event_effect_text(emp_data: EmployeeData) -> String:
	var em = get_node_or_null("/root/EventManager")
	if em == null:
		return ""
	var emoji = em.get_employee_effect_emoji(emp_data.employee_name)
	if emoji == "💚":
		return tr("ROSTER_STATUS_BUFF")
	elif emoji == "😤":
		return tr("ROSTER_STATUS_DEBUFF")
	return ""

func _get_working_project_name(emp_data: EmployeeData) -> String:
	for project in ProjectManager.active_projects:
		if project.state != ProjectData.State.IN_PROGRESS:
			continue
		for stage in project.stages:
			if stage.get("is_completed", false):
				continue
			for worker in stage.workers:
				if worker == emp_data:
					return tr(project.title)
	return "?"

func _find_npc_node(emp_data: EmployeeData):
	for npc in get_tree().get_nodes_in_group("npc"):
		if npc.data == emp_data:
			return npc
	return null

func _on_fire_pressed(emp_data: EmployeeData, npc_node):
	_pending_fire_data = emp_data
	_pending_fire_node = npc_node

	var projects_list = _get_assigned_projects(emp_data)

	var text = tr("ROSTER_FIRE_CONFIRM_NAME") % emp_data.employee_name
	if projects_list.size() > 0:
		var proj_names = []
		for p in projects_list:
			proj_names.append(tr(p.title))
		text += "\n\n" + tr("ROSTER_FIRE_WARN_PROJECTS") + "\n" + ", ".join(proj_names)
		text += "\n\n" + tr("ROSTER_FIRE_WARN_STAGES")

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

	for desk in get_tree().get_nodes_in_group("desk"):
		if not desk.has_method("unassign_employee"):
			continue
		if not ("assigned_employee" in desk):
			continue
		if desk.assigned_employee == _pending_fire_data:
			desk.unassign_employee()
			print("🪑 Стол освобождён")
			break

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
	if UITheme: UITheme.apply_shadow(dialog_style)
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
	title_lbl.text = tr("ROSTER_FIRE_TITLE")
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(title_lbl, "bold")
	vbox.add_child(title_lbl)

	_confirm_label = Label.new()
	_confirm_label.text = ""
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme: UITheme.apply_font(_confirm_label, "regular")
	vbox.add_child(_confirm_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 15)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var cancel_btn = Button.new()
	cancel_btn.text = tr("UI_CANCEL")
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
	if UITheme: UITheme.apply_font(cancel_btn, "semibold")
	cancel_btn.pressed.connect(_cancel_fire)
	btn_hbox.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = tr("ROSTER_FIRE_BTN")
	confirm_btn.custom_minimum_size = Vector2(180, 40)
	confirm_btn.focus_mode = Control.FOCUS_NONE
	confirm_btn.add_theme_stylebox_override("normal", fire_btn_hover_style)
	confirm_btn.add_theme_stylebox_override("hover", fire_btn_hover_style)
	confirm_btn.add_theme_stylebox_override("pressed", fire_btn_hover_style)
	confirm_btn.add_theme_color_override("font_color", Color.WHITE)
	confirm_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	confirm_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	if UITheme: UITheme.apply_font(confirm_btn, "semibold")
	confirm_btn.pressed.connect(_confirm_fire)
	btn_hbox.add_child(confirm_btn)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		if _dialog_layer and _dialog_layer.visible:
			_cancel_fire()
		else:
			_on_close_pressed()
		get_viewport().set_input_as_handled()
