extends Control

signal closed

const COLOR_BLUE = Color(0.17254902, 0.30980393, 0.5686275, 1)
const COLOR_WHITE = Color(1, 1, 1, 1)
const COLOR_TURQUOISE = Color(0.0, 0.6, 0.6, 1)

var _overlay: ColorRect
var _window: PanelContainer
var _top_vbox: VBoxContainer
var _tickets_vbox: VBoxContainer

var _project: SupportProjectData = null
var _was_paused: bool = false
var _last_refresh_key: int = -1

var _assignment_overlay: ColorRect
var _assignment_list: ItemList
var _assignment_callback: Callable

func _tr_format_safe(key: String, args, fallback: String) -> String:
    var text = tr(key)
    if text.find("%") >= 0:
        return text % args
    return fallback

func _ready():
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    z_index = 97
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build_ui()

func open_for_project(proj: SupportProjectData):
    if proj == null:
        return
    _project = proj
    _was_paused = GameTime.is_game_paused
    GameTime.set_paused(true)
    _rebuild()
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
    emit_signal("closed")

func _build_ui():
    _overlay = ColorRect.new()
    _overlay.color = Color(0, 0, 0, 0.55)
    _overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_overlay)

    var center = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    _window = PanelContainer.new()
    _window.custom_minimum_size = Vector2(1200, 750)
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
    center.add_child(_window)

    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 0)
    _window.add_child(root)

    var header = Panel.new()
    header.custom_minimum_size = Vector2(0, 42)
    var hs = StyleBoxFlat.new()
    hs.bg_color = COLOR_BLUE
    hs.corner_radius_top_left = 20
    hs.corner_radius_top_right = 20
    header.add_theme_stylebox_override("panel", hs)
    root.add_child(header)

    var title_lbl = Label.new()
    title_lbl.name = "TitleLabel"
    title_lbl.add_theme_color_override("font_color", COLOR_WHITE)
    title_lbl.add_theme_font_size_override("font_size", 16)
    title_lbl.set_anchors_preset(Control.PRESET_CENTER)
    title_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
    title_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
    title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if UITheme:
        UITheme.apply_font(title_lbl, "bold")
    header.add_child(title_lbl)

    var margin = MarginContainer.new()
    margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_theme_constant_override("margin_left", 20)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_right", 20)
    margin.add_theme_constant_override("margin_bottom", 16)
    root.add_child(margin)

    var body = VBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 12)
    margin.add_child(body)

    _top_vbox = VBoxContainer.new()
    _top_vbox.add_theme_constant_override("separation", 8)
    body.add_child(_top_vbox)
    body.add_child(HSeparator.new())

    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)

    _tickets_vbox = VBoxContainer.new()
    _tickets_vbox.add_theme_constant_override("separation", 8)
    scroll.add_child(_tickets_vbox)

    var footer_margin = MarginContainer.new()
    footer_margin.add_theme_constant_override("margin_top", 4)
    body.add_child(footer_margin)

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
    cbtn_style.border_color = Color(0.5, 0.5, 0.5, 1)
    cbtn_style.corner_radius_top_left = 16
    cbtn_style.corner_radius_top_right = 16
    cbtn_style.corner_radius_bottom_right = 16
    cbtn_style.corner_radius_bottom_left = 16
    var cbtn_hover = StyleBoxFlat.new()
    cbtn_hover.bg_color = Color(0.5, 0.5, 0.5, 1)
    cbtn_hover.border_width_left = 2
    cbtn_hover.border_width_top = 2
    cbtn_hover.border_width_right = 2
    cbtn_hover.border_width_bottom = 2
    cbtn_hover.border_color = Color(0.5, 0.5, 0.5, 1)
    cbtn_hover.corner_radius_top_left = 16
    cbtn_hover.corner_radius_top_right = 16
    cbtn_hover.corner_radius_bottom_right = 16
    cbtn_hover.corner_radius_bottom_left = 16
    close_btn.add_theme_stylebox_override("normal", cbtn_style)
    close_btn.add_theme_stylebox_override("hover", cbtn_hover)
    close_btn.add_theme_stylebox_override("pressed", cbtn_hover)
    close_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
    close_btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
    close_btn.pressed.connect(_close_window)
    close_center.add_child(close_btn)

    _build_assignment_popup()

