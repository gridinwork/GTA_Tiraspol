extends CharacterBody3D
const G=preload("res://scripts/geo.gd")
var manager
var pedestrian=false
var model_type=0
var edge={}
var progress=0.0
var speed=0.0
var desired_speed=7.0
var wheels=[]
var limbs=[]
var visual:Node3D
var age=0.0
var travelled=0.0
var previous=Vector3.ZERO
var blocked_time=0.0

func _ready() -> void:
    collision_layer=16 if pedestrian else 8
    collision_mask=11 if pedestrian else 31
    floor_snap_length=.4
    var col=CollisionShape3D.new()
    if pedestrian:
        var shape=CapsuleShape3D.new();shape.radius=.24;shape.height=1.75;col.shape=shape;col.position.y=.91
        var donor=preload("res://scripts/player.gd").new();add_child(donor);donor.set_physics_process(false)
        visual=donor.visual;limbs=donor.limbs.duplicate();visual.reparent(self);donor.queue_free()
        visual.scale=Vector3.ONE*(.94+.04*(model_type%3))
        for child in visual.get_children():
            if child is MeshInstance3D and child.material_override and child.material_override.albedo_color.is_equal_approx(Color("334c5b")):
                var mat=child.material_override.duplicate();mat.albedo_color=[Color("80554b"),Color("47635b"),Color("536c89"),Color("a69874")][model_type%4];child.material_override=mat
        desired_speed=1.1+.17*(model_type%4)
    else:
        var shape=BoxShape3D.new();shape.size=Vector3(1.8,1.55,4.35);col.shape=shape;col.position.y=.79
        visual=Node3D.new();add_child(visual)
        wheels=preload("res://scripts/traffic_model.gd").build(visual,model_type,[Color("c0a66c"),Color("872e2b"),Color("487b86"),Color("a6adb2")][model_type])
        desired_speed=6.5+model_type*.55
    add_child(col)
    previous=position

func _physics_process(dt:float) -> void:
    if edge.is_empty():return
    age+=dt
    var target=manager.edge_point(edge,1.0,pedestrian)
    var delta=target-global_position;delta.y=0
    if delta.length()<1.0:
        edge=manager.next_edge(edge,pedestrian)
        target=manager.edge_point(edge,1.0,pedestrian);delta=target-global_position;delta.y=0
    var direction=delta.normalized()
    var stop=false
    var scan=4.0 if pedestrian else maxf(7.0,speed*1.6)
    if not pedestrian:
        var query=PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.85,global_position+Vector3.UP*.85+direction*scan,30,[get_rid()])
        stop=not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
        # Unsignalised intersections: deterministic alternating priority.
        if delta.length()<7 and manager.outgoing.get(edge.b,[]).size()>2:
            stop=stop or (int(manager.clock/4.0)%2 != (int(absf(direction.x)>.65)))
    speed=move_toward(speed,0 if stop else desired_speed,dt*(5.0 if stop else 1.4))
    velocity.x=direction.x*speed;velocity.z=direction.z*speed
    velocity.y=-.5 if is_on_floor() else velocity.y-19.6*dt
    var before=global_position
    move_and_slide()
    var dist=Vector2(global_position.x-before.x,global_position.z-before.z).length();travelled+=dist
    if dist<.005 and not stop:blocked_time+=dt
    else:blocked_time=0
    if dist>.001:
        var yaw=atan2(-direction.x,-direction.z)
        if pedestrian:visual.rotation.y=lerp_angle(visual.rotation.y,yaw,dt*7)
        else:rotation.y=lerp_angle(rotation.y,yaw,dt*3)
    for wheel in wheels:wheel.rotation.x-=speed*dt/.34
    for i in range(limbs.size()):limbs[i].rotation.x=sin(age*speed*5)*.45*(1 if i in [0,3] else -1)
    if blocked_time>8:manager.relocate(self)
