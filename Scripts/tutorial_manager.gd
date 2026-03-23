extends Node

# ===================================================
# === TUTORIAL MANAGER (Autoload Singleton) =========
# ===================================================
# Manages tutorial state, step progression, and provides
# helper data (tutorial project, tutorial candidate).

signal tutorial_step_changed(step: int)
signal tutorial_completed
signal hint_triggered(hint_id: String)

enum Step {
	NONE = 0,
	STEP_1_MOVE_TO_BOSS = 1,       # Move to boss desk
	STEP_2_TAKE_PROJECT = 2,       # Press E, take project
	STEP_3_WAIT_MEETING = 3,       # Wait for 4h meeting
	STEP_4_GO_TO_HR = 4,           # Go to HR desk
	STEP_5_HIRE_BA = 5,            # Hire BA (search + hire)
	STEP_6_SEAT_WORKER = 6,        # Seat worker at desk
	STEP_7_ASSIGN_DESK = 7,        # Assign at desk (approach)
	STEP_8_GO_TO_PM_DESK = 8,      # Go to PM desk
	STEP_9_START_PROJECT = 9,      # Start project
	STEP_9B_PROJECT_LAUNCHED = 95, # Project launched, exit screen (95 to avoid renumbering STEP_10=10)
	STEP_10_END_DAY = 10,          # End the day
}

var current_step: int = Step.NONE

# Cached tutorial project / candidate
var _tutorial_project: ProjectData = null
var _tutorial_candidate: EmployeeData = null

# Step 5: track sub-phase (searching vs hiring)
var _searching_for_ba: bool = false

# Step 9: track that project was started before screen closed
var _project_started_in_step9: bool = false

# Track total projects taken (for hint_second_project)
var _total_projects_taken: int = 0

# === Day 2+ one-time hint system ===
var shown_hints: Dictionary = {}  # {String hint_id: bool}
var _pending_morning_hint: String = ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Deferred so all other autoloads (GameTime, BossManager, etc.) finish their _ready() first
	call_deferred("_connect_hint_signals")

func _connect_hint_signals():
	GameTime.day_started.connect(_on_day_started_hint)
	GameTime.time_tick.connect(_on_time_tick_hint)
	BossManager.trust_changed.connect(_on_boss_trust_changed_hint)
	ProjectManager.project_finished.connect(_on_project_finished_hint)
	EventManager.event_triggered.connect(_on_event_triggered_hint)
	PMData.xp_changed.connect(_on_pm_xp_changed_hint)

func is_active() -> bool:
	# Tutorial is active as long as it hasn't been completed and a step is in progress
	return not GameState.tutorial_completed and current_step != Step.NONE

# Start tutorial (called after loading office scene on new game)
func start_tutorial():
	current_step = Step.STEP_1_MOVE_TO_BOSS
	emit_signal("tutorial_step_changed", current_step)
	print("📖 Tutorial started: step 1")

func advance_to_step(step: int):
	if not is_active():
		return
	current_step = step
	emit_signal("tutorial_step_changed", current_step)
	print("📖 Tutorial step: %d" % step)
	# Unfreeze time when reaching step 10
	if step == Step.STEP_10_END_DAY:
		GameTime.is_game_paused = false
		GameTime.speed_1x()
	# Reset project-started flag when leaving step 9
	if step != Step.STEP_9_START_PROJECT:
		_project_started_in_step9 = false

# ─── Step transitions ───────────────────────────────

# Step 1 → 2: player entered boss radius
func notify_player_near_boss():
	if not is_active():
		return
	if current_step == Step.STEP_1_MOVE_TO_BOSS:
		advance_to_step(Step.STEP_2_TAKE_PROJECT)

# Step 2 → 3: player selected/took a project from boss menu
func notify_project_taken():
	if not is_active():
		return
	if current_step == Step.STEP_2_TAKE_PROJECT:
		advance_to_step(Step.STEP_3_WAIT_MEETING)

# General notification when any project is taken (called unconditionally)
func notify_any_project_taken():
	if is_active() and current_step == Step.STEP_2_TAKE_PROJECT:
		advance_to_step(Step.STEP_3_WAIT_MEETING)
	_total_projects_taken += 1
	if _total_projects_taken >= 2:
		show_hint("hint_second_project")

# Step 3 → 4: boss meeting/discussion finished
func notify_discussion_finished():
	if not is_active():
		return
	if current_step == Step.STEP_3_WAIT_MEETING:
		advance_to_step(Step.STEP_4_GO_TO_HR)

# Step 4 → 5: player entered HR desk radius
func notify_player_near_hr():
	if not is_active():
		return
	if current_step == Step.STEP_4_GO_TO_HR:
		advance_to_step(Step.STEP_5_HIRE_BA)

# Step 5 → 6: BA worker hired
func notify_worker_hired():
	if not is_active():
		return
	if current_step == Step.STEP_5_HIRE_BA:
		advance_to_step(Step.STEP_6_SEAT_WORKER)

# General notification when any employee is hired (called unconditionally)
func notify_any_worker_hired():
	if is_active() and current_step == Step.STEP_5_HIRE_BA:
		advance_to_step(Step.STEP_6_SEAT_WORKER)
	var npc_count = get_tree().get_nodes_in_group("npc").size()
	if npc_count >= 2:
		show_hint("hint_second_employee")