func _build_assignment_popup():
    _assignment_overlay = ColorRect.new()
    _assignment_overlay.color = Color(0, 0, 0, 0.45)
    _assignment_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    _assignment_overlay.visible = false
    _assignment_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_assignment_overlay)

    var panel = PanelContainer.new()
    panel.custom_minimum_size = Vector2(560, 560)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -280
    panel.offset_top = -280
    panel.offset_right = 280
    panel.offset_bottom = 280
    var ps = StyleBoxFlat.new()
    ps.bg_color = COLOR_WHITE
    ps.border_width_left = 3
    ps.border_width_top = 3
    ps.border_width_right = 3
    ps.border_width_bottom = 3
    ps.border_color = COLOR_TURQUOISE
    ps.corner_radius_top_left = 20
    ps.corner_radius_top_right = 20
    ps.corner_radius_bottom_left = 20
    ps.corner_radius_bottom_right = 20
    panel.add_theme_stylebox_override("panel", ps)
    _assignment_overlay.add_child(panel)

    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 10)
    panel.add_child(v)

    var title = Label.new()
    title.text = tr("TICKET_ASSIGN")
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    if UITheme:
        UITheme.apply_font(title, "bold")
    v.add_child(title)

    _assignment_list = ItemList.new()
    _assignment_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _assignment_list.item_activated.connect(_on_assignment_item_activated)
    v.add_child(_assignment_list)

    var close_btn = Button.new()
    close_btn.text = tr("UI_CANCEL")
    close_btn.custom_minimum_size = Vector2(0, 42)
    close_btn.pressed.connect(func(): _assignment_overlay.visible = false)
    v.add_child(close_btn)

func _rebuild():
    if _project == null:
        return

    for c in _top_vbox.get_children():
        c.queue_free()
    for c in _tickets_vbox.get_children():
        c.queue_free()

    var title_lbl: Label = _window.find_child("TitleLabel", true, false)
    var client = _project.get_client()
    var client_name = client.get_display_name() if client else _project.client_id
    title_lbl.text = _tr_format_safe("SUPPORT_WINDOW_TITLE", client_name, "Support — %s" % client_name)

    var sla_text = tr("SLA_" + _project.sla_level.to_upper())
    var sla_days = SupportProjectManager.get_sla_deadline_days(_project.sla_level)
    _top_vbox.add_child(_info_label(_tr_format_safe("SUPPORT_SLA_BADGE", [sla_text, sla_days], "SLA: %s (%d days)" % [sla_text, sla_days]), Color(0.1, 0.55, 0.55, 1), true))

    var eff_rate = SupportProjectManager.get_effective_daily_rate(_project)
    _top_vbox.add_child(_info_label(_tr_format_safe("SUPPORT_DAILY_RATE_LABEL", eff_rate, "Rate: $%d/day" % eff_rate), Color(0.2, 0.6, 0.2, 1), true))

    var support_row = HBoxContainer.new()
    support_row.add_theme_constant_override("separation", 8)
    _top_vbox.add_child(support_row)

    var specialist_lbl = Label.new()
    specialist_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if _project.assigned_support_employee:
        specialist_lbl.text = "🎧 %s" % _project.assigned_support_employee.get_display_name()
    else:
        specialist_lbl.text = tr("TICKET_NOT_ASSIGNED")
    support_row.add_child(specialist_lbl)

    if _project.assigned_support_employee:
        var remove_btn = Button.new()
        remove_btn.text = tr("SUPPORT_REMOVE_SPECIALIST")
        remove_btn.custom_minimum_size = Vector2(160, 34)
        _style_blue_button(remove_btn)
        remove_btn.pressed.connect(func():
            _project.assigned_support_employee = null
            _rebuild()
        )
        support_row.add_child(remove_btn)
    else:
        var assign_btn = Button.new()
        assign_btn.text = tr("SUPPORT_ASSIGN_SPECIALIST")
        assign_btn.custom_minimum_size = Vector2(260, 34)
        _style_blue_button(assign_btn)
        assign_btn.pressed.connect(func():
            _open_assignment_popup("Customer Support", func(emp):
                _project.assigned_support_employee = emp
                _rebuild()
            )
        )
        support_row.add_child(assign_btn)

    if _project.assigned_support_employee == null:
        _top_vbox.add_child(_info_label(tr("SUPPORT_NO_SPECIALIST"), Color(0.9, 0.25, 0.2, 1), false))

    var open_count = 0
    var overdue_count = 0
    for t in _project.tickets:
        if t is SupportTicketData and not t.is_completed:
            open_count += 1
            if t.is_overdue:
                overdue_count += 1
    _top_vbox.add_child(_info_label(_tr_format_safe("SUPPORT_STATUS_TICKETS", [open_count, overdue_count], "Tickets: %d open / %d overdue" % [open_count, overdue_count]), COLOR_BLUE, false))
    _top_vbox.add_child(_info_label(_tr_format_safe("SUPPORT_WEEKLY_RATE", eff_rate * 5, "~$%d/wk" % (eff_rate * 5)), Color(0.2, 0.6, 0.2, 1), true))

    var sorted_tickets = _project.tickets.duplicate()
    sorted_tickets.sort_custom(func(a, b): return _ticket_sort_key(a) < _ticket_sort_key(b))
    for ticket in sorted_tickets:
        if ticket is SupportTicketData:
            _tickets_vbox.add_child(_create_ticket_card(ticket))

