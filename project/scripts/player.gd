extends CharacterBody3D
const G=preload("res://scripts/geo.gd")
var active=true
var visual: Node3D
var limbs: Array=[]
var anim=0.0
var knees:Array=[]
var elbows:Array=[]
var main
var test_direction=Vector2.ZERO
var test_control=false

func _ready() -> void:
    collision_layer=4;collision_mask=11
    floor_snap_length=.4
    var col=CollisionShape3D.new();var cap=CapsuleShape3D.new();cap.radius=.3;cap.height=1.75;col.shape=cap;col.position.y=.91;add_child(col)
    visual=Node3D.new();add_child(visual)
    var jacket=G.mat(Color("334c5b"),.88);var jeans=G.mat(Color("263646"));var skin=G.mat(Color("c59d7b"));var shoes=G.mat(Color("24282a"));var hair=G.mat(Color("39332e"));var dark=G.mat(Color("17242c"));var white=G.mat(Color("ddd8c7"))
    G.ellipsoid(visual,Vector3(0,1.20,0),Vector3(.25,.32,.15),jacket)
    G.ellipsoid(visual,Vector3(0,.94,0),Vector3(.21,.15,.14),jeans)
    G.cylinder(visual,Vector3(0,1.49,0),.075,.15,skin,20)
    G.ellipsoid(visual,Vector3(0,1.68,-.012),Vector3(.145,.195,.145),skin)
    G.ellipsoid(visual,Vector3(0,1.79,.012),Vector3(.150,.102,.146),hair)
    G.ellipsoid(visual,Vector3(0,1.671,-.157),Vector3(.030,.042,.040),skin)
    for side in [-1,1]:
        G.ellipsoid(visual,Vector3(side*.145,1.685,0),Vector3(.028,.048,.025),skin)
        G.ellipsoid(visual,Vector3(side*.053,1.718,-.139),Vector3(.031,.015,.008),white)
        G.ellipsoid(visual,Vector3(side*.053,1.718,-.148),Vector3(.010,.011,.004),dark)
        G.tube(visual,Vector3(side*.031,1.746,-.14),Vector3(side*.080,1.748,-.132),.009,hair)
    G.tube(visual,Vector3(-.038,1.607,-.138),Vector3(.038,1.607,-.138),.007,G.mat(Color("8d5d52")))
    G.tube(visual,Vector3(0,.98,-.15),Vector3(0,1.43,-.147),.006,white)
    for side in [-1,1]:
        G.box(visual,Vector3(side*.12,1.16,-.147),Vector3(.11,.12,.018),dark)
        G.tube(visual,Vector3(side*.035,1.47,-.075),Vector3(side*.13,1.37,-.14),.025,jacket)
        var leg=Node3D.new();visual.add_child(leg);leg.position=Vector3(side*.115,.89,0);limbs.append(leg)
        G.ellipsoid(leg,Vector3(0,-.20,0),Vector3(.10,.225,.11),jeans)
        var knee=Node3D.new();leg.add_child(knee);knee.position.y=-.39;knees.append(knee)
        G.ellipsoid(knee,Vector3(0,-.185,0),Vector3(.080,.21,.085),jeans)
        G.ellipsoid(knee,Vector3(0,-.40,-.045),Vector3(.105,.073,.18),shoes)
        G.box(knee,Vector3(0,-.445,-.047),Vector3(.20,.035,.30),white)
        for z in [-.07,-.11,-.15]:G.tube(knee,Vector3(-.046,-.365,z),Vector3(.046,-.365,z),.005,white,8)
    for side in [-1,1]:
        var arm=Node3D.new();visual.add_child(arm);arm.position=Vector3(side*.255,1.39,0);limbs.append(arm)
        G.ellipsoid(arm,Vector3(side*.025,-.14,0),Vector3(.095,.20,.095),jacket)
        var elbow=Node3D.new();arm.add_child(elbow);elbow.position=Vector3(side*.035,-.30,0);elbows.append(elbow)
        G.ellipsoid(elbow,Vector3(0,-.115,0),Vector3(.073,.16,.075),jacket)
        G.ellipsoid(elbow,Vector3(0,-.29,-.006),Vector3(.061,.082,.036),skin)
        for finger in range(4):G.tube(elbow,Vector3(-.039+finger*.025,-.31,-.007),Vector3(-.039+finger*.025,-.385,-.017),.010,skin,8)
        G.tube(elbow,Vector3(-side*.042,-.272,-.008),Vector3(-side*.071,-.32,-.033),.015,skin,10)

func _physics_process(dt: float) -> void:
    if not active:return
    var input=Input.get_vector("left","right","forward","back")
    if test_control:input=test_direction
    var yaw = main.camera_yaw if main else 0.0
    var wish=Vector3(input.x,0,input.y).rotated(Vector3.UP,yaw)
    var speed=6.2 if Input.is_action_pressed("run") else 3.1
    velocity.x=move_toward(velocity.x,wish.x*speed,dt*18)
    velocity.z=move_toward(velocity.z,wish.z*speed,dt*18)
    if not is_on_floor():velocity.y-=19.6*dt
    elif Input.is_action_just_pressed("handbrake"):velocity.y=5.5
    else:velocity.y=-.5
    var old=global_position
    move_and_slide()
    if main and not main.world.contains(global_position):global_position=old;velocity=Vector3.ZERO
    var moving=Vector2(velocity.x,velocity.z).length()
    if moving>.12:
        visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-velocity.x,-velocity.z),dt*12)
    anim+=dt*moving*2.9
    for i in range(limbs.size()):
        var signv=1 if i in [0,3] else -1
        limbs[i].rotation.x=lerpf(limbs[i].rotation.x,sin(anim)*.55*signv if moving>.1 else 0,dt*14)

    for i in range(knees.size()):
        knees[i].rotation.x=maxf(0,-sin(anim+(0 if i==0 else PI)))*.70 if moving>.1 else 0
    for i in range(elbows.size()):elbows[i].rotation.x=-.20-(.45 if moving>4 else .12)

func set_active(value: bool) -> void:
    active=value
    visible=value
    set_physics_process(value)
    collision_layer=4 if value else 0
    velocity=Vector3.ZERO
