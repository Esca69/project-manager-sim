extends Node

# === RELATIONSHIP MANAGER ===
# Autoload-синглтон. Хранит и управляет отношениями между сотрудниками.

# --- ШКАЛА ОТНОШЕНИЙ ---
# Диапазон: -100 .. +100, начало = 0 (нейтрально)
const REL_MIN: int = -100
const REL_MAX: int = 100
const REL_DEFAULT: int = 0

# --- ПОРОГИ УРОВНЕЙ ---
const THRESHOLD_NEMESIS: int = -60     # <= -60: Враги (Nemesis)
const THRESHOLD_DISLIKE: int = -25     # <= -25: Неприязнь (Dislike)
const THRESHOLD_NEUTRAL_LOW: int = -24 # -24 .. +24: Нейтральные
const THRESHOLD_NEUTRAL_HIGH: int = 24
const THRESHOLD_FRIENDLY: int = 25     # >= 25: Приятели (Friendly)
const THRESHOLD_BESTIES: int = 60      # >= 60: Лучшие друзья (Besties)

# --- ЗАТУХАНИЕ (DECAY) ---
const DECAY_AMOUNT: int = 1           # Сколько очков затухает в день
const DECAY_NEUTRAL_ZONE: int = 5     # Не затухает если |value| <= 5

# --- ЛИМИТЫ ЧАТОВ ---
const MAX_CHATS_PER_DAY: int = 3      # Макс. чатов на сотрудника в день

# --- КУБИК СОВМЕСТИМОСТИ ---
const BASE_ROLL_MIN: int = -3
const BASE_ROLL_MAX: int = 3
const SHARED_INTEREST_BONUS: int = 3   # За каждый общий интерес
const CONFLICT_PENALTY: int = -4       # За каждый конфликт

# --- MOOD-ЭФФЕКТЫ ЧАТА ---
const CHAT_MOOD_POSITIVE_VALUE: float = 5.0
const CHAT_MOOD_NEGATIVE_VALUE: float = -5.0
const CHAT_MOOD_DURATION: float = 480.0  # 8 игровых часов = 480 минут

# --- БОНУС СОСЕДСТВА (NEIGHBOR) ---
const NEIGHBOR_BESTIES_MOD: float = 0.08     # +8% эффективности для Besties
const NEIGHBOR_FRIENDLY_MOD: float = 0.04    # +4% для Friendly
const NEIGHBOR_NEUTRAL_MOD: float = 0.0      # 0% для Neutral
const NEIGHBOR_DISLIKE_MOD: float = -0.04    # -4% для Dislike
const NEIGHBOR_NEMESIS_MOD: float = -0.08    # -8% для Nemesis

# --- MOOD-МОДИФИКАТОРЫ СОСЕДСТВА ---
const NEIGHBOR_BESTIES_MOOD: float = 5.0
const NEIGHBOR_FRIENDLY_MOOD: float = 2.0
const NEIGHBOR_DISLIKE_MOOD: float = -3.0
const NEIGHBOR_NEMESIS_MOOD: float = -6.0
const NEIGHBOR_MOOD_DURATION: float = 480.0   # 8 игровых часов

# --- ДАННЫЕ ---
# Словарь отношений. Ключ = "Name1::Name2" (имена отсортированы), значение = int
var relationships: Dictionary = {}

# Счётчик чатов за день. Ключ = employee_name, значение = int
var daily_chat_counts: Dictionary = {}

# === УРОВЕНЬ ОТНОШЕНИЙ ===
enum RelLevel { NEMESIS, DISLIKE, NEUTRAL, FRIENDLY, BESTIES }

# === КЛЮЧИ ===

# Ключ пары: имена сортируются, чтобы A::B == B::A
func _make_key(name_a: String, name_b: String) -> String:
	var names = [name_a, name_b]
	names.sort()
	return names[0] + "::" + names[1]

func get_relationship(name_a: String, name_b: String) -> int:
	var key = _make_key(name_a, name_b)
	return relationships.get(key, REL_DEFAULT)

func set_relationship(name_a: String, name_b: String, value: int):
	var key = _make_key(name_a, name_b)
	relationships[key] = clampi(value, REL_MIN, REL_MAX)

func change_relationship(name_a: String, name_b: String, delta: int):
	var current = get_relationship(name_a, name_b)
	set_relationship(name_a, name_b, current + delta)

# === УРОВЕНЬ ОТНОШЕНИЙ ===

func get_rel_level(name_a: String, name_b: String) -> RelLevel:
	var val = get_relationship(name_a, name_b)
	if val <= THRESHOLD_NEMESIS:
		return RelLevel.NEMESIS
	elif val <= THRESHOLD_DISLIKE:
		return RelLevel.DISLIKE
	elif val >= THRESHOLD_BESTIES:
		return RelLevel.BESTIES
	elif val >= THRESHOLD_FRIENDLY:
		return RelLevel.FRIENDLY
	return RelLevel.NEUTRAL

