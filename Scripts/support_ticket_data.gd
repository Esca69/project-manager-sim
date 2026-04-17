class_name SupportTicketData
extends Resource

@export var ticket_id: String = ""
@export var required_role: String = ""
@export var work_amount: int = 0
@export var progress: float = 0.0
@export var created_at_day: int = 0
@export var deadline_day: int = 0
@export var is_completed: bool = false
@export var is_overdue: bool = false

var assigned_worker: EmployeeData = null
