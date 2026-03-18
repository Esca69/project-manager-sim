extends Node2D

# Ссылка на сцену сотрудника — load вместо preload!
var employee_scene: PackedScene = null

# Точка спавна
@onready var spawn_point = $SpawnPoint

# Системы
var _lighting: Node = null
var _shadows: Node = null
var _post_effects: Node = null

const DESK_PURCHASE_ORDER = [
"EmployeeDesk2", "EmployeeDesk4", "EmployeeDesk6", "EmployeeDesk7",
"EmployeeDesk8", "EmployeeDesk9", "EmployeeDesk11", "EmployeeDesk10", "EmployeeDesk12"
]
const STARTING_DESKS = ["EmployeeDesk3", "EmployeeDesk", "EmployeeDesk5"]
const DESK_TUMBOCHKA_MAP = {
	"EmployeeDesk2": "Tumbochka",
	"EmployeeDesk4": "Tumbochka2",
	"EmployeeDesk6": "Tumbochka3",
}

func _ready():
	# === КРИТИЧНО: добавляем в группу "office" для поиска из SaveManager ===
	add_to_group("office")
	
	# === ЗАГРУЗКА СЦЕНЫ СОТРУДНИКА (load вместо preload!) ===
	employee_scene = load("res://Scenes/Employee.tscn")
	if employee_scene == null:
		# Пробуем альтернативные пути (на случай переименования)
		employee_scene = load("res://Scenes/employee.tscn")
	if employee_scene == null:
		push_error("🔴 [OFFICE] Employee.tscn НЕ НАЙДЕН! Проверь что файл существует в Scenes/")
	else:
		print("🟢 [OFFICE] Employee.tscn загружен успешно")
	
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

	# === Пост-эффекты (��иньетка) ===
	_post_effects = preload("res://Scripts/post_effects.gd").new()
	add_child(_post_effects)
	_post_effects.setup(self)

	# === Применяем состояние улучшений офиса ===
	call_deferred("_apply_and_connect_upgrades")

	# === ЗАГРУЗКА СОХРАНЕНИЯ ===
	# Используем call_deferred, чтобы вся сцена была готова,
	# а затем запускаем restore как отдельную корутину
	call_deferred("_try_restore_save")

func _apply_and_connect_upgrades():
	apply_office_upgrades()
	if not GameState.office_upgrade_purchased.is_connected(_on_office_upgrade_purchased):
		GameState.office_upgrade_purchased.connect(_on_office_upgrade_purchased)

func _on_office_upgrade_purchased(_upgrade_id: String):
	apply_office_upgrades()

func _set_node_collision(node: Node, enabled: bool):
	for child in node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = not enabled
		_set_node_collision(child, enabled)

func apply_office_upgrades():
	# Coffee Machine
	var coffee = find_child("CoffeeMachine", true, false)
	if coffee:
		coffee.visible = GameState.office_upgrades.get("coffee_machine", false)
		_set_node_collision(coffee, coffee.visible)

	# Kitchen objects
	var kitchen_objects = ["Fridge", "Kitchen", "foodtable", "foodtable2", "foodtable3"]
	var kitchen_bought = GameState.office_upgrades.get("kitchen", false)
	for obj_name in kitchen_objects:
		var obj = find_child(obj_name, true, false)
		if obj:
			obj.visible = kitchen_bought
			_set_node_collision(obj, kitchen_bought)

	# Desks — starting desks always visible
	for desk_name in STARTING_DESKS:
		var desk = find_child(desk_name, true, false)
		if desk:
			desk.visible = true
			_set_node_collision(desk, true)
			if not desk.is_in_group("desk"):
				desk.add_to_group("desk")

	# Purchased additional desks
	var desk_count = GameState.office_upgrades.get("desk_count", 3)
	for i in range(DESK_PURCHASE_ORDER.size()):
		var desk_name = DESK_PURCHASE_ORDER[i]
		var desk = find_child(desk_name, true, false)
		if desk:
			var should_show = i < (desk_count - 3)
			desk.visible = should_show
			_set_node_collision(desk, should_show)
			if should_show:
				if not desk.is_in_group("desk"):
					desk.add_to_group("desk")
				else:
					if desk.is_in_group("desk"):
						desk.remove_from_group("desk")
			if DESK_TUMBOCHKA_MAP.has(desk_name):
				var tumb_name = DESK_TUMBOCHKA_MAP[desk_name]
				var tumb = find_child(tumb_name, true, false)
				if tumb:
					tumb.visible = should_show
					_set_node_collision(tumb, should_show)

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
	# Подстраховка: если не загрузилось в _ready, пробуем ещё раз
	if employee_scene == null:
		employee_scene = load("res://Scenes/Employee.tscn")
	if employee_scene == null:
		push_error("🔴 [OFFICE] Employee.tscn НЕ ЗАГРУЖЕН! Сотрудник не создан: " + data.employee_name)
		return

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
