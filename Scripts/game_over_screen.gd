extends Control

# ===================================================
# === GAME OVER SCREEN ==============================
# ===================================================
# Shows a "You're Fired!" card over the game.
# Style matches tutorial_overlay.gd.

const COLOR_PRIMARY = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_DANGER  = Color(0.85, 0.25, 0.25, 1)
const COLOR_WHITE   = Color(1, 1, 1, 1)
const COLOR_GRAY    = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK    = Color(0.2, 0.2, 0.2, 1)
const COLOR_BORDER  = Color(0, 0, 0, 1)

var _reason_text: String = ""

var _overlay: ColorRect
var _card_window: PanelContainer
var _reason_label: RichTextLabel
var _btn: Button

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

	_build_ui()
	_reason_label.text = _reason_text

	GameTime.set_paused(true)

	if UITheme:
		UITheme.fade_in(_card_window, 0.25)

# Called before adding to the tree to set the dismissal text
func setup(reason: String) -> void:
	_reason_text = reason
	if _reason_label:
		_reason_label.text = reason

func _build_ui():
	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Card: 620×420, centered
	_card_window = PanelContainer.new()
	_card_window.custom_minimum_size = Vector2(620, 420)
	_card_window.set_anchors_preset(Control.PRESET_CENTER)
	_card_window.offset_left = -310
	_card_window.offset_top = -210
	_card_window.offset_right = 310
	_card_window.offset_bottom = 210
	_card_window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card_window.grow_vertical = Control.GROW_DIRECTION_BOTH

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = COLOR_WHITE
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3
	card_style.border_color = COLOR_BORDER
	card_style.corner_radius_top_left = 22
	card_style.corner_radius_top_right = 22
	card_style.corner_radius_bottom_right = 20
	card_style.corner_radius_bottom_left = 20
	if UITheme:
		UITheme.apply_shadow(card_style, false)
	_card_window.add_theme_stylebox_override("panel", card_style)
	add_child(_card_window)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_card_window.add_child(main_vbox)

	# Header (red)
	var header = Panel.new()
	header.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_DANGER
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = tr("GAMEOVER_TITLE")
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.offset_left = -180
	title_lbl.offset_top = -11.5
	title_lbl.offset_right = 180
	title_lbl.offset_bottom = 11.5
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
	title_lbl.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(title_lbl, "bold")
	header.add_child(title_lbl)

	# Content area
	var content_margin = MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 30)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_right", 30)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	main_vbox.add_child(content_margin)

	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 12)
	content_margin.add_child(content_vbox)

	# Emoji
	var emoji_lbl = Label.new()
	emoji_lbl.text = "😤"
	emoji_lbl.add_theme_font_size_override("font_size", 42)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(emoji_lbl)

	# "Boss says..." subtitle
	var boss_says = Label.new()
	boss_says.text = tr("GAMEOVER_BOSS_SAYS")
	boss_says.add_theme_color_override("font_color", COLOR_GRAY)
	boss_says.add_theme_font_size_override("font_size", 13)
	boss_says.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if UITheme:
		UITheme.apply_font(boss_says, "regular")
	content_vbox.add_child(boss_says)

	# Reason text
	_reason_label = RichTextLabel.new()
	_reason_label.bbcode_enabled = false
	_reason_label.fit_content = true
	_reason_label.scroll_active = false
	_reason_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reason_label.add_theme_color_override("default_color", COLOR_DARK)
	_reason_label.add_theme_font_size_override("normal_font_size", 15)
	if UITheme:
		UITheme.apply_font(_reason_label, "regular")
	content_vbox.add_child(_reason_label)

	# Bottom button area
	var bottom_margin = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 30)
	bottom_margin.add_theme_constant_override("margin_right", 30)
	bottom_margin.add_theme_constant_override("margin_bottom", 20)
	bottom_margin.add_theme_constant_override("margin_top", 5)
	main_vbox.add_child(bottom_margin)

	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 10)
	bottom_margin.add_child(bottom_hbox)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	# "Main Menu" button
	_btn = Button.new()
	_btn.text = tr("GAMEOVER_BTN_MAIN_MENU")
	_btn.custom_minimum_size = Vector2(200, 44)
	_btn.focus_mode = Control.FOCUS_NONE

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = COLOR_WHITE
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = COLOR_DANGER
	btn_normal.corner_radius_top_left = 20
	btn_normal.corner_radius_top_right = 20
	btn_normal.corner_radius_bottom_right = 20
	btn_normal.corner_radius_bottom_left = 20

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = COLOR_DANGER
	btn_hover.border_width_left = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_bottom = 2
	btn_hover.border_color = COLOR_DANGER
	btn_hover.corner_radius_top_left = 20
	btn_hover.corner_radius_top_right = 20
	btn_hover.corner_radius_bottom_right = 20
	btn_hover.corner_radius_bottom_left = 20

	_btn.add_theme_stylebox_override("normal", btn_normal)
	_btn.add_theme_stylebox_override("hover", btn_hover)
	_btn.add_theme_stylebox_override("pressed", btn_hover)
	_btn.add_theme_color_override("font_color", COLOR_DANGER)
	_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	_btn.add_theme_font_size_override("font_size", 16)
	if UITheme:
		UITheme.apply_font(_btn, "semibold")

	_btn.pressed.connect(_on_main_menu_pressed)
	bottom_hbox.add_child(_btn)

func _on_main_menu_pressed():
	Engine.time_scale = 1.0
	GameTime.set_paused(false)
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
