class_name Hud
extends Control
## All UI. Reads/controls the game through `m` (main.gd).

const T = Catalog.Id
var m: Node2D
var lbl_time: Label
var perf_l: Label
var pintip: PanelContainer
var pintip_lbl: RichTextLabel
var lbl_coins: Label
var lbl_pop: Label
var lbl_jobs: Label
var lbl_mood: Label
var bar_mood: ProgressBar
var tgauge: Control
var maptip: PanelContainer
var maptip_lbl: RichTextLabel
var lbl_net: Label
var ticker: Label
var detail: RichTextLabel
var tabs: TabContainer
var tool_btns := {}
var acc_boxes := {}
var insp: RichTextLabel
var needs_l: Label
var goal_l: Label
var murm: Label
var budget: RichTextLabel
var graph: Control
var gauge: Control
var cov_box: VBoxContainer
var cov_bars := {}
var crime_bar: ProgressBar
var commute_l: Label
var land_l: Label
var region_l: RichTextLabel
var shown_town: City
var people_l: RichTextLabel
var act_l: RichTextLabel
var log_l: RichTextLabel
var pol_btns := {}
var auto_opt: OptionButton
var focus_auto: CheckButton
var ask_chk: CheckButton
var focus_sliders := {}
var tax_ls := {}
var tax_sliders := {}
var auto_chk: CheckButton
var codex_list: ItemList
var codex_text: RichTextLabel
var codex_ids: Array = []
var over_panel: PanelContainer
var over_l: Label
var hover_text := ""
var tick_n := 0
const WIN_KEYS := ["build", "info", "detail", "mayor", "army", "empire", "market"]
const UI_FILE := "user://ui.cfg"
var wins := {}
var win_open := {}
var win_home := {}
var win_bar := {}  # key -> title bar (hidden while the window is popped out)
var win_title := {}
var win_prev := {}
var pop_wins := {}  # key -> native OS Window holding the panel (the player can drag it to another screen)
var win_min := {}
var lbl_appr: Label
var appr_bar: ProgressBar
var elect_l: Label
var rally_b: Button
var dec_box: VBoxContainer
var dec_ver := -1
var dec_town: City
var adv_l: RichTextLabel
var goals_l: RichTextLabel
var econ_l: RichTextLabel
var loans_l: Label
var dipl_box: VBoxContainer
var dipl_key := ""
var guide: Guide
var dipl_ui := {}
var terr_l: Label
var exp_btns: Array = []
var exp_chk: CheckButton


func _ready() -> void:
    theme = _theme()
    _top()
    _left()
    _right()
    _bottom()
    _mayor()
    _army()
    _empire()
    _market_win()
    maptip = PanelContainer.new()
    maptip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    maptip.z_index = 100
    maptip.visible = false
    maptip_lbl = RichTextLabel.new()
    maptip_lbl.bbcode_enabled = true
    maptip_lbl.fit_content = true
    maptip_lbl.scroll_active = false
    maptip_lbl.custom_minimum_size = Vector2(230, 0)
    maptip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    maptip.add_child(maptip_lbl)
    add_child(maptip)
    pintip = PanelContainer.new()
    pintip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pintip.z_index = 99
    pintip.visible = false
    pintip_lbl = RichTextLabel.new()
    pintip_lbl.bbcode_enabled = true
    pintip_lbl.fit_content = true
    pintip_lbl.scroll_active = false
    pintip_lbl.custom_minimum_size = Vector2(230, 0)
    pintip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pintip.add_child(pintip_lbl)
    add_child(pintip)
    perf_l = Label.new()
    perf_l.position = Vector2(8, 62)
    perf_l.visible = false
    perf_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(perf_l)
    guide = Guide.new()
    guide.m = m
    guide.visible = false
    add_child(guide)
    _load_ui()
    get_viewport().size_changed.connect(_clamp_all)
    _clamp_all.call_deferred()
    over_panel = PanelContainer.new()
    over_panel.position = Vector2(400, 250)
    over_panel.custom_minimum_size = Vector2(480, 150)
    over_panel.visible = false
    add_child(over_panel)
    over_l = Label.new()
    over_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    over_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    over_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    over_l.add_theme_font_size_override("font_size", 20)
    over_panel.add_child(over_l)


func _theme() -> Theme:
    var t := Theme.new()
    var pb := StyleBoxFlat.new()
    pb.bg_color = Color(0.11, 0.13, 0.12, 0.95)
    pb.set_corner_radius_all(6)
    pb.set_border_width_all(1)
    pb.border_color = Color(0.3, 0.36, 0.32)
    pb.set_content_margin_all(8)
    t.set_stylebox("panel", "PanelContainer", pb)
    t.set_stylebox("panel", "PopupMenu", pb)
    for cls in ["Button", "MenuButton", "OptionButton"]:
        for st in [["normal", Color(0.2, 0.24, 0.22)], ["hover", Color(0.28, 0.33, 0.3)], ["pressed", Color(0.36, 0.5, 0.34)],
                ["disabled", Color(0.15, 0.17, 0.16)], ["hover_pressed", Color(0.4, 0.54, 0.38)]]:
            var s := StyleBoxFlat.new()
            s.bg_color = st[1]
            s.set_corner_radius_all(4)
            s.set_content_margin_all(4)
            t.set_stylebox(st[0], cls, s)
        t.set_color("font_color", cls, Color("e8e2d0"))
        t.set_color("font_hover_color", cls, Color.WHITE)
        t.set_color("font_pressed_color", cls, Color.WHITE)
        t.set_color("font_disabled_color", cls, Color(0.5, 0.52, 0.48))
        t.set_font_size("font_size", cls, 13)
    t.set_color("font_color", "Label", Color("e8e2d0"))
    t.set_font_size("font_size", "Label", 13)
    t.set_color("default_color", "RichTextLabel", Color("e8e2d0"))
    t.set_font_size("normal_font_size", "RichTextLabel", 13)
    t.set_font_size("bold_font_size", "RichTextLabel", 13)
    t.set_color("font_color", "PopupMenu", Color("e8e2d0"))
    t.set_font_size("font_size", "TabContainer", 11)
    return t


func _lbl(p: Node, w: float, tip := "") -> Label:
    var l := Label.new()
    l.custom_minimum_size = Vector2(w, 0)
    l.mouse_filter = Control.MOUSE_FILTER_PASS
    l.tooltip_text = tip
    p.add_child(l)
    return l


