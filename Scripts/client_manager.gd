extends Node

var clients: Array[ClientData] = []

# === РЕПУТАЦИЯ ===
var reputation_points: int = 0   # Тратимая валюта (общий пул)
var global_reputation: int = 0   # Нетратимая метрика

signal reputation_points_changed(new_rp: int)
signal global_reputation_changed(new_gr: int)

func _ready():
	_init_clients()

func _init_clients():
	clients.clear()

	var defs = [
		{"id": "novotech",     "name": "CLIENT_NOVOTECH",      "emoji": "🚀", "desc": "CLIENT_NOVOTECH_DESC"},
		{"id": "edaplus",      "name": "CLIENT_EDAPLUS",       "emoji": "🍕", "desc": "CLIENT_EDAPLUS_DESC"},
		{"id": "finansgroup",  "name": "CLIENT_FINANSGROUP",   "emoji": "🏦", "desc": "CLIENT_FINANSGROUP_DESC"},
		{"id": "medialine",    "name": "CLIENT_MEDIALINE",     "emoji": "📺", "desc": "CLIENT_MEDIALINE_DESC"},
		{"id": "stroymaster",  "name": "CLIENT_STROYMASTER",   "emoji": "🏗", "desc": "CLIENT_STROYMASTER_DESC"},
	]

	for d in defs:
		var client = ClientData.new()
		client.client_id = d["id"]
		client.client_name = d["name"]
		client.emoji = d["emoji"]
		client.description = d["desc"]
		clients.append(client)

func get_client_by_id(client_id: String) -> ClientData:
	for c in clients:
		if c.client_id == client_id:
			return c
	return null

func get_random_client() -> ClientData:
	if clients.is_empty():
		return null
	return clients.pick_random()

func get_budget_bonus_for_client(client_id: String) -> float:
	var client = get_client_by_id(client_id)
	if client == null:
		return 0.0
	return float(client.get_budget_bonus_percent()) / 100.0

# === НАЧИСЛЕНИЕ ОЧКОВ РЕПУТАЦИИ ===
func add_reputation_points(amount: int):
	reputation_points += amount
	emit_signal("reputation_points_changed", reputation_points)

func spend_reputation_points(amount: int) -> bool:
	if reputation_points < amount:
		return false
	reputation_points -= amount
	emit_signal("reputation_points_changed", reputation_points)
	return true

func penalize_reputation_points(amount: int):
	reputation_points -= amount
	emit_signal("reputation_points_changed", reputation_points)

func add_global_reputation(amount: int):
	global_reputation += amount
	emit_signal("global_reputation_changed", global_reputation)

# === ПОКУПКА УЛУЧШЕНИЙ КЛИЕНТА ===
func buy_budget_upgrade(client_id: String) -> bool:
	var client = get_client_by_id(client_id)
	if client == null: return false
	if client.budget_level >= ClientData.MAX_BUDGET_LEVEL: return false
	if not spend_reputation_points(ClientData.BUDGET_UPGRADE_COST): return false
	client.budget_level += 1
	return true

func buy_simple_unlock(client_id: String) -> bool:
	var client = get_client_by_id(client_id)
	if client == null: return false
	if client.has_simple: return false
	if not spend_reputation_points(ClientData.SIMPLE_UNLOCK_COST): return false
	client.has_simple = true
	return true

func buy_easy_unlock(client_id: String) -> bool:
	var client = get_client_by_id(client_id)
	if client == null: return false
	if not client.has_simple: return false
	if client.has_easy: return false
	if not spend_reputation_points(ClientData.EASY_UNLOCK_COST): return false
	client.has_easy = true
	return true

func buy_support_unlock(client_id: String) -> bool:
	var client = get_client_by_id(client_id)
	if client == null: return false
	if client.has_support: return false
	if not spend_reputation_points(ClientData.SUPPORT_UNLOCK_COST): return false
	client.has_support = true
	return true

# === ДИНАМИЧЕСКОЕ КОЛИЧЕСТВО ПРОЕКТОВ НА НЕДЕЛЮ (зависит от ГР) ===
func get_weekly_project_count() -> int:
	if global_reputation >= 50:
		return 13
	elif global_reputation >= 30:
		return 11
	elif global_reputation >= 15:
		return 9
	elif global_reputation >= 5:
		return 7
	else:
		return 5
