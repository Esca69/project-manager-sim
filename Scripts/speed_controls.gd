extends HBoxContainer

func _ready():
	# Подключаем кнопки
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
	
func _process(delta):
	# Опционально: Подсветка активной кнопки
	# (Можно сделать красивее через Theme, но для примера так)
	var current = GameTime.current_speed_scale
	if GameTime.is_game_paused: current = 0
	
	$PauseBtn.modulate = Color.GREEN if current == 0 else Color.WHITE
	$Speed1Btn.modulate = Color.GREEN if current == 1 else Color.WHITE
	$Speed2Btn.modulate = Color.GREEN if current == 2 else Color.WHITE
	$Speed5Btn.modulate = Color.GREEN if current == 5 else Color.WHITE
