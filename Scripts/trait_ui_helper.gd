extends RefCounted
class_name TraitUIHelper

const COLOR_POSITIVE = Color(0.29803923, 0.6862745, 0.3137255, 1)
const COLOR_NEGATIVE = Color(0.8980392, 0.22352941, 0.20784314, 1)
const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)

# Создаёт HFlowContainer с трейтами В СТРОКУ (перенос если не влезает)
static func create_traits_row(emp: EmployeeData, parent_control: Control) -> HFlowContainer:
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 4)
	
	if emp.traits.is_empty():
		return flow
	
	for trait_id in emp.traits:
		var item = _create_single_trait(trait_id, emp, parent_control)
		flow.add_child(item)
	
	return flow

static func _create_single_trait(trait_id: String, emp: EmployeeData, parent_control: Control) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	
	var color = COLOR_NEGATIVE
	if emp.is_positive_trait(trait_id):
		color = COLOR_POSITIVE
	
	var name_text = EmployeeData.TRAIT_NAMES.get(trait_id, trait_id)
	var lbl = Label.new()
	lbl.text = name_text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)
	
	# Кнопка "?"
	var help_btn = Button.new()
	help_btn.text = "?"
	help_btn.custom_minimum_size = Vector2(22, 22)
	help_btn.focus_mode = Control.FOCUS_NONE
	help_btn.add_theme_font_size_override("font_size", 11)
	help_btn.add_theme_color_override("font_color", COLOR_BLUE)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(1, 1, 1, 1)
	btn_style.border_width_left = 2
	btn_style.border_width_top = 2
	btn_style.border_width_right = 2
	btn_style.border_width_bottom = 2
	btn_style.border_color = COLOR_BLUE
	btn_style.corner_radius_top_left = 11
	btn_style.corner_radius_top_right = 11
	btn_style.corner_radius_bottom_right = 11
	btn_style.corner_radius_bottom_left = 11
	help_btn.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover_style = StyleBoxFlat.new()
	btn_hover_style.bg_color = Color(0.92, 0.94, 1.0, 1)
	btn_hover_style.border_width_left = 2
	btn_hover_style.border_width_top = 2
	btn_hover_style.border_width_right = 2
	btn_hover_style.border_width_bottom = 2
	btn_hover_style.border_color = COLOR_BLUE
	btn_hover_style.corner_radius_top_left = 11
	btn_hover_style.corner_radius_top_right = 11
	btn_hover_style.corner_radius_bottom_right = 11
	btn_hover_style.corner_radius_bottom_left = 11
	help_btn.add_theme_stylebox_override("hover", btn_hover_style)
	
	var description = emp.get_trait_description(trait_id)
	
	# [ИСПРАВЛЕНИЕ] Используем массив для хранения ссылки на тултип
	# Это нужно чтобы лямбды могли менять значение
	var tooltip_ref: Array = [null]
	
	help_btn.mouse_entered.connect(func():
		# Убираем старый, если есть
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		var tp = _create_tooltip(description, color)
		parent_control.add_child(tp)
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

static func _create_tooltip(text: String, border_color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.z_index = 300
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(250, 0)
	margin.add_child(lbl)
	
	return panel
