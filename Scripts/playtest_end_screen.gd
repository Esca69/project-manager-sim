extends Control

# ===================================================
# === PLAYTEST END SCREEN ===========================
# ===================================================
# Shows a "Thank you for playtesting!" card over the game.
# Style matches game_over_screen.gd.

const COLOR_PRIMARY = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_ACCENT  = Color(0.18, 0.72, 0.35, 1)
const COLOR_ACCENT_HOVER = Color(0.22, 0.82, 0.42, 1)
const COLOR_WHITE   = Color(1, 1, 1, 1)
const COLOR_GRAY    = Color(0.5, 0.5, 0.5, 1)
const COLOR_DARK    = Color(0.2, 0.2, 0.2, 1)
const COLOR_BORDER  = Color(0, 0, 0, 1)

const FEEDBACK_URL = "https://docs.google.com/forms/d/e/1FAIpQLSc0JJVKE4665icJ70x1Ja4zuT2KmqCOHURLNbHD2nMHHXE98A/viewform?usp=dialog"
const WISHLIST_URL = "https://store.steampowered.com/app/4454610/Project_manager_SIM/"

var _overlay: ColorRect
var _card_window: PanelContainer
var _btn_wishlist: Button
var _wishlist_tween: Tween

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

	_build_ui()

	GameTime.set_paused(true)

	if UITheme:
		UITheme.fade_in(_card_window, 0.25)

func _build_ui():
	# Dark overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.5)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Card: 650×480, centered
	_card_window = PanelContainer.new()
	_card_window.custom_minimum_size = Vector2(650, 480)
	_card_window.set_anchors_preset(Control.PRESET_CENTER)
	_card_window.offset_left = -325
	_card_window.offset_top = -240
	_card_window.offset_right = 325
	_card_window.offset_bottom = 240
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

	# Header (blue / COLOR_PRIMARY)
	var header = Panel.new()
	header.custom_minimum_size = Vector2(0, 40)
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = COLOR_PRIMARY
	header_style.corner_radius_top_left = 20
	header_style.corner_radius_top_right = 20
	header.add_theme_stylebox_override("panel", header_style)
	main_vbox.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = tr("PLAYTEST_END_TITLE")
	title_lbl.set_anchors_preset(Control.PRESET_CENTER)
	title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	title_lbl.offset_left = -200
	title_lbl.offset_top = -11.5
	title_lbl.offset_right = 200
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

	# Big emoji
	var emoji_lbl = Label.new()
	emoji_lbl.text = "🎉"
	emoji_lbl.add_theme_font_size_override("font_size", 48)
	emoji_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(emoji_lbl)

	# Thank you text
	var thank_you = RichTextLabel.new()
	thank_you.bbcode_enabled = false
	thank_you.fit_content = true
	thank_you.scroll_active = false
	thank_you.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thank_you.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thank_you.add_theme_color_override("default_color", COLOR_DARK)
	thank_you.add_theme_font_size_override("normal_font_size", 15)
	thank_you.text = tr("PLAYTEST_END_TEXT")
	if UITheme:
		UITheme.apply_font(thank_you, "regular")
	content_vbox.add_child(thank_you)

	# Bottom button area
	var bottom_margin = MarginContainer.new()
	bottom_margin.add_theme_constant_override("margin_left", 30)
	bottom_margin.add_theme_constant_override("margin_right", 30)
	bottom_margin.add_theme_constant_override("margin_bottom", 20)
	bottom_margin.add_theme_constant_override("margin_top", 5)
	main_vbox.add_child(bottom_margin)

	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 10)
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_margin.add_child(bottom_hbox)

	# Button 1: Feedback (outline, COLOR_PRIMARY)
	var btn_feedback = _make_button_outline(
		"📝 " + tr("PLAYTEST_BTN_FEEDBACK"),
		COLOR_PRIMARY
	)
	btn_feedback.pressed.connect(func(): OS.shell_open(FEEDBACK_URL))
	bottom_hbox.add_child(btn_feedback)

	# Button 2: Wishlist (filled green, prominent, with pulse)
	_btn_wishlist = _make_button_filled(
		"⭐ " + tr("PLAYTEST_BTN_WISHLIST"),
		COLOR_ACCENT,
		COLOR_ACCENT_HOVER
	)
	_btn_wishlist.pressed.connect(func(): OS.shell_open(WISHLIST_URL))
	bottom_hbox.add_child(_btn_wishlist)
	_start_wishlist_pulse()

	# Button 3: Main Menu (outline, gray)
	var btn_main_menu = _make_button_outline(
		"🏠 " + tr("PLAYTEST_BTN_MAIN_MENU"),
		COLOR_GRAY
	)
	btn_main_menu.pressed.connect(_on_main_menu_pressed)
	bottom_hbox.add_child(btn_main_menu)

func _start_wishlist_pulse():
	if _wishlist_tween:
		_wishlist_tween.kill()
	_wishlist_tween = create_tween()
	_wishlist_tween.set_loops()
	_wishlist_tween.tween_property(_btn_wishlist, "modulate:a", 0.65, 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_wishlist_tween.tween_property(_btn_wishlist, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _make_button_outline(btn_text: String, accent: Color) -> Button:
	var btn = Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(180, 44)
	btn.focus_mode = Control.FOCUS_NONE

	var style_n = StyleBoxFlat.new()
	style_n.bg_color = COLOR_WHITE
	style_n.border_width_left = 2
	style_n.border_width_top = 2
	style_n.border_width_right = 2
	style_n.border_width_bottom = 2
	style_n.border_color = accent
	style_n.corner_radius_top_left = 20
	style_n.corner_radius_top_right = 20
	style_n.corner_radius_bottom_right = 20
	style_n.corner_radius_bottom_left = 20

	var style_h = style_n.duplicate()
	style_h.bg_color = accent
	style_h.border_color = accent

	var style_p = style_n.duplicate()
	style_p.bg_color = accent.darkened(0.1)
	style_p.border_color = accent.darkened(0.1)

	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_p)
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	btn.add_theme_font_size_override("font_size", 15)
	if UITheme:
		UITheme.apply_font(btn, "semibold")
	return btn

func _make_button_filled(btn_text: String, bg_color: Color, hover_color: Color) -> Button:
	var btn = Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(180, 44)
	btn.focus_mode = Control.FOCUS_NONE

	var style_n = StyleBoxFlat.new()
	style_n.bg_color = bg_color
	style_n.corner_radius_top_left = 20
	style_n.corner_radius_top_right = 20
	style_n.corner_radius_bottom_right = 20
	style_n.corner_radius_bottom_left = 20
	style_n.shadow_color = Color(bg_color.r, bg_color.g, bg_color.b, 0.3)
	style_n.shadow_size = 5
	style_n.shadow_offset = Vector2(0, 3)

	var style_h = style_n.duplicate()
	style_h.bg_color = hover_color
	style_h.shadow_size = 8

	var style_p = style_n.duplicate()
	style_p.bg_color = bg_color.darkened(0.15)
	style_p.shadow_size = 2

	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_p)
	btn.add_theme_color_override("font_color", COLOR_WHITE)
	btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	btn.add_theme_font_size_override("font_size", 15)
	if UITheme:
		UITheme.apply_font(btn, "semibold")
	return btn

func _on_main_menu_pressed():
	Engine.time_scale = 1.0
	GameTime.set_paused(false)
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
