extends Control

# === ЭКРАН КАСТОМИЗАЦИИ ИГРОКА ===
# Строит UI полностью кодом (аналогично loading_screen.gd).

# Локальные индексы состояния
var _gender_idx: int = 0          # 0=male, 1=female
var _body_idx: int = 0            # индекс в массиве вариантов для текущего пола
var _skin_idx: int = 0            # индекс в VisualGlobals.ALL_SKIN_COLORS
var _hair_idx: int = 0            # -1 = без волос, 0..N-1 = индекс в массиве
var _hair_color_idx: int = 0      # индекс в VisualGlobals.HAIR_PALETTE

var _preview_player = null        # инстанс player.tscn внутри SubViewport
var _sub_viewport: SubViewport = null

# Ссылки на label'ы каруселей для обновления
var _gender_label: Label = null
var _body_label: Label = null
var _skin_label: Label = null
var _hair_label: Label = null
var _hair_color_label: Label = null
var _hair_color_row: HBoxContainer = null

# Цветные превью для кожи и волос
var _skin_color_rect: ColorRect = null
var _hair_color_rect: ColorRect = null


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_sync_indices_from_pm_data()
	_apply_to_preview()
	_update_all_labels()


func _build_ui():
	# Белый фон
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(1, 1, 1, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Центральный контейнер
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 40)
	center.add_child(hbox)

	# === Левая колонка: превью игрока ===
	var viewport_container = SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(300, 500)
	viewport_container.stretch = true
	hbox.add_child(viewport_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(300, 500)
	_sub_viewport.transparent_bg = true
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(_sub_viewport)

	var preview_root = Node2D.new()
	preview_root.name = "PreviewRoot"
	_sub_viewport.add_child(preview_root)

	# Инстанцируем player.tscn для превью
	var player_scene = load("res://Scenes/player.tscn")
	if player_scene:
		_preview_player = player_scene.instantiate()
		_preview_player.position = Vector2(150, 350)
		# Отключаем процесс и камеру чтобы превью было статичным
		_preview_player.set_process(false)
		_preview_player.set_physics_process(false)
		_preview_player.set_process_input(false)
		preview_root.add_child(_preview_player)
		# Отключаем камеру превью-игрока
		var cam = _preview_player.get_node_or_null("Camera2D")
		if cam:
			cam.enabled = false

	# === Правая колонка: настройки ===
	var right_col = VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 16)
	right_col.custom_minimum_size = Vector2(400, 0)
	hbox.add_child(right_col)

	# Заголовок
	var title = Label.new()
	title.text = tr("UI_CUSTOM_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.17, 0.31, 0.57, 1))
	right_col.add_child(title)

	# Карусели
	_gender_label = _add_carousel(right_col, "UI_CUSTOM_GENDER", _on_gender_prev, _on_gender_next)
	_body_label = _add_carousel(right_col, "UI_CUSTOM_BODY", _on_body_prev, _on_body_next)
	var skin_row = _add_carousel_with_color(right_col, "UI_CUSTOM_SKIN", _on_skin_prev, _on_skin_next)
	_skin_label = skin_row[0]
	_skin_color_rect = skin_row[1]
	var hair_row = _add_carousel(right_col, "UI_CUSTOM_HAIR", _on_hair_prev, _on_hair_next)
	_hair_label = hair_row
	_hair_color_row = HBoxContainer.new()
	_hair_color_row.add_theme_constant_override("separation", 8)
	right_col.add_child(_hair_color_row)
	var hc_row = _add_carousel_with_color_in(_hair_color_row, "UI_CUSTOM_HAIR_COLOR", _on_hair_color_prev, _on_hair_color_next)
	_hair_color_label = hc_row[0]
	_hair_color_rect = hc_row[1]

	# Разделитель
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	right_col.add_child(spacer)

	# Кнопка "Начать работу"
	var finish_btn = Button.new()
	finish_btn.text = tr("UI_CUSTOM_FINISH")
	finish_btn.custom_minimum_size = Vector2(200, 50)
	finish_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	finish_btn.pressed.connect(_on_finish_pressed)
	right_col.add_child(finish_btn)


func _add_carousel(parent: Control, category_key: String, prev_cb: Callable, next_cb: Callable) -> Label:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var cat_label = Label.new()
	cat_label.text = tr(category_key)
	cat_label.custom_minimum_size = Vector2(140, 0)
	cat_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	row.add_child(cat_label)

	var prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(40, 40)
	prev_btn.pressed.connect(prev_cb)
	row.add_child(prev_btn)

	var value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(160, 0)
	value_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	row.add_child(value_label)

	var next_btn = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(40, 40)
	next_btn.pressed.connect(next_cb)
	row.add_child(next_btn)

	return value_label


func _add_carousel_with_color(parent: Control, category_key: String, prev_cb: Callable, next_cb: Callable) -> Array:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var cat_label = Label.new()
	cat_label.text = tr(category_key)
	cat_label.custom_minimum_size = Vector2(140, 0)
	cat_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	row.add_child(cat_label)

	var prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(40, 40)
	prev_btn.pressed.connect(prev_cb)
	row.add_child(prev_btn)

	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(30, 30)
	row.add_child(color_rect)

	var value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(120, 0)
	value_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	row.add_child(value_label)

	var next_btn = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(40, 40)
	next_btn.pressed.connect(next_cb)
	row.add_child(next_btn)

	return [value_label, color_rect]


func _add_carousel_with_color_in(parent: Control, category_key: String, prev_cb: Callable, next_cb: Callable) -> Array:
	var cat_label = Label.new()
	cat_label.text = tr(category_key)
	cat_label.custom_minimum_size = Vector2(140, 0)
	cat_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	parent.add_child(cat_label)

	var prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(40, 40)
	prev_btn.pressed.connect(prev_cb)
	parent.add_child(prev_btn)

	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(30, 30)
	parent.add_child(color_rect)

	var value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(120, 0)
	value_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	parent.add_child(value_label)

	var next_btn = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(40, 40)
	next_btn.pressed.connect(next_cb)
	parent.add_child(next_btn)

	return [value_label, color_rect]


# === НАВИГАЦИЯ КАРУСЕЛЕЙ ===

func _on_gender_prev():
	_gender_idx = (_gender_idx - 1 + 2) % 2
	_body_idx = 0
	_hair_idx = 0
	_apply_to_preview()
	_update_all_labels()

func _on_gender_next():
	_gender_idx = (_gender_idx + 1) % 2
	_body_idx = 0
	_hair_idx = 0
	_apply_to_preview()
	_update_all_labels()

func _on_body_prev():
	var options = _get_body_options()
	_body_idx = (_body_idx - 1 + options.size()) % options.size()
	_apply_to_preview()
	_update_all_labels()

func _on_body_next():
	var options = _get_body_options()
	_body_idx = (_body_idx + 1) % options.size()
	_apply_to_preview()
	_update_all_labels()

func _on_skin_prev():
	var count = VisualGlobals.ALL_SKIN_COLORS.size()
	_skin_idx = (_skin_idx - 1 + count) % count
	_apply_to_preview()
	_update_all_labels()

func _on_skin_next():
	var count = VisualGlobals.ALL_SKIN_COLORS.size()
	_skin_idx = (_skin_idx + 1) % count
	_apply_to_preview()
	_update_all_labels()

func _on_hair_prev():
	var hair_paths = _get_hair_paths()
	# Допустимые значения: -1, 0, 1, ..., size-1
	var total = hair_paths.size() + 1  # +1 для варианта "без волос"
	var mapped = _hair_idx + 1  # -1 -> 0, 0 -> 1, ...
	mapped = (mapped - 1 + total) % total
	_hair_idx = mapped - 1
	_apply_to_preview()
	_update_all_labels()

func _on_hair_next():
	var hair_paths = _get_hair_paths()
	var total = hair_paths.size() + 1
	var mapped = _hair_idx + 1
	mapped = (mapped + 1) % total
	_hair_idx = mapped - 1
	_apply_to_preview()
	_update_all_labels()

func _on_hair_color_prev():
	var count = VisualGlobals.HAIR_PALETTE.size()
	_hair_color_idx = (_hair_color_idx - 1 + count) % count
	_apply_to_preview()
	_update_all_labels()

func _on_hair_color_next():
	var count = VisualGlobals.HAIR_PALETTE.size()
	_hair_color_idx = (_hair_color_idx + 1) % count
	_apply_to_preview()
	_update_all_labels()


# === ХЕЛПЕРЫ ===

func _get_body_options() -> Array[String]:
	if _gender_idx == 0:
		return ["default", "man_fat", "man_fit", "man_skinny"] as Array[String]
	else:
		return ["default", "woman_fat", "woman_fit", "woman_skinny"] as Array[String]

func _get_hair_paths() -> Array[String]:
	if _gender_idx == 0:
		return VisualGlobals.MALE_HAIR_PATHS
	else:
		return VisualGlobals.FEMALE_HAIR_PATHS

func _get_current_body_type() -> String:
	var options = _get_body_options()
	return options[_body_idx]

func _get_body_display_text() -> String:
	var body_type = _get_current_body_type()
	match body_type:
		"default":
			return "Default"
		"man_fat", "woman_fat":
			return tr("UI_CUSTOM_BODY_FAT")
		"man_fit", "woman_fit":
			return tr("UI_CUSTOM_BODY_FIT")
		"man_skinny", "woman_skinny":
			return tr("UI_CUSTOM_BODY_SKINNY")
	return body_type

func _get_hair_display_text() -> String:
	if _hair_idx < 0:
		return tr("UI_CUSTOM_HAIR_NONE")
	return tr("UI_CUSTOM_HAIR") + " %d" % (_hair_idx + 1)


# === ОБНОВЛЕНИЕ МЕТОК ===

func _update_all_labels():
	if _gender_label:
		_gender_label.text = tr("UI_CUSTOM_GENDER_MALE") if _gender_idx == 0 else tr("UI_CUSTOM_GENDER_FEMALE")
	if _body_label:
		_body_label.text = _get_body_display_text()
	if _skin_label:
		var color = VisualGlobals.ALL_SKIN_COLORS[_skin_idx]
		_skin_label.text = "#" + color.to_html(false)
		if _skin_color_rect:
			_skin_color_rect.color = color
	if _hair_label:
		_hair_label.text = _get_hair_display_text()
	if _hair_color_label:
		var hc = VisualGlobals.HAIR_PALETTE[_hair_color_idx]
		_hair_color_label.text = "#" + hc.to_html(false)
		if _hair_color_rect:
			_hair_color_rect.color = hc
	# Скрыть/показать цвет волос если нет волос
	if _hair_color_row:
		_hair_color_row.visible = (_hair_idx >= 0)


# === ПРЕВЬЮ ===

func _apply_to_preview():
	PMData.appearance_gender = "male" if _gender_idx == 0 else "female"
	PMData.appearance_body_type = _get_current_body_type()
	PMData.appearance_skin_color = VisualGlobals.ALL_SKIN_COLORS[_skin_idx]
	PMData.appearance_hair_type = _hair_idx
	PMData.appearance_hair_color = VisualGlobals.HAIR_PALETTE[_hair_color_idx]
	if is_instance_valid(_preview_player) and _preview_player.has_method("update_visuals"):
		_preview_player.update_visuals()


func _sync_indices_from_pm_data():
	# Пол
	_gender_idx = 0 if PMData.appearance_gender == "male" else 1

	# Телосложение
	var body_options = _get_body_options()
	var bi = body_options.find(PMData.appearance_body_type)
	_body_idx = bi if bi >= 0 else 0

	# Цвет кожи
	var skin_match = -1
	for i in range(VisualGlobals.ALL_SKIN_COLORS.size()):
		if VisualGlobals.ALL_SKIN_COLORS[i].is_equal_approx(PMData.appearance_skin_color):
			skin_match = i
			break
	_skin_idx = skin_match if skin_match >= 0 else 0

	# Тип причёски
	_hair_idx = PMData.appearance_hair_type

	# Цвет волос
	var hc_match = -1
	for i in range(VisualGlobals.HAIR_PALETTE.size()):
		if VisualGlobals.HAIR_PALETTE[i].is_equal_approx(PMData.appearance_hair_color):
			hc_match = i
			break
	_hair_color_idx = hc_match if hc_match >= 0 else 0


# === ЗАВЕРШЕНИЕ ===

func _on_finish_pressed():
	# Данные уже в PMData (из _apply_to_preview)
	GameState.appearance_configured = true
	LoadingScreen.target_scene_path = "res://Scenes/office.tscn"
	get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")
