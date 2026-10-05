extends CharacterBody3D
const G=preload("res://scripts/geo.gd")
var active=true
var visual: Node3D
var limbs: Array=[]
var anim=0.0
var main
var test_direction=Vector2.ZERO
var test_control=false

func _ready() -> void:
    collision_layer=4;collision_mask=3
    floor_snap_length=.4
    var col=CollisionShape3D.new();var cap=CapsuleShape3D.new();cap.radius=.3;cap.height=1.75;col.shape=cap;col.position.y=.91;add_child(col)
    visual=Node3D.new();add_child(visual)
    var jacket=G.mat(Color("334c5b"));var jeans=G.mat(Color("283743"));var skin=G.mat(Color("c09876"));var shoes=G.mat(Color("1a222a"));var hair=G.mat(Color("423a30"))
    G.box(visual,Vector3(0,1.2,0),Vector3(.48,.57,.28),jacket)
    G.box(visual,Vector3(0,.9,0),Vector3(.38,.19,.26),jeans)
    G.ball(visual,Vector3(0,1.68,-.01),.19,skin)
    var h=G.ball(visual,Vector3(0,1.76,.025),.184,hair);h.scale.y=.5
    for side in [-1,1]:
        var leg=Node3D.new();visual.add_child(leg);leg.position=Vector3(side*.125,.88,0);limbs.append(leg)
        G.box(leg,Vector3(0,-.34,0),Vector3(.18,.64,.20),jeans)
        G.box(leg,Vector3(0,-.76,-.045),Vector3(.20,.16,.32),shoes)
    for side in [-1,1]:
        var arm=Node3D.new();visual.add_child(arm);arm.position=Vector3(side*.30,1.41,0);limbs.append(arm)
        G.box(arm,Vector3(0,-.23,0),Vector3(.16,.46,.18),jacket)
        G.ball(arm,Vector3(0,-.51,0),.095,skin)

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

func set_active(value: bool) -> void:
    active=value
    visible=value
    set_physics_process(value)
    collision_layer=4 if value else 0
    velocity=Vector3.ZERO
