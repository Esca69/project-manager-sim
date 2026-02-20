extends Node2D

# Ссылка на сцену сотрудника
var employee_scene = preload("res://Scenes/Employee.tscn")

# Точка спавна
@onready var spawn_point = $SpawnPoint

# Системы
var _lighting: Node = null
var _shadows: Node = null
var _post_effects: Node = null

func _ready():
	# === КРИТИЧНО: добавляем в группу "office" для поиска из SaveManager ===
	add_to_group("office")
	
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

	# === Пост-эффекты (виньетка) ===
	_post_effects = preload("res://Scripts/post_effects.gd").new()
	add_child(_post_effects)
	_post_effects.setup(self)

	# === ЗАГРУЗКА СОХРАНЕНИЯ ===
	# Используем call_deferred, чтобы вся сцена была готова,
	# а затем запускаем restore как отдельную корутину
	call_deferred("_try_restore_save")

func _try_restore_save():
	if SaveManager.pending_restore:
		SaveManager.pending_restore = false
		print("📂 Восстанавливаем сотрудников и проекты из сохранения...")
		# Запускаем как корутину — await внутри restore будет работать корректно
		_do_restore()

func _do_restore():
	await SaveManager.restore_employees_and_projects()
	print("📂 Восстановление завершено")

func _setup_environment():
	# Ищем существующий WorldEnvironment среди детей
	var world_env = null
	for child in get_children():
		if child is WorldEnvironment:
			world_env = child
			break

	if not world_env:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		add_child(world_env)

	# Создаём ресурс Environment
	var env = Environment.new()

	# Фон — Canvas Items (обязательно для 2D!)
	env.background_mode = Environment.BG_CANVAS

	# === Adjustments — сочность картинки ===
	env.adjustment_enabled = false
	env.adjustment_brightness = 1.05
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12

	# === Glow (Bloom) — мягкое свечение ===
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_strength = 0.8
	env.glow_bloom = 0.05
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
