extends Node

var clients: Array[ClientData] = []

signal client_loyalty_changed(client: ClientData, old_value: int, new_value: int)

func _ready():
	_init_clients()

func _init_clients():
	clients.clear()

	var defs = [
		{"id": "novotech",     "name": "НовоТех",      "emoji": "🚀", "desc": "IT-стартап. Всегда хочет быстро и дёшево."},
		{"id": "edaplus",      "name": "ЕдаПлюс",      "emoji": "🍕", "desc": "Сеть доставки еды. Много мелких задач."},
		{"id": "finansgroup",  "name": "ФинансГрупп",   "emoji": "🏦", "desc": "Банк. Серьёзные проекты, хорошие бюджеты."},
		{"id": "medialine",    "name": "МедиаЛайн",    "emoji": "📺", "desc": "Рекламное агентство. Креативные задачи."},
		{"id": "stroymaster",  "name": "СтройМастер",   "emoji": "🏗", "desc": "Строительная компания. Стабильный поток."},
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
