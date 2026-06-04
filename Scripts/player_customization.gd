extends Control

# === ЭКРАН КАСТОМИЗАЦИИ ИГРОКА ===
# Строит UI полностью кодом (аналогично loading_screen.gd).

# Локальные индексы состояния
var _gender_idx: int = 0          # 0=male, 1=female
var _body_idx: int = 0            # индекс в массиве вариантов для текущего пола
var _skin_idx: int = 0            # индекс в VisualGlobals.ALL_SKIN_COLORS
var _hair_idx: int = 0            # -1 = без волос, 0..N-1 = индекс в массиве
var _hair_color_idx: int = 0      # индекс в VisualGlobals.HAIR_PALETTE
var _clothing_color_idx: int = 5  # индекс в VisualGlobals.CLOTHING_PALETTE (default #A0C4FF)

var _preview_player = null        # инстанс player.tscn внутри SubViewport
var _sub_viewport: SubViewport = null

# Ссылки на label'ы каруселей для обновления
var _gender_label: Label = null
var _body_label: Label = null
var _skin_label: Label = null
var _hair_label: Label = null
var _hair_color_label: Label = null
var _hair_color_row: HBoxContainer = null
var _clothing_color_label: Label = null
var _clothing_color_rect: ColorRect = null

# Цветные превью для кожи и волос
var _skin_color_rect: ColorRect = null
var _hair_color_rect: ColorRect = null

# Панель трейтов
var _trait_buttons: Dictionary = {}   # trait_id -> Button/Panel
var _points_label: Label = null
var _trait_tooltip: PanelContainer = null

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_GREEN = Color(0.29, 0.69, 0.31, 1)
const COLOR_RED = Color(0.8, 0.3, 0.2, 1)


func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_sync_indices_from_pm_data()
	_apply_to_preview()
	_update_all_labels()
	_update_points_label()
	_refresh_all_trait_buttons()