func get_rel_level_name(name_a: String, name_b: String) -> String:
	# Возвращает ключ локализации
	match get_rel_level(name_a, name_b):
		RelLevel.NEMESIS: return "REL_LEVEL_NEMESIS"
		RelLevel.DISLIKE: return "REL_LEVEL_DISLIKE"
		RelLevel.NEUTRAL: return "REL_LEVEL_NEUTRAL"
		RelLevel.FRIENDLY: return "REL_LEVEL_FRIENDLY"
		RelLevel.BESTIES: return "REL_LEVEL_BESTIES"
	return "REL_LEVEL_NEUTRAL"

# === МАТРИЦА СОВМЕСТИМОСТИ ===

# Бросок кубика при чате. Возвращает delta отношений.
func roll_compatibility(emp_a: EmployeeData, emp_b: EmployeeData) -> int:
	var result: int = randi_range(BASE_ROLL_MIN, BASE_ROLL_MAX)

	# Общие интересы (из PERSONALITY_INTERESTS)
	var shared_interests: int = 0
	for tag in emp_a.personality:
		if tag in EmployeeData.PERSONALITY_INTERESTS and tag in emp_b.personality:
			shared_interests += 1
	result += shared_interests * SHARED_INTEREST_BONUS

	# Конфликты раздражителей
	# sexist мужчина + женщина → конфликт
	if "sexist" in emp_a.personality and emp_b.gender == "female":
		result += CONFLICT_PENALTY
	if "sexist" in emp_b.personality and emp_a.gender == "female":
		result += CONFLICT_PENALTY

	# man_hater женщина + мужчина → конфликт
	if "man_hater" in emp_a.personality and emp_b.gender == "male":
		result += CONFLICT_PENALTY
	if "man_hater" in emp_b.personality and emp_a.gender == "male":
		result += CONFLICT_PENALTY

	# smelly → штраф всем (кроме другого smelly)
	if "smelly" in emp_a.personality and "smelly" not in emp_b.personality:
		result += CONFLICT_PENALTY
	if "smelly" in emp_b.personality and "smelly" not in emp_a.personality:
		result += CONFLICT_PENALTY

	# toxic → штраф introvert'ам
	if "toxic" in emp_a.personality and "introvert" in emp_b.personality:
		result += CONFLICT_PENALTY
	if "toxic" in emp_b.personality and "introvert" in emp_a.personality:
		result += CONFLICT_PENALTY

	# flirt + противоположный пол → бонус (вместо штрафа)
	if "flirt" in emp_a.personality and emp_a.gender != emp_b.gender:
		result += 2
	if "flirt" in emp_b.personality and emp_b.gender != emp_a.gender:
		result += 2

	return result

# === ОБРАБОТКА РЕЗУЛЬТАТА ЧАТА ===

func process_chat_result(emp_a: EmployeeData, emp_b: EmployeeData) -> Dictionary:
	# Возвращает {delta: int, is_positive: bool} для UI
	var delta = roll_compatibility(emp_a, emp_b)
	change_relationship(emp_a.employee_name, emp_b.employee_name, delta)

	# Лимит чатов
	daily_chat_counts[emp_a.employee_name] = daily_chat_counts.get(emp_a.employee_name, 0) + 1
	daily_chat_counts[emp_b.employee_name] = daily_chat_counts.get(emp_b.employee_name, 0) + 1

	# Mood-эффект
	var is_positive = delta >= 0
	if is_positive:
		emp_a.add_mood_modifier("chat_" + emp_b.employee_name, "MOOD_MOD_GOOD_CHAT", CHAT_MOOD_POSITIVE_VALUE, CHAT_MOOD_DURATION)
		emp_b.add_mood_modifier("chat_" + emp_a.employee_name, "MOOD_MOD_GOOD_CHAT", CHAT_MOOD_POSITIVE_VALUE, CHAT_MOOD_DURATION)
	else:
		emp_a.add_mood_modifier("chat_" + emp_b.employee_name, "MOOD_MOD_BAD_CHAT", CHAT_MOOD_NEGATIVE_VALUE, CHAT_MOOD_DURATION)
		emp_b.add_mood_modifier("chat_" + emp_a.employee_name, "MOOD_MOD_BAD_CHAT", CHAT_MOOD_NEGATIVE_VALUE, CHAT_MOOD_DURATION)

	return {"delta": delta, "is_positive": is_positive}

func can_chat(employee_name: String) -> bool:
	return daily_chat_counts.get(employee_name, 0) < MAX_CHATS_PER_DAY

# === ЗАТУХАНИЕ (DECAY) — вызывается раз в день ===

func apply_daily_decay():
	for key in relationships.keys():
		var val = relationships[key]
		if abs(val) <= DECAY_NEUTRAL_ZONE:
			continue  # Не затухает рядом с нулём
		if val > 0:
			relationships[key] = maxi(val - DECAY_AMOUNT, 0)
		else:
			relationships[key] = mini(val + DECAY_AMOUNT, 0)

