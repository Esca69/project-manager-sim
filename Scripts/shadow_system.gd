extends Node

# === СИСТЕМА ТЕНЕЙ v3 ===
# Мягкие эллиптические тени под NPC, Player и мебе��ь.

# --- NPC (Employee) ---
# --- NPC (Employee) ---
const NPC_SHADOW_WIDTH = 90.0      # было 90
const NPC_SHADOW_HEIGHT = 40.0      # было 30
const NPC_SHADOW_OFFSET_Y = -5.0
const NPC_SHADOW_ALPHA = 0.30       # было 0.22

# --- Player ---
const PLAYER_SHADOW_WIDTH = 90.0   # было 90
const PLAYER_SHADOW_HEIGHT = 40.0   # было 30
const PLAYER_SHADOW_OFFSET_Y = -5.0
const PLAYER_SHADOW_ALPHA = 0.30    # было 0.25

# --- Мебель ---
const FURNITURE_SHADOW_ALPHA = 0.18

var _shadow_texture: ImageTexture = null
var _tracked_npcs: Dictionary = {}
var _player_tracked: bool = false
var _scene_root: Node2D = null

# Увеличил текстуру и сделал более мягкий градиент
const SHADOW_TEX_SIZE = 128

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shadow_texture = _generate_shadow_texture()

func setup(scene_root: Node2D):
	_scene_root = scene_root
	call_deferred("_add_furniture_shadows")
	call_deferred("_add_player_shadow")
	call_deferred("_add_office_border_shadow")

func _process(_delta):
	if _scene_root == null:
		return

	# NPC (Employee) — группа "npc"
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		if npc in _tracked_npcs:
			var shadow = _tracked_npcs[npc]
			if is_instance_valid(shadow):
				shadow.visible = npc.visible
			continue
		_add_npc_shadow(npc)

	# Чистка удалённых
	var to_remove = []
	for npc in _tracked_npcs:
		if not is_instance_valid(npc):
			to_remove.append(npc)
	for npc in to_remove:
		var shadow = _tracked_npcs[npc]
		if is_instance_valid(shadow):
			shadow.queue_free()
		_tracked_npcs.erase(npc)

# === ТЕНЬ ДЛЯ PLAYER ===
func _add_player_shadow():
	if _player_tracked:
		return

	var world_objects = _scene_root.get_node_or_null("WorldObjects")
	if not world_objects:
		return

	var player = world_objects.get_node_or_null("Player")
	if not player:
		return

	var shadow = _create_shadow_sprite(
		PLAYER_SHADOW_WIDTH,
		PLAYER_SHADOW_HEIGHT,
		PLAYER_SHADOW_ALPHA,
		Vector2(0, PLAYER_SHADOW_OFFSET_Y)
	)

	player.add_child(shadow)
	# Ставим тень первым ребёнком — под всеми спрайтами
	player.move_child(shadow, 0)
	_player_tracked = true

# === ТЕНЬ ДЛЯ NPC (Employee) ===
func _add_npc_shadow(npc: Node):
	var visuals = npc.find_child("Visuals", false, false)
	var parent_node = visuals if visuals else npc

	var shadow = _create_shadow_sprite(
		NPC_SHADOW_WIDTH,
		NPC_SHADOW_HEIGHT,
		NPC_SHADOW_ALPHA,
		Vector2(0, NPC_SHADOW_OFFSET_Y)
	)

	parent_node.add_child(shadow)
	parent_node.move_child(shadow, 0)

	_tracked_npcs[npc] = shadow

