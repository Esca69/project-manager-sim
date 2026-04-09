extends Control
class_name LoadingScreen

# === ЭКРАН ЗАГРУЗКИ ===
# Показывается при переходе в office.tscn после старта или загрузки игры.
# Прогревает шрифт NotoColorEmoji и асинхронно загружает целевую сцену.

const COLOR_PRIMARY = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_TEXT_MUTED = Color(0.45, 0.45, 0.55, 1)
const SPINNER_FRAMES = ["◐", "◓", "◑", "◒"]
const TARGET_SCENE = "res://Scenes/office.tscn"

# Все emoji из игры для прогрева шрифта
const WARMUP_EMOJIS = "☀★☎☕♀♂♥⚖⚙⚠⚡⚪✅✈✕❌❓❗❤➕🌙🌴🍔🍕🍽🎉🎩🎯🎲🏆🏎🏖🏗🏠🏢🏥🏦🏹🐞👁👋👍👤👥👦👧👨👩💊💔💚💛💢💨💬💰💵💸💻💼💾📁📂📅📈📉📊📋📖📚📝📞📦📷📺🔀🔄🔍🔒🔔🔥🔴🕐🖥🗑🗣😄😊😕😠😣😤😩😮🙂🙏🚀🚪🚫🚽🛠🛡🟡🟢🤒🤝🤦🤬🧑🧠🧪🪑💤⬆️"
# Все размеры шрифтов, используемые в 6 основных панелях
const WARMUP_FONT_SIZES = [11, 12, 13, 14, 15, 16, 17, 18, 20, 28, 40, 56]
# Текст прогрева — покрывает латиницу, кириллицу, цифры и знаки препинания
const WARMUP_TEXT = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя .,!?:;()[]$%+-=/«»—"
# Количество кадров ожидания после инстанциирования сцены.
# За это время выполняются все _ready() (синхронно) и call_deferred-вызовы
# (нужен минимум 1 кадр), а также синхронный _preheat_panels.
const WARMUP_FRAMES = 5
# Слот для загрузки сохранения; -1 = нет сохранения (новая игра)
static var pending_save_slot: int = -1
# Путь к целевой сцене; если пустой — используется TARGET_SCENE
static var target_scene_path: String = ""

var _spinner_label: Label
var _loading_label: Label
var _stage_label: Label
var _progress_bar: ProgressBar
var _spinner_timer: float = 0.0
var _spinner_index: int = 0
var _loading_started: bool = false
var _scene_to_load: String = ""


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
	# Этап 1: показываем экран, рендерим первый кадр
	_progress_bar.value = 20.0
	_stage_label.text = _tr_or("MENU_LOADING", "Загрузка...")
	await get_tree().process_frame

	# Этап 2: загружаем сохранение (если есть)
	if pending_save_slot > 0:
		_stage_label.text = _tr_or("LOADING_STAGE_SAVE", "Загрузка сохранения...")
		# Даём несколько кадров чтобы спиннер точно начал крутиться и текст обновился
		await get_tree().process_frame
		await get_tree().process_frame

		var slot = pending_save_slot
		pending_save_slot = -1

		# load_game_async() выполняет работу пошагово с await, позволяя спиннеру крутиться
		var ok = await SaveManager.load_game_async(slot)
		# После загрузки даём кадр для обновления спиннера
		await get_tree().process_frame
		if not ok:
			# Не удалось загрузить сохранение — возвращаемся в главное меню
			get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
			return
	pending_save_slot = -1
	_progress_bar.value = 40.0
	await get_tree().process_frame

	# Этап 3: прогреваем шрифты для всех размеров и начертаний, используемых в панелях
	_stage_label.text = _tr_or("LOADING_STAGE_RESOURCES", "Прогрев шрифтов...")
	var warmup_container = Control.new()
	warmup_container.modulate.a = 0.0
	warmup_container.visible = true
	add_child(warmup_container)

	var warmup_text = WARMUP_TEXT + WARMUP_EMOJIS
	for size in WARMUP_FONT_SIZES:
		for weight in ["regular", "semibold", "bold"]:
			var lbl = Label.new()
			lbl.visible = true
			lbl.modulate.a = 0.0
			lbl.text = warmup_text
			lbl.add_theme_font_size_override("font_size", size)
			if UITheme:
				UITheme.apply_font(lbl, weight)
			warmup_container.add_child(lbl)

	# Ждём 5 кадров — достаточно для растеризации всех глифов в TextServer
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	warmup_container.queue_free()
	_progress_bar.value = 65.0

	# Этап 4: асинхронная загрузка сцены
	_stage_label.text = _tr_or("LOADING_STAGE_PREPARING", "Подготовка интерфейса...")
	_scene_to_load = target_scene_path if target_scene_path != "" else TARGET_SCENE
	target_scene_path = ""
	ResourceLoader.load_threaded_request(_scene_to_load)
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
	var status = ResourceLoader.load_threaded_get_status(_scene_to_load, progress)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var scene_progress = progress[0] if progress.size() > 0 else 0.0
		_progress_bar.value = 65.0 + scene_progress * 35.0
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		_progress_bar.value = 100.0
		_stage_label.text = _tr_or("LOADING_STAGE_DONE", "Почти готово...")
		_loading_started = false
		var packed = ResourceLoader.load_threaded_get(_scene_to_load)
		if packed:
			_instantiate_and_switch(packed)
		else:
			get_tree().change_scene_to_file(_scene_to_load)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("[LoadingScreen] Threaded load failed, falling back to sync")
		_loading_started = false
		get_tree().change_scene_to_file(_scene_to_load)


# Инстанциируем сцену офиса прямо на loading screen, ждём несколько кадров
# чтобы все _ready() и call_deferred отработали, затем убираем loading screen.
func _instantiate_and_switch(packed: PackedScene) -> void:
	_stage_label.text = _tr_or("LOADING_STAGE_INIT", "Инициализация интерфейса...")
	var office = packed.instantiate()
	# Скрываем офис пока loading screen видим; _ready() и call_deferred
	# выполнятся, но рендеринг не произойдёт — пользователь видит loading screen
	office.visible = false
	get_tree().root.add_child(office)
	# Ждём WARMUP_FRAMES кадров: _ready() синхронны, но call_deferred нужен 1+ кадр,
	# а синхронный _preheat_panels успевает отработать в первом кадре.
	for _i in WARMUP_FRAMES:
		await get_tree().process_frame
	# Всё готово: показываем офис и убираем loading screen
	office.visible = true
	get_tree().current_scene = office
	queue_free()
