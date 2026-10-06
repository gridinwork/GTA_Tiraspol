extends Control
const MAP=preload("res://scripts/map.gd")
var main
var font=preload("res://assets/DejaVuSans.ttf")
var mini: Control
var bigmap: Control
var map_title: Label
var panel: PanelContainer
var menu: VBoxContainer
var help=true
var toast=""
var toast_left=0.0
var settings_page=false
var accent=Color("ffba68")
var white=Color("f4eee3")

func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    theme=Theme.new();theme.default_font=font;theme.default_font_size=17
    var bs=StyleBoxFlat.new();bs.bg_color=Color("273b43");bs.set_corner_radius_all(6);bs.content_margin_left=16;bs.content_margin_right=16;bs.content_margin_top=10;bs.content_margin_bottom=10
    theme.set_stylebox("normal","Button",bs)
    var hover=bs.duplicate();hover.bg_color=Color("3d535a");theme.set_stylebox("hover","Button",hover)
    var pressed=bs.duplicate();pressed.bg_color=Color("a97641");theme.set_stylebox("pressed","Button",pressed)
    theme.set_color("font_color","Button",white)
    theme.set_color("font_hover_color","Button",accent)
    mini=MAP.new();mini.main=main;add_child(mini)
    bigmap=MAP.new();bigmap.main=main;bigmap.expanded=true;bigmap.visible=false;add_child(bigmap)
    map_title=Label.new();map_title.text="КАРТА РАЙОНА   ·   Tab / Esc — закрыть   ·   ЛКМ — метка   ·   ПКМ — убрать";map_title.visible=false;map_title.add_theme_font_size_override("font_size",16);add_child(map_title)
    panel=PanelContainer.new();add_child(panel)
    var style=StyleBoxFlat.new();style.bg_color=Color(0.05,.095,.12,.95);style.set_corner_radius_all(12);style.border_color=Color("51666a");style.set_border_width_all(1);style.content_margin_left=30;style.content_margin_right=30;style.content_margin_top=25;style.content_margin_bottom=24
    panel.add_theme_stylebox_override("panel",style)
    menu=VBoxContainer.new();menu.add_theme_constant_override("separation",9);panel.add_child(menu)
    show_main_menu()

func _clear_menu() -> void:
    for child in menu.get_children():menu.remove_child(child);child.queue_free()

func _label(textv: String, fontsize: int=17, color: Color=Color("f4eee3")) -> Label:
    var l=Label.new();l.text=textv;l.add_theme_font_size_override("font_size",fontsize);l.modulate=color;menu.add_child(l);return l

func _button(textv: String, action: Callable) -> Button:
    var b=Button.new();b.text=textv;b.custom_minimum_size.y=43;b.pressed.connect(action);menu.add_child(b);return b

func show_main_menu() -> void:
    settings_page=false;_clear_menu()
    _label("TECHNOLAB   /   OPEN DISTRICT",13,accent)
    _label("TIRASPOL",43)
    _label("БАЛКА   ·   СВОБОДНАЯ ПОЕЗДКА",17,Color("a8bfc3"))
    _label("",4)
    var start=_button("Продолжить" if main.started else "Начать прогулку",func():main.resume_game())
    _button("Настройки",show_settings)
    _button("Вернуться к «Тернополю»",func():main.reset_start();main.resume_game())
    _button("Сохранить и выйти",func():main.save_game();get_tree().quit())
    _label("Стрелки / WASD — движение    Enter — сесть / выйти",14,Color("b9c8c9"))
    _label("Пробел — ручник / прыжок    C — камера    Tab — карта",14,Color("b9c8c9"))
    _label("Мышь — обзор    Shift — бег    R — вернуть на дорогу",14,Color("b9c8c9"))
    _label("0.3 · 409 зданий · пешеходы и 4 типа машин",13,Color("859b9e"))
    start.grab_focus()

func show_settings() -> void:
    settings_page=true;_clear_menu()
    _label("НАСТРОЙКИ",29)
    _label("Профиль для Intel UHD 620",14,accent)
    _button("Графика: "+["низкая","средняя","высокая"][main.quality],func():main.set_quality((main.quality+1)%3);show_settings())
    _button("Город: "+["пустой","8 машин / 12 пешеходов","16 машин / 24 пешехода"][main.population_density],func():main.set_population((main.population_density+1)%3);show_settings())
    var res=OptionButton.new();res.add_item("1280 × 720 — рекомендуется");res.add_item("1600 × 900");res.add_item("1920 × 1080");res.selected=main.resolution_index;res.custom_minimum_size.y=36;menu.add_child(res)
    res.item_selected.connect(func(i):main.change_resolution(i))
    _button("Полный экран / окно · F11",func():main.toggle_fullscreen())
    _slider("Громкость",0.0,1.0,main.volume,func(v):main.set_volume(v))
    _slider("Сцепление шин",0.55,1.5,main.car.grip,func(v):main.car.grip=v;main.save_settings())
    _slider("Инерция / масса",0.6,1.6,main.car.inertia,func(v):main.car.inertia=v;main.save_settings())
    _label("F5 — сохранить позицию     F9 — загрузить",14,Color("a8bfc3"))
    _button("Назад",show_main_menu)

