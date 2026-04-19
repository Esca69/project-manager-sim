extends Control

signal contract_signed(project)

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)
const COLOR_GRAY = Color(0.5, 0.5, 0.5, 1)
const COLOR_GREEN = Color(0.29803923, 0.6862745, 0.3137255, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _list_vbox: VBoxContainer
var _confirm_btn: Button

var _project: SupportProjectData = null
var _selected_sla: String = ""
var _was_paused: bool = false

func _tr_format_safe(key: String, args, fallback: String) -> String:
    var text = tr(key)
    if text.find("%") >= 0:
        return text % args
    return fallback

func _ready():
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS
    z_index = 98
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build_ui()

func open_for_project(proj: SupportProjectData):
    if proj == null:
        return
    _project = proj
    _selected_sla = ""
    _was_paused = GameTime.is_game_paused
    GameTime.set_paused(true)
    _rebuild_cards()
    mouse_filter = Control.MOUSE_FILTER_STOP
    if UITheme:
        UITheme.fade_in(self, 0.2)
    else:
        visible = true

func _close_window():
    if not _was_paused:
        GameTime.set_paused(false)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if UITheme:
        UITheme.fade_out(self, 0.15)
    else:
        visible = false

func _build_ui():
    _overlay = ColorRect.new()
    _overlay.color = Color(0, 0, 0, 0.45)
    _overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_overlay)

    var center = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    _window = PanelContainer.new()
    _window.custom_minimum_size = Vector2(550, 0)
    var win_style = StyleBoxFlat.new()
    win_style.bg_color = COLOR_WHITE
    win_style.border_width_left = 3
    win_style.border_width_top = 3
    win_style.border_width_right = 3
    win_style.border_width_bottom = 3
    win_style.border_color = Color(0, 0, 0, 1)
    win_style.corner_radius_top_left = 18
    win_style.corner_radius_top_right = 18
    win_style.corner_radius_bottom_right = 16
    win_style.corner_radius_bottom_left = 16
    if UITheme:
        UITheme.apply_shadow(win_style, false)
    _window.add_theme_stylebox_override("panel", win_style)
    center.add_child(_window)

    var main_vbox = VBoxContainer.new()
    main_vbox.add_theme_constant_override("separation", 0)
    _window.add_child(main_vbox)

    var header = Panel.new()
    header.custom_minimum_size = Vector2(0, 44)
    var hdr_style = StyleBoxFlat.new()
    hdr_style.bg_color = COLOR_BLUE
    hdr_style.corner_radius_top_left = 16
    hdr_style.corner_radius_top_right = 16
    header.add_theme_stylebox_override("panel", hdr_style)
    main_vbox.add_child(header)

    var title_lbl = Label.new()
    title_lbl.text = tr("SLA_SELECTION_TITLE")
    title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
    title_lbl.add_theme_font_size_override("font_size", 16)
    title_lbl.set_anchors_preset(Control.PRESET_CENTER)
    title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
    title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
    title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if UITheme:
        UITheme.apply_font(title_lbl, "bold")
    header.add_child(title_lbl)

    var content_margin = MarginContainer.new()
    content_margin.add_theme_constant_override("margin_left", 20)
    content_margin.add_theme_constant_override("margin_top", 16)
    content_margin.add_theme_constant_override("margin_right", 20)
    content_margin.add_theme_constant_override("margin_bottom", 16)
    main_vbox.add_child(content_margin)

    var content_vbox = VBoxContainer.new()
    content_vbox.add_theme_constant_override("separation", 14)
    content_margin.add_child(content_vbox)

    var cards_scroll = ScrollContainer.new()
    cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    cards_scroll.custom_minimum_size = Vector2(0, 260)
    cards_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_vbox.add_child(cards_scroll)

    _list_vbox = VBoxContainer.new()
    _list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list_vbox.add_theme_constant_override("separation", 8)
    cards_scroll.add_child(_list_vbox)

    var confirm_center = CenterContainer.new()
    content_vbox.add_child(confirm_center)

    _confirm_btn = Button.new()
    _confirm_btn.text = tr("SLA_CONFIRM")
    _confirm_btn.custom_minimum_size = Vector2(220, 40)
    _confirm_btn.disabled = true
    _confirm_btn.add_theme_font_size_override("font_size", 14)
    _confirm_btn.focus_mode = Control.FOCUS_NONE
    if UITheme:
        UITheme.apply_font(_confirm_btn, "semibold")
    var cfm_n = StyleBoxFlat.new()
    cfm_n.bg_color = COLOR_WHITE
    cfm_n.border_width_left = 2
    cfm_n.border_width_top = 2
    cfm_n.border_width_right = 2
    cfm_n.border_width_bottom = 2
    cfm_n.border_color = COLOR_GREEN
    cfm_n.corner_radius_top_left = 16
    cfm_n.corner_radius_top_right = 16
    cfm_n.corner_radius_bottom_right = 16
    cfm_n.corner_radius_bottom_left = 16
    var cfm_h = StyleBoxFlat.new()
    cfm_h.bg_color = COLOR_GREEN
    cfm_h.border_width_left = 2
    cfm_h.border_width_top = 2
    cfm_h.border_width_right = 2
    cfm_h.border_width_bottom = 2
    cfm_h.border_color = COLOR_GREEN
    cfm_h.corner_radius_top_left = 16
    cfm_h.corner_radius_top_right = 16
    cfm_h.corner_radius_bottom_right = 16
    cfm_h.corner_radius_bottom_left = 16
    _confirm_btn.add_theme_stylebox_override("normal", cfm_n)
    _confirm_btn.add_theme_stylebox_override("hover", cfm_h)
    _confirm_btn.add_theme_stylebox_override("pressed", cfm_h)
    _confirm_btn.add_theme_color_override("font_color", COLOR_GREEN)
    _confirm_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
    _confirm_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
    _confirm_btn.pressed.connect(_on_confirm_pressed)
    confirm_center.add_child(_confirm_btn)

    var footer_margin = MarginContainer.new()
    footer_margin.add_theme_constant_override("margin_top", 4)
    content_vbox.add_child(footer_margin)

    var close_center = CenterContainer.new()
    footer_margin.add_child(close_center)

    var close_btn = Button.new()
    close_btn.text = tr("UI_CLOSE")
    close_btn.custom_minimum_size = Vector2(160, 36)
    close_btn.add_theme_font_size_override("font_size", 14)
    close_btn.focus_mode = Control.FOCUS_NONE
    if UITheme:
        UITheme.apply_font(close_btn, "semibold")
    var cbtn_style = StyleBoxFlat.new()
    cbtn_style.bg_color = COLOR_WHITE
    cbtn_style.border_width_left = 2
    cbtn_style.border_width_top = 2
    cbtn_style.border_width_right = 2
    cbtn_style.border_width_bottom = 2
    cbtn_style.border_color = COLOR_GRAY
    cbtn_style.corner_radius_top_left = 16
    cbtn_style.corner_radius_top_right = 16
    cbtn_style.corner_radius_bottom_right = 16
    cbtn_style.corner_radius_bottom_left = 16
    var cbtn_hover = StyleBoxFlat.new()
    cbtn_hover.bg_color = COLOR_GRAY
    cbtn_hover.border_width_left = 2
    cbtn_hover.border_width_top = 2
    cbtn_hover.border_width_right = 2
    cbtn_hover.border_width_bottom = 2
    cbtn_hover.border_color = COLOR_GRAY
    cbtn_hover.corner_radius_top_left = 16
    cbtn_hover.corner_radius_top_right = 16
    cbtn_hover.corner_radius_bottom_right = 16
    cbtn_hover.corner_radius_bottom_left = 16
    close_btn.add_theme_stylebox_override("normal", cbtn_style)
    close_btn.add_theme_stylebox_override("hover", cbtn_hover)
    close_btn.add_theme_stylebox_override("pressed", cbtn_hover)
    close_btn.add_theme_color_override("font_color", COLOR_GRAY)
    close_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
    close_btn.pressed.connect(_close_window)
    close_center.add_child(close_btn)

