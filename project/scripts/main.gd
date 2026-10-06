extends Node3D
const WORLD=preload("res://scripts/world.gd")
const CAR=preload("res://scripts/car.gd")
const PLAYER=preload("res://scripts/player.gd")
const HUD=preload("res://scripts/hud.gd")
var world
var car
var player
var hud
var camera: Camera3D
var driving=false
var started=false
var camera_yaw=-.64
var camera_pitch=.26
var camera_mode=1
var camera_names=["Ближняя камера","Дальняя камера","Из салона","На капоте","Вид сверху"]
var mouse_idle=10.0
var street_name="Краснодонская улица"
var road_timer=0.0
var quality=0
var volume=.65
var resolution_index=0
var waypoint=Vector2.INF
var testing=false
var capturing=false
var cfg=ConfigFile.new()

func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    testing="--test" in OS.get_cmdline_user_args()
    capturing="--capture" in OS.get_cmdline_user_args()
    _input_actions()
    world=WORLD.new();world.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(world)
    car=CAR.new();car.main=self;car.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(car)
    player=PLAYER.new();player.main=self;player.process_mode=Node.PROCESS_MODE_PAUSABLE;add_child(player)
    camera=Camera3D.new();camera.near=.08;camera.far=900;camera.fov=67;add_child(camera);camera.current=true
    var layer=CanvasLayer.new();add_child(layer)
    hud=HUD.new();hud.main=self;layer.add_child(hud)
    load_settings()
    reset_start()
    _update_camera(1.0,true)
    if testing or capturing:
        started=true;hud.panel.visible=false;get_tree().paused=false
        if testing:call_deferred("_run_tests")
        if capturing:call_deferred("_capture")
    else:
        get_tree().paused=true
        Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _input_actions() -> void:
    var bindings={"forward":[KEY_W,KEY_UP],"back":[KEY_S,KEY_DOWN],"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"run":[KEY_SHIFT],"handbrake":[KEY_SPACE],"enter_car":[KEY_ENTER,KEY_KP_ENTER],"camera":[KEY_C],"map":[KEY_TAB],"pause":[KEY_ESCAPE],"reset":[KEY_R],"headlights":[KEY_L],"horn":[KEY_H]}
    for action in bindings:
        if not InputMap.has_action(action):InputMap.add_action(action)
        for key in bindings[action]:
            var e=InputEventKey.new();e.physical_keycode=key;InputMap.action_add_event(action,e)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
        camera_yaw-=event.relative.x*.003
        camera_pitch=clampf(camera_pitch+event.relative.y*.003,-.18,1.18)
        mouse_idle=0
    if event is InputEventMouseButton and event.pressed and not get_tree().paused:
        if event.button_index==MOUSE_BUTTON_RIGHT:
            camera_yaw=car.rotation.y if driving else player.visual.rotation.y;camera_pitch=.26;mouse_idle=10
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode==KEY_F11:toggle_fullscreen();return
        if event.physical_keycode==KEY_F1:hud.help=not hud.help;return
        if event.is_action_pressed("pause"):
            if hud.bigmap.visible:toggle_map()
            elif get_tree().paused:resume_game()
            else:pause_game()
            return
        if event.is_action_pressed("map") and not hud.panel.visible:toggle_map();return
        if get_tree().paused:return
        if event.is_action_pressed("enter_car"):interact_car()
        if event.is_action_pressed("camera"):cycle_camera()
        if event.is_action_pressed("reset"):reset_road()
        if event.is_action_pressed("headlights"):car.toggle_lights()
        if event.is_action_pressed("horn") and driving:car.horn.play()
        if event.physical_keycode==KEY_F5:save_game();notify("Позиция сохранена")
        if event.physical_keycode==KEY_F9:load_game()
        if event.physical_keycode==KEY_F2:set_quality(1-quality);notify("Графика: "+("низкая" if quality==0 else "средняя"))

func _process(dt: float) -> void:
    if get_tree().paused:return
    mouse_idle+=dt
    _update_camera(dt)
    road_timer-=dt
    if road_timer<0:
        road_timer=.65
        var pos=car.position if driving else player.position
        var road=world.nearest_road(pos)
        street_name=road.name

func _update_camera(dt: float, snap: bool=false) -> void:
    var target: Vector3
    var desired: Vector3
    if driving:
        target=car.global_position+Vector3(0,1.3,0)
        if mouse_idle>2.4 and car.speed_kmh>2:
            camera_yaw=lerp_angle(camera_yaw,car.rotation.y,1-exp(-dt*2.5))
            camera_pitch=lerpf(camera_pitch,.23,dt)
        if camera_mode==2:
            desired=car.to_global(Vector3(-.43,1.70,-.32))
            var local_yaw=wrapf(camera_yaw-car.rotation.y,-PI,PI)
            local_yaw=clampf(local_yaw,-1.6,1.6)
            target=desired+Vector3(0,-sin(camera_pitch-.20),-cos(camera_pitch-.20)).rotated(Vector3.UP,car.rotation.y+local_yaw)*20
        elif camera_mode==3:
            desired=car.to_global(Vector3(0,1.37,-1.93))
            target=desired-car.global_basis.z*20+Vector3.UP*.1
        elif camera_mode==4:
            desired=target+Vector3(0,35,12)
        else:
            var distance=7.0 if camera_mode==0 else 10.5
            var offset=Vector3(0,sin(camera_pitch)*distance+1.1,cos(camera_pitch)*distance).rotated(Vector3.UP,camera_yaw)
            desired=target+offset
    else:
        target=player.global_position+Vector3.UP*1.4
        desired=target+Vector3(.5,sin(camera_pitch)*5.2+.65,cos(camera_pitch)*5.2).rotated(Vector3.UP,camera_yaw)
    if not driving or camera_mode in [0,1,4]:
        var query=PhysicsRayQueryParameters3D.create(target,desired,1)
        var hit=get_world_3d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():desired=hit.position+hit.normal*.3
    var weight=1.0 if snap or (driving and camera_mode in [2,3]) else 1-exp(-dt*10)
    camera.global_position=camera.global_position.lerp(desired,weight)
    if camera.global_position.distance_to(target)>.05:camera.look_at(target,Vector3.UP)
    camera.fov=lerpf(camera.fov,67+minf(car.speed_kmh*.085,9) if driving else 65,clampf(dt*3,0,1))

func resume_game() -> void:
    started=true;hud.panel.visible=false;hud.set_map(false);get_tree().paused=false
    if not testing and not capturing:Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func pause_game() -> void:
    get_tree().paused=true;hud.panel.visible=true;hud.set_map(false);hud.show_main_menu();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
    save_settings()

func toggle_map() -> void:
    var value=not hud.bigmap.visible
    hud.set_map(value);get_tree().paused=value
    Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED

func interact_car() -> bool:
    if driving:
        if car.speed_kmh>7:
            notify("Сначала останови автомобиль")
            return false
        var exits=[Vector3(-2.0,.25,.25),Vector3(2.0,.25,.25),Vector3(0,.25,3.4)]
        for exit_offset in exits:
            var point=car.to_global(exit_offset)
            var shape=CapsuleShape3D.new();shape.radius=.32;shape.height=1.8
            var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*.92);query.collision_mask=3;query.exclude=[car.get_rid()]
            if world.contains(point) and get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
                driving=false;car.active=false;car.velocity=Vector3.ZERO;car.cockpit_visibility(false)
                player.global_position=point;player.set_active(true);player.visual.rotation.y=car.rotation.y
                camera_yaw=car.rotation.y;camera_pitch=.26;_update_camera(1,true)
                return true
        notify("Недостаточно места для выхода. Отъедь от стены.")
        return false
    if player.global_position.distance_to(car.global_position)>4.1:
        notify("Подойди ближе к Touareg")
        return false
    driving=true;car.active=true;player.set_active(false)
    camera_yaw=car.rotation.y;camera_pitch=.26;mouse_idle=10
    car.cockpit_visibility(camera_mode==2)
    _update_camera(1,true)
    return true