func _info_label(text: String, color: Color, bold: bool) -> Label:
    var lbl = Label.new()
    lbl.text = text
    lbl.add_theme_color_override("font_color", color)
    if UITheme:
        UITheme.apply_font(lbl, "bold" if bold else "regular")
    return lbl

func _ticket_sort_key(ticket: SupportTicketData) -> int:
    if ticket.is_overdue and not ticket.is_completed:
        return 0
    if not ticket.is_completed and ticket.assigned_worker == null:
        return 1
    if not ticket.is_completed and ticket.assigned_worker != null:
        return 2
    return 3

func _create_ticket_card(ticket: SupportTicketData) -> PanelContainer:
    var card = PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var s = StyleBoxFlat.new()
    s.bg_color = Color(1, 1, 1, 1)
    s.border_width_left = 2
    s.border_width_top = 2
    s.border_width_right = 2
    s.border_width_bottom = 2
    s.corner_radius_top_left = 12
    s.corner_radius_top_right = 12
    s.corner_radius_bottom_left = 12
    s.corner_radius_bottom_right = 12

    var days_left = ticket.deadline_day - GameTime.day
    if ticket.is_completed:
        s.bg_color = Color(0.91, 0.98, 0.91, 1)
        s.border_color = Color(0.29803923, 0.6862745, 0.3137255, 1)
    elif ticket.is_overdue:
        s.bg_color = Color(0.99, 0.93, 0.93, 1)
        s.border_color = Color(0.8980392, 0.22352941, 0.20784314, 1)
    elif days_left == 1:
        s.bg_color = Color(1.0, 0.97, 0.9, 1)
        s.border_color = Color(0.95, 0.75, 0.15, 1)
    else:
        s.border_color = Color(0.85, 0.85, 0.85, 1)
    card.add_theme_stylebox_override("panel", s)

    var m = MarginContainer.new()
    m.add_theme_constant_override("margin_left", 12)
    m.add_theme_constant_override("margin_top", 10)
    m.add_theme_constant_override("margin_right", 12)
    m.add_theme_constant_override("margin_bottom", 10)
    card.add_child(m)

    var root = VBoxContainer.new()
    root.add_theme_constant_override("separation", 4)
    m.add_child(root)

    var role_icon = "📊"
    if ticket.required_role == "DEV":
        role_icon = "💻"
    elif ticket.required_role == "QA":
        role_icon = "🧪"
    root.add_child(_info_label("%s %s" % [role_icon, tr("ROLE_SHORT_" + ticket.required_role)], COLOR_BLUE, true))
    root.add_child(_info_label("%d / %d" % [int(ticket.progress), ticket.work_amount], COLOR_BLUE, false))

    var date_txt = GameTime.get_date_short(ticket.deadline_day)
    root.add_child(_info_label(_tr_format_safe("TICKET_DEADLINE", [date_txt, max(days_left, 0)], "Deadline: %s (%d days left)" % [date_txt, max(days_left, 0)]), Color(0.4, 0.4, 0.4, 1), false))

    if ticket.is_overdue and not ticket.is_completed:
        root.add_child(_info_label(tr("TICKET_OVERDUE"), Color(0.9, 0.2, 0.2, 1), true))
    if ticket.is_completed:
        root.add_child(_info_label(tr("TICKET_COMPLETED"), Color(0.2, 0.65, 0.25, 1), true))

    var worker_name = tr("TICKET_NOT_ASSIGNED")
    if ticket.assigned_worker:
        worker_name = "👤 " + ticket.assigned_worker.get_display_name()
    root.add_child(_info_label(worker_name, Color(0.3, 0.3, 0.3, 1), false))

    if not ticket.is_completed:
        var btn = Button.new()
        btn.text = tr("TICKET_ASSIGN")
        btn.custom_minimum_size = Vector2(180, 34)
        _style_blue_button(btn)
        btn.disabled = ticket.assigned_worker != null
        btn.pressed.connect(func():
            _open_assignment_popup(_role_to_job_title(ticket.required_role), func(emp):
                ticket.assigned_worker = emp
                _rebuild()
            )
        )
        root.add_child(btn)

    return card

