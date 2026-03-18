extends Node

# ============================
# AUDIO MANAGER — Глобальный менеджер звука
# ============================

# --- БИБЛИОТЕКА ЗВУКОВЫХ ЭФФЕКТОВ ---
const SFX_LIBRARY = {
	"interact": "res://Sound/popsnd.mp3",
	"bark": "res://Sound/bark.mp3",
	"closedoor": "res://Sound/closedoor.mp3",
	"typing": "res://Sound/typing.mp3", 
	"bosssound": "res://Sound/bosssound.mp3",
	"bossmeeting": "res://Sound/bossmeeting.mp3",
	"eating": "res://Sound/eatingsound.mp3",
	"sippingcoffee": "res://Sound/sippingcoffe.mp3",
	"startworkingday": "res://Sound/startworkingday.mp3",
	"buttonclick": "res://Sound/buttonclick.mp3" # <-- ДОБАВЛЕН ЗВУК КНОПКИ
}

# --- ИНДИВИДУАЛЬНАЯ ГРОМКОСТЬ ЗВУКОВ (Множители от 0.0 до 1.0) ---
const SFX_VOLUME_MULTIPLIERS = {
	"bossmeeting": 0.4,
	"sippingcoffee": 1.3,
	"typing": 1.0,
	"startworkingday": 0.6,
	"buttonclick": 0.7 # <-- ДОБАВЛЕН РЕГУЛЯТОР ДЛЯ КНОПОК
}

# --- НАСТРОЙКИ ГРОМКОСТИ (0.0 = тишина, 1.0 = макс) ---
var master_volume: float = 1.0
var music_volume: float = 0.2      
var sfx_volume: float = 0.8        

# Множитель громкости для фонового шума
const AMBIENCE_VOLUME_MULTIPLIER: float = 1.5 

# --- ВНУТРЕННИЕ НОДЫ ---
var _music_player: AudioStreamPlayer = null
var _ambience_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []

const SFX_POOL_SIZE = 8

# --- ОГРАНИЧЕНИЯ ДЛЯ SPATIAL ЗВУКОВ ---
const MAX_TYPING_SOUNDS: int = 2
var active_typing_sounds: int = 0

const MAX_EATING_SOUNDS: int = 1
var active_eating_sounds: int = 0

const MAX_COFFEE_SOUNDS: int = 1
var active_coffee_sounds: int = 0

var _sfx_cache: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# --- Создаём плеер для музыки ---
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	
	# --- Создаём плеер для эмбиента ---
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = "Master"
	add_child(_ambience_player)
	
	# --- Создаём пул плееров для SFX ---
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)
	
	# --- Запускаем музыку и эмбиент ---
	_start_music("res://Sound/maintheme.mp3")
	_start_ambience("res://Sound/ambience.mp3") 
	
	# --- Подключаемся к сигналу начала дня (в 9:00) ---
	if GameTime and not GameTime.work_started.is_connected(_on_work_started):
		GameTime.work_started.connect(_on_work_started)
			
	# === МАГИЯ АВТОМАТИЧЕСКИХ КНОПОК ===
	# 1. Слушаем появление новых объектов в игре
	get_tree().node_added.connect(_on_node_added)
	# 2. Пробегаемся по уже существующим объектам (на всякий случай)
	_connect_existing_buttons(get_tree().root)

# ============================
# ГЛОБАЛЬНЫЕ ИГРОВЫЕ СОБЫТИЯ
# ============================
func _on_work_started():
	# Звук играет только если сегодня не выходной
	if GameTime and not GameTime.is_weekend():
		play_sfx("startworkingday")

# ============================
# АВТОМАТИЧЕСКАЯ ОЗВУЧКА UI
# ============================
# Функция ловит любую новую ноду, появившуюся в игре
func _on_node_added(node: Node):
	if node is BaseButton:
		if not node.pressed.is_connected(_play_button_sound):
			node.pressed.connect(_play_button_sound)

