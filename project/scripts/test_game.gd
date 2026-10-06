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
    # Regression checks for the requested driving, map and obstacle changes.
    var probe=preload("res://scripts/car.gd").new();game.add_child(probe)
    probe.position=Vector3(1200,10,1000);probe.collision_mask=0
    probe.test_control=true;probe.test_throttle=1
    await frames(180)
    check(probe.speed_kmh>22 and probe.speed_kmh<33,"Gentler acceleration: 22–33 km/h after three seconds")
    await frames(480)
    check(probe.speed_kmh>59 and probe.speed_kmh<=60.001,"Physical forward speed is capped at 60 km/h")
    probe.test_steer=1;probe.test_brake=true
    await frames(25)
    check(probe.speed_kmh<=60.001,"Drift lateral velocity also respects the speed cap")
    probe.queue_free()
    check(game.world.tree_bodies.size()==game.world.data.trees.size(),"Every visible tree has a solid trunk collider")
    game.car.set_physics_process(false)
    var tree=game.world.tree_bodies[0]
    game.car.position=tree.position+Vector3(0,.10,5);game.car.rotation=Vector3.ZERO
    var hit=game.car.move_and_collide(Vector3(0,0,-8))
    check(hit!=null and hit.get_collider().has_meta("solid_tree"),"Vehicle sweep is blocked by a tree trunk")
    var lamp=preload("res://scripts/pole.gd").new();game.add_child(lamp);lamp.position=Vector3(1100,0,900)
    await frames(2)
    game.car.position=lamp.position+Vector3(0,.10,5)
    var pole_hit=game.car.move_and_collide(Vector3(0,0,-8))
    check(pole_hit!=null and pole_hit.get_collider()==lamp,"Lamp post collision is detected by the car")
    lamp.vehicle_hit(Vector3(0,0,-3));await frames(35)
    check(lamp.state=="bent" and lamp.angle>.2 and not lamp.upper_shape.disabled,"Low speed impact bends the pole and keeps its collider")
    lamp.vehicle_hit(Vector3(0,0,-10));await frames(65)
    check(lamp.state=="broken" and lamp.angle>1.4 and lamp.upper_shape.disabled,"Strong impact breaks the pole and clears the driving path")
    lamp.queue_free();game.car.set_physics_process(true);game.reset_start()
    var map=preload("res://scripts/map.gd").new();map.size=Vector2(200,200);map.center=Vector2.ZERO;map.factor=1;map.heading=PI/2
    var forward_point=map._point(Vector2(-10,0))-map.size/2
    check(absf(forward_point.x)<.001 and forward_point.y<0,"Heading-up minimap puts vehicle forward at the top")
    map.free()
    check(game.world.data.buildings.filter(func(b):return not str(b.get("housenumber","")).is_empty()).size()>250,"House numbers are retained from OSM for address labels")
    game.set_population(1)
    await frames(3)
    check(game.population.cars.size()==8 and game.population.people.size()==12,"Light population creates 8 cars and 12 pedestrians")
    var types={}
    for actor in game.population.cars:types[actor.model_type]=true
    check(types.size()==4,"Traffic contains ZAZ, Zhiguli, Moskvich and modern Lada")
    check(game.population.cars.all(func(a):return not a.edge.is_empty()),"All traffic cars have valid road routes")
    check(game.population.people.all(func(a):return not a.edge.is_empty()),"All pedestrians have sidewalk routes")
    await frames(180)
    var car_motion=0.0;var ped_motion=0.0
    for actor in game.population.cars:car_motion+=actor.travelled
    for actor in game.population.people:ped_motion+=actor.travelled
    check(car_motion>10,"Traffic cars move along their routes")
    check(ped_motion>5,"Pedestrians walk and animate along sidewalks")
    game.population.set_process(false)
    var actor=game.population.cars[0];actor.set_physics_process(false);actor.edge={};actor.position=Vector3(1100,.15,1000);actor.rotation=Vector3.ZERO
    game.car.set_physics_process(false);game.car.position=Vector3(1100,.15,1007);game.car.rotation=Vector3.ZERO
    await frames(2)
    var traffic_hit=game.car.move_and_collide(Vector3(0,0,-10))
    check(traffic_hit!=null and traffic_hit.get_collider()==actor,"Player vehicle collides with a traffic vehicle")
    actor.edge={"a":"test_a","b":"test_b","start":Vector3(1100,.15,1100),"end":Vector3(1100,.15,900),"width":8.0}
    actor.position=game.population.edge_point(actor.edge,.5,false);actor.rotation=Vector3.ZERO
    game.car.position=actor.position+Vector3(0,0,-6);game.car.velocity=Vector3.ZERO
    actor.speed=2;actor.set_physics_process(true)
    await frames(90)
    check(actor.speed<.1 and actor.position.distance_to(game.car.position)>3.5,"Traffic brakes for the player's car and preserves separation")
    game.car.set_physics_process(true);game.reset_start()
    game.set_population(0);game.population.set_process(true);await frames(2)
    check(game.population.cars.is_empty() and game.population.people.is_empty(),"Population can be disabled without leftover actors")
    for preset in range(3):game.set_quality(preset);check(game.quality==preset,"Graphics preset "+str(preset)+" applies")
    game.set_quality(0)
    var geo=preload("res://scripts/geo.gd")
    var group=Node3D.new();game.add_child(group);var material=geo.mat(Color.WHITE)
    var surface=geo.surface();geo.tri(surface,Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3.FORWARD)
    geo.mesh_node(group,surface,material);geo.box(group,Vector3.ZERO,Vector3.ONE,material)
    geo.merge_static_children(group)
    var faces=0
    for child in group.get_children():faces+=child.mesh.get_faces().size()/3
    check(faces==13,"Mesh batching preserves both unindexed body panels and indexed primitive details")
    group.queue_free()
    var report={"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"platform":OS.get_name(),"note":"Automated functional checks; not a Windows or UHD 620 benchmark."}
    var args=OS.get_cmdline_user_args();var output="user://test_report.json";var idx=args.find("--test")
    if idx>=0 and args.size()>idx+1:output=args[idx+1]
    var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
    print("TEST_RESULT ",checks.size()-failures.size(),"/",checks.size()," ",output)
    get_tree().call_deferred("quit",0 if failures.is_empty() else 1)