func _style_blue_button(btn: Button):
    btn.add_theme_font_size_override("font_size", 13)
    btn.focus_mode = Control.FOCUS_NONE
    if UITheme:
        UITheme.apply_font(btn, "semibold")
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
    btn.add_theme_stylebox_override("normal", btn_n)
    btn.add_theme_stylebox_override("hover", btn_h)
    btn.add_theme_stylebox_override("pressed", btn_h)
    btn.add_theme_color_override("font_color", COLOR_BLUE)
    btn.add_theme_color_override("font_hover_color", COLOR_WHITE)
    btn.add_theme_color_override("font_pressed_color", COLOR_WHITE)

func _role_to_job_title(role: String) -> String:
    match role:
        "BA":
            return "Business Analyst"
        "DEV":
            return "Backend Developer"
        "QA":
            return "QA Engineer"
    return ""

func _open_assignment_popup(required_job_title: String, callback: Callable):
    _assignment_callback = callback
    _assignment_list.clear()
    for npc in get_tree().get_nodes_in_group("npc"):
        if not npc.data:
            continue
        var emp: EmployeeData = npc.data
        if required_job_title != "" and emp.job_title != required_job_title:
            continue
        if _is_employee_busy(emp):
            continue
        var idx = _assignment_list.add_item("%s (%s)" % [emp.get_display_name(), tr(emp.job_title)])
        _assignment_list.set_item_metadata(idx, emp)

    if _assignment_list.item_count == 0:
        var idx = _assignment_list.add_item(tr("ASSIGN_MENU_NO_STAFF"))
        _assignment_list.set_item_disabled(idx, true)
        _assignment_list.set_item_selectable(idx, false)

    _assignment_overlay.visible = true

func _on_assignment_item_activated(index: int):
    var emp = _assignment_list.get_item_metadata(index)
    if emp == null:
        return
    _assignment_overlay.visible = false
    if _assignment_callback.is_valid():
        _assignment_callback.call(emp)

func _is_employee_busy(emp: EmployeeData) -> bool:
    if SupportProjectManager.is_employee_on_support(emp):
        return true
    if SupportProjectManager.is_employee_on_ticket(emp):
        return true
    for project in ProjectManager.active_projects:
        if project.state == ProjectData.State.FINISHED or project.state == ProjectData.State.FAILED:
            continue
        for stage in project.stages:
            for worker in stage.workers:
                if worker == emp:
                    return true
    return false

func _process(_delta):
    if not visible or _project == null:
        return
    var key = GameTime.hour * 60 + GameTime.minute
    if key != _last_refresh_key:
        _last_refresh_key = key
        _rebuild()

func _input(event: InputEvent) -> void:
    if visible and event.is_action_pressed("ui_cancel"):
        if _assignment_overlay.visible:
            _assignment_overlay.visible = false
        else:
            _close_window()
        get_viewport().set_input_as_handled()