func _build_ui():
	# Белый фон
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(1, 1, 1, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Корневой HBoxContainer на весь экран
	var root_hbox = HBoxContainer.new()
	root_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_hbox.add_theme_constant_override("separation", 0)
	add_child(root_hbox)

	# === Левая панель (2/3 экрана) ===
	var left_panel = MarginContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 2.0
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_hbox.add_child(left_panel)

	# VBoxContainer внутри — центрирует содержимое по вертикали
	var left_vbox = VBoxContainer.new()
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_theme_constant_override("separation", 16)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_vbox)

	# HBoxContainer для превью + карусели (центрируется по горизонтали)
	var content_hbox = HBoxContainer.new()
	content_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_hbox.add_theme_constant_override("separation", 24)
	left_vbox.add_child(content_hbox)

	# SubViewportContainer (превью персонажа)
	var viewport_container = SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(220, 400)
	viewport_container.stretch = true
	content_hbox.add_child(viewport_container)

	_sub_viewport = SubViewport.new()
	_sub_viewport.size = Vector2i(220, 400)
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
		_preview_player.position = Vector2(110, 280)
		# Отключаем процесс и камеру чтобы превью было статичным
		_preview_player.set_process(false)
		_preview_player.set_physics_process(false)
		_preview_player.set_process_input(false)
		preview_root.add_child(_preview_player)
		# Отключаем камеру превью-игрока
		var cam = _preview_player.get_node_or_null("Camera2D")
		if cam:
			cam.enabled = false

	# VBoxContainer с каруселями (рядом с превью)
	var carousels_vbox = VBoxContainer.new()
	carousels_vbox.add_theme_constant_override("separation", 16)
	carousels_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_hbox.add_child(carousels_vbox)

	# Карусели
	_gender_label = _add_carousel(carousels_vbox, "UI_CUSTOM_GENDER", _on_gender_prev, _on_gender_next)
	_body_label = _add_carousel(carousels_vbox, "UI_CUSTOM_BODY", _on_body_prev, _on_body_next)
	var skin_row = _add_carousel_with_color(carousels_vbox, "UI_CUSTOM_SKIN", _on_skin_prev, _on_skin_next)
	_skin_label = skin_row[0]
	_skin_color_rect = skin_row[1]
	var clothing_row = _add_carousel_with_color(carousels_vbox, "UI_CUSTOM_CLOTHING", _on_clothing_prev, _on_clothing_next)
	_clothing_color_label = clothing_row[0]
	_clothing_color_rect = clothing_row[1]
	var hair_row = _add_carousel(carousels_vbox, "UI_CUSTOM_HAIR", _on_hair_prev, _on_hair_next)
	_hair_label = hair_row
	_hair_color_row = HBoxContainer.new()
	_hair_color_row.add_theme_constant_override("separation", 8)
	carousels_vbox.add_child(_hair_color_row)
	var hc_row = _add_carousel_with_color_in(_hair_color_row, "UI_CUSTOM_HAIR_COLOR", _on_hair_color_prev, _on_hair_color_next)
	_hair_color_label = hc_row[0]
	_hair_color_rect = hc_row[1]

	# Кнопка Continue внизу левой панели, по центру
	var continue_hbox = HBoxContainer.new()
	continue_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_child(continue_hbox)

	var finish_btn = Button.new()
	finish_btn.text = tr("UI_CUSTOM_FINISH")
	finish_btn.custom_minimum_size = Vector2(280, 60)
	finish_btn.focus_mode = Control.FOCUS_NONE
	finish_btn.pressed.connect(_on_finish_pressed)
	_apply_styled_button(finish_btn)
	continue_hbox.add_child(finish_btn)

	# === Правая панель (1/3 экрана) — белый фон ===
	var right_panel = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var right_style = StyleBoxFlat.new()
	right_style.bg_color = Color(1, 1, 1, 1)  # белый фон
	right_style.border_width_left = 0
	right_style.border_width_top = 0
	right_style.border_width_right = 0
	right_style.border_width_bottom = 0
	right_style.content_margin_top = 24
	right_style.content_margin_bottom = 24
	right_style.content_margin_left = 16
	right_style.content_margin_right = 24
	right_panel.add_theme_stylebox_override("panel", right_style)
	root_hbox.add_child(right_panel)

	var right_vbox = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_vbox)

	_build_traits_panel(right_vbox)


# Структура каждой строки карусели (с и без цвета):
#   [cat_label 140px] [8] [< btn 40px] [8] [color_rect/placeholder 30px] [8] [value_label 120px] [8] [> btn 40px]
# Плейсхолдер в строках без цвета обеспечивает одинаковое смещение кнопок < > по вертикали.

func _add_carousel(parent: Control, category_key: String, prev_cb: Callable, next_cb: Callable) -> Label:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var cat_label = Label.new()
	cat_label.text = tr(category_key)
	cat_label.custom_minimum_size = Vector2(140, 0)
	cat_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cat_label.clip_text = true
	cat_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	row.add_child(cat_label)

	var prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(40, 40)
	prev_btn.focus_mode = Control.FOCUS_NONE
	prev_btn.pressed.connect(prev_cb)
	_apply_arrow_style(prev_btn)
	row.add_child(prev_btn)

	# Плейсхолдер 30px вместо ColorRect — выравнивает кнопки с цветными строками
	var placeholder = Control.new()
	placeholder.custom_minimum_size = Vector2(30, 0)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(placeholder)

	var value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(120, 0)
	value_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	row.add_child(value_label)

	var next_btn = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(40, 40)
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(next_cb)
	_apply_arrow_style(next_btn)
	row.add_child(next_btn)

	return value_label


