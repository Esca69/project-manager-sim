class_name ProjectCardHelpers
extends RefCounted

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const TOOLTIP_PANEL_OFFSET_X = 10
const TOOLTIP_PANEL_OFFSET_Y = -5
const TOOLTIP_BUTTON_OFFSET_X = 28
const TOOLTIP_BUTTON_OFFSET_Y = -10
const TOOLTIP_OVERFLOW_FIX_Y = 20

const CATEGORY_COLORS := {
	"micro": Color(0.29, 0.69, 0.31, 1),
	"simple": Color(0.30, 0.65, 0.85, 1),
	"easy": Color(0.17, 0.31, 0.57, 1),
}

const ROLE_COLORS := {
	"ba": Color(0.9, 0.55, 0.2, 1),
	"dev": Color(0.30, 0.65, 0.85, 1),
	"qa": Color(0.40, 0.60, 0.45, 1),
}

static func _resolve_tooltip_group(parent: Control) -> String:
	if parent and parent.is_in_group("project_selection_ui"):
		return "project_selection_tooltip"
	return "project_list_tooltip"

static func create_category_badge(category_id: String, parent: Control) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "category_badge"

	var category_key = category_id.to_lower()
	var color: Color = CATEGORY_COLORS.get(category_key, COLOR_BLUE)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = color
	style.bg_color = Color(color.r, color.g, color.b, 0.18)
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	var lbl = Label.new()
	lbl.text = category_key.to_upper()
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	if UITheme:
		UITheme.apply_font(lbl, "semibold")
	margin.add_child(lbl)

	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS

	var tooltip_key = "PROJ_CAT_TOOLTIP_" + category_key.to_upper()
	var tooltip_text = tr(tooltip_key)
	if tooltip_text == tooltip_key:
		tooltip_text = tr("PROJ_CAT_TOOLTIP_UNKNOWN")
	attach_tooltip(panel, parent, tooltip_text, color, _resolve_tooltip_group(parent))

	return panel

static func create_help_button() -> Button:
	var btn = Button.new()
	btn.text = "?"
	btn.custom_minimum_size = Vector2(22, 22)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", COLOR_BLUE)

	var bstyle = StyleBoxFlat.new()
	bstyle.bg_color = Color(1, 1, 1, 1)
	bstyle.border_width_left = 2
	bstyle.border_width_top = 2
	bstyle.border_width_right = 2
	bstyle.border_width_bottom = 2
	bstyle.border_color = COLOR_BLUE
	bstyle.corner_radius_top_left = 11
	bstyle.corner_radius_top_right = 11
	bstyle.corner_radius_bottom_right = 11
	bstyle.corner_radius_bottom_left = 11
	btn.add_theme_stylebox_override("normal", bstyle)

	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.92, 0.94, 1.0, 1)
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = COLOR_BLUE
	hover_style.corner_radius_top_left = 11
	hover_style.corner_radius_top_right = 11
	hover_style.corner_radius_bottom_right = 11
	hover_style.corner_radius_bottom_left = 11
	btn.add_theme_stylebox_override("hover", hover_style)
	if UITheme:
		UITheme.apply_font(btn, "semibold")

	return btn

static func attach_tooltip(target: Control, parent: Control, tooltip_text: String, color: Color, group_name: String):
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	var tooltip_ref: Array = [null]

	target.mouse_entered.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		var tp = TraitUIHelper.create_tooltip(tooltip_text, color)
		parent.add_child(tp)
		tp.add_to_group(group_name)

		await parent.get_tree().process_frame
		if not is_instance_valid(tp):
			return

		var target_global = target.global_position
		var target_pos = Vector2(
			target_global.x + target.size.x + TOOLTIP_PANEL_OFFSET_X,
			target_global.y + TOOLTIP_PANEL_OFFSET_Y
		)
		if target is Button:
			target_pos = Vector2(
				target_global.x + TOOLTIP_BUTTON_OFFSET_X,
				target_global.y + TOOLTIP_BUTTON_OFFSET_Y
			)

		var viewport_height = parent.get_viewport_rect().size.y
		if target_pos.y + tp.size.y > viewport_height:
			target_pos.y = target_global.y - tp.size.y + TOOLTIP_OVERFLOW_FIX_Y

		tp.global_position = target_pos
		tooltip_ref[0] = tp
	)

	target.mouse_exited.connect(func():
		if tooltip_ref[0] != null and is_instance_valid(tooltip_ref[0]):
			tooltip_ref[0].queue_free()
		tooltip_ref[0] = null
	)

static func get_role_color(role_type: String) -> Color:
	return ROLE_COLORS.get(str(role_type).to_lower(), COLOR_BLUE)