func cycle_camera() -> void:
    if driving:
        camera_mode=(camera_mode+1)%camera_names.size()
        car.cockpit_visibility(camera_mode==2)
        camera_yaw=car.rotation.y;camera_pitch=.26;mouse_idle=10
        notify(camera_names[camera_mode])
    else:
        camera_yaw=player.visual.rotation.y
        camera_pitch=.26
    _update_camera(1,true)

func reset_start() -> void:
    driving=false;car.active=false;car.reset_to(world.spawn_pos,world.spawn_yaw);car.cockpit_visibility(false)
    player.set_active(true);player.global_position=world.spawn_pos+Vector3(-2.6,.5,.5).rotated(Vector3.UP,world.spawn_yaw)
    player.visual.rotation.y=world.spawn_yaw
    camera_yaw=world.spawn_yaw;camera_pitch=.26
    if camera:_update_camera(1,true)

func reset_road() -> void:
    var road=world.nearest_road(car.position if driving else player.position)
    if driving:car.reset_to(road.point,road.yaw);camera_yaw=road.yaw
    else:player.global_position=road.point+Vector3.UP*.3;player.velocity=Vector3.ZERO
    _update_camera(1,true);notify("Возвращено на ближайшую дорогу")

func notify(textv: String) -> void:
    if hud:hud.notify(textv)

