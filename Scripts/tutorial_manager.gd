extends Node

# ===================================================
# === TUTORIAL MANAGER (Autoload Singleton) =========
# ===================================================
# Manages tutorial state, step progression, and provides
# helper data (tutorial project, tutorial candidate).

signal tutorial_step_changed(step: int)
signal tutorial_completed

enum Step {
	NONE = 0,
	STEP_1_MOVE_TO_BOSS = 1,    # Move to boss desk
	STEP_2_TAKE_PROJECT = 2,    # Press E, take project
	STEP_3_WAIT_MEETING = 3,    # Wait for 4h meeting
	STEP_4_GO_TO_HR = 4,        # Go to HR desk
	STEP_5_HIRE_BA = 5,         # Hire BA (search + hire)
	STEP_6_SEAT_WORKER = 6,     # Seat worker at desk
	STEP_7_ASSIGN_DESK = 7,     # Assign at desk (approach)
	STEP_8_GO_TO_PM_DESK = 8,   # Go to PM desk
	STEP_9_START_PROJECT = 9,   # Start project
	STEP_10_END_DAY = 10,       # End the day
}

var current_step: int = Step.NONE

# Cached tutorial project / candidate
var _tutorial_project: ProjectData = null
var _tutorial_candidate: EmployeeData = null

# Step 5: track sub-phase (searching vs hiring)
var _searching_for_ba: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_active() -> bool:
	# Tutorial is active on day 0 if not yet completed
	return GameTime.day == 0 and not GameState.tutorial_completed

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

# Step 9 → 10: project started (IN_PROGRESS)
func notify_project_started():
	if not is_active():
		return
	if current_step == Step.STEP_9_START_PROJECT:
		advance_to_step(Step.STEP_10_END_DAY)

# Step 10 → done: end day pressed
func notify_end_day():
	if not is_active():
		return
	if current_step == Step.STEP_10_END_DAY:
		GameState.tutorial_completed = true
		GameTime.day = 1
		current_step = Step.NONE
		emit_signal("tutorial_completed")
		print("📖 Tutorial completed!")

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
