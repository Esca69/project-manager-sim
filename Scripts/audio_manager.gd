extends Node

# ============================
# AUDIO MANAGER — Глобальный менеджер звука
# ============================
# Autoload-синглтон. Управляет музыкой и звуковыми эффектами.
# Вызов из любого скрипта: AudioManager.play_sfx("interact")
#
# Чтобы добавить новый звук:
# 1. Положи файл в res://Sound/
# 2. Добавь запись в SFX_LIBRARY
# Готово!

# --- БИБЛИОТЕКА ЗВУКОВЫХ ЭФФЕКТОВ ---
# Ключ → путь к файлу. Добавляй сюда новые звуки.
const SFX_LIBRARY = {
	"interact": "res://Sound/popsnd.mp3",
	"bark": "res://Sound/bark.mp3",
	"closedoor": "res://Sound/closedoor.mp3",
}

# --- НАСТРОЙКИ ГРОМКОСТИ (0.0 = тишина, 1.0 = макс) ---
# Эти значения можно менять в рантайме и сохранять в настройки
var master_volume: float = 1.0
var music_volume: float = 0.3      # Музыка тише, чтобы не давила
var sfx_volume: float = 0.7        # Эффекты громче

# --- ВНУТРЕННИЕ НОДЫ ---
var _music_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []

# Сколько одновременных SFX допускаем (пул)
const SFX_POOL_SIZE = 8

# --- КЭШИ ---
var _sfx_cache: Dictionary = {}   # "interact" -> AudioStream

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# --- Создаём плеер для музыки ---
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	
	# --- Создаём пул плееров для SFX ---
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)
	
	# --- Запускаем музыку ---
	_start_music("res://Sound/maintheme.mp3")

# ============================
# МУЗЫКА
# ============================

func _start_music(path: String):
	var stream = load(path)
	if not stream:
		push_warning("AudioManager: Не удалось загрузить музыку: " + path)
		return
	
	_music_player.stream = stream
	_music_player.volume_db = _volume_to_db(music_volume * master_volume)
	
	_music_player.finished.connect(_on_music_finished)
	_music_player.play()

func _on_music_finished():
	_music_player.play()

## Установить громкость музыки (0.0 - 1.0)
func set_music_volume(vol: float):
	music_volume = clampf(vol, 0.0, 1.0)
	_update_music_volume()

## Установить общую громкость (0.0 - 1.0)
func set_master_volume(vol: float):
	master_volume = clampf(vol, 0.0, 1.0)
	_update_music_volume()

func _update_music_volume():
	if _music_player:
		_music_player.volume_db = _volume_to_db(music_volume * master_volume)

# ============================
# ЗВУКОВЫЕ ЭФФЕКТЫ
# ============================

## Проиграть звуковой эффект по имени из SFX_LIBRARY
## Вызов: AudioManager.play_sfx("interact")
func play_sfx(sfx_name: String):
	if not SFX_LIBRARY.has(sfx_name):
		push_warning("AudioManager: Неизвестный SFX: " + sfx_name)
		return
	
	var stream = _get_or_load_sfx(sfx_name)
	if not stream:
		return
	
	# Ищем свободный плеер в пуле
	var player = _get_free_sfx_player()
	if not player:
		return
	
	player.stream = stream
	player.volume_db = _volume_to_db(sfx_volume * master_volume)
	player.play()

## Установить громкость SFX (0.0 - 1.0)
func set_sfx_volume(vol: float):
	sfx_volume = clampf(vol, 0.0, 1.0)

# --- ВНУТРЕННИЕ ---

func _get_or_load_sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	
	var path = SFX_LIBRARY[sfx_name]
	var stream = load(path)
	if not stream:
		push_warning("AudioManager: Не удалось загрузить: " + path)
		return null
	
	_sfx_cache[sfx_name] = stream
	return stream

func _get_free_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player
	return null

## Конвертация линейной ��ромкости (0.0-1.0) в децибелы
func _volume_to_db(linear: float) -> float:
	if linear <= 0.001:
		return -80.0
	return 20.0 * log(linear) / log(10.0)
