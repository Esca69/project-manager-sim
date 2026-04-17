class_name SupportProjectData
extends Resource

@export var project_id: String = ""
@export var client_id: String = ""
@export var title: String = ""
@export var created_at_day: int = 0
@export var sla_level: String = "medium"
@export var daily_rate: int = 0
@export var is_active: bool = true

var assigned_support_employee: EmployeeData = null
var tickets: Array = []

var week_start_day: int = 0
var total_earned: int = 0
var total_labor_cost: float = 0.0
var daily_labor_cost: float = 0.0

func get_client():
if client_id == "":
return null
var cm = Engine.get_main_loop().root.get_node_or_null("/root/ClientManager")
if cm:
return cm.get_client_by_id(client_id)
return null

func get_display_title() -> String:
return tr(title)