# Рекурсивная функция для кнопок, которые уже были в сцене до старта AudioManager
func _connect_existing_buttons(node: Node):
	if node is BaseButton:
		if not node.pressed.is_connected(_play_button_sound):
			node.pressed.connect(_play_button_sound)
	
	for child in node.get_children():
		_connect_existing_buttons(child)

# Сам вызов звука кнопки
func _play_button_sound():
	play_sfx("buttonclick")

# ============================
# МУЗЫКА И ЭМБИЕНТ
# ============================
func _start_music(path: String):
	var stream = load(path)
	if not stream: return
	_music_player.stream = stream
	_music_player.volume_db = _volume_to_db(music_volume * master_volume)
	_music_player.finished.connect(_on_music_finished)
	_music_player.play()

func _on_music_finished():
	_music_player.play()

# Запуск фонового шума
func _start_ambience(path: String):
	var stream = load(path)
	if not stream: return
	_ambience_player.stream = stream
	_ambience_player.volume_db = _volume_to_db(music_volume * master_volume * AMBIENCE_VOLUME_MULTIPLIER)
	_ambience_player.finished.connect(_on_ambience_finished)
	_ambience_player.play()

func _on_ambience_finished():
	_ambience_player.play()

func set_music_volume(vol: float):
	music_volume = clampf(vol, 0.0, 1.0)
	_update_music_volume()

func set_master_volume(vol: float):
	master_volume = clampf(vol, 0.0, 1.0)
	_update_music_volume()

func _update_music_volume():
	if _music_player:
		_music_player.volume_db = _volume_to_db(music_volume * master_volume)
	if _ambience_player:
		_ambience_player.volume_db = _volume_to_db(music_volume * master_volume * AMBIENCE_VOLUME_MULTIPLIER)

# ============================
# ЗВУКОВЫЕ ЭФФЕКТЫ
# ============================
func play_sfx(sfx_name: String):
	if not SFX_LIBRARY.has(sfx_name): return
	
	var stream = _get_or_load_sfx(sfx_name)
	if not stream: return
	
	var player = _get_free_sfx_player()
	if not player: return
	
	player.stream = stream
	
	# Применяем индивидуальный множитель звука
	var multiplier = SFX_VOLUME_MULTIPLIERS.get(sfx_name, 1.0)
	player.volume_db = _volume_to_db(sfx_volume * master_volume * multiplier)
	
	player.play()

func set_sfx_volume(vol: float):
	sfx_volume = clampf(vol, 0.0, 1.0)

# ============================
# SPATIAL AUDIO ЛИМИТЫ
# ============================
func can_play_typing() -> bool: return active_typing_sounds < MAX_TYPING_SOUNDS
func register_typing_sound(): active_typing_sounds += 1
func unregister_typing_sound(): active_typing_sounds = max(0, active_typing_sounds - 1)

func can_play_eating() -> bool: return active_eating_sounds < MAX_EATING_SOUNDS
func register_eating_sound(): active_eating_sounds += 1
func unregister_eating_sound(): active_eating_sounds = max(0, active_eating_sounds - 1)

func can_play_coffee() -> bool: return active_coffee_sounds < MAX_COFFEE_SOUNDS
func register_coffee_sound(): active_coffee_sounds += 1
func unregister_coffee_sound(): active_coffee_sounds = max(0, active_coffee_sounds - 1)

## Получить текущую громкость для 2D плееров с учетом индивидуальной настройки
func get_current_sfx_db(sfx_name: String = "") -> float:
	var multiplier = SFX_VOLUME_MULTIPLIERS.get(sfx_name, 1.0)
	return _volume_to_db(sfx_volume * master_volume * multiplier)

# --- ВНУТРЕННИЕ ---
func _get_or_load_sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name): return _sfx_cache[sfx_name]
	var path = SFX_LIBRARY[sfx_name]
	var stream = load(path)
	if stream: _sfx_cache[sfx_name] = stream
	return stream

func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing: return player
	return null

func _volume_to_db(linear: float) -> float:
	if linear <= 0.001: return -80.0
	return 20.0 * log(linear) / log(10.0)