func _add_carousel_with_color(parent: Control, category_key: String, prev_cb: Callable, next_cb: Callable) -> Array:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var cat_label = Label.new()
	cat_label.text = tr(category_key)
	cat_label.custom_minimum_size = Vector2(140, 0)
	cat_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cat_label.clip_text = true
	cat_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	row.add_child(cat_label)

	var prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(40, 40)
	prev_btn.focus_mode = Control.FOCUS_NONE
	prev_btn.pressed.connect(prev_cb)
	_apply_arrow_style(prev_btn)
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
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(next_cb)
	_apply_arrow_style(next_btn)
	row.add_child(next_btn)

	return [value_label, color_rect]


func _add_carousel_with_color_in(parent: Control, category_key: String, prev_cb: Callable, next_cb: Callable) -> Array:
	var cat_label = Label.new()
	cat_label.text = tr(category_key)
	cat_label.custom_minimum_size = Vector2(140, 0)
	cat_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cat_label.clip_text = true
	cat_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	parent.add_child(cat_label)

	var prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(40, 40)
	prev_btn.focus_mode = Control.FOCUS_NONE
	prev_btn.pressed.connect(prev_cb)
	_apply_arrow_style(prev_btn)
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
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.pressed.connect(next_cb)
	_apply_arrow_style(next_btn)
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

func _on_clothing_prev():
	var count = VisualGlobals.CLOTHING_PALETTE.size()
	_clothing_color_idx = (_clothing_color_idx - 1 + count) % count
	_apply_to_preview()
	_update_all_labels()

func _on_clothing_next():
	var count = VisualGlobals.CLOTHING_PALETTE.size()
	_clothing_color_idx = (_clothing_color_idx + 1) % count
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
	if _clothing_color_label:
		var cc = VisualGlobals.CLOTHING_PALETTE[_clothing_color_idx]
		_clothing_color_label.text = "#" + cc.to_html(false)
		if _clothing_color_rect:
			_clothing_color_rect.color = cc
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
	PMData.appearance_clothing_color = VisualGlobals.CLOTHING_PALETTE[_clothing_color_idx]
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

	# Цвет одежды
	var cc_match = -1
	for i in range(VisualGlobals.CLOTHING_PALETTE.size()):
		if VisualGlobals.CLOTHING_PALETTE[i].is_equal_approx(PMData.appearance_clothing_color):
			cc_match = i
			break
	_clothing_color_idx = cc_match if cc_match >= 0 else 5

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
	# Бонусные очки навыков от обучающих трейтов — применяется ровно один раз при старте
	if PMData.has_pm_trait("pm_well_trained"):
		PMData.skill_points += 3
	elif PMData.has_pm_trait("pm_trained"):
		PMData.skill_points += 1
	# Данные уже в PMData (из _apply_to_preview)
	GameState.appearance_configured = true
	LoadingScreen.target_scene_path = "res://Scenes/office.tscn"
	get_tree().change_scene_to_file("res://Scenes/loading_screen.tscn")


# === СТИЛИ КНОПОК ===

func _apply_styled_button(btn: Button):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = COLOR_WHITE
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = COLOR_BLUE
	style_normal.corner_radius_top_left = 20
	style_normal.corner_radius_top_right = 20
	style_normal.corner_radius_bottom_right = 20
	style_normal.corner_radius_bottom_left = 20

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = COLOR_BLUE
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = COLOR_BLUE
	style_hover.corner_radius_top_left = 20
	style_hover.corner_radius_top_right = 20
	style_hover.corner_radius_bottom_right = 20
	style_hover.corner_radius_bottom_left = 20

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_color_override("font_color", COLOR_BLUE)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)


func _apply_arrow_style(btn: Button):
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = COLOR_WHITE
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = COLOR_BLUE
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_right = 10
	style_normal.corner_radius_bottom_left = 10

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = COLOR_BLUE
	style_hover.border_width_left = 2
	style_hover.border_width_top = 2
	style_hover.border_width_right = 2
	style_hover.border_width_bottom = 2
	style_hover.border_color = COLOR_BLUE
	style_hover.corner_radius_top_left = 10
	style_hover.corner_radius_top_right = 10
	style_hover.corner_radius_bottom_right = 10
	style_hover.corner_radius_bottom_left = 10

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_color_override("font_color", COLOR_BLUE)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)