# === ТЕНИ ДЛЯ МЕБЕЛИ ===
func _add_furniture_shadows():
	if _scene_root == null:
		return

	var world_objects = _scene_root.get_node_or_null("WorldObjects")
	if not world_objects:
		return

	for child in world_objects.get_children():
		var child_name = child.name as String

		if child_name == "Player":
			continue

		# Пропускаем чистые Sprite2D (Board, Plant, Panel, Hr, Boss)
		if child is Sprite2D:
			continue

		var shadow_w: float = 0.0
		var shadow_h: float = 0.0
		var offset_y: float = 0.0

		# Размеры привязаны к реальным collision shapes из .tscn
		# Тень ШИРЕ коллизии (чтобы выглядывала из-под предмета)
		# offset_y близок к 0, т.к. спрайты уже сдвинуты через offset

		if child_name.begins_with("EmployeeDesk"):
			# capsule 256×78, sprite offset=-75
			shadow_w = 300.0
			shadow_h = 80.0
			offset_y = 5.0

		elif child_name == "ComputerDesk":
			# collision 252×133
			shadow_w = 300.0
			shadow_h = 100.0
			offset_y = 15.0

		elif child_name == "BossDesk":
			# collision 253×141
			shadow_w = 300.0
			shadow_h = 100.0
			offset_y = 10.0

		elif child_name == "HrDesk":
			# collision 257×143, sprite offset=-75
			shadow_w = 300.0
			shadow_h = 80.0
			offset_y = 5.0

		elif child_name == "CoffeeMachine":
			# collision 123×92, sprite offset=-100
			shadow_w = 160.0
			shadow_h = 60.0
			offset_y = 5.0

		elif child_name == "Flipchart":
			# collision 78×61, sprite offset=-72
			shadow_w = 110.0
			shadow_h = 40.0
			offset_y = 2.0

		elif child_name == "Toilet":
			# collision 44×119, sprite offset=-60
			shadow_w = 80.0
			shadow_h = 60.0
			offset_y = 2.0

		elif child_name.begins_with("Tumbochka"):
			# collision 91×26, sprite offset=-50
			shadow_w = 130.0
			shadow_h = 40.0
			offset_y = 0.0

		elif child_name == "Sofa":
			# collision 258×48, sprite offset=-50
			shadow_w = 310.0
			shadow_h = 60.0
			offset_y = 5.0

		elif child_name == "Lampa":
			# collision 14×48, sprite offset=-85
			shadow_w = 70.0
			shadow_h = 30.0
			offset_y = 0.0

		else:
			continue

		var shadow = _create_shadow_sprite(
			shadow_w,
			shadow_h,
			FURNITURE_SHADOW_ALPHA,
			Vector2(0, offset_y)
		)

		child.add_child(shadow)
		child.move_child(shadow, 0)

# === СОЗДАНИЕ СПРАЙТА ТЕНИ ===
func _create_shadow_sprite(w: float, h: float, alpha: float, offset: Vector2) -> Sprite2D:
	var shadow = Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = _shadow_texture
	shadow.z_index = -1
	shadow.z_as_relative = true
	shadow.self_modulate = Color(0, 0, 0, alpha)
	shadow.scale = Vector2(
		w / float(SHADOW_TEX_SIZE),
		h / float(SHADOW_TEX_SIZE)
	)
	shadow.position = offset
	return shadow

# === ГЕНЕРАЦИЯ ТЕКСТУРЫ ЭЛЛИПСА ===
# Размер 128px, более мягкий градиент — тень затухает плавнее
func _generate_shadow_texture() -> ImageTexture:
	var img = Image.create(SHADOW_TEX_SIZE, SHADOW_TEX_SIZE, false, Image.FORMAT_RGBA8)
	var center = Vector2(SHADOW_TEX_SIZE / 2.0, SHADOW_TEX_SIZE / 2.0)
	var radius = SHADOW_TEX_SIZE / 2.0

	for y in range(SHADOW_TEX_SIZE):
		for x in range(SHADOW_TEX_SIZE):
			var dx = (float(x) - center.x) / radius
			var dy = (float(y) - center.y) / radius
			var dist = sqrt(dx * dx + dy * dy)

			if dist <= 1.0:
				# Более мягкий градиент: центр плотный, край очень плавный
				# Используем степень 0.6 чтобы тень была "шире" визуально
				var t = _smoothstep(0.0, 1.0, dist)
				var alpha = pow(1.0 - t, 0.6)
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0))

	return ImageTexture.create_from_image(img)

func _smoothstep(edge0: float, edge1: float, x_val: float) -> float:
	var t = clamp((x_val - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
