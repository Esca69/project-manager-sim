extends Control

# === ЭКРАН ЗАГРУЗКИ ===
# Показывается при переходе в office.tscn после старта или загрузки игры.
# Прогревает шрифт NotoColorEmoji и асинхронно загружает целевую сцену.

const COLOR_PRIMARY = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_TEXT_MUTED = Color(0.45, 0.45, 0.55, 1)
const SPINNER_FRAMES = ["◐", "◓", "◑", "◒"]
const TARGET_SCENE = "res://Scenes/office.tscn"

# Все emoji из игры для прогрева шрифта
const WARMUP_EMOJIS = "📋👥📊⚡🛡✅🧠🔍💰🏢💼☕📈🤝⏰📝🍽️🎯⬆️❌⏳▶📂🆕⚙📅💻🖥️📁🕐➕🗑🏎️⭐🔔💬📌🎮🔒🏆🤖👔📉🏗️🔥💎🚀🧩💡📦🎓🔧⚠️🪙🎉🩹🧪🕹️🌍📡🛒👨‍💼👩‍💻🧑‍🔧👷💀🫡😊😃😠😢😴🤔🥳😎🫣😐😤😈🫠😵😡🔴🟢🟡⚪🟣🔵🏠🪑💺🖨️📱🔑🔗📎✏️🗂️📤📥🏆📐🎯🛡⚔️🧲🎁🍀🌿🌸🌧️☀️🌙❄️🌊🌈"

var _spinner_label: Label
var _loading_label: Label
var _stage_label: Label
var _progress_bar: ProgressBar
var _spinner_timer: float = 0.0
var _spinner_index: int = 0
var _loading_started: bool = false


func _tr_or(key: String, fallback: String) -> String:
	var result = tr(key)
	return result if result != key else fallback


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	call_deferred("_start_warmup")


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

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# Emoji иконка
	var emoji_lbl = Label.new()
	emoji_lbl.text = "⏳"
	emoji_lbl.add_theme_font_size_override("font_size", 52)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(emoji_lbl)

	# Текст "Загрузка..."
	_loading_label = Label.new()
	_loading_label.text = _tr_or("MENU_LOADING", "Загрузка...")
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 28)
	_loading_label.add_theme_color_override("font_color", COLOR_PRIMARY)
	if UITheme:
		UITheme.apply_font(_loading_label, "semibold")
	vbox.add_child(_loading_label)

	# Спиннер
	_spinner_label = Label.new()
	_spinner_label.text = SPINNER_FRAMES[0]
	_spinner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spinner_label.add_theme_font_size_override("font_size", 40)
	_spinner_label.add_theme_color_override("font_color", COLOR_PRIMARY)
	vbox.add_child(_spinner_label)

	# Прогресс-бар
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(300, 8)
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.9, 0.9, 0.93, 1)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_right = 4
	bg_style.corner_radius_bottom_left = 4
	_progress_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = COLOR_PRIMARY
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_right = 4
	fill_style.corner_radius_bottom_left = 4
	_progress_bar.add_theme_stylebox_override("fill", fill_style)

	vbox.add_child(_progress_bar)

	# Текст этапа
	_stage_label = Label.new()
	_stage_label.text = _tr_or("LOADING_STAGE_RESOURCES", "Загрузка ресурсов...")
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.add_theme_font_size_override("font_size", 14)
	_stage_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	if UITheme:
		UITheme.apply_font(_stage_label, "regular")
	vbox.add_child(_stage_label)


func _start_warmup():
	# Прогреваем emoji шрифт — используем modulate.a = 0.0 (НЕ visible = false!)
	var warmup = Label.new()
	warmup.modulate.a = 0.0
	warmup.text = WARMUP_EMOJIS
	warmup.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(warmup, "regular")
	add_child(warmup)

	_progress_bar.value = 20.0

	# Ждём 2 кадра рендера — первый для layout, второй для кеширования глифов
	await get_tree().process_frame
	await get_tree().process_frame

	warmup.queue_free()
	_progress_bar.value = 40.0

	# Обновляем этап
	_stage_label.text = _tr_or("LOADING_STAGE_PREPARING", "Подготовка интерфейса...")

	# Запускаем асинхронную загрузку сцены
	ResourceLoader.load_threaded_request(TARGET_SCENE)
	_loading_started = true


func _process(delta: float):
	# Анимируем спиннер
	if _spinner_label:
		_spinner_timer += delta
		if _spinner_timer >= 0.15:
			_spinner_timer = 0.0
			_spinner_index = (_spinner_index + 1) % SPINNER_FRAMES.size()
			_spinner_label.text = SPINNER_FRAMES[_spinner_index]

	# Проверяем статус загрузки
	if not _loading_started:
		return

	var progress: Array = []
	var status = ResourceLoader.load_threaded_get_status(TARGET_SCENE, progress)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var scene_progress = progress[0] if progress.size() > 0 else 0.0
		_progress_bar.value = 40.0 + scene_progress * 60.0
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		_progress_bar.value = 100.0
		_stage_label.text = _tr_or("LOADING_STAGE_DONE", "Почти готово...")
		_loading_started = false
		var packed = ResourceLoader.load_threaded_get(TARGET_SCENE)
		if packed:
			get_tree().change_scene_to_packed(packed)
		else:
			get_tree().change_scene_to_file(TARGET_SCENE)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("[LoadingScreen] Threaded load failed, falling back to sync")
		_loading_started = false
		get_tree().change_scene_to_file(TARGET_SCENE)