func set_quality(value: int) -> void:
    quality=value
    world.sun.shadow_enabled=quality==1
    get_viewport().msaa_3d=Viewport.MSAA_DISABLED if quality==0 else Viewport.MSAA_2X
    world.environment.fog_density=.0016 if quality==0 else .00105
    camera.far=720 if quality==0 else 900
    save_settings()

func change_resolution(i: int) -> void:
    resolution_index=i
    var sizes=[Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]
    DisplayServer.window_set_size(sizes[i])
    get_tree().root.content_scale_size=Vector2i(1280,720)
    save_settings()

func toggle_fullscreen() -> void:
    var mode=DisplayServer.window_get_mode()
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func set_volume(value: float) -> void:
    volume=value
    AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,volume)))
    save_settings()

func load_settings() -> void:
    cfg.load("user://settings.cfg")
    quality=int(cfg.get_value("graphics","quality",0));resolution_index=int(cfg.get_value("graphics","resolution",0))
    volume=float(cfg.get_value("audio","volume",.65));car.grip=float(cfg.get_value("car","grip",1.0));car.inertia=float(cfg.get_value("car","inertia",1.0))
    set_quality(quality);set_volume(volume)
    if not testing and not capturing:change_resolution(clampi(resolution_index,0,2))

func save_settings() -> void:
    if testing or capturing:return
    cfg.set_value("graphics","quality",quality);cfg.set_value("graphics","resolution",resolution_index)
    cfg.set_value("audio","volume",volume);cfg.set_value("car","grip",car.grip);cfg.set_value("car","inertia",car.inertia)
    cfg.save("user://settings.cfg")

func save_game(path: String="user://save.cfg") -> void:
    var save=ConfigFile.new();save.set_value("state","car_position",car.position);save.set_value("state","car_yaw",car.rotation.y)
    save.set_value("state","player_position",player.position);save.set_value("state","driving",driving);save.set_value("state","camera",camera_mode)
    save.save(path)

func load_game(path: String="user://save.cfg") -> bool:
    var save=ConfigFile.new()
    if save.load(path)!=OK:notify("Сохранения пока нет. Используй F5.");return false
    var p=save.get_value("state","car_position",world.spawn_pos)
    if not world.contains(p):notify("Сохранение вне карты");return false
    car.reset_to(p,save.get_value("state","car_yaw",world.spawn_yaw))
    driving=save.get_value("state","driving",false);car.active=driving;player.set_active(not driving)
    player.position=save.get_value("state","player_position",world.spawn_pos)
    camera_mode=clampi(int(save.get_value("state","camera",1)),0,4)
    car.cockpit_visibility(driving and camera_mode==2)
    camera_yaw=car.rotation.y;_update_camera(1,true);notify("Позиция загружена");return true

func _notification(what: int) -> void:
    if what==NOTIFICATION_WM_CLOSE_REQUEST and car and player:save_game()

func _run_tests() -> void:
    var test=load("res://scripts/test_game.gd").new()
    add_child(test)
    test.run(self)

func _capture() -> void:
    var args=OS.get_cmdline_user_args();var path="/tmp/tiraspol"
    var i=args.find("--capture");if i>=0 and args.size()>i+1:path=args[i+1]
    for step in range(50):await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(path+"_walk.png")
    interact_car();camera_mode=1;camera_yaw=car.rotation.y-.38;_update_camera(1,true)
    for step in range(15):await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(path+"_drive.png")
    camera_mode=2;car.cockpit_visibility(true);camera_yaw=car.rotation.y;_update_camera(1,true)
    for step in range(15):await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(path+"_cockpit.png")
    toggle_map()
    for step in range(5):await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(path+"_map.png")
    hud.bigmap.zoom=3.2;hud.bigmap.pan=Vector2(300,90)
    for step in range(5):await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(path+"_addresses.png")
    toggle_map();car.cockpit_visibility(false);set_process(false);get_tree().paused=true
    camera.position=car.position+Vector3(-4.5,2.9,-6.5).rotated(Vector3.UP,car.rotation.y)
    camera.look_at(car.position+Vector3(0,1.1,0))
    for step in range(5):await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(path+"_car.png")
    camera.position=car.position+Vector3(0,10,0);camera.look_at(Vector3(-60,3,18))
    for step in range(5):await get_tree().process_frame
    await RenderingServer.frame_post_draw
    get_viewport().get_texture().get_image().save_png(path+"_ternopol.png")
    print("CAPTURES_OK ",path)
    get_tree().call_deferred("quit")
