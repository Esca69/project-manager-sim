extends CharacterBody2D

const SPEED = 300.0

# Ссылка на нашу зону взаимодействия (чтобы каждый раз не искать)
@onready var interaction_zone = $InteractionZone

func _physics_process(delta):
	# --- БЛОК ДВИЖЕНИЯ (старый) ---
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	# --- БЛОК ВЗАИМОДЕЙСТВИЯ (новый) ---
	# Если нажали кнопку "interact" (наша E)
	if Input.is_action_just_pressed("interact"):
		interact()

func interact():
	var bodies = interaction_zone.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("npc") and body.data:
			# ВМЕСТО print() ПИШЕМ ЭТО:
			
			# "Эй, дерево игры! Найди всех, кто в группе 'ui', 
			# и вызови у них функцию 'show_employee_card' с данными body.data"
			get_tree().call_group("ui", "show_employee_card", body.data)
			
			return
	# Если это стол (НОВОЕ)
		if body.is_in_group("desk"):
			body.interact() # Вызываем функцию стола
			return