func _btn(p: Node, text: String, cb: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(cb)
    p.add_child(b)
    return b


func _rich(p: Node, h: float) -> RichTextLabel:
    var r := RichTextLabel.new()
    r.bbcode_enabled = true
    r.fit_content = h <= 0.0
    r.custom_minimum_size = Vector2(250, maxf(h, 0.0))
    r.scroll_active = h > 0.0
    r.mouse_filter = Control.MOUSE_FILTER_PASS
    p.add_child(r)
    return r


func _menu(p: Node, title: String) -> PopupMenu:
    var mb := MenuButton.new()
    mb.text = title
    mb.focus_mode = Control.FOCUS_NONE
    p.add_child(mb)
    return mb.get_popup()


# ---------- top bar ----------

func _top() -> void:
    var top := PanelContainer.new()
    top.set_anchors_preset(Control.PRESET_TOP_WIDE)
    add_child(top)
    var tb := HBoxContainer.new()
    tb.add_theme_constant_override("separation", 5)
    top.add_child(tb)
    for sp in [["Pause", 0.0], ["1x", 1.0], ["3x", 3.0], ["8x", 8.0]]:
        _btn(tb, sp[0], func() -> void: m.speed = sp[1])
    lbl_time = _lbl(tb, 230, "Game clock and current weather. A day lasts 60 sim seconds. Weather changes mood and fire behaviour.")
    lbl_coins = _lbl(tb, 120, "Treasury and net income per second. Below -150 the city goes bankrupt. Open the Budget tab to see where money goes.")
    lbl_pop = _lbl(tb, 66, "Population / housing capacity. Peak population unlocks new buildings.")
    lbl_jobs = _lbl(tb, 70, "Employed citizens / total jobs. Unemployed citizens pay no income tax.")
    lbl_mood = _lbl(tb, 62, "City happiness. Falls with uncovered needs, pollution, weather, high taxes and bad news. Low mood stalls growth and can trigger protests.")
    lbl_time.clip_text = true
    bar_mood = ProgressBar.new()
    bar_mood.custom_minimum_size = Vector2(50, 14)
    bar_mood.show_percentage = false
    bar_mood.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    tb.add_child(bar_mood)
    lbl_appr = _lbl(tb, 92, "Your approval rating. Driven by mood, the budget, tribe opinion and whether you keep your promises. Elections are held every 28 days (end of winter): below 50% you are voted out.")
    tgauge = Control.new()
    tgauge.custom_minimum_size = Vector2(96, 26)
    tgauge.tooltip_text = "Demand for new Residential, Commercial, Industrial and Office zones. Up = people want more. Down = oversupplied."
    tgauge.mouse_filter = Control.MOUSE_FILTER_PASS
    tgauge.draw.connect(_draw_tgauge)
    var st := PanelContainer.new()
    st.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    st.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    st.offset_top = 58
    st.offset_right = -8
    st.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(st)
    var sb := HBoxContainer.new()
    sb.add_theme_constant_override("separation", 10)
    st.add_child(sb)
    sb.add_child(tgauge)
    lbl_net = _lbl(sb, 170, "Utilities: supply / demand for power, water and sewage. Red = shortage, so every connected building suffers.")
    # World menu: events by category
    var wp := _menu(tb, "World events")
    wp.id_pressed.connect(_on_event_menu)
    var sub := {}
    for c in WorldEvents.CATS:
        var pm := PopupMenu.new()
        pm.name = String(c)
        pm.id_pressed.connect(_on_event_menu)
        wp.add_child(pm)
        sub[c] = pm
    var ids: Array = WorldEvents.EVENTS.keys()
    for k in ids.size():
        var e: Dictionary = WorldEvents.EVENTS[ids[k]]
        (sub[e["cat"]] as PopupMenu).add_item(String(e["n"]) + ("" if not e.get("player", false) else "  (you)"), k)
        (sub[e["cat"]] as PopupMenu).set_item_tooltip(-1, WorldEvents.describe(ids[k]).replace("[b]", "").replace("[/b]", ""))
    for c in WorldEvents.CATS:
        wp.add_submenu_node_item(String(c), sub[c])
    var wm := _menu(tb, "Windows")
    wm.add_check_item("Build menu", 0)
    wm.add_check_item("City panel", 1)
    wm.add_check_item("Hover details", 2)
    wm.add_check_item("Mayor's office", 3)
    wm.add_check_item("Army", 4)
    wm.add_check_item("Empire (all towns)", 5)
    wm.add_check_item("Market", 6)
    wm.add_separator()
    wm.add_item("Reset window layout", 9)
    wm.about_to_popup.connect(func() -> void:
        for k in WIN_KEYS.size():
            wm.set_item_checked(k, bool(win_open.get(WIN_KEYS[k], true))))
    wm.id_pressed.connect(func(id: int) -> void:
        if id == 9:
            _reset_wins()
        else:
            _set_open(WIN_KEYS[id], not bool(win_open.get(WIN_KEYS[id], true))))
    # Towns
    var tp := _menu(tb, "Towns")
    tp.about_to_popup.connect(func() -> void:
        tp.clear()
        for k in m.towns.size():
            tp.add_item("%s%s  (pop %d)" % ["> " if m.towns[k] == m.city else "", m.towns[k].town_name, m.towns[k].pop], k)
        tp.add_separator()
        tp.add_item("Whole world (M)", 98)
        tp.add_item("Found a new town (from $%d)" % int(m.FOUND_COST), 99))
    tp.id_pressed.connect(func(id: int) -> void:
        if id == 99:
            m.found_town()
        elif id == 98:
            m.toggle_map()
        else:
            m.switch_town(id))
    # Overlays
    var op := _menu(tb, "Overlays")
    op.add_item("None", 0)
    op.add_item("ALL (everything at once)", 2)
    op.add_item("Crime", 3)
    op.add_item("Land value", 4)
    op.add_item("Traffic", 5)
    op.add_item("Pollution", 1)
    var mk: Array = Catalog.METRICS.keys()
    for k in mk.size():
        op.add_item("Coverage: " + String(Catalog.METRICS[mk[k]]["n"]), 10 + k)
    op.id_pressed.connect(func(id: int) -> void:
        m.overlay = "" if id == 0 else ({1: "pollution", 2: "all", 3: "crime", 4: "land", 5: "traffic"}[id] if id < 10 else String(mk[id - 10])))
    # City menu
    var cp := _menu(tb, "City")
    cp.add_item("Auto-growth: off", 0)
    cp.add_item("Auto-growth: zones only", 1)
    cp.add_item("Auto-growth: zones + roads", 2)
    cp.add_separator()
    cp.add_item("Save now (autosaves every day)", 5)
    cp.add_item("Show the guide", 10)
    cp.add_item("New city (opens the start menu)", 9)
    cp.add_separator()
    cp.add_item("Sound on / off", 6)
    cp.add_item("Volume up", 7)
    cp.add_item("Volume down", 8)
    cp.id_pressed.connect(func(id: int) -> void:
        if id == 10:
            guide.restart()
        elif id == 9:
            m.new_game()
        elif id == 5:
            m.save_game()
            m.headline = "City saved."
        elif id == 6:
            m.sfx.muted = not m.sfx.muted
            m.headline = "Sound off." if m.sfx.muted else "Sound on."
        elif id == 7 or id == 8:
            m.sfx.vol = clampf(m.sfx.vol + (0.1 if id == 7 else -0.1), 0.0, 1.0)
            m.headline = "Volume %d%%" % int(m.sfx.vol * 100.0)
        else:
            m.cmd("auto_mode", [id])
            auto_opt.select(id))


func _on_event_menu(id: int) -> void:
    var ids: Array = WorldEvents.EVENTS.keys()
    var key: String = ids[id]
    if key == "fire":
        m.headline = m.city.ignite()
    elif not m.city.trigger(key):
        m.headline = "Could not trigger %s (not enough coins?)." % WorldEvents.EVENTS[key]["n"]


# ---------- left: accordion build menu ----------

func _left() -> void:
    var vs := get_viewport_rect().size
    var lb := _win("build", "Build", Vector2(8, 44), Vector2(176, clampf(vs.y - 200.0, 220.0, 440.0)))
    var sc := ScrollContainer.new()
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    lb.add_child(sc)
    var lv := VBoxContainer.new()
    lv.add_theme_constant_override("separation", 3)
    lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(lv)
    var group := ButtonGroup.new()
    _tool_btn(lv, group, "Inspect  (Q)", m.INSPECT, "Click a citizen or a building to see what it is doing and thinking.")
    _tool_btn(lv, group, "Bulldoze  (B)", m.BULLDOZE, "Remove roads, zones and buildings. No refund.")
    _tool_btn(lv, group, "Paint water (editor)", m.WATER_ADD, "World editor: click or drag to add river on empty ground. Free. Zones can't be built on water; roads become bridges.")
    _tool_btn(lv, group, "Remove water (editor)", m.WATER_DEL, "World editor: click or drag to turn river back into land. Free.")
    for c in Catalog.CATS:
        var head := Button.new()
        head.text = "> " + String(c[1])
        head.focus_mode = Control.FOCUS_NONE
        head.alignment = HORIZONTAL_ALIGNMENT_LEFT
        lv.add_child(head)
        var box := VBoxContainer.new()
        box.visible = c[0] == "infra" or c[0] == "zone"
        lv.add_child(box)
        acc_boxes[c[0]] = box
        head.pressed.connect(func() -> void:
            box.visible = not box.visible
            head.text = ("v " if box.visible else "> ") + String(c[1]))
        if box.visible:
            head.text = "v " + String(c[1])
        for id in Catalog.DEFS:
            var d: Dictionary = Catalog.DEFS[id]
            if d["cat"] == c[0]:
                _tool_btn(box, group, "%s  $%d" % [d["n"], d["cost"]], id, "")
    gauge = Control.new()
    gauge.custom_minimum_size = Vector2(150, 70)
    gauge.draw.connect(_draw_gauge)
    gauge.tooltip_text = "Demand for new Residential, Commercial, Industrial and Office zones. Up = people want more. Down = oversupplied."
    gauge.mouse_filter = Control.MOUSE_FILTER_PASS
    lv.add_child(gauge)
    # detail panel
    var db := _win("detail", "Details (hover a building)", Vector2(200, clampf(vs.y - 300.0, 60.0, 400.0)), Vector2(364, 214))
    detail = _rich(db, 214)
    detail.custom_minimum_size = Vector2(364, 214)
    var dp: PanelContainer = wins["detail"]
    dp.visible = false
    detail.set_meta("panel", dp)


func _tool_btn(p: Node, g: ButtonGroup, text: String, id: int, tip: String) -> void:
    var b := Button.new()
    b.text = text
    b.toggle_mode = true
    b.button_group = g
    b.focus_mode = Control.FOCUS_NONE
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.button_pressed = id == m.tool
    b.pressed.connect(func() -> void: m.tool = id)
    b.mouse_entered.connect(func() -> void: hover_text = _tool_text(id, tip))
    b.mouse_exited.connect(func() -> void: hover_text = "")
    if Catalog.DEFS.has(id):
        var vp := SubViewport.new()
        vp.size = Vector2i(32, 32)
        vp.transparent_bg = true
        vp.render_target_update_mode = SubViewport.UPDATE_ONCE
        vp.add_child(Art.IconView.new(id))
        b.add_child(vp)
        b.icon = vp.get_texture()
    p.add_child(b)
    tool_btns[id] = b
    b.set_meta("base", text)


func _tool_text(id: int, tip: String) -> String:
    if Catalog.DEFS.has(id):
        return Catalog.describe_building(id, m.city.peak)
    return "[b]%s[/b]\n%s" % ["Tool", tip]


# ---------- right: tabs ----------

func _right() -> void:
    var vs := get_viewport_rect().size
    var rb := _win("info", "City panel", Vector2(maxf(vs.x - 396.0, 200.0), 44), Vector2(368, clampf(vs.y - 130.0, 260.0, 560.0)))
    tabs = TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tabs.clip_tabs = false
    rb.add_child(tabs)
    # Overview
    var ov := _tab("Info")
    _hdr(ov, "INSPECTOR")
    insp = _rich(ov, 90)
    _hdr(ov, "WHAT THE CITY NEEDS")
    needs_l = _wrap(ov, 100)
    _hdr(ov, "GOAL")
    goal_l = _wrap(ov, 40)
    _hdr(ov, "MURMURS")
    murm = _wrap(ov, 90)
    # Budget
    var bu := _tab("Budget")
    _hdr(bu, "TAX RATES (income per second shown below)")
    for k in [["r", "Residential", "Tax on homes. High rates lower mood."], ["c", "Commercial", "Tax on shops. Too high and shop income collapses."], ["i", "Industrial", "Tax on factories and offices."]]:
        var h := HBoxContainer.new()
        bu.add_child(h)
        var l := _lbl(h, 110, k[2])
        tax_ls[k[0]] = l
        var sl := HSlider.new()
        sl.min_value = 0
        sl.max_value = 30
        sl.step = 1
        sl.value = 10
        sl.custom_minimum_size = Vector2(150, 0)
        sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        sl.tooltip_text = k[2]
        tax_sliders[k[0]] = sl
        sl.value_changed.connect(func(v: float) -> void: m.cmd("tax", [String(k[0]), v / 100.0]))
        h.add_child(sl)
    _hdr(bu, "FINANCIAL FOCUS (where the mayor puts the money)")
    var afc := CheckButton.new()
    afc.text = "Council sets focus"
    afc.button_pressed = true
    afc.focus_mode = Control.FOCUS_NONE
    afc.tooltip_text = "On: focus follows prices (dear ore raises mining, dear food raises farming) and danger (military). Moving a slider turns this off."
    afc.toggled.connect(func(on: bool) -> void: m.cmd("auto_focus", [on]))
    focus_auto = afc
    bu.add_child(afc)
    for k in City.FOCUS:
        var fh := HBoxContainer.new()
        bu.add_child(fh)
        var fl := _lbl(fh, 110, "Weight of %s in planner spending. Below 0.4 the town stops making it and buys instead (mining: ore and smelting; military: arms)." % k)
        fl.text = String(k).capitalize()
        var fs := HSlider.new()
        fs.min_value = 0
        fs.max_value = 200
        fs.step = 10
        fs.value = 100
        fs.custom_minimum_size = Vector2(150, 0)
        fs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        focus_sliders[k] = fs
        fs.value_changed.connect(func(v: float) -> void: m.cmd("focus", [String(k), int(v)]))
        fh.add_child(fs)
    _hdr(bu, "INCOME AND EXPENSES  /s")
    budget = _rich(bu, 0)
    graph = Control.new()
    graph.custom_minimum_size = Vector2(0, 60)
    graph.draw.connect(_draw_graph)
    bu.add_child(graph)
    _hdr(bu, "ECONOMY: farms -> mill -> food, factories -> goods")
    econ_l = _rich(bu, 0)
    _hdr(bu, "LOANS (max 3 at once)")
    for k in Civics.LOANS.size():
        var L: Dictionary = Civics.LOANS[k]
        var b := _btn(bu, "%s: get $%d, repay $%d over %d days" % [L["n"], L["amt"], int(float(L["amt"]) * (1.0 + float(L["rate"]))), L["days"]], func() -> void:
            m.headline = "Loan approved: +$%d." % L["amt"] if m.cmd("loan", [k]) else "The bank says no (3 loans max, or the city is too small: pop %d needed)." % L["minpop"])
        b.tooltip_text = "Repayments come out of income every second until it is paid off."
    loans_l = _wrap(bu, 20)
    # Services
    var sv := _tab("Stats")
    _hdr(sv, "COVERAGE OF HOMES (hover for details)")
    cov_box = sv
    for k in Catalog.METRICS:
        var h := HBoxContainer.new()
        h.tooltip_text = Catalog.describe_metric(k).replace("[b]", "").replace("[/b]", "").replace("[color=#9aa88f]", "").replace("[/color]", "")
        sv.add_child(h)
        _lbl(h, 110).text = Catalog.METRICS[k]["n"]
        var pb := ProgressBar.new()
        pb.custom_minimum_size = Vector2(150, 12)
        pb.show_percentage = false
        pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        pb.mouse_filter = Control.MOUSE_FILTER_PASS
        h.add_child(pb)
        cov_bars[k] = pb
    var ch := HBoxContainer.new()
    ch.tooltip_text = "Average crime across homes. Driven by unemployment, density and weak police; street lamps and courts cut it. Raises theft losses and lowers mood."
    sv.add_child(ch)
    _lbl(ch, 110).text = "Crime"
    crime_bar = ProgressBar.new()
    crime_bar.custom_minimum_size = Vector2(150, 12)
    crime_bar.show_percentage = false
    crime_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    crime_bar.mouse_filter = Control.MOUSE_FILTER_PASS
    ch.add_child(crime_bar)
    var cmh := HBoxContainer.new()
    cmh.tooltip_text = "Average walk to work (tiles) and to the nearest shop. Long commutes lower mood; far shops cut shop income. Avenues, buses and mixed zoning shorten them."
    sv.add_child(cmh)
    commute_l = _lbl(cmh, 260)
    land_l = _lbl(sv, 280, "Average land value of homes (0-100). Rises with parks, schools, culture, utilities and low crime; falls with pollution and crime. Raises residential tax and decides which housing styles the planner builds.")
    var pe := _tab("People")
    _hdr(pe, "TRIBES (everyone belongs to one)")
    people_l = _rich(pe, 0)
    var rg := _tab("Region")
    _hdr(rg, "TOWNS (they trade power, water and commuters)")
    region_l = _rich(rg, 0)
    _hdr(rg, "YOUR LAND (the map is bigger than your town)")
    terr_l = _wrap(rg, 0)
    var lh := HBoxContainer.new()
    rg.add_child(lh)
    for d in 4:
        var dn: int = d
        var eb := _btn(lh, "", func() -> void:
            if not m.cmd("expand", [dn]):
                m.headline = "Annexing needs $%d, or you have reached the edge of the map." % int(m.city.expand_cost()))
        eb.tooltip_text = "Buy a strip of land on this side. Each purchase costs more. New land is empty and ready for roads and zones."
        exp_btns.append(eb)
    exp_chk = CheckButton.new()
    exp_chk.text = "Auto-annex when cramped"
    exp_chk.button_pressed = true
    exp_chk.focus_mode = Control.FOCUS_NONE
    exp_chk.tooltip_text = "The planner buys more land by itself when it runs out of room beside roads (needs 1.5x the price in the treasury)."
    exp_chk.toggled.connect(func(on: bool) -> void: m.cmd("auto_expand", [on]))
    rg.add_child(exp_chk)
    dipl_box = VBoxContainer.new()
    dipl_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rg.add_child(dipl_box)
    # Policies
    var po := _tab("Policy")
    _hdr(po, "AUTO-GROWTH (city builds for itself)")
    auto_opt = OptionButton.new()
    auto_opt.add_item("Off - I build everything", 0)
    auto_opt.add_item("Zones only", 1)
    auto_opt.add_item("Zones + roads", 2)
    auto_opt.select(2)
    auto_opt.tooltip_text = "When demand rises, the planner zones free plots next to roads (and extends roads) at the city's own cost. Zones only: it never lays roads."
    auto_opt.item_selected.connect(func(i: int) -> void: m.cmd("auto_mode", [i]))
    po.add_child(auto_opt)
    var ap := CheckButton.new()
    ap.text = "Auto-policies (council decides)"
    ap.button_pressed = true
    ap.focus_mode = Control.FOCUS_NONE
    ap.tooltip_text = "The council switches policies on when the city needs them (crime, waste, pollution, deficit...) and off again when the problem passes. Turn off to run policies yourself."
    auto_chk = ap
    ap.toggled.connect(func(on: bool) -> void: m.cmd("auto_policy", [on]))
    po.add_child(ap)
    var ab := CheckButton.new()
    ab.text = "Ask before planners build services"
    ab.focus_mode = Control.FOCUS_NONE
    ab.tooltip_text = "Planner towns propose each service building (clinic, station, armoury...) as a decision in the Mayor's office. Build it, or veto it and the planner leaves that building alone for 10 days."
    ask_chk = ab
    ab.toggled.connect(func(on: bool) -> void: m.cmd("ask_build", [on]))
    po.add_child(ab)
    _hdr(po, "POLICIES (continuous cost or saving)")
    for k in Catalog.POLICIES:
        var cb := CheckButton.new()
        cb.text = Catalog.POLICIES[k]["n"]
        cb.focus_mode = Control.FOCUS_NONE
        cb.tooltip_text = Catalog.describe_policy(k).replace("[b]", "").replace("[/b]", "").replace("[color=#9aa88f]", "").replace("[/color]", "")
        cb.toggled.connect(func(on: bool) -> void: m.cmd("policy", [k, on]))
        po.add_child(cb)
        pol_btns[k] = cb
    # Events
    var ev := _tab("Events")
    _hdr(ev, "ACTIVE")
    act_l = _rich(ev, 0)
    _hdr(ev, "LOG")
    log_l = _rich(ev, 0)
    # Codex
    var cx := VBoxContainer.new()
    cx.name = "Codex"
    tabs.add_child(cx)
    codex_list = ItemList.new()
    codex_list.custom_minimum_size = Vector2(0, 220)
    codex_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cx.add_child(codex_list)
    for id in Catalog.DEFS:
        codex_list.add_item("Building: " + String(Catalog.DEFS[id]["n"]))
        codex_ids.append(["b", id])
    for k in Catalog.METRICS:
        codex_list.add_item("Stat: " + String(Catalog.METRICS[k]["n"]))
        codex_ids.append(["m", k])
    for k in Catalog.POLICIES:
        codex_list.add_item("Policy: " + String(Catalog.POLICIES[k]["n"]))
        codex_ids.append(["p", k])
    for k in WorldEvents.EVENTS:
        codex_list.add_item("Event: " + String(WorldEvents.EVENTS[k]["n"]))
        codex_ids.append(["e", k])
    codex_text = _rich(cx, 220)
    codex_list.item_selected.connect(_codex_pick)


func _codex_pick(i: int) -> void:
    var c: Array = codex_ids[i]
    match c[0]:
        "b":
            codex_text.text = Catalog.describe_building(c[1], m.city.peak)
        "m":
            codex_text.text = Catalog.describe_metric(c[1])
        "p":
            codex_text.text = Catalog.describe_policy(c[1])
        _:
            codex_text.text = WorldEvents.describe(c[1])


func _tab(name_: String) -> VBoxContainer:
    var sc := ScrollContainer.new()
    sc.name = name_
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    tabs.add_child(sc)
    var v := VBoxContainer.new()
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    v.add_theme_constant_override("separation", 4)
    sc.add_child(v)
    return v


func _hdr(p: Node, text: String) -> void:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 11)
    l.add_theme_color_override("font_color", Color("9aa88f"))
    p.add_child(l)


