extends Control

signal contract_signed(project)

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_BORDER = Color(0.8784314, 0.8784314, 0.8784314, 1)

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
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    z_index = 98
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _build_ui()

func open_for_project(proj: SupportProjectData):
    if proj == null:
        return
    _project = proj
    _selected_sla = ""
    _was_paused = GameTime.is_game_paused
    GameTime.set_paused(true)
    _rebuild_cards()
    if UITheme:
        UITheme.fade_in(self, 0.2)
    else:
        visible = true

func _close_window():
    if not _was_paused:
        GameTime.set_paused(false)
    if UITheme:
        UITheme.fade_out(self, 0.15)
    else:
        visible = false

func _build_ui():
    _overlay = ColorRect.new()
    _overlay.color = Color(0, 0, 0, 0.55)
    _overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_overlay)

    _window = PanelContainer.new()
    _window.custom_minimum_size = Vector2(700, 700)
    _window.set_anchors_preset(Control.PRESET_CENTER)
    _window.offset_left = -350
    _window.offset_top = -350
    _window.offset_right = 350
    _window.offset_bottom = 350
    var ws = StyleBoxFlat.new()
    ws.bg_color = COLOR_WHITE
    ws.border_width_left = 3
    ws.border_width_top = 3
    ws.border_width_right = 3
    ws.border_width_bottom = 3
    ws.border_color = Color(0, 0, 0, 1)
    ws.corner_radius_top_left = 22
    ws.corner_radius_top_right = 22
    ws.corner_radius_bottom_left = 20
    ws.corner_radius_bottom_right = 20
    if UITheme:
        UITheme.apply_shadow(ws, false)
    _window.add_theme_stylebox_override("panel", ws)
    add_child(_window)

    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 12)
    _window.add_child(root)

    var header = Panel.new()
    header.custom_minimum_size = Vector2(0, 44)
    var hs = StyleBoxFlat.new()
    hs.bg_color = COLOR_BLUE
    hs.corner_radius_top_left = 20
    hs.corner_radius_top_right = 20
    header.add_theme_stylebox_override("panel", hs)
    root.add_child(header)

    var title = Label.new()
    title.text = tr("SLA_SELECTION_TITLE")
    title.set_anchors_preset(Control.PRESET_CENTER)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", Color.WHITE)
    if UITheme:
        UITheme.apply_font(title, "bold")
    header.add_child(title)

    var close_btn = Button.new()
    close_btn.text = "X"
    close_btn.focus_mode = Control.FOCUS_NONE
    close_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
    close_btn.offset_left = -50
    close_btn.offset_top = -14
    close_btn.offset_right = -24
    close_btn.offset_bottom = 14
    close_btn.add_theme_color_override("font_color", COLOR_BLUE)
    var cs = StyleBoxFlat.new()
    cs.bg_color = COLOR_WHITE
    cs.corner_radius_top_left = 10
    cs.corner_radius_top_right = 10
    cs.corner_radius_bottom_left = 10
    cs.corner_radius_bottom_right = 10
    close_btn.add_theme_stylebox_override("normal", cs)
    close_btn.pressed.connect(_close_window)
    header.add_child(close_btn)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 24)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_right", 24)
    margin.add_theme_constant_override("margin_bottom", 18)
    margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(margin)

    var body = VBoxContainer.new()
    body.add_theme_constant_override("separation", 10)
    margin.add_child(body)

    _list_vbox = VBoxContainer.new()
    _list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _list_vbox.add_theme_constant_override("separation", 10)
    body.add_child(_list_vbox)

    var btn_row = HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_END
    body.add_child(btn_row)

    var cancel_btn = Button.new()
    cancel_btn.text = tr("UI_CANCEL")
    cancel_btn.custom_minimum_size = Vector2(160, 42)
    cancel_btn.pressed.connect(_close_window)
    btn_row.add_child(cancel_btn)

    _confirm_btn = Button.new()
    _confirm_btn.text = tr("SLA_CONFIRM")
    _confirm_btn.custom_minimum_size = Vector2(220, 42)
    _confirm_btn.disabled = true
    _confirm_btn.pressed.connect(_on_confirm_pressed)
    btn_row.add_child(_confirm_btn)

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
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.96, 0.97, 1, 1) if selected else COLOR_WHITE
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.border_color = COLOR_BLUE if selected else COLOR_BORDER
    style.corner_radius_top_left = 14
    style.corner_radius_top_right = 14
    style.corner_radius_bottom_left = 14
    style.corner_radius_bottom_right = 14
    if UITheme:
        UITheme.apply_shadow(style)
    card.add_theme_stylebox_override("panel", style)

    var m = MarginContainer.new()
    m.add_theme_constant_override("margin_left", 14)
    m.add_theme_constant_override("margin_top", 10)
    m.add_theme_constant_override("margin_right", 14)
    m.add_theme_constant_override("margin_bottom", 10)
    card.add_child(m)

    var h = HBoxContainer.new()
    m.add_child(h)

    var left = VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(left)

    var title = Label.new()
    title.text = "%s %s" % [definition["icon"], tr(definition["name_key"])]
    if UITheme:
        UITheme.apply_font(title, "bold")
    left.add_child(title)

    var desc = Label.new()
    desc.text = tr(definition["desc_key"])
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
    rate_lbl.add_theme_color_override("font_color", Color(0.2, 0.65, 0.2, 1))
    if UITheme:
        UITheme.apply_font(rate_lbl, "semibold")
    right.add_child(rate_lbl)

    var week_lbl = Label.new()
    week_lbl.text = _tr_format_safe("SLA_WEEKLY_ESTIMATE", weekly_estimate, "≈ $%d/week" % weekly_estimate)
    week_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    if UITheme:
        UITheme.apply_font(week_lbl, "regular")
    right.add_child(week_lbl)

    var pick_btn = Button.new()
    pick_btn.text = tr("UI_SELECT")
    pick_btn.custom_minimum_size = Vector2(130, 34)
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