# === ПАНЕЛЬ ТРЕЙТОВ ===

func _build_traits_panel(parent: VBoxContainer):
	# Заголовок (одинаковый размер с "Personalize Profile")
	var title = Label.new()
	title.text = tr("PM_TRAITS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.17, 0.31, 0.57, 1))
	parent.add_child(title)

	# Счётчик очков — крупный и зелёный (заметный)
	_points_label = Label.new()
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_label.add_theme_font_size_override("font_size", 24)
	_points_label.add_theme_color_override("font_color", COLOR_GREEN)
	parent.add_child(_points_label)

	# Разделитель
	var sep1 = HSeparator.new()
	parent.add_child(sep1)

	var scroll_wrap = MarginContainer.new()
	scroll_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_wrap.add_theme_constant_override("margin_right", 4)
	parent.add_child(scroll_wrap)

	var traits_scroll = ScrollContainer.new()
	traits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	traits_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traits_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_wrap.add_child(traits_scroll)

	var traits_vbox = VBoxContainer.new()
	traits_vbox.add_theme_constant_override("separation", 10)
	traits_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traits_scroll.add_child(traits_vbox)

	# Заголовок "Положительные" (подзаголовок — крупнее)
	var pos_header = Label.new()
	pos_header.text = tr("PM_TRAITS_POSITIVE_HEADER")
	pos_header.add_theme_font_size_override("font_size", 20)
	pos_header.add_theme_color_override("font_color", COLOR_GREEN)
	traits_vbox.add_child(pos_header)

	# Положительные трейты (cost > 0)
	for def in PMData.PM_TRAIT_DEFINITIONS:
		if def.positive:
			_add_trait_button(traits_vbox, def)

	# Разделитель
	var sep2 = HSeparator.new()
	traits_vbox.add_child(sep2)

	# Заголовок "Недостатки" (подзаголовок — крупнее)
	var neg_header = Label.new()
	neg_header.text = tr("PM_TRAITS_NEGATIVE_HEADER")
	neg_header.add_theme_font_size_override("font_size", 20)
	neg_header.add_theme_color_override("font_color", COLOR_RED)
	traits_vbox.add_child(neg_header)

	# Отрицательные трейты (cost < 0)
	for def in PMData.PM_TRAIT_DEFINITIONS:
		if not def.positive:
			_add_trait_button(traits_vbox, def)


func _add_trait_button(parent: Control, def: Dictionary):
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 48)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_apply_trait_panel_style(panel, false, false, def.positive)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(hbox)

	# Чекбокс (Label с символом) — цвет по знаку трейта
	var base_check_color = COLOR_GREEN if def.positive else COLOR_RED
	var check_lbl = Label.new()
	check_lbl.text = "☐"
	check_lbl.add_theme_font_size_override("font_size", 18)
	check_lbl.add_theme_color_override("font_color", base_check_color)
	check_lbl.custom_minimum_size = Vector2(24, 0)
	check_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(check_lbl)

	# Название
	var name_lbl = Label.new()
	name_lbl.text = tr(def.name_key)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1))
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_lbl)

	# Стоимость
	var cost_lbl = Label.new()
	var cost_sign = "+" if def.cost > 0 else ""
	cost_lbl.text = tr("PM_TRAITS_COST") % [cost_sign + str(def.cost)]
	cost_lbl.add_theme_font_size_override("font_size", 15)
	var cost_color = COLOR_GREEN if def.cost > 0 else COLOR_RED
	cost_lbl.add_theme_color_override("font_color", cost_color)
	cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(cost_lbl)

	# Обработка клика
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			PMData.toggle_pm_trait(def.id)
			_refresh_all_trait_buttons()
			_update_points_label()
	)

	# Тултип при наведении
	panel.mouse_entered.connect(func():
		_show_trait_tooltip(panel, def)
	)
	panel.mouse_exited.connect(func():
		_hide_trait_tooltip()
	)

	_trait_buttons[def.id] = {"panel": panel, "check": check_lbl, "name": name_lbl, "positive": def.positive}
	parent.add_child(panel)