func _slider(title: String, low: float, high: float, value: float, action: Callable) -> void:
    var label=_label(title+"  "+str(snappedf(value,.01)),14)
    var slider=HSlider.new();slider.min_value=low;slider.max_value=high;slider.step=.05;slider.value=value;slider.custom_minimum_size.y=23;menu.add_child(slider)
    slider.value_changed.connect(func(v):label.text=title+"  "+str(snappedf(v,.01));action.call(v))

func _process(dt: float) -> void:
    toast_left=maxf(0,toast_left-dt)
    var s=get_viewport_rect().size
    mini.position=Vector2(24,s.y-216);mini.size=Vector2(258,180)
    mini.visible=not panel.visible and not bigmap.visible
    bigmap.size=Vector2(minf(s.x-120,960),s.y-140);bigmap.position=(s-bigmap.size)/2+Vector2(0,10)
    map_title.position=bigmap.position-Vector2(0,31)
    panel.size=Vector2(570,0)
    panel.position=(s-panel.size)/2
    queue_redraw()

func _text(pos: Vector2, txt: String, fontsize: int=18, color: Color=Color("f4eee3")) -> void:
    draw_string(font,pos,txt,HORIZONTAL_ALIGNMENT_LEFT,-1,fontsize,color)

func _draw() -> void:
    if not main:return
    var s=get_viewport_rect().size
    if panel.visible:
        draw_rect(Rect2(Vector2.ZERO,s),Color(0.02,.045,.06,.29))
        return
    if bigmap.visible:
        draw_rect(Rect2(Vector2.ZERO,s),Color(0.025,.05,.065,.94))
        _text(Vector2(60,44),"БАЛКА / ТИРАСПОЛЬ",25)
        _text(Vector2(60,s.y-29),"Контур выбранной территории · © OpenStreetMap contributors · геопривязка приблизительная",13,Color("a8bfc3"))
        return
    draw_rect(Rect2(24,22,295,72),Color(0.045,.085,.105,.85))
    draw_rect(Rect2(24,22,3,72),accent)
    _text(Vector2(40,49),"TIRASPOL  /  БАЛКА",21)
    _text(Vector2(40,77),main.street_name,14,Color("a9c0c5"))
    _text(Vector2(s.x-190,39),str(Engine.get_frames_per_second())+" FPS  /  "+["НИЗКИЕ","СРЕДНИЕ","ВЫСОКИЕ"][main.quality],13,Color("d7e0db"))
    _text(Vector2(26,s.y-225),"КАРТА   [TAB]",12,accent)
    _text(Vector2(26,s.y-15),"© OpenStreetMap contributors",10,Color("a2b4b1"))
    if main.driving:
        var x=s.x-239;var y=s.y-145
        draw_rect(Rect2(x,y,215,120),Color(.045,.085,.105,.88))
        _text(Vector2(x+16,y+25),"TOUAREG  R5  /  2005",12,Color("a9c0c5"))
        _text(Vector2(x+15,y+82),"%03d" % int(main.car.speed_kmh),48)
        _text(Vector2(x+127,y+79),"км/ч",15,accent)
        var gear="R" if main.car.longitudinal < -.4 else ("N" if main.car.speed_kmh<1 else str(clampi(1+int(main.car.speed_kmh/22),1,5)))
        _text(Vector2(x+175,y+79),gear,25)
        var ratio=clampf(main.car.speed_kmh/60,0,1)
        draw_rect(Rect2(x+16,y+98,180,3),Color("405257"));draw_rect(Rect2(x+16,y+98,180*ratio,3),accent)
        _text(Vector2(x,y-12),main.camera_names[main.camera_mode]+"  [C]",12,Color("e1e6df"))
    else:
        var near=main.player.position.distance_to(main.car.position)<4.1
        if near:
            draw_rect(Rect2(s.x/2-169,s.y-105,338,39),Color(.04,.07,.09,.88))
            _text(Vector2(s.x/2-151,s.y-80),"ENTER  ·  Сесть в Touareg",19,accent)
    if help:
        _text(Vector2(303,s.y-67),"Стрелки / WASD · движение     Enter · сесть / выйти",12,Color("e0e6df"))
        _text(Vector2(303,s.y-45),"Пробел · ручник     C · камера     R · сброс     Esc · меню",12,Color("e0e6df"))
        _text(Vector2(303,s.y-24),"F1 · скрыть подсказки     L · фары     H · сигнал",12,Color("a8bfc3"))
    if toast_left>0:
        var length=font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
        draw_rect(Rect2(s.x/2-length/2-18,114,length+36,39),Color(.04,.07,.09,.91))
        _text(Vector2(s.x/2-length/2,140),toast,17,accent)
    if main.waypoint!=Vector2.INF:
        var p=main.car.position if main.driving else main.player.position
        var dist=Vector2(p.x,p.z).distance_to(main.waypoint)
        _text(Vector2(s.x/2-80,40),"МЕТКА  ·  "+str(int(dist))+" м",15,accent)

func notify(textv: String) -> void:
    if toast==textv and toast_left>1:return
    toast=textv;toast_left=3.8

func set_map(value: bool) -> void:
    bigmap.visible=value;map_title.visible=value

