extends PanelContainer

signal tab_pressed(tab_name: String)

@onready var hbox = $MarginContainer/HBoxContainer

var btn_style_normal: StyleBoxFlat
var btn_style_hover: StyleBoxFlat

var _projects_btn: Button = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(1, 1, 1, 1)
	btn_style_normal.border_width_left = 2
	btn_style_normal.border_width_top = 2
	btn_style_normal.border_width_right = 2
	btn_style_normal.border_width_bottom = 2
	btn_style_normal.border_color = Color(1, 1, 1, 0.6)
	btn_style_normal.corner_radius_top_left = 10
	btn_style_normal.corner_radius_top_right = 10
	btn_style_normal.corner_radius_bottom_right = 10
	btn_style_normal.corner_radius_bottom_left = 10

	btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.9, 0.93, 1.0, 1)
	btn_style_hover.border_width_left = 2
	btn_style_hover.border_width_top = 2
	btn_style_hover.border_width_right = 2
	btn_style_hover.border_width_bottom = 2
	btn_style_hover.border_color = Color(1, 1, 1, 1)
	btn_style_hover.corner_radius_top_left = 10
	btn_style_hover.corner_radius_top_right = 10
	btn_style_hover.corner_radius_bottom_right = 10
	btn_style_hover.corner_radius_bottom_left = 10

	_add_tab_button(tr("TAB_EMPLOYEES"), "employees")
	_add_tab_button(tr("TAB_CLIENTS"), "clients")
	_add_tab_button(tr("TAB_PM_SKILLS"), "pm_skills")
	_add_tab_button(tr("TAB_BOSS"), "boss")
	_add_tab_button(tr("BOTTOMBAR_MY_LIFE"), "my_life")
	_add_tab_button(tr("TAB_REPORTS"), "reports")

	# Projects button — visible only if project_management_soft is bought
	_projects_btn = Button.new()
	_projects_btn.text = tr("BOTTOMBAR_PROJECTS")
	_projects_btn.custom_minimum_size = Vector2(180, 36)
	_projects_btn.focus_mode = Control.FOCUS_NONE
	_projects_btn.add_theme_stylebox_override("normal", btn_style_normal)
	_projects_btn.add_theme_stylebox_override("hover", btn_style_hover)
	_projects_btn.add_theme_stylebox_override("pressed", btn_style_hover)
	_projects_btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	_projects_btn.add_theme_color_override("font_hover_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	_projects_btn.add_theme_color_override("font_pressed_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	_projects_btn.add_theme_font_size_override("font_size", 15)
	if UITheme:
		UITheme.apply_font(_projects_btn, "semibold")
	_projects_btn.pressed.connect(_on_tab_pressed.bind("projects_menu"))
	hbox.add_child(_projects_btn)

	_update_projects_btn_visibility()

	var gs = get_node_or_null("/root/GameState")
	if gs and not gs.office_upgrade_purchased.is_connected(_on_office_upgrade_purchased):
		gs.office_upgrade_purchased.connect(_on_office_upgrade_purchased)

func _update_projects_btn_visibility():
	if _projects_btn == null:
		return
	var gs = get_node_or_null("/root/GameState")
	_projects_btn.visible = gs != null and gs.office_upgrades.get("project_management_soft", false)

func _on_office_upgrade_purchased(upgrade_id: String):
	if upgrade_id == "project_management_soft":
		_update_projects_btn_visibility()

func _add_tab_button(label_text: String, tab_name: String):
	var btn = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(180, 36)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", btn_style_normal)
	btn.add_theme_stylebox_override("hover", btn_style_hover)
	btn.add_theme_stylebox_override("pressed", btn_style_hover)
	btn.add_theme_color_override("font_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.17254902, 0.30980393, 0.5686275, 1))
	btn.add_theme_font_size_override("font_size", 15)
	# Применяем шрифт Inter
	if UITheme:
		UITheme.apply_font(btn, "semibold")
	btn.pressed.connect(_on_tab_pressed.bind(tab_name))
	hbox.add_child(btn)

func _on_tab_pressed(tab_name: String):
	emit_signal("tab_pressed", tab_name)
