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
@export var was_unattended: bool = false  # SUPPORT v1.3: тикет создан, когда саппорт был не WORKING

var assigned_worker: EmployeeData = null
