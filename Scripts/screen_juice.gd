extends Node

# ============================================================
# ScreenJuice — визуальная обратная связь (без звуков)
# Autoload-синглтон. Stateless — ничего не сохраняется.
# ============================================================

const MAX_TOASTS: int = 5
const TOAST_WIDTH: float = 360.0
const TOAST_MARGIN_RIGHT: float = 12.0
const TOAST_MARGIN_TOP: float = 120.0  # Опущено ниже, чтобы не залезать на верхнюю панель
const TOAST_SPACING: float = 8.0
const TOAST_SHOW_DURATION: float = 6.0
const TOAST_FADE_DURATION: float = 0.5
const TOAST_SLIDE_DURATION: float = 0.3

var _ui_layer: CanvasLayer = null
var _active_toasts: Array = []
var _balance_label_ref: Control = null
var _personal_balance_label_ref: Control = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui_layer()

func _build_ui_layer():
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 100
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

# ============================================================
# Регистрация опорных лейблов (вызывается из hud.gd)
# ============================================================
func register_balance_label(label: Control):
	_balance_label_ref = label

func register_personal_balance_label(label: Control):
	_personal_balance_label_ref = label

# ============================================================
# ФИЧА 1: Floating Money Text
# ============================================================
func show_floating_text(anchor_node: Control, text: String, color: Color):
	if not is_instance_valid(anchor_node) or not _ui_layer:
		return

	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 24)
	if UITheme:
		UITheme.apply_font(label, "bold")
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer.add_child(label)

	# Позиция над anchor_node (в экранных координатах)
	var anchor_rect = anchor_node.get_global_rect()
	var start_pos = Vector2(anchor_rect.position.x + anchor_rect.size.x * 0.5, anchor_rect.position.y - 4.0)
	label.position = start_pos

	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", start_pos + Vector2(0.0, -55.0), 2.0)
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.chain().tween_callback(label.queue_free)

# Хелперы для game_state.gd (нет прямого доступа к лейблам)
func show_income_float(amount: int):
	if is_instance_valid(_balance_label_ref):
		show_floating_text(_balance_label_ref, "+$%d" % amount, Color(0.2, 0.9, 0.3))

func show_expense_float(amount: int):
	if is_instance_valid(_balance_label_ref):
		show_floating_text(_balance_label_ref, "-$%d" % amount, Color(1.0, 0.3, 0.3))

func show_personal_income_float(amount: int):
	if is_instance_valid(_personal_balance_label_ref):
		show_floating_text(_personal_balance_label_ref, "+$%d" % amount, Color(0.2, 0.9, 0.3))

func show_personal_expense_float(amount: int):
	if is_instance_valid(_personal_balance_label_ref):
		show_floating_text(_personal_balance_label_ref, "-$%d" % amount, Color(1.0, 0.3, 0.3))

# ============================================================
# ФИЧА 2: Конфетти при завершении проекта
# ============================================================
func show_confetti():
	if not _ui_layer:
		return
	var confetti_script = load("res://Scripts/confetti_effect.gd")
	if not confetti_script:
		return
	var c = Node2D.new()
	c.set_script(confetti_script)
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui_layer.add_child(c)

# ============================================================
# ФИЧА 3: Toast-нотификации
# ============================================================
func show_toast(emoji: String, text: String):
	if not _ui_layer:
		return

	# Ограничение количества тостов
	while _active_toasts.size() >= MAX_TOASTS:
		var oldest = _active_toasts[0]
		_active_toasts.remove_at(0)
		if is_instance_valid(oldest):
			oldest.queue_free()

	var toast = _build_toast(emoji, text)
	_ui_layer.add_child(toast)
	_active_toasts.append(toast)

	_reposition_toasts()
	_animate_toast_in(toast)

	get_tree().create_timer(TOAST_SHOW_DURATION).timeout.connect(func():
		if is_instance_valid(toast):
			_animate_toast_out(toast)
	)

func _build_toast(emoji: String, text: String) -> PanelContainer:
	var toast = PanelContainer.new()
	toast.process_mode = Node.PROCESS_MODE_ALWAYS
	# Фиксированная ширина: min = max = TOAST_WIDTH → тост не растянется
	toast.custom_minimum_size = Vector2(TOAST_WIDTH, 0.0)
	toast.size = Vector2(TOAST_WIDTH, 0.0)
	# Запрещаем контейнеру расти больше заданной ширины
	toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	var style = StyleBoxFlat.new()
	# Синий фон вместо чёрного, под стиль игры
	style.bg_color = Color(0.14, 0.25, 0.45, 0.93)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	# Тонкая светлая рамка для стиля
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.4, 0.55, 0.8, 0.5)
	# Тень
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_size = 4
	toast.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	toast.add_child(hbox)

	var emoji_label = Label.new()
	emoji_label.text = emoji
	emoji_label.add_theme_font_size_override("font_size", 20)
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(emoji_label)

	var text_label = Label.new()
	text_label.text = text
	text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0, 1.0))
	text_label.add_theme_font_size_override("font_size", 14)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Ограничиваем ширину текста через custom_minimum_size (custom_maximum_size НЕ существует у Label)
	# TOAST_WIDTH - margins(14*2) - emoji(~30) - separation(10) ≈ 292
	text_label.custom_minimum_size = Vector2(0, 0)
	if UITheme:
		UITheme.apply_font(text_label, "semibold")
	hbox.add_child(text_label)

	# Начальная позиция — за правым краем экрана
	var vp_size = _ui_layer.get_viewport().get_visible_rect().size
	toast.position = Vector2(vp_size.x + 10.0, TOAST_MARGIN_TOP)

	# КЛЮЧЕВОЙ ФИКС: принудительно задаём размер после добавления всех дочерних элементов
	# Это предотвращает авто-расширение PanelContainer
	toast.set_deferred("size", Vector2(TOAST_WIDTH, 0.0))
	return toast

