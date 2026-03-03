extends Node

var clients: Array[ClientData] = []

signal client_loyalty_changed(client: ClientData, old_value: int, new_value: int)

func _ready():
	_init_clients()

func _init_clients():
	clients.clear()

	var defs = [
		{"id": "novotech",     "name": tr("CLIENT_NOVOTECH"),      "emoji": "🚀", "desc": tr("CLIENT_NOVOTECH_DESC")},
		{"id": "edaplus",      "name": tr("CLIENT_EDAPLUS"),       "emoji": "🍕", "desc": tr("CLIENT_EDAPLUS_DESC")},
		{"id": "finansgroup",  "name": tr("CLIENT_FINANSGROUP"),   "emoji": "🏦", "desc": tr("CLIENT_FINANSGROUP_DESC")},
		{"id": "medialine",    "name": tr("CLIENT_MEDIALINE"),     "emoji": "📺", "desc": tr("CLIENT_MEDIALINE_DESC")},
		{"id": "stroymaster",  "name": tr("CLIENT_STROYMASTER"),   "emoji": "🏗", "desc": tr("CLIENT_STROYMASTER_DESC")},
	]

	for d in defs:
		var client = ClientData.new()
		client.client_id = d["id"]
		client.client_name = d["name"]
		client.emoji = d["emoji"]
		client.description = d["desc"]
		client.loyalty = 0
		client.loyalty_changed.connect(_on_client_loyalty_changed)
		clients.append(client)

func _on_client_loyalty_changed(client: ClientData, old_value: int, new_value: int):
	emit_signal("client_loyalty_changed", client, old_value, new_value)

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

# === СУММАРНАЯ ЛОЯЛЬНОСТЬ ВСЕХ КЛИЕНТОВ ===
func get_total_loyalty() -> int:
	var total = 0
	for c in clients:
		total += c.loyalty
	return total

# === ДИНАМИЧЕСКОЕ КОЛИЧЕСТВО ПРОЕКТОВ НА НЕДЕЛЮ ===
func get_weekly_project_count() -> int:
	var total = get_total_loyalty()
	if total >= 50:
		return 13
	elif total >= 30:
		return 11
	elif total >= 15:
		return 9
	elif total >= 5:
		return 7
	else:
		return 5