func _apply_trait_panel_style(panel: PanelContainer, selected: bool, disabled: bool, positive: bool):
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6

	# Цвета по знаку трейта: зелёный для положительных, красный для отрицательных
	var accent = COLOR_GREEN if positive else COLOR_RED

	if disabled:
		style.bg_color = Color(0.92, 0.92, 0.92, 1)
		style.border_color = Color(0.75, 0.75, 0.75, 1)
	elif selected:
		style.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
		style.border_color = accent
	else:
		style.bg_color = Color(1, 1, 1, 1)
		style.border_color = Color(accent.r, accent.g, accent.b, 0.5)

	panel.add_theme_stylebox_override("panel", style)


func _refresh_all_trait_buttons():
	for trait_id in _trait_buttons:
		var data = _trait_buttons[trait_id]
		var panel: PanelContainer = data.panel
		var check_lbl: Label = data.check
		var name_lbl: Label = data.name
		var positive: bool = data.positive

		var is_selected = PMData.has_pm_trait(trait_id)
		var can_take = PMData.can_take_trait(trait_id)
		var is_disabled = not is_selected and not can_take

		_apply_trait_panel_style(panel, is_selected, is_disabled, positive)
		check_lbl.text = "☑" if is_selected else "☐"
		var accent = COLOR_GREEN if positive else COLOR_RED
		check_lbl.add_theme_color_override("font_color",
			accent if (is_selected or not is_disabled) else Color(0.5, 0.5, 0.5, 1))
		name_lbl.add_theme_color_override("font_color",
			Color(0.1, 0.1, 0.1, 1) if not is_disabled else Color(0.6, 0.6, 0.6, 1))


func _update_points_label():
	if _points_label:
		var free = PMData.get_free_trait_points()
		var total = PMData.PM_TRAIT_STARTING_POINTS
		_points_label.text = tr("PM_TRAITS_POINTS") % [free, total]
		# Зелёный когда есть очки, красный когда нет
		var col = COLOR_GREEN if free > 0 else COLOR_RED
		_points_label.add_theme_color_override("font_color", col)


func _show_trait_tooltip(anchor: Control, def: Dictionary):
	_hide_trait_tooltip()

	var tp = PanelContainer.new()
	tp.z_index = 200
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.17, 0.31, 0.57, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 4
	tp.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	tp.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = tr(def.name_key)
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color(0.17, 0.31, 0.57, 1))
	vbox.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = tr(def.desc_key)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3, 1))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(220, 0)
	vbox.add_child(desc_lbl)

	add_child(tp)
	await get_tree().process_frame
	# Позиционирование: справа от панели, или слева если не помещается
	var vp_size = get_viewport_rect().size
	var anchor_pos = anchor.get_global_rect()
	var tp_pos = Vector2(anchor_pos.position.x + anchor_pos.size.x + 8, anchor_pos.position.y)
	if tp_pos.x + tp.size.x > vp_size.x:
		tp_pos.x = anchor_pos.position.x - tp.size.x - 8
	if tp_pos.y + tp.size.y > vp_size.y:
		tp_pos.y = anchor_pos.position.y - tp.size.y
		if tp_pos.y < 0:
			tp_pos.y = 0
	tp.global_position = tp_pos

	_trait_tooltip = tp


func _hide_trait_tooltip():
	if _trait_tooltip and is_instance_valid(_trait_tooltip):
		_trait_tooltip.queue_free()
	_trait_tooltip = null