func _wrap(p: Node, h: float) -> Label:
    var l := Label.new()
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.custom_minimum_size = Vector2(270, h)
    l.add_theme_font_size_override("font_size", 12)
    p.add_child(l)
    return l


func _bottom() -> void:
    var tk := PanelContainer.new()
    tk.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    tk.offset_top = -34
    tk.offset_left = 8
    tk.offset_right = -8
    tk.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(tk)
    ticker = Label.new()
    ticker.clip_text = true
    tk.add_child(ticker)


# ---------- per frame ----------

func _draw_gauge() -> void:
    var c: City = m.city
    var cols := [Color("7bb274"), Color("6f9fcf"), Color("d1b04a"), Color("7d98b8")]
    var vals := [c.res_dem, c.com_dem, c.ind_dem, c.off_dem]
    var names := ["R", "C", "I", "O"]
    var mid := 28.0
    gauge.draw_line(Vector2(0, mid), Vector2(150, mid), Color(1, 1, 1, 0.3))
    for k in 4:
        var x := 8.0 + k * 36.0
        var v: float = vals[k]
        gauge.draw_rect(Rect2(x, mid - maxf(v, 0.0) * 26.0, 22, absf(v) * 26.0), cols[k])
        gauge.draw_string(ThemeDB.fallback_font, Vector2(x + 6, 66), names[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


func _draw_tgauge() -> void:
    var c: City = m.city
    var cols := [Color("7bb274"), Color("6f9fcf"), Color("d1b04a"), Color("7d98b8")]
    var vals := [c.res_dem, c.com_dem, c.ind_dem, c.off_dem]
    var names := ["R", "C", "I", "O"]
    var mid := 11.0
    tgauge.draw_line(Vector2(0, mid), Vector2(96, mid), Color(1, 1, 1, 0.3))
    for k in 4:
        var x := 4.0 + k * 23.0
        var v: float = vals[k]
        tgauge.draw_rect(Rect2(x, mid - maxf(v, 0.0) * 10.0, 14, absf(v) * 10.0), cols[k])
        tgauge.draw_string(ThemeDB.fallback_font, Vector2(x + 3, 25), names[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)


func _net_text(c: City) -> String:
    var parts: Array[String] = []
    var short := false
    for m2 in City.NETS:
        var s: float = c.net_sup[m2]
        var d: float = c.net_dem[m2]
        short = short or (d > s + 0.01 and d > 0.0)
        parts.append("%s %d/%d%s" % [{"power": "P", "water": "W", "sewage": "S"}[m2], int(s), int(d), "!" if d > s + 0.01 else ""])
    _tint(lbl_net, Color("e07a5f") if short else Color("9fd3a0"))
    return "  ".join(parts)


func _draw_graph() -> void:
    graph.draw_rect(Rect2(Vector2.ZERO, graph.size), Color(0, 0, 0, 0.25))
    _line(m.city.hist_coins, Color("d4a017"))
    _line(m.city.hist_pop, Color("9fd3a0"))


func _line(a: Array[float], col: Color) -> void:
    if a.size() < 2:
        return
    var mn: float = a.min()
    var mx: float = a.max()
    if mx - mn < 1.0:
        mx = mn + 1.0
    var pts := PackedVector2Array()
    for i in a.size():
        pts.append(Vector2(float(i) / (a.size() - 1) * graph.size.x, graph.size.y - 4.0 - (a[i] - mn) / (mx - mn) * (graph.size.y - 8.0)))
    graph.draw_polyline(pts, col, 1.5)


func _insp_text() -> String:
    var c: City = m.city
    var sel: City.Citizen = m.sel
    if sel != null and c.citizens.has(sel):
        var hc := City.cell(sel.home)
        var w := "none" if sel.work < 0 else "(%d,%d)" % [City.cell(sel.work).x, City.cell(sel.work).y]
        return "[b]%s[/b] (#%d, %s)  Mood %d%%\nHome (%d,%d)  Work %s\nCommute %d tiles\nNow: %s\nThinks: \"%s\"" % [sel.nm, sel.id, Catalog.TRIBES[sel.tribe]["n"], int(sel.mood * 100.0), hc.x, hc.y, w, sel.commute, sel.doing, c.thought(sel)]
    var i: int = m.sel_cell
    if i >= 0:
        var t: int = c.grid[i]
        if t == T.EMPTY:
            return "Empty land."
        var d: Dictionary = Catalog.DEFS[t]
        var s := "[b]%s[/b]" % d["n"]
        if c.is_zone(t):
            s += "  level %d" % c.lvl[i] if c.lvl[i] > 0 else "  (empty zone)"
        s += "\n" + ("Road access: yes" if c.connected[i] == 1 else "[color=#e07a5f]NO road access - nothing works here[/color]")
        if c.is_zone(t) and c.lvl[i] == 0 and c.connected[i] == 1:
            s += ("\nUnder construction %d%%" % int(c.build[i] * 100.0)) if c.build[i] > 0.0 else "\nWaiting for funds"
        if c.home_load.has(i):
            s += "\nResidents %d / %d" % [c.home_load[i], int(d.get("home", 0)) * c.lvl[i]]
        if c.work_load.has(i):
            s += "\nWorkers %d / %d" % [c.work_load[i], int(d.get("jobs", 0)) * maxi(c.lvl[i], 1)]
        if c.burn[i] > 0.0:
            s += "\n[color=#e07a5f]ON FIRE[/color]"
        return s
    return "Pick Inspect (Q), then click a walking citizen or a building."


## Floating info card for the map cell under the mouse (hidden over UI panels).
## Card pinned by clicking a tile (Inspect tool); stays put and updates live until you click elsewhere.
func _update_pin() -> void:
    var txt := ""
    if m.pin_cell >= 0 and m.started:
        txt = _maptip_text(m.pin_cell % City.W, m.pin_cell / City.W)
    pintip.visible = txt != ""
    if txt == "":
        return
    txt += "\n[color=#9aa88f]click again to close[/color]"
    if pintip_lbl.text != txt:
        pintip_lbl.text = txt
        pintip.reset_size()
    var wp: Vector2 = Vector2(m.pin_cell % City.W + 1, m.pin_cell / City.W) * float(m.TILE)
    var p: Vector2 = m.get_canvas_transform() * wp + Vector2(6, 0)
    p.x = clampf(p.x, 4.0, size.x - pintip.size.x - 4.0)
    p.y = clampf(p.y, 40.0, size.y - pintip.size.y - 40.0)
    pintip.position = p


func _update_maptip() -> void:
    _update_pin()
    var h := get_viewport().gui_get_hovered_control()
    var txt := ""
    if (h == null or h == self) and m.started:
        var mp: Vector2 = m.mouse_tile()
        if m.pin_cell != int(floorf(mp.y)) * City.W + int(floorf(mp.x)):
            txt = _maptip_text(int(floorf(mp.x)), int(floorf(mp.y)))
    maptip.visible = txt != ""
    if txt == "":
        return
    if maptip_lbl.text != txt:
        maptip_lbl.text = txt
        maptip.reset_size()
    var p := get_local_mouse_position() + Vector2(18, 18)
    var sz := maptip.size
    p.x = minf(p.x, size.x - sz.x - 4.0)
    p.y = minf(p.y, size.y - sz.y - 40.0)
    maptip.position = p


func _maptip_text(x: int, y: int) -> String:
    var c: City = m.city
    if not c.inside(x, y):
        return ""
    var i := y * City.W + x
    var wet: bool = c.water[i] == 1
    var t: int = c.grid[i]
    if t == T.EMPTY:
        return "[b]River[/b]  health %d%%\nNo zoning on water. Roads become bridges (4x cost). Untreated sewage kills the fish." % int(c.river_health * 100.0) if wet else ""
    var d: Dictionary = Catalog.DEFS[t]
    var s := "[b]%s[/b]" % d["n"]
    if wet:
        s += " (bridge)"
    if c.is_zone(t):
        s += ("  level %d" % c.lvl[i]) if c.lvl[i] > 0 else "  (empty plot)"
    if c.is_road(t):
        return s
    s += "\n" + ("Road access" if c.connected[i] == 1 else "[color=#e07a5f]NO road access[/color]")
    if c.home_load.has(i):
        s += "\nResidents %d / %d" % [c.home_load[i], int(d.get("home", 0)) * c.lvl[i]]
    if c.work_load.has(i):
        s += "\nWorkers %d / %d" % [c.work_load[i], int(d.get("jobs", 0)) * maxi(c.lvl[i], 1)]
    if c.burn[i] > 0.0:
        s += "\n[color=#e07a5f]ON FIRE[/color]"
    if not d.has("out") and (c.lvl[i] > 0 or not c.is_zone(t)) and String(d["kind"]) != "net":
        var u: Array[String] = []
        for m2 in City.NETS:
            var ok: bool = c.net_val[m2][i] > 0.0
            u.append("[color=%s]%s[/color]" % ["#9fd3a0" if ok else "#e07a5f", {"power": "Power", "water": "Water", "sewage": "Sewer"}[m2]])
        s += "\n" + "  ".join(u)
    s += "\nLand value %d%%" % int(c.land_val[i] * 100.0)
    return s


## Sets a label colour only when it changes (theme overrides re-layout the control every call).
func _tint(l: Label, col: Color) -> void:
    if l.get_meta("tint", Color.TRANSPARENT) != col:
        l.set_meta("tint", col)
        l.add_theme_color_override("font_color", col)


func _process(_d: float) -> void:
    var c: City = m.city
    tick_n += 1
    _update_maptip()
    perf_l.visible = m.perf_on
    if m.perf_on:
        perf_l.text = "%d fps   sim %.1f ms   draw %.1f ms   towns %d" % [Engine.get_frames_per_second(), m.sim_ms, m.draw_ms, m.towns.size()]
    lbl_time.text = "%s  %s  %s" % [c.town_name, c.clock_str(), Civics.SEASONS[c.season]["n"]]
    lbl_appr.text = "Approval %d%%" % int(c.approval * 100.0)
    _tint(lbl_appr, Color("e07a5f") if c.approval < 0.5 else Color("9fd3a0"))
    lbl_coins.text = "$ %d  (%+.2f/s)" % [int(c.coins), c.income]
    _tint(lbl_coins, Color("e07a5f") if c.coins < 0.0 else Color("e8e2d0"))
    lbl_pop.text = "Pop %d/%d" % [c.pop, c.housing]
    lbl_jobs.text = "Jobs %d/%d" % [c.employed, c.jobs]
    lbl_mood.text = "Mood %d%%" % int(c.mood * 100.0)
    bar_mood.value = c.mood * 100.0
    lbl_net.text = _net_text(c)
    ticker.text = m.headline
    var dp: PanelContainer = detail.get_meta("panel")
    var txt := hover_text
    if txt == "" and Catalog.DEFS.has(m.tool):
        txt = Catalog.describe_building(m.tool, c.peak)
    dp.visible = txt != "" and bool(win_open.get("detail", true))
    if detail.text != txt:
        detail.text = txt
    over_panel.visible = c.over != ""
    if c.over != "":
        over_l.text = "GAME OVER\n%s\nPeak population %d.   Press R to restart." % [c.over, int(c.peak)]
    if tick_n % 6 != 0:
        return
    _empire_refresh(c)
    _market_refresh(c)
    for id in tool_btns:
        if Catalog.DEFS.has(id):
            var open: bool = c.unlocked(id)
            var b: Button = tool_btns[id]
            b.disabled = not open
            b.text = String(b.get_meta("base")) + ("" if open else "  (pop %d)" % Catalog.DEFS[id]["unlock"])
    insp.text = _insp_text()
    needs_l.text = "\n".join(c.needs().slice(0, 7))
    goal_l.text = "%s  |  %s" % [Civics.rank(c.peak), c.goal_text()]
    _mayor_tick(c)
    murm.text = "\n".join(c.murmurs.slice(0, 5))
    for k in tax_ls:
        (tax_ls[k] as Label).text = "%s %d%%" % [{"r": "Residential", "c": "Commercial", "i": "Industrial"}[k], int(float(c.get("tax_" + k)) * 100.0)]
    var bt := ""
    for l in c.budget_lines:
        bt += "%s  %+.2f\n" % [l[0], l[1]]
    budget.text = bt + "[b]Net  %+.2f[/b]" % c.income
    crime_bar.value = c.crime * 100.0
    var pt := ""
    for k in Catalog.TRIBES:
        var tr: Dictionary = Catalog.TRIBES[k]
        var mo: float = float(c.tribe_mood.get(k, 0.6))
        pt += "[b]%s[/b]  %d%% of town  opinion %d%%\n[color=#9aa88f]Wants: %s\n%s  %s[/color]\n\n" % [tr["n"], int(float(c.tribe_share.get(k, 0.0)) * 100.0), int(mo * 100.0), tr["wants"], tr["up"], tr["down"]]
    people_l.text = pt
    var rt := ""
    for t in m.towns:
        rt += "[b]%s[/b]%s  pop %d  $%d  mood %d%%\n[color=#9aa88f]Imports power %.0f water %.0f   commuters in %d   trade %+.2f/s%s[/color]\n\n" % [t.town_name, "  (viewing)" if t == c else "", t.pop, int(t.coins), int(t.mood * 100.0), t.imports["power"], t.imports["water"], t.commuters_in, t.trade_net, "   GAME OVER" if t.over != "" else ""]
    _army_refresh(c)
    region_l.text = rt
    terr_l.text = "Territory %dx%d of %dx%d. Next strip costs $%d (annexed %d times)." % [c.terr.size.x, c.terr.size.y, City.W, City.H, int(c.expand_cost()), c.expansions]
    for d in 4:
        var eb: Button = exp_btns[d]
        eb.text = "%s $%d" % [["North", "East", "South", "West"][d], int(c.expand_cost())] if c.can_expand(d) else "%s (edge)" % ["North", "East", "South", "West"][d]
        eb.disabled = not c.can_expand(d)
    _dipl_tick(c)
    land_l.text = "Land value %d / 100   Housing mix tax x%.2f" % [int(c.land_avg * 100.0), c.res_mult * (0.75 + 0.5 * c.land_avg)]
    commute_l.text = "Avg commute %d tiles   nearest shop %d tiles" % [int(c.avg_commute), int(c.avg_shop)]
    for k in cov_bars:
        (cov_bars[k] as ProgressBar).value = float(c.cov.get(k, 0.0)) * 100.0
    var at := ""
    for a in c.active:
        at += "[b]%s[/b]  %ds left\n" % [WorldEvents.EVENTS[a["id"]]["n"], int(a["left"])]
    act_l.text = at if at != "" else "Nothing happening."
    log_l.text = "\n".join(c.event_log.slice(0, 14))
    for k in pol_btns:
        var pb: CheckButton = pol_btns[k]
        if pb.button_pressed != bool(c.policies.get(k, false)):
            pb.set_pressed_no_signal(bool(c.policies.get(k, false)))
    gauge.queue_redraw()
    tgauge.queue_redraw()
    graph.queue_redraw()


# ---------- army window: roster, veterans and training priorities ----------

var army_l: RichTextLabel
var army_chk: CheckButton
var army_rows := {}


func _army() -> void:
    var body := _win("army", "Army", Vector2(220, 80), Vector2(380, 330))
    army_chk = CheckButton.new()
    army_chk.text = "Auto-train troops (T)"
    army_chk.focus_mode = Control.FOCUS_NONE
    army_chk.tooltip_text = "Barracks and bases train units while you can afford them. Units cost upkeep; unpaid troops desert."
    army_chk.toggled.connect(func(on: bool) -> void: m.cmd("train", [on]))
    body.add_child(army_chk)
    army_l = _rich(body, 0)
    _hdr(body, "TRAINING PRIORITY (0 off, 1 slow, 2 normal, 3 fast)")
    var sc := ScrollContainer.new()
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(sc)
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(box)
    for k in Military.KIND:
        var kk: String = k
        var kd: Dictionary = Military.KIND[k]
        var row := HBoxContainer.new()
        row.tooltip_text = "%s: hp %d, damage %.1f, range %d, cost $%d, upkeep %.2f/s. Counts as %s; strong vs %s." % [kd["n"], kd["hp"], kd["dmg"], kd["rng"], kd["cost"], kd["upk"], kd["t"], ", ".join((kd["vs"] as Dictionary).keys().filter(func(t: String) -> bool: return float(kd["vs"][t]) >= 1.3)) if kd.get("heal", 0.0) == 0.0 else "nothing (heals allies)"]
        box.add_child(row)
        _lbl(row, 100).text = String(kd["n"])
        var cl := _lbl(row, 70)
        _btn(row, "-", func() -> void: _set_prio(kk, -1))
        var pl := _lbl(row, 20)
        _btn(row, "+", func() -> void: _set_prio(kk, 1))
        army_rows[k] = {"cnt": cl, "pr": pl}
    win_open["army"] = false
    (wins["army"] as PanelContainer).visible = false


func _set_prio(k: String, d: int) -> void:
    var w := Military.weights(m.city)
    m.cmd("train_w", [k, clampi(int(w[k]) + d, 0, 3)])


func _army_refresh(c: City) -> void:
    if not bool(win_open["army"]):
        return
    army_chk.set_pressed_no_signal(c.train_on)
    var n := Military.counts(c)
    var cap := Military.caps(c)
    var w := Military.weights(c)
    var vets := [0, 0, 0, 0]
    for u in c.army:
        vets[Military.rank(u)] += 1
    army_l.text = "%s\n[color=#9aa88f]Ranks: %d recruits, %d veterans, %d elite, %d legends. Units gain rank by dealing damage.\nBuild barracks (infantry), bases (armour, air) and radar posts (jets, fighters, bombers).[/color]" % [Military.summary(c), vets[0], vets[1], vets[2], vets[3]]
    for k in Military.KIND:
        (army_rows[k]["cnt"] as Label).text = "%d / %d" % [n[k], cap[k]]
        (army_rows[k]["pr"] as Label).text = str(w[k])


# ---------- empire: all your towns at a glance ----------

var emp_tot: Label
var emp_grid: GridContainer
var emp_cells: Array = []  # per town: {"nm", "pop", "co", "inc", "mood", "fl", "go", "send"}
var emp_sort := 0  # 0 order founded, 1 name, 2 pop, 3 coins, 4 net, 5 mood
var emp_auto: OptionButton
var emp_pol: CheckButton
var emp_pool: CheckButton
var emp_exp: CheckButton
var emp_train: CheckButton
var emp_taxl := {}


func _empire() -> void:
    var body := _win("empire", "Empire (all your towns)", Vector2(160, 70), Vector2(600, 400))
    emp_tot = _lbl(body, 0)
    emp_tot.add_theme_font_size_override("font_size", 13)
    var sc := ScrollContainer.new()
    sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    sc.custom_minimum_size = Vector2(0, 250)
    body.add_child(sc)
    emp_grid = GridContainer.new()
    emp_grid.columns = 8
    emp_grid.add_theme_constant_override("h_separation", 8)
    sc.add_child(emp_grid)
    _hdr(body, "ALL MY TOWNS: one setting for every town you run")
    var r1 := HBoxContainer.new()
    body.add_child(r1)
    _lbl(r1, 90).text = "Auto-growth"
    emp_auto = OptionButton.new()
    emp_auto.focus_mode = Control.FOCUS_NONE
    for o in ["Off", "Zones only", "Zones + roads"]:
        emp_auto.add_item(o)
    emp_auto.item_selected.connect(func(i: int) -> void: m.cmd("apply_all", ["auto_mode", i]))
    r1.add_child(emp_auto)
    var r2 := HBoxContainer.new()
    body.add_child(r2)
    emp_pol = _chk(r2, "Auto-policies", "auto_policy")
    emp_exp = _chk(r2, "Auto-annex", "auto_expand")
    emp_train = _chk(r2, "Auto-train troops", "train")
    emp_pool = _chk(r2, "Shared treasury", "pool")
    emp_pool.tooltip_text = "Pooled towns even out their money every 10 seconds: a town above $450 shares half of what exceeds $300, towns under $150 are topped up."
    var r3 := HBoxContainer.new()
    body.add_child(r3)
    _lbl(r3, 40).text = "Tax"
    for k in ["r", "c", "i"]:
        var kk: String = k
        emp_taxl[k] = _lbl(r3, 78)
        _btn(r3, "-", func() -> void: _tax_all(kk, -0.01))
        _btn(r3, "+", func() -> void: _tax_all(kk, 0.01))
    var r4 := HBoxContainer.new()
    body.add_child(r4)
    var bb := _btn(r4, "Balance treasuries (floor $200)", func() -> void:
        var n: Variant = m.cmd("balance", [200])
        m.headline = "Moved $%d between your towns." % int(float(n)) if n != null else "Nothing to balance.")
    bb.tooltip_text = "Rich towns (over $600) give half of what they hold above $400; towns under $200 are topped up. No money is created."
    win_open["empire"] = false
    (wins["empire"] as PanelContainer).visible = false


var mk_grid: GridContainer
var mk_cells := {}  # good -> {"price", "vs", "sup", "dem", "line", "you"}
var mk_note: Label
const MK_NAMES := {"crops": "Crops", "food": "Food", "goods": "Goods", "ore": "Ore", "metal": "Metal", "arms": "Arms"}


func _market_win() -> void:
    var body := _win("market", "Market", Vector2(180, 90), Vector2(560, 260))
    mk_note = _lbl(body, 540)
    mk_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mk_grid = GridContainer.new()
    mk_grid.columns = 7
    mk_grid.add_theme_constant_override("h_separation", 10)
    body.add_child(mk_grid)
    for h in ["Good", "World", "Here", "Offered/s", "Wanted/s", "Last 15 min", "Your town"]:
        _hdr(mk_grid, h)
    for k in Market.GOODS:
        var cell := {"nm": _lbl(mk_grid, 56), "price": _lbl(mk_grid, 52), "vs": _lbl(mk_grid, 56), "sup": _lbl(mk_grid, 66), "dem": _lbl(mk_grid, 66)}
        (cell["nm"] as Label).text = MK_NAMES[k]
        var line := Control.new()
        line.custom_minimum_size = Vector2(120, 24)
        var gk: String = k
        line.draw.connect(func() -> void: _spark(line, gk))
        mk_grid.add_child(line)
        cell["line"] = line
        cell["you"] = _lbl(mk_grid, 150)
        mk_cells[k] = cell
    _hdr(body, "World = the outside market, set by all towns together. Here = your town's price: low when you have plenty, high when you are short, always between selling abroad (80%) and buying abroad (120%). Linked towns (road to the shared border) trade goods when the price gap pays the freight.")
    win_open["market"] = false
    (wins["market"] as PanelContainer).visible = false


func _spark(line: Control, k: String) -> void:
    var h: Array = m.sig.mk.hist[k]
    var r := Rect2(Vector2.ZERO, line.size)
    line.draw_rect(r, Color(0, 0, 0, 0.18))
    if h.size() < 2:
        return
    var lo := float(Market.BASE[k]) * Market.LOW
    var hi := float(Market.BASE[k]) * Market.HIGH
    var by := r.size.y - (float(Market.BASE[k]) - lo) / (hi - lo) * r.size.y
    line.draw_line(Vector2(0, by), Vector2(r.size.x, by), Color(1, 1, 1, 0.25))
    var pts := PackedVector2Array()
    for i in h.size():
        pts.append(Vector2(r.size.x * i / float(Market.HIST - 1), r.size.y - clampf((float(h[i]) - lo) / (hi - lo), 0.0, 1.0) * r.size.y))
    line.draw_polyline(pts, Color("e8c860"), 1.5)


func _market_refresh(c: City) -> void:
    if not bool(win_open["market"]):
        return
    var mk: Market = m.sig.mk
    var sell: Array[String] = []
    var glut: Array[String] = []
    for k in Market.GOODS:
        var cell: Dictionary = mk_cells[k]
        var rt := mk.ratio(k)
        (cell["price"] as Label).text = "$%.2f" % float(mk.price[k])
        (cell["vs"] as Label).text = "$%.2f" % float(c.price_loc[k])
        (cell["sup"] as Label).text = "%.1f" % float(mk.last_sup[k])
        (cell["dem"] as Label).text = "%.1f" % float(mk.last_dem[k])
        (cell["line"] as Control).queue_redraw()
        var sold := float((c.flow.get("sold", {}) as Dictionary).get(k, 0.0))
        var bought := float((c.flow.get("bought", {}) as Dictionary).get(k, 0.0))
        var wanted := float((c.flow.get("want", {}) as Dictionary).get(k, 0.0))
        var tr := float((c.flow.get("traded", {}) as Dictionary).get(k, 0.0))
        (cell["you"] as Label).text = "stock %d, sell %.1f, buy %.1f%s" % [int(c.stock.get(k, 0.0)), sold, maxf(bought, wanted if k in ["food", "goods"] else bought), ("  linked %+.1f" % tr) if absf(tr) > 0.05 else ""]
        if rt > 1.25 and float(c.flow.get(k, 0.0)) > 0.0:
            sell.append(MK_NAMES[k])
        if rt < 0.8:
            glut.append(MK_NAMES[k])
    mk_note.text = ("Worth selling: %s.  " % ", ".join(sell) if not sell.is_empty() else "") + ("Glut (cheap, held back): %s.  " % ", ".join(glut) if not glut.is_empty() else "") + ("Prices are near their base values." if sell.is_empty() and glut.is_empty() else "")


func _chk(p: Node, text: String, key: String) -> CheckButton:
    var c := CheckButton.new()
    c.text = text
    c.focus_mode = Control.FOCUS_NONE
    c.toggled.connect(func(on: bool) -> void: m.cmd("apply_all", [key, on]))
    p.add_child(c)
    return c


func _tax_all(k: String, d: float) -> void:
    m.cmd("apply_all", ["tax", k, clampf(snappedf(float(m.city.get("tax_" + k)) + d, 0.01), 0.0, 0.5)])


func _empire_sort(col: int) -> void:
    emp_sort = col
    emp_cells.clear()  # rebuild in the new order


func _empire_refresh(c: City) -> void:
    if not bool(win_open["empire"]):
        return
    var mine := Empire.mine(m.towns, c)
    var tt := Empire.totals(mine)
    emp_tot.text = "%d of your towns   pop %d   treasury $%d   net %+.1f/s" % [tt["towns"], tt["pop"], int(tt["coins"]), tt["income"]]
    var rows: Array = []
    for t in m.towns:
        rows.append(Empire.row(m.towns, t))
    if emp_sort > 0:
        var key: String = ["", "name", "pop", "coins", "income", "mood"][emp_sort]
        rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a[key]) < String(b[key]) if emp_sort == 1 else float(a[key]) > float(b[key]))
    if emp_cells.size() != rows.size():
        for ch in emp_grid.get_children():
            ch.queue_free()
        emp_cells.clear()
        for k in ["Town", "Pop", "Coins", "Net/s", "Mood", "Alerts", "", ""]:
            var i: int = ["Town", "Pop", "Coins", "Net/s", "Mood", "Alerts", "", ""].find(k)
            if k == "" or k == "Alerts":
                _lbl(emp_grid, 0).text = k
            else:
                _btn(emp_grid, k, func() -> void: _empire_sort(i + 1)).flat = true
        for r in rows:
            var cell := {"nm": _lbl(emp_grid, 100), "pop": _lbl(emp_grid, 40), "co": _lbl(emp_grid, 54), "inc": _lbl(emp_grid, 50), "mood": _lbl(emp_grid, 44), "fl": _lbl(emp_grid, 170)}
            (cell["fl"] as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            (cell["fl"] as Label).add_theme_font_size_override("font_size", 11)
            cell["go"] = _btn(emp_grid, "Go", func() -> void: pass)
            cell["send"] = _btn(emp_grid, "+$100", func() -> void: pass)
            (cell["send"] as Button).tooltip_text = "Send $100 from the town you are viewing (towns on your side only)."
            emp_cells.append(cell)
    for k in rows.size():
        var r: Dictionary = rows[k]
        var cell: Dictionary = emp_cells[k]
        var t: City = m.towns[r["idx"]]
        (cell["nm"] as Label).text = ("> " if t == c else "") + String(r["name"])
        (cell["pop"] as Label).text = str(r["pop"])
        (cell["co"] as Label).text = "$%d" % int(r["coins"])
        (cell["inc"] as Label).text = "%+.1f" % float(r["income"])
        (cell["mood"] as Label).text = "%d%%" % int(float(r["mood"]) * 100.0)
        (cell["fl"] as Label).text = "; ".join(r["flags"]) if not (r["flags"] as Array).is_empty() else "ok"
        var idx: int = r["idx"]
        for sg in (cell["go"] as Button).pressed.get_connections():
            (cell["go"] as Button).pressed.disconnect(sg["callable"])
        (cell["go"] as Button).pressed.connect(func() -> void: m.switch_town(idx))
        for sg in (cell["send"] as Button).pressed.get_connections():
            (cell["send"] as Button).pressed.disconnect(sg["callable"])
        (cell["send"] as Button).pressed.connect(func() -> void: m.cmd("send", [idx, 100]))
        (cell["send"] as Button).disabled = t == c or not Empire.same_side(c, t)
    emp_auto.select(c.auto_mode)
    emp_pol.set_pressed_no_signal(c.auto_policy)
    emp_exp.set_pressed_no_signal(c.auto_expand)
    emp_train.set_pressed_no_signal(c.train_on)
    emp_pool.set_pressed_no_signal(c.pool)
    for k in emp_taxl:
        (emp_taxl[k] as Label).text = "%s %d%%" % [{"r": "Res", "c": "Com", "i": "Ind"}[k], int(float(c.get("tax_" + k)) * 100.0)]


# ---------- mayor's office ----------

func _mayor() -> void:
    var body := _win("mayor", "Mayor's office", Vector2(200, 44), Vector2(330, 360))
    var top := HBoxContainer.new()
    body.add_child(top)
    _lbl(top, 70).text = "Approval"
    appr_bar = ProgressBar.new()
    appr_bar.custom_minimum_size = Vector2(120, 12)
    appr_bar.show_percentage = false
    appr_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    top.add_child(appr_bar)
    rally_b = _btn(top, "Rally $%d" % int(Civics.RALLY_COST), func() -> void:
        m.headline = "" if m.cmd("rally") else "Rallies only in the last 7 days before an election, once per campaign, and they cost $%d." % int(Civics.RALLY_COST))
    rally_b.tooltip_text = "Hold a campaign rally: +7 points of approval. Once per election, only in the last week."
    elect_l = _wrap(body, 0)
    var mt := TabContainer.new()
    mt.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(mt)
    var sc := ScrollContainer.new()
    sc.name = "Decisions"
    sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    mt.add_child(sc)
    dec_box = VBoxContainer.new()
    dec_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sc.add_child(dec_box)
    var av := ScrollContainer.new()
    av.name = "Advisors"
    mt.add_child(av)
    adv_l = _rich(av, 0)
    adv_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var gv := ScrollContainer.new()
    gv.name = "Goals"
    mt.add_child(gv)
    goals_l = _rich(gv, 0)
    goals_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _mayor_tick(c: City) -> void:
    appr_bar.value = c.approval * 100.0
    var dl := c.next_election - c.day
    elect_l.text = "Election in %d day(s), polling %d%%.  Promises kept %d, broken %d.%s" % [dl, int(c.approval * 100.0), c.kept, c.broken, ("  Last vote %d%%." % int(c.last_vote * 100.0)) if c.last_vote > 0.0 else ""]
    rally_b.disabled = c.rally_used or dl > 7 or c.coins < Civics.RALLY_COST
    if c.pet_ver != dec_ver or c != dec_town:
        dec_ver = c.pet_ver
        dec_town = c
        _rebuild_decisions(c)
    var at := ""
    for a in c.advisors():
        at += "[b]%s[/b] %s\n%s\n\n" % [a[0], "[color=#9fd3a0](ok)[/color]" if a[2] else "[color=#e07a5f](worried)[/color]", a[1]]
    adv_l.text = at
    var gt := "[b]Rank: %s[/b]  (peak pop %d)\n\n" % [Civics.rank(c.peak), int(c.peak)]
    for ms in Civics.MILESTONES:
        var done: bool = c.done_ms.has(ms["id"])
        var cur := float(c.get(ms["stat"]))
        gt += "%s %s%s\n" % ["[color=#9fd3a0][x][/color]" if done else "[ ]", ms["n"], "" if done else ("  [color=#9aa88f]%s / %s  reward $%d[/color]" % [_num(cur), _num(float(ms["v"])), ms["reward"]])]
    goals_l.text = gt
    var f: Dictionary = c.flow
    var et := "Stock (cap %d): crops %d  food %d  goods %d  ore %d  metal %d  arms %d\n" % [int(c.cap), int(c.stock["crops"]), int(c.stock["food"]), int(c.stock["goods"]), int(c.stock.get("ore", 0.0)), int(c.stock.get("metal", 0.0)), int(c.stock.get("arms", 0.0))]
    et += "Per second: crops +%.1f  food milled +%.1f  goods +%.1f  ore +%.1f  metal +%.1f\n" % [f.get("crops", 0.0), f.get("food", 0.0), f.get("goods", 0.0), f.get("ore", 0.0), f.get("metal", 0.0)]
    et += "Needs: food %.1f (%d%% local)  goods %.1f (%d%% local)\n" % [f.get("food_need", 0.0), int(float(f.get("food_local", 1.0)) * 100.0), f.get("goods_need", 0.0), int(float(f.get("goods_local", 1.0)) * 100.0)]
    et += "Imports -$%.2f/s   Exports +$%.2f/s   Market price x%.2f\n" % [f.get("imp", 0.0), f.get("ex", 0.0), f.get("price", 1.0)]
    var h: Dictionary = c.hh
    et += "Households: average savings $%d (median $%d), %d%% broke, %d%% comfortable. Prices x%.2f, wages x%.2f (real wage %d%%)\n" % [int(h["avg"]), int(h["median"]), int(float(h["broke"]) * 100.0), int(float(h["rich"]) * 100.0), c.cpi, c.wage_ix, int(float(h["real"]) * 100.0)]
    et += "[color=#9aa88f]Food mills turn crops into food; mines dig ore and foundries smelt it into metal that boosts factories; warehouses add storage; trade depots sell surplus abroad.[/color]"
    econ_l.text = et
    var lt := ""
    for l in c.loans:
        lt += "%s: $%d left (%.2f/s)\n" % [l["n"], int(l["left"]), l["pay"]]
    loans_l.text = lt if lt != "" else "No loans."


func _dipl_tick(c: City) -> void:
    var names: Array[String] = [c.town_name]
    for p in c.partners:
        names.append(p.town_name)
    var key := ",".join(names)
    if key != dipl_key:
        dipl_key = key
        _rebuild_dipl(c)
    for p in c.partners:
        var u: Dictionary = dipl_ui.get(p.town_name, {})
        if u.is_empty():
            continue
        var mine := Diplo.rel(c, p)
        var theirs := Diplo.rel(p, c)
        var tr := Diplo.treaty(c, p)
        (u["bar"] as ProgressBar).value = Diplo.avg(c, p) * 100.0
        (u["r"] as RichTextLabel).text = "[b]%s[/b]  %s%s\n[color=#9aa88f]They like you %d%%, you like them %d%%.  Pop %d  $%d  mood %d%%\nMilitary: theirs %.1f, yours %.1f.  Trade multiplier x%.2f[/color]" % [p.town_name, Diplo.stance(Diplo.avg(c, p)), ("   [%s]" % tr.to_upper()) if tr != "" else "", int(theirs * 100.0), int(mine * 100.0), p.pop, int(p.coins), int(p.mood * 100.0), Diplo.mil(p), Diplo.mil(c), Diplo.tmult(c, p)]
        (u["side"] as Label).text = _side_text(c, p)
        (u["emb"] as Button).text = "Lift embargo" if tr == "embargo" else "Embargo"


func _rebuild_dipl(c: City) -> void:
    for ch in dipl_box.get_children():
        ch.queue_free()
    dipl_ui.clear()
    _hdr(dipl_box, "RELATIONS (bar: how close you are)")
    if c.partners.is_empty():
        _wrap(dipl_box, 0).text = "No neighbours yet."
    for p in c.partners:
        var pp: City = p
        var pc := PanelContainer.new()
        dipl_box.add_child(pc)
        var v := VBoxContainer.new()
        pc.add_child(v)
        var sd := Label.new()
        sd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        sd.custom_minimum_size = Vector2(290, 0)
        sd.add_theme_color_override("font_color", Color("f2cf4a"))
        v.add_child(sd)
        var r := _rich(v, 0)
        r.custom_minimum_size = Vector2(290, 0)
        var bar := ProgressBar.new()
        bar.min_value = -100
        bar.max_value = 100
        bar.show_percentage = false
        bar.custom_minimum_size = Vector2(0, 10)
        v.add_child(bar)
        var h1 := HBoxContainer.new()
        v.add_child(h1)
        var h2 := HBoxContainer.new()
        v.add_child(h2)
        _act_btn(h1, "Gift $100", pp, "gift", "Send aid: they like you +16%, you like them a little more. They keep half the money.")
        _act_btn(h1, "Trade pact $200", pp, "pact", "Needs 15% relation. +25% power/water imports and commuters, and their opinion drifts up.")
        _act_btn(h1, "Alliance $400", pp, "alliance", "Needs a pact and 55% relation. +40% trade and +25% defence coverage for both.")
        var emb := _btn(h2, "Embargo", func() -> void: m.headline = m.say("diplo", [m.towns.find(pp), "lift" if Diplo.treaty(m.city, pp) == "embargo" else "embargo"]))
        emb.tooltip_text = "Cut all trade and commuting. They resent it a lot."
        _act_btn(h2, "Demand tribute", pp, "tribute", "Only works if your military is clearly stronger. They pay up to $150 and resent it.")
        _act_btn(h2, "Peace $150", pp, "peace", "Envoys and apologies: +25% their opinion. Lifts an embargo.")
        _act_btn(h2, "Declare WAR", pp, "war", "Armies march across the border and fight in the enemy town; raids damage buildings and an occupied town surrenders. Strong military (barracks, bases) matters. No trade during war.")
        _act_btn(h2, "Cancel treaty", pp, "leave", "End a pact or alliance. They are upset.")
        dipl_ui[p.town_name] = {"side": sd, "r": r, "bar": bar, "emb": emb}


func _side_text(c: City, p: City) -> String:
    var k := Diplo.side(c, p)
    if k < 0:
        return "%s lies far from you: no road link possible, diplomacy only." % p.town_name
    var s := "%s lies to the %s." % [p.town_name, Diplo.DIRN[k]]
    if Diplo.treaty(c, p) == "war":
        return s + " AT WAR (%d s, enemy units destroyed %d).\nYour army: %s.\n%s army: %s.\nOccupation of your border: %d/40." % [int(c.war_n.get(p.town_name, 0)) * 20, int(c.war_sc.get(p.town_name, 0)), Military.summary(c), p.town_name, Military.summary(p), int(c.occ.get(p.town_name, 0.0))]
    if Diplo.linked(c, p):
        return s + " Road link open: trade and commuters flow."
    if int(c.gate[k]) == 0:
        return s + " No link: build a road to your %s border (gold line)." % Diplo.DIRN[k]
    return s + " Your road reaches the border; they have not met it yet."


func _act_btn(par: Node, text: String, pp: City, what: String, tip: String) -> void:
    var b := _btn(par, text, func() -> void: m.headline = m.say("diplo", [m.towns.find(pp), what]))
    b.tooltip_text = tip


func _num(v: float) -> String:
    return ("%d%%" % int(v * 100.0)) if v <= 1.0 and v > 0.0 and v != floorf(v) else str(int(v))


func _rebuild_decisions(c: City) -> void:
    for ch in dec_box.get_children():
        ch.queue_free()
    _hdr(dec_box, "PETITIONS & DECISIONS")
    if c.petitions.is_empty():
        _wrap(dec_box, 0).text = "No petitions right now. Tribes send them every day or two."
    for k in c.petitions.size():
        var p: Dictionary = c.petitions[k]
        var pc := PanelContainer.new()
        dec_box.add_child(pc)
        var v := VBoxContainer.new()
        pc.add_child(v)
        var r := _rich(v, 0)
        r.custom_minimum_size = Vector2(290, 0)
        var kind: String = p["kind"]
        var rec: bool = kind == "recover"
        var dip: bool = kind == "offer" or kind == "demand"
        var bld: bool = kind == "build"
        var who := "Disaster recovery" if rec else ("Planners" if bld else ("Diplomacy" if dip else String(Catalog.TRIBES[p["tribe"]]["n"])))
        var t := "[b]%s[/b]  [color=#9aa88f]%s, answer by day %d[/color]\n%s" % [p["t"], who, p["expires"], p["txt"]]
        if kind == "petition":
            t += "\n[color=#f2cf4a]Promise: %s within %d days.[/color]" % [Civics.need_text(p["need"]), p["days"]]
        r.text = t
        var h := HBoxContainer.new()
        v.add_child(h)
        var idx := k
        var yes_t := "Accept"
        var no_t := "Decline"
        if rec:
            yes_t = "Rebuild ($%d)" % int(p["cost"])
            no_t = "Let it recover"
        elif bld:
            yes_t = "Build ($%d)" % int(p["cost"])
            no_t = "Veto"
        elif kind == "offer":
            yes_t = "Sign it"
        elif kind == "demand":
            yes_t = "Pay $%d" % int(p["amount"])
            no_t = "Refuse"
        _btn(h, yes_t, func() -> void: m.cmd("answer", [idx, true]))
        _btn(h, no_t, func() -> void: m.cmd("answer", [idx, false]))
    _hdr(dec_box, "PROMISES YOU MADE")
    if c.promises.is_empty():
        _wrap(dec_box, 0).text = "None. Kept promises raise approval; broken ones hurt badly."
    for p in c.promises:
        _wrap(dec_box, 0).text = "%s (%s): %s by day %d" % [p["t"], Catalog.TRIBES[p["tribe"]]["n"], Civics.need_text(p["need"]), p["deadline"]]


func reset() -> void:
    if m.spectating() and wins.has("empire"):  # no mayor: the empire dashboard is the way to play
        _set_open("empire", true)
    dipl_key = ""
    dec_ver = -1
    dec_town = null
    sync_town()


func sync_town() -> void:
    var c: City = m.city
    for k in tax_sliders:
        (tax_sliders[k] as HSlider).set_value_no_signal(float(c.get("tax_" + k)) * 100.0)
    auto_opt.select(c.auto_mode)
    auto_chk.set_pressed_no_signal(c.auto_policy)
    focus_auto.set_pressed_no_signal(c.auto_focus)
    ask_chk.set_pressed_no_signal(c.ask_build)
    for k in City.FOCUS:
        (focus_sliders[k] as HSlider).set_value_no_signal(c.foc(k) * 100.0)
    exp_chk.set_pressed_no_signal(c.auto_expand)


# ---------- floating windows: drag by title, minimize, close, reopen from Windows menu ----------

func _win(key: String, title: String, pos: Vector2, body_min: Vector2) -> VBoxContainer:
    var p := PanelContainer.new()
    p.position = pos
    add_child(p)
    wins[key] = p
    win_open[key] = true
    win_home[key] = pos
    win_min[key] = false
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 4)
    p.add_child(v)
    var bar := HBoxContainer.new()
    bar.mouse_filter = Control.MOUSE_FILTER_STOP
    bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
    v.add_child(bar)
    var t := Label.new()
    t.text = title
    t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    t.add_theme_font_size_override("font_size", 12)
    t.add_theme_color_override("font_color", Color("9aa88f"))
    bar.add_child(t)
    var body := VBoxContainer.new()
    body.custom_minimum_size = body_min
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    v.add_child(body)
    win_bar[key] = bar
    win_title[key] = title
    if key != "detail":  # the hover card shows and hides itself, so it stays in the main window
        var po := _btn(bar, "Out", func() -> void: _popout(key))
        po.tooltip_text = "Move this window into its own OS window (drag it to another screen). Close that window to dock it back."
    var mn := _btn(bar, "-", func() -> void: _minimize(key, body))
    mn.tooltip_text = "Minimize / restore"
    var cl := _btn(bar, "x", func() -> void: _set_open(key, false))
    cl.tooltip_text = "Close (reopen from the Windows menu)"
    bar.gui_input.connect(func(e: InputEvent) -> void:
        if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
            p.position += e.relative
            _clamp(p)
        elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
            if e.pressed:
                p.move_to_front()
                tk_front()
            else:
                _save_ui())
    return body


## Move a window's panel into its own native OS window. Closing that window docks it back. Headless or without
## sub-window support Godot falls back to an embedded window, which behaves the same.
func _popout(key: String, at := Vector2i(-1, -1), sz := Vector2i.ZERO) -> void:
    if pop_wins.has(key) or not wins.has(key):
        return
    var p: PanelContainer = wins[key]
    var w := Window.new()
    w.visible = false  # force_native can only change while hidden
    w.title = "Murmur: %s" % win_title[key]
    w.force_native = true
    w.theme = theme
    w.wrap_controls = true  # never smaller than the panel needs
    w.size = sz if sz != Vector2i.ZERO else Vector2i(maxi(int(p.size.x), 320), maxi(int(p.size.y), 200))
    var win0 := get_window()
    w.position = at if at.x >= 0 else win0.position + Vector2i(p.global_position) + Vector2i(40, 40)
    w.close_requested.connect(func() -> void: _dock(key))
    w.focus_exited.connect(_save_ui)
    w.window_input.connect(func(e: InputEvent) -> void:  # keep the game's hotkeys (Space, Tab, ...) working from here
        if e is InputEventKey and not (w.gui_get_focus_owner() is LineEdit):
            m._unhandled_input(e))
    add_child(w)
    pop_wins[key] = w
    win_prev[key] = p.position
    p.get_parent().remove_child(p)
    w.add_child(p)
    p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    p.visible = true
    (win_bar[key] as Control).visible = false
    w.visible = bool(win_open.get(key, true))
    _save_ui()


func _dock(key: String) -> void:
    if not pop_wins.has(key):
        return
    var w: Window = pop_wins[key]
    var p: PanelContainer = wins[key]
    pop_wins.erase(key)
    w.remove_child(p)
    add_child(p)
    p.set_anchors_preset(Control.PRESET_TOP_LEFT)
    p.position = win_prev.get(key, win_home[key])
    p.set_deferred("size", Vector2.ZERO)
    (win_bar[key] as Control).visible = true
    p.visible = bool(win_open.get(key, true))
    w.queue_free()
    _clamp.call_deferred(p)
    _save_ui()


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST and not pop_wins.is_empty():
        _save_ui()  # remember where the pop-out windows were


func tk_front() -> void:
    ticker.get_parent().move_to_front()


func _minimize(key: String, body: Control) -> void:
    body.visible = not body.visible
    win_min[key] = not body.visible
    var p: PanelContainer = wins[key]
    p.set_deferred("size", Vector2.ZERO)
    _save_ui()


func _set_open(key: String, on: bool) -> void:
    win_open[key] = on
    if pop_wins.has(key):
        (pop_wins[key] as Window).visible = on
    elif key != "detail":
        (wins[key] as PanelContainer).visible = on
        if on:
            (wins[key] as PanelContainer).move_to_front()
            _clamp.call_deferred(wins[key])
    _save_ui()


func _clamp(p: Control) -> void:
    var vs := get_viewport_rect().size
    p.position.x = clampf(p.position.x, 0.0, maxf(vs.x - maxf(p.size.x, 120.0), 0.0))
    p.position.y = clampf(p.position.y, 0.0, maxf(vs.y - maxf(p.size.y, 28.0) - 4.0, 0.0))


func _clamp_all() -> void:
    for k in wins:
        if not pop_wins.has(k):
            _clamp(wins[k])


func _reset_wins() -> void:
    for k in pop_wins.keys():
        _dock(k)
    var vs := get_viewport_rect().size
    for k in wins:
        var p: PanelContainer = wins[k]
        p.visible = k != "detail" and k != "army" and k != "empire" and k != "market"
        win_open[k] = k != "army" and k != "empire" and k != "market"
        p.set_deferred("size", Vector2.ZERO)
    (wins["build"] as PanelContainer).position = Vector2(8, 44)
    (wins["info"] as PanelContainer).position = Vector2(maxf(vs.x - 396.0, 200.0), 44)
    (wins["detail"] as PanelContainer).position = Vector2(200, clampf(vs.y - 300.0, 60.0, 400.0))
    (wins["mayor"] as PanelContainer).position = Vector2(200, 44)
    (wins["army"] as PanelContainer).position = Vector2(220, 80)
    (wins["empire"] as PanelContainer).position = Vector2(160, 70)
    (wins["market"] as PanelContainer).position = Vector2(180, 90)
    _clamp_all.call_deferred()
    _save_ui()


func _save_ui() -> void:
    var cf := ConfigFile.new()
    for k in wins:
        var p: PanelContainer = wins[k]
        cf.set_value(k, "pos", p.position)
        cf.set_value(k, "open", bool(win_open[k]))
        cf.set_value(k, "min", bool(win_min[k]))
        cf.set_value(k, "popped", pop_wins.has(k))
        if pop_wins.has(k):
            cf.set_value(k, "wpos", (pop_wins[k] as Window).position)
            cf.set_value(k, "wsize", (pop_wins[k] as Window).size)
    cf.save(UI_FILE)


func _load_ui() -> void:
    var cf := ConfigFile.new()
    if cf.load(UI_FILE) != OK:
        return
    for k in wins:
        if not cf.has_section(k):
            continue
        var p: PanelContainer = wins[k]
        p.position = cf.get_value(k, "pos", p.position)
        win_open[k] = bool(cf.get_value(k, "open", k != "army"))
        if k != "detail":
            p.visible = bool(win_open[k])
        if bool(cf.get_value(k, "min", false)) and k != "detail":
            _minimize.call_deferred(k, p.get_child(0).get_child(1))
        if bool(cf.get_value(k, "popped", false)) and k != "detail":
            _popout.call_deferred(k, cf.get_value(k, "wpos", Vector2i(-1, -1)), cf.get_value(k, "wsize", Vector2i.ZERO))
    _clamp_all.call_deferred()
