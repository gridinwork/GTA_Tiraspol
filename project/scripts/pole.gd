extends StaticBody3D
const G=preload("res://scripts/geo.gd")
var state="intact"
var last_hit_ms=-1000
var bend_axis=Vector3.RIGHT
var angle=0.0
var target_angle=0.0
var hinge:Node3D
var upper_shape:CollisionShape3D
var upper:Node3D

func _ready() -> void:
    collision_layer=1;collision_mask=0
    var metal=G.mat(Color("68777c"),.4)
    G.cylinder(self,Vector3(0,.42,0),.15,.84,metal,12,.115)
    hinge=Node3D.new();hinge.position.y=.82;add_child(hinge)
    upper=Node3D.new();hinge.add_child(upper)
    G.cylinder(upper,Vector3(0,2.55,0),.11,5.1,metal,12,.065)
    var arm=G.cylinder(upper,Vector3(0,5.0,-.5),.055,1.25,metal,10);arm.rotation.x=PI/2
    G.box(upper,Vector3(0,5,-1.05),Vector3(.36,.16,.66),G.mat(Color("dde1cb")))
    upper_shape=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=.16;shape.height=6.2;upper_shape.shape=shape;upper_shape.position.y=3.1;add_child(upper_shape)
    set_physics_process(false)

func vehicle_hit(impact:Vector3) -> void:
    var speed=Vector2(impact.x,impact.z).length()
    if state=="broken" or speed<1.5:return
    if speed<6.0 and Time.get_ticks_msec()-last_hit_ms<800:return
    last_hit_ms=Time.get_ticks_msec()
    var direction=(global_basis.inverse()*Vector3(impact.x,0,impact.z)).normalized()
    bend_axis=Vector3.UP.cross(direction).normalized()
    if speed>=6.0 or state=="bent":
        state="broken";target_angle=1.56
        upper_shape.set_deferred("disabled",true)
    else:
        state="bent";target_angle=.40
    set_physics_process(true)

func _physics_process(dt:float) -> void:
    angle=move_toward(angle,target_angle,dt*(1.9 if state=="broken" else 1.2))
    hinge.basis=Basis(bend_axis,angle)
    if state=="broken":hinge.position.y=lerpf(.82,.13,angle/target_angle)
    else:
        upper_shape.position=Vector3(0,.82,0)+hinge.basis*Vector3(0,2.4,0)
        upper_shape.basis=hinge.basis
    if is_equal_approx(angle,target_angle):set_physics_process(false)
