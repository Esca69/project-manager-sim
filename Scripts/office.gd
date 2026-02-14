extends Node2D

# Ссылка на сцену сотрудника
var employee_scene = preload("res://Scenes/Employee.tscn")

# Точка спавна
@onready var spawn_point = $SpawnPoint

# Системы
var _lighting: Node = null
var _shadows: Node = null

func _ready():
	# === WorldEnvironment — настраиваем кодом (deferred чтобы дерево было готово) ===
	call_deferred("_setup_environment")

	# === Динамическое освещение ===
	_lighting = preload("res://Scripts/office_lighting.gd").new()
	add_child(_lighting)
	_lighting.setup(self)

	# === Система теней ===
	_shadows = preload("res://Scripts/shadow_system.gd").new()
	add_child(_shadows)
	_shadows.setup(self)

func _setup_environment():
	# Ищем существующий WorldEnvironment в сцене
	var world_env = find_child("WorldEnvironment", false, false)
	if not world_env:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		add_child(world_env)

	# Создаём ресурс Environment
	var env = Environment.new()

	# Фон — Canvas Items (обязательно для 2D!)
	env.background_mode = Environment.BG_CANVAS

	# === Tonemap — мягкие переходы свет/тень ===
	env.tonemap_mode = Environment.TONE_MAP_FILMIC
	env.tonemap_white = 1.0

	# === Adjustments — сочность картинки ===
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.05    # Чуть ярче
	env.adjustment_contrast = 1.08      # Чуть контрастнее
	env.adjustment_saturation = 1.12    # Чуть сочнее цвета

	# === Glow (Bloom) — мягкое свечение ===
	env.glow_enabled = true
	env.glow_intensity = 0.3           # Лёгкое, не навязчивое
	env.glow_strength = 0.8
	env.glow_bloom = 0.05              # Минимальный bloom
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	world_env.environment = env

# Эту функцию вызывает UI Найма
func spawn_new_employee(data: EmployeeData):
	# 1. Создаем копию
	var new_npc = employee_scene.instantiate()

	# 2. Настраиваем данные СРАЗУ (до добавления в сцену)
	new_npc.setup_employee(data)

	# 3. Ищем слой для сортировки
	var world_layer = get_tree().get_first_node_in_group("world_layer")

	if world_layer:
		world_layer.add_child(new_npc)
	else:
		add_child(new_npc)
		print("ВНИМАНИЕ: Нет группы 'world_layer'! Сортировка может сломаться.")

	# 4. Позиция
	if spawn_point:
		var random_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		new_npc.global_position = spawn_point.global_position + random_offset
	else:
		new_npc.global_position = Vector2(500, 300)

	print("Заспавнен сотрудник: ", data.employee_name)
