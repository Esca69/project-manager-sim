extends PanelContainer

signal tab_pressed(tab_name: String)

@onready var hbox = $MarginContainer/HBoxContainer

var btn_style_normal: StyleBoxFlat
var btn_style_hover: StyleBoxFlat

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Стиль как у кнопок "Нанять" / "Открыть" — белый фон, синяя обводка
	btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(1, 1, 1, 1)
	btn_style_normal.border_width_left = 2
	btn_style_normal.border_width_top = 2
	btn_style_normal.border_width_right = 2
	btn_style_normal.border_width_bottom = 2
	btn_style_normal.border_color = Color(1, 1, 1, 0.6)
	btn_style_normal.corner_radius_top_left = 10
	btn_style_normal.corner_radius_top_right = 10
	btn_style_normal.corner_radius_bottom_right = 10
	btn_style_normal.corner_radius_bottom_left = 10
	
	btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.9, 0.93, 1.0, 1)
	btn_style_hover.border_width_left = 2
	btn_style_hover.border_width_top = 2
	btn_style_hover.border_width_right = 2
	btn_style_hover.border_width_bottom = 2
	btn_style_hover.border_color = Color(1, 1, 1, 1)
	btn_style_hover.corner_radius_top_left = 10
	btn_style_hover.corner_radius_top_right = 10
	btn_style_hover.corner_radius_bottom_right = 10
	btn_style_hover.corner_radius_bottom_left = 10
	
	_add_tab_button("👥 Сотрудники", "employees")
	# Сюда потом:
	# _add_tab_button("📋 Проекты", "projects")
	# _add_tab_button("💰 Финансы", "finances")

func _add_tab_button(label_text: String, tab_name: String):
	var btn = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(180, 36)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", btn_style_normal)
	btn.add_theme_stylebox_override("hover", btn_style_hover)
	btn.add_theme_stylebox_override("pressed", btn_style_hover)
	btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(_on_tab_pressed.bind(tab_name))
	hbox.add_child(btn)

func _on_tab_pressed(tab_name: String):
	emit_signal("tab_pressed", tab_name)