# === ПОДКЛЮЧЕНИЕ К GAMETIME ===

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_connect_signals")

func _connect_signals():
	GameTime.day_started.connect(_on_day_started)

func _on_day_started(_day_number: int):
	apply_daily_decay()
	daily_chat_counts.clear()

# === СЕРИАЛИЗАЦИЯ / ДЕСЕРИАЛИЗАЦИЯ ===

func serialize() -> Dictionary:
	return {
		"relationships": relationships.duplicate(),
		"daily_chat_counts": daily_chat_counts.duplicate(),
	}

func deserialize(data: Dictionary):
	relationships = {}
	var saved_rels = data.get("relationships", {})
	for key in saved_rels:
		relationships[str(key)] = int(saved_rels[key])
	daily_chat_counts = {}
	var saved_counts = data.get("daily_chat_counts", {})
	for key in saved_counts:
		daily_chat_counts[str(key)] = int(saved_counts[key])

# === ХЕЛПЕР ДЛЯ УДАЛЕНИЯ УВОЛЕННОГО СОТРУДНИКА ===

func remove_employee(employee_name: String):
	var keys_to_remove = []
	for key in relationships.keys():
		if employee_name in key.split("::"):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		relationships.erase(key)
	daily_chat_counts.erase(employee_name)

# === ХЕЛПЕР: СПИСОК НЕ-НЕЙТРАЛЬНЫХ СВЯЗЕЙ СОТРУДНИКА ===

func get_non_neutral_relationships(employee_name: String) -> Array:
	# Возвращает [{name: String, value: int, level: RelLevel}]
	var result = []
	for key in relationships.keys():
		var parts = key.split("::")
		if parts.size() != 2:
			continue
		var other_name = ""
		if parts[0] == employee_name:
			other_name = parts[1]
		elif parts[1] == employee_name:
			other_name = parts[0]
		else:
			continue
		var val = relationships[key]
		if abs(val) > DECAY_NEUTRAL_ZONE:
			var level = get_rel_level(employee_name, other_name)
			result.append({"name": other_name, "value": val, "level": level})
	# Сортируем по value (от лучшего к худшему)
	result.sort_custom(func(a, b): return a.value > b.value)
	return result

# === NEIGHBOR SYSTEM: Получить модификатор эффективности от соседей ===
func get_neighbor_efficiency_mod(employee_name: String, neighbor_names: Array) -> float:
	if neighbor_names.is_empty():
		return 0.0
	var total_mod: float = 0.0
	for neighbor_name in neighbor_names:
		var level = get_rel_level(employee_name, neighbor_name)
		match level:
			RelLevel.BESTIES:
				total_mod += NEIGHBOR_BESTIES_MOD
			RelLevel.FRIENDLY:
				total_mod += NEIGHBOR_FRIENDLY_MOD
			RelLevel.DISLIKE:
				total_mod += NEIGHBOR_DISLIKE_MOD
			RelLevel.NEMESIS:
				total_mod += NEIGHBOR_NEMESIS_MOD
			_:
				total_mod += NEIGHBOR_NEUTRAL_MOD
	return total_mod

# === NEIGHBOR SYSTEM: Применить mood-модификатор от соседа ===
func apply_neighbor_mood(emp_data: EmployeeData, neighbor_name: String):
	var level = get_rel_level(emp_data.employee_name, neighbor_name)
	var mood_value: float = 0.0
	match level:
		RelLevel.BESTIES:
			mood_value = NEIGHBOR_BESTIES_MOOD
		RelLevel.FRIENDLY:
			mood_value = NEIGHBOR_FRIENDLY_MOOD
		RelLevel.DISLIKE:
			mood_value = NEIGHBOR_DISLIKE_MOOD
		RelLevel.NEMESIS:
			mood_value = NEIGHBOR_NEMESIS_MOOD
	if mood_value != 0.0:
		emp_data.add_mood_modifier(
			"neighbor_" + neighbor_name,
			"MOOD_MOD_NEIGHBOR_GOOD" if mood_value > 0 else "MOOD_MOD_NEIGHBOR_BAD",
			mood_value,
			NEIGHBOR_MOOD_DURATION
		)
	else:
		emp_data.remove_mood_modifier("neighbor_" + neighbor_name)

# === NEIGHBOR SYSTEM: Получить описание связей для UI ===
func get_relationship_summary(employee_name: String) -> Array:
	# Возвращает [{name, value, level_key}] — ВСЕ связи (не только non-neutral)
	var result = []
	for key in relationships.keys():
		var parts = key.split("::")
		if parts.size() != 2:
			continue
		var other_name = ""
		if parts[0] == employee_name:
			other_name = parts[1]
		elif parts[1] == employee_name:
			other_name = parts[0]
		else:
			continue
		var val = relationships[key]
		if val == 0:
			continue
		var level_key = get_rel_level_name(employee_name, other_name)
		result.append({"name": other_name, "value": val, "level_key": level_key})
	result.sort_custom(func(a, b): return a.value > b.value)
	return result
