extends HBoxContainer

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_ACTIVE = Color(0.95, 0.85, 0.2, 1)  # Жёлтый для активной
const COLOR_ACTIVE_BORDER = Color(0.8, 0.7, 0.1, 1)

var _normal_style: StyleBoxFlat
var _active_style: StyleBoxFlat

func _ready():
	# Ст��ль обычной кнопки (белый фон, синяя обводка)
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(1, 1, 1, 1)
	_normal_style.border_width_left = 2
	_normal_style.border_width_top = 2
	_normal_style.border_width_right = 2
	_normal_style.border_width_bottom = 2
	_normal_style.border_color = COLOR_BLUE
	_normal_style.corner_radius_top_left = 12
	_normal_style.corner_radius_top_right = 12
	_normal_style.corner_radius_bottom_right = 12
	_normal_style.corner_radius_bottom_left = 12
	
	# Стиль ак��ивной кнопки (жёлтый фон)
	_active_style = StyleBoxFlat.new()
	_active_style.bg_color = COLOR_ACTIVE
	_active_style.border_width_left = 2
	_active_style.border_width_top = 2
	_active_style.border_width_right = 2
	_active_style.border_width_bottom = 2
	_active_style.border_color = COLOR_ACTIVE_BORDER
	_active_style.corner_radius_top_left = 12
	_active_style.corner_radius_top_right = 12
	_active_style.corner_radius_bottom_right = 12
	_active_style.corner_radius_bottom_left = 12
	
	# Применяем стиль ко всем кнопкам
	for btn in [$PauseBtn, $Speed1Btn, $Speed2Btn, $Speed5Btn]:
		btn.custom_minimum_size = Vector2(44, 30)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_stylebox_override("normal", _normal_style)
		btn.add_theme_stylebox_override("hover", _normal_style)
		btn.add_theme_stylebox_override("pressed", _active_style)
		btn.add_theme_color_override("font_color", COLOR_BLUE)
		btn.add_theme_color_override("font_hover_color", COLOR_BLUE)
		btn.add_theme_color_override("font_pressed_color", Color(0.2, 0.2, 0.2, 1))
	
	$PauseBtn.pressed.connect(_on_pause_pressed)
	$Speed1Btn.pressed.connect(_on_1x_pressed)
	$Speed2Btn.pressed.connect(_on_2x_pressed)
	$Speed5Btn.pressed.connect(_on_5x_pressed)

func _on_pause_pressed():
	GameTime.set_speed(0)

func _on_1x_pressed():
	GameTime.speed_1x()

func _on_2x_pressed():
	GameTime.speed_2x()

func _on_5x_pressed():
	GameTime.speed_5x()

func _process(_delta):
	var current = GameTime.current_speed_scale
	if GameTime.is_game_paused: current = 0
	
	_update_btn_style($PauseBtn, current == 0)
	_update_btn_style($Speed1Btn, current == 1)
	_update_btn_style($Speed2Btn, current == 2)
	_update_btn_style($Speed5Btn, current == 5)

func _update_btn_style(btn: Button, is_active: bool):
	if is_active:
		btn.add_theme_stylebox_override("normal", _active_style)
		btn.add_theme_stylebox_override("hover", _active_style)
		btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.2, 0.2, 0.2, 1))
	else:
		btn.add_theme_stylebox_override("normal", _normal_style)
		btn.add_theme_stylebox_override("hover", _normal_style)
		btn.add_theme_color_override("font_color", COLOR_BLUE)
		btn.add_theme_color_override("font_hover_color", COLOR_BLUE)