# Step 6 → 7: player approached a free desk
func notify_player_near_free_desk():
	if not is_active():
		return
	if current_step == Step.STEP_6_SEAT_WORKER:
		advance_to_step(Step.STEP_7_ASSIGN_DESK)

# Step 7 → 8: worker assigned to desk
func notify_worker_assigned():
	if not is_active():
		return
	if current_step == Step.STEP_7_ASSIGN_DESK:
		advance_to_step(Step.STEP_8_GO_TO_PM_DESK)

# Step 8 → 9: player entered PM desk radius
func notify_player_near_pm_desk():
	if not is_active():
		return
	if current_step == Step.STEP_8_GO_TO_PM_DESK:
		advance_to_step(Step.STEP_9_START_PROJECT)

# Step 9: project started (IN_PROGRESS) — set flag, wait for screen close
func notify_project_started():
	if not is_active():
		return
	if current_step == Step.STEP_9_START_PROJECT:
		_project_started_in_step9 = true

# Step 9 → 9B: project management screen closed after project was started
func notify_project_screen_closed():
	if not is_active():
		return
	if current_step == Step.STEP_9_START_PROJECT and _project_started_in_step9:
		advance_to_step(Step.STEP_9B_PROJECT_LAUNCHED)

# Step 10 → done: end day pressed
func notify_end_day():
	if not is_active():
		return
	if current_step == Step.STEP_10_END_DAY:
		GameState.tutorial_completed = true
		current_step = Step.NONE
		emit_signal("tutorial_completed")
		print("📖 Tutorial completed!")

# ─── Day 2+ one-time hint system ────────────────────

func is_hint_shown(hint_id: String) -> bool:
	return shown_hints.get(hint_id, false)

func show_hint(hint_id: String):
	if is_hint_shown(hint_id):
		return
	if not GameState.tutorial_completed:
		return  # Day 2+ hints only after Day 1 tutorial is done
	shown_hints[hint_id] = true
	emit_signal("hint_triggered", hint_id)

# ─── Hint trigger handlers ───────────────────────────

func _on_day_started_hint(day_number: int):
	if day_number == 2:
		_pending_morning_hint = "hint_day2_morning"
	elif day_number == 8:
		_pending_morning_hint = "hint_day8_morning"
	elif day_number == 15:
		_pending_morning_hint = "hint_day15_morning"

func _on_time_tick_hint(h: int, _m: int):
	if _pending_morning_hint != "" and h >= 8 and not GameTime.is_night_skip:
		var hint_id = _pending_morning_hint
		_pending_morning_hint = ""
		show_hint(hint_id)

func _on_boss_trust_changed_hint(new_trust: int):
	if new_trust > 0:
		show_hint("hint_first_boss_trust")

func _on_project_finished_hint(proj: ProjectData):
	# project_finished fires on success; project_failed fires on hard deadline miss.
	# So is_finished_on_time() == false here means soft deadline was missed, not hard.
	if not proj.is_finished_on_time(GameTime.day):
		show_hint("hint_soft_deadline_failed")

func _on_event_triggered_hint(event_data: Dictionary):
	if event_data.get("id", "") == "day_off":
		show_hint("hint_first_day_off_request")

func _on_pm_xp_changed_hint(_new_xp: int, _new_sp: int):
	if PMData.get_level() >= 2:
		show_hint("hint_first_pm_level")

# ─── Tutorial project / candidate ───────────────────

func create_tutorial_project() -> ProjectData:
	if _tutorial_project != null:
		return _tutorial_project
	var proj = ProjectData.new()
	proj.title = "PROJ_WRITE_TZ"
	proj.category = "micro"
	proj.client_id = ""
	proj.hard_days_budget = 10
	proj.soft_days_budget = 6
	proj.budget = 150
	proj.soft_deadline_penalty_percent = 10
	proj.stages = [{
		"type": "BA",
		"amount": 600,
		"progress": 0.0,
		"workers": [],
		"plan_start": 0.0,
		"plan_duration": 0.0,
		"actual_start": -1.0,
		"actual_end": -1.0,
		"is_completed": false,
	}]
	_tutorial_project = proj
	return proj

func get_tutorial_project() -> ProjectData:
	return _tutorial_project

func create_tutorial_candidate() -> EmployeeData:
	var emp = EmployeeData.new()
	emp.employee_name = "Алексей Смирнов"
	emp.name_ru = "Алексей Смирнов"
	emp.name_en = "Alex Smith"
	emp.gender = "male"
	emp.job_title = "Business Analyst"
	emp.employee_level = 3  # Middle
	emp.employee_xp = 0
	emp.skill_business_analysis = EmployeeData.SKILL_TABLE[3]  # 145
	emp.skill_backend = 0
	emp.skill_qa = 0
	emp.employment_type = "freelancer"
	emp.monthly_salary = 1200
	emp.current_energy = 100.0
	emp.mood = 70.0
	emp.traits.clear()
	emp.trait_text = ""
	emp.onboarding_hours_left = 0.0  # Skip onboarding for tutorial
	_tutorial_candidate = emp
	return emp

func get_tutorial_candidate() -> EmployeeData:
	return _tutorial_candidate