func _rebuild_cards():
    for c in _list_vbox.get_children():
        c.queue_free()

    var definitions = [
        {"id": "strict", "icon": "🔴", "name_key": "SLA_STRICT", "desc_key": "SLA_STRICT_DESC"},
        {"id": "medium", "icon": "🟡", "name_key": "SLA_MEDIUM", "desc_key": "SLA_MEDIUM_DESC"},
        {"id": "easy", "icon": "🟢", "name_key": "SLA_EASY", "desc_key": "SLA_EASY_DESC"},
    ]

    for d in definitions:
        _list_vbox.add_child(_make_sla_card(d))
    _confirm_btn.disabled = _selected_sla == ""

func _make_sla_card(definition: Dictionary) -> PanelContainer:
    var card = PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var selected = _selected_sla == str(definition["id"])
    var card_style = StyleBoxFlat.new()
    card_style.bg_color = Color(0.98, 0.98, 0.98, 1)
    card_style.border_width_left = 2 if selected else 1
    card_style.border_width_top = 2 if selected else 1
    card_style.border_width_right = 2 if selected else 1
    card_style.border_width_bottom = 2 if selected else 1
    card_style.border_color = COLOR_BLUE if selected else COLOR_BORDER
    card_style.corner_radius_top_left = 8
    card_style.corner_radius_top_right = 8
    card_style.corner_radius_bottom_right = 8
    card_style.corner_radius_bottom_left = 8
    card.add_theme_stylebox_override("panel", card_style)

    var m = MarginContainer.new()
    m.add_theme_constant_override("margin_left", 14)
    m.add_theme_constant_override("margin_top", 10)
    m.add_theme_constant_override("margin_right", 14)
    m.add_theme_constant_override("margin_bottom", 10)
    card.add_child(m)

    var h = HBoxContainer.new()
    h.add_theme_constant_override("separation", 12)
    m.add_child(h)

    var left = VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_theme_constant_override("separation", 4)
    h.add_child(left)

    var title = Label.new()
    title.text = "%s %s" % [definition["icon"], tr(definition["name_key"])]
    title.add_theme_font_size_override("font_size", 14)
    if UITheme:
        UITheme.apply_font(title, "semibold")
    left.add_child(title)

    var desc = Label.new()
    desc.text = tr(definition["desc_key"])
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.add_theme_font_size_override("font_size", 12)
    desc.add_theme_color_override("font_color", COLOR_GRAY)
    if UITheme:
        UITheme.apply_font(desc, "regular")
    left.add_child(desc)

    var rate = _project.daily_rate
    if str(definition["id"]) == "strict":
        rate = int(_project.daily_rate * 1.2)
    elif str(definition["id"]) == "easy":
        rate = int(_project.daily_rate * 0.8)
    var weekly_estimate = rate * 5

    var right = VBoxContainer.new()
    right.alignment = BoxContainer.ALIGNMENT_CENTER
    h.add_child(right)

    var rate_lbl = Label.new()
    rate_lbl.text = _tr_format_safe("SLA_DAILY_RATE", rate, "Rate: $%d/day" % rate)
    rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    rate_lbl.add_theme_color_override("font_color", COLOR_GREEN)
    rate_lbl.add_theme_font_size_override("font_size", 13)
    if UITheme:
        UITheme.apply_font(rate_lbl, "semibold")
    right.add_child(rate_lbl)

    var week_lbl = Label.new()
    week_lbl.text = _tr_format_safe("SLA_WEEKLY_ESTIMATE", weekly_estimate, "≈ $%d/week" % weekly_estimate)
    week_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    week_lbl.add_theme_font_size_override("font_size", 12)
    week_lbl.add_theme_color_override("font_color", COLOR_GRAY)
    if UITheme:
        UITheme.apply_font(week_lbl, "regular")
    right.add_child(week_lbl)

    var pick_btn = Button.new()
    pick_btn.text = tr("PROJ_SEL_BTN_SELECT")
    pick_btn.custom_minimum_size = Vector2(140, 34)
    pick_btn.add_theme_font_size_override("font_size", 13)
    pick_btn.focus_mode = Control.FOCUS_NONE
    if UITheme:
        UITheme.apply_font(pick_btn, "semibold")
    var btn_n = StyleBoxFlat.new()
    btn_n.bg_color = COLOR_WHITE
    btn_n.border_width_left = 2
    btn_n.border_width_top = 2
    btn_n.border_width_right = 2
    btn_n.border_width_bottom = 2
    btn_n.border_color = COLOR_BLUE
    btn_n.corner_radius_top_left = 16
    btn_n.corner_radius_top_right = 16
    btn_n.corner_radius_bottom_right = 16
    btn_n.corner_radius_bottom_left = 16
    var btn_h = StyleBoxFlat.new()
    btn_h.bg_color = COLOR_BLUE
    btn_h.border_width_left = 2
    btn_h.border_width_top = 2
    btn_h.border_width_right = 2
    btn_h.border_width_bottom = 2
    btn_h.border_color = COLOR_BLUE
    btn_h.corner_radius_top_left = 16
    btn_h.corner_radius_top_right = 16
    btn_h.corner_radius_bottom_right = 16
    btn_h.corner_radius_bottom_left = 16
    pick_btn.add_theme_stylebox_override("normal", btn_n)
    pick_btn.add_theme_stylebox_override("hover", btn_h)
    pick_btn.add_theme_stylebox_override("pressed", btn_h)
    pick_btn.add_theme_color_override("font_color", COLOR_BLUE)
    pick_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
    pick_btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)
    pick_btn.pressed.connect(func():
        _selected_sla = str(definition["id"])
        _rebuild_cards()
    )
    right.add_child(pick_btn)

    return card

func _on_confirm_pressed():
    if _project == null or _selected_sla == "":
        return
    _project.sla_level = _selected_sla
    if _project.week_start_day <= 0:
        _project.week_start_day = GameTime.day
    if not SupportProjectManager.add_support_project(_project):
        return

    var client = _project.get_client()
    var client_name = client.get_display_name() if client else _project.client_id
    var sla_name = tr("SLA_" + _selected_sla.to_upper())
    EventLog.add(_tr_format_safe("LOG_SUPPORT_CONTRACT_SIGNED", [client_name, sla_name], "Support contract with %s signed (SLA: %s)" % [client_name, sla_name]), EventLog.LogType.PROGRESS)
    if ScreenJuice:
        ScreenJuice.show_toast("🔧", tr("TOAST_SUPPORT_SIGNED"))

    emit_signal("contract_signed", _project)
    _close_window()

func _input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        _close_window()
        get_viewport().set_input_as_handled()
