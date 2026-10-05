extends Node
var checks: Array=[]
var failures: Array=[]

func check(value: bool, description: String) -> void:
    checks.append({"pass":value,"check":description})
    if not value:failures.append(description)
    print("PASS " if value else "FAIL ",description)

func frames(count: int) -> void:
    for i in range(count):await get_tree().physics_frame

func run(game) -> void:
    await frames(40)
    check(game.world.data.buildings.size()==409,"409 real building footprints loaded")
    check(game.world.roads.size()==276,"276 real street/path sections loaded")
    check(game.world.contains(game.car.position),"Starting vehicle is inside selected boundary")
    check(game.world.collision_count>20,"Batched building collision shapes exist")
    check(game.player.is_on_floor(),"Character settles onto the ground")
    var first=game.player.position
    game.player.test_control=true;game.player.test_direction=Vector2(-1,0)
    await frames(60)
    game.player.test_direction=Vector2.ZERO;game.player.test_control=false
    check(game.player.position.distance_to(first)>1,"Walking changes the character's position")
    game.reset_start();await frames(5)
    check(game.interact_car() and game.driving and not game.player.visible,"Enter vehicle hides and disables walking character")
    game.car.test_control=true;game.car.test_throttle=1
    var start=game.car.position
    await frames(180)
    check(game.car.speed_kmh>20,"Vehicle accelerates above 20 km/h")
    check(game.car.position.distance_to(start)>10,"Driving moves across the map")
    check(not game.interact_car() and game.driving,"Exit is prevented while moving quickly")
    var prev_yaw=game.car.rotation.y
    game.car.test_steer=.7;game.car.test_brake=true
    await frames(35)
    check(absf(game.car.rotation.y-prev_yaw)>.1,"Steering and handbrake change vehicle heading")
    game.car.test_control=false;game.car.test_throttle=0;game.car.test_steer=0;game.car.test_brake=false
    game.car.reset_to(game.world.spawn_pos,game.world.spawn_yaw)
    await frames(6)
    var cameras=[]
    for i in range(5):
        game.camera_mode=i;game.car.cockpit_visibility(i==2);game._update_camera(1,true)
        cameras.append(game.camera.position)
        check(game.camera.position.is_finite(),"Camera "+str(i)+" has a finite transform")
    check(cameras[1].distance_to(cameras[2])>5,"Cockpit and external cameras use different locations")
    check(game.interact_car() and not game.driving and game.player.visible,"Stopped vehicle permits a safe exit")
    await frames(20)
    check(game.player.is_on_floor(),"Character remains grounded after exit")
    game.car.set_physics_process(false)
    var building=game.world.data.buildings.filter(func(b):return b.name=="Тернополь")[0]
    var poly=PackedVector2Array()
    for p in building.polygon:poly.append(Vector2(p[0],p[1]))
    var a=poly[0];var b=poly[1];var edge=(b-a).normalized();var normal=Vector2(edge.y,-edge.x)
    var mid=(a+b)/2
    if Geometry2D.is_point_in_polygon(mid+normal*2,poly):normal=-normal
    game.car.position=Vector3(mid.x+normal.x*10,.3,mid.y+normal.y*10)
    game.car.rotation.y=atan2(normal.x,normal.y)
    var collision=game.car.move_and_collide(Vector3(-normal.x*17,0,-normal.y*17))
    check(collision!=null,"Vehicle shape collides with an actual building wall")
    game.car.set_physics_process(true)
    game.reset_start();await frames(5)
    game.interact_car()
    game.save_game("user://test_save.cfg")
    var saved=game.car.position
    game.car.position+=Vector3(12,0,12)
    check(game.load_game("user://test_save.cfg") and game.car.position.distance_to(saved)<.01,"Save/load restores vehicle position and driving state")
    game.reset_road()
    check(game.world.contains(game.car.position),"Reset puts the car on a road inside the map")
    game.pause_game();check(get_tree().paused and game.hud.panel.visible,"Pause opens menu and stops simulation")
    game.resume_game();check(not get_tree().paused and not game.hud.panel.visible,"Resume returns to the game")
    game.toggle_map();check(get_tree().paused and game.hud.bigmap.visible,"Map opens and pauses game")
    game.toggle_map();check(not get_tree().paused,"Closing map resumes game")
    var report={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"platform":OS.get_name(),"note":"Automated functional checks; not a Windows or UHD 620 benchmark."}
    var args=OS.get_cmdline_user_args();var output="user://test_report.json";var idx=args.find("--test")
    if idx>=0 and args.size()>idx+1:output=args[idx+1]
    var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
    print("TEST_RESULT ",checks.size()-failures.size(),"/",checks.size()," ",output)
    get_tree().quit(0 if failures.is_empty() else 1)