func _reposition_toasts():
	var vp_size = _ui_layer.get_viewport().get_visible_rect().size
	var current_y = TOAST_MARGIN_TOP
	for i in range(_active_toasts.size()):
		var t = _active_toasts[i]
		if not is_instance_valid(t):
			continue
		# Принудительно держим ширину
		t.size.x = TOAST_WIDTH
		# Target X: right-aligned with margin
		t.position.x = vp_size.x - TOAST_WIDTH - TOAST_MARGIN_RIGHT
		t.position.y = current_y
		# Use actual size if available, otherwise estimate height
		var h = t.size.y if t.size.y > 2.0 else 48.0
		current_y += h + TOAST_SPACING

func _animate_toast_in(toast: PanelContainer):
	var vp_size = _ui_layer.get_viewport().get_visible_rect().size
	var target_x = vp_size.x - TOAST_WIDTH - TOAST_MARGIN_RIGHT
	# Start from off-screen right, then slide to target
	toast.position.x = vp_size.x + 10.0
	# Принудительно фиксируем ширину перед анимацией
	toast.size.x = TOAST_WIDTH
	var tween = toast.create_tween()
	tween.tween_property(toast, "position:x", target_x, TOAST_SLIDE_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

func _animate_toast_out(toast: PanelContainer):
	if not is_instance_valid(toast):
		return
	_active_toasts.erase(toast)
	var tween = toast.create_tween()
	tween.tween_property(toast, "modulate:a", 0.0, TOAST_FADE_DURATION)
	tween.tween_callback(toast.queue_free)

# ============================================================
# ФИЧА 4: Pulse/Bounce анимация лейбла
# ============================================================
func bounce_node(node: Control, is_positive: bool, reset_color: Color = Color.WHITE):
	if not is_instance_valid(node):
		return
	var flash_color = Color(0.3, 1.0, 0.4) if is_positive else Color(1.0, 0.35, 0.35)
	var tween = node.create_tween()
	# Фаза 1: scale up + flash (параллельно, 0.15с)
	tween.tween_property(node, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "modulate", flash_color, 0.15)
	# Фаза 2: scale back + fade to reset_color (параллельно, 0.2с)
	tween.tween_property(node, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "modulate", reset_color, 0.2)

# ============================================================
# ФИЧА 5: Level-Up эффект над головой NPC
# ============================================================
func show_levelup_effect(npc_node: Node2D, level: int):
	if not is_instance_valid(npc_node):
		return

	var effect = Node2D.new()
	npc_node.add_child(effect)
	effect.position = Vector2(0.0, -130.0)
	effect.z_index = 101
	effect.process_mode = Node.PROCESS_MODE_ALWAYS

	var label = Label.new()
	effect.add_child(label)
	label.text = "⬆️ Lvl %d!" % level
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.05, 1.0))
	label.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(label, "bold")
	label.position = Vector2(-50.0, -16.0)
	label.custom_minimum_size = Vector2(100.0, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Анимация pop-in: scale 0 → 1.2 → 1.0
	effect.scale = Vector2.ZERO
	var tween = effect.create_tween()
	tween.tween_property(effect, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(effect, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Висит 2 секунды, затем fade out 0.5с
	tween.tween_interval(2.0)
	tween.tween_property(effect, "modulate:a", 0.0, 0.5)
	tween.tween_callback(effect.queue_free)

# ============================================================
# ФИЧА 6: Mood Ring — кольцо-пульс при смене зоны настроения NPC
# ============================================================
func show_mood_ring(npc_node: Node2D, is_positive: bool):
	if not is_instance_valid(npc_node):
		return
	var ring_script = load("res://Scripts/mood_ring_effect.gd")
	if not ring_script:
		return
	var ring = Node2D.new()
	ring.set_script(ring_script)
	ring.process_mode = Node.PROCESS_MODE_ALWAYS
	ring.ring_color = Color(0.2, 0.9, 0.3, 1.0) if is_positive else Color(1.0, 0.3, 0.3, 1.0)
	ring.position = Vector2(0.0, -80.0)
	ring.z_index = 100
	npc_node.add_child(ring)

# ============================================================
# ФИЧА 7: Chat Sparkles — искры при proximity chat между NPC
# ============================================================
func show_chat_sparkles(npc_a: Node2D, npc_b: Node2D, is_positive: bool):
	if not is_instance_valid(npc_a) or not is_instance_valid(npc_b):
		return
	var sparkle_script = load("res://Scripts/chat_sparkle_effect.gd")
	if not sparkle_script:
		return
	var sparkle = Node2D.new()
	sparkle.set_script(sparkle_script)
	sparkle.process_mode = Node.PROCESS_MODE_ALWAYS
	sparkle.z_index = 99
	# Добавляем в мировую сцену, а не в NPC, чтобы координаты не плыли
	var world = npc_a.get_tree().current_scene
	if world:
		world.add_child(sparkle)
	else:
		npc_a.add_child(sparkle)
	var color = Color(0.2, 0.9, 0.3, 1.0) if is_positive else Color(1.0, 0.3, 0.3, 1.0)
	var from = npc_a.global_position + Vector2(0.0, -60.0)
	var to = npc_b.global_position + Vector2(0.0, -60.0)
	sparkle.setup(from, to, color)
