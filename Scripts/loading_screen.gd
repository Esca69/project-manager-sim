extends Control
class_name LoadingScreen

# === ЭКРАН ЗАГРУЗКИ ===
# Показывается при переходе в office.tscn после старта или загрузки игры.
# Прогревает шрифт NotoColorEmoji и асинхронно загружает целевую сцену.

const COLOR_PRIMARY = Color(0.17254902, 0.30980393, 0.5686275, 1)
const SPINNER_FRAMES = ["◐", "◓", "◑", "◒"]

# Целевая сцена для загрузки (устанавливается перед переходом сюда)
static var target_scene_path: String = "res://Scenes/office.tscn"

var _spinner_label: Label
var _loading_label: Label
var _spinner_timer: float = 0.0
var _spinner_index: int = 0
var _font_warmed: bool = false
var _loading_started: bool = false

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	# Прогреваем шрифт emoji в следующем кадре, потом запускаем загрузку сцены
	call_deferred("_warm_font_and_start_loading")

func _build_ui():
	# Тёмный фон
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.10, 0.14, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Центральный контейнер
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	# Надпись "Загрузка..."
	_loading_label = Label.new()
	_loading_label.text = tr("MENU_LOADING")
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
	if UITheme:
		UITheme.apply_font(_spinner_label, "regular")
	vbox.add_child(_spinner_label)

func _warm_font_and_start_loading():
	# Создаём невидимый лейбл со всеми emoji из игры, чтобы закешировать глифы
	var warmup = Label.new()
	warmup.visible = false
	warmup.text = "📋👥📊⚡🛡✅🧠🔍💰🏢💼☕📈🤝⏰📝🍽️🎯⬆️❌⏳▶📂🆕⚙📅💻🖥️📁🕐➕🗑🏎️⭐🔔💬📌🎮🔒🏆🤖👔📉🏗️🔧🆓🚀"
	warmup.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(warmup, "regular")
	add_child(warmup)

	# Ждём один кадр рендера для кеширования глифов
	await get_tree().process_frame

	warmup.queue_free()
	_font_warmed = true

	# Запускаем асинхронную загрузку целевой сцены
	ResourceLoader.load_threaded_request(target_scene_path)
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

	var status = ResourceLoader.load_threaded_get_status(target_scene_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var packed = ResourceLoader.load_threaded_get(target_scene_path)
		if packed:
			get_tree().change_scene_to_packed(packed)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		# Запасной вариант — синхронная загрузка
		push_error("[LoadingScreen] Threaded load failed for: %s — falling back to synchronous load" % target_scene_path)
		get_tree().change_scene_to_file(target_scene_path)
