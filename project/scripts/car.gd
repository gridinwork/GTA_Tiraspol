extends CharacterBody3D
const G = preload("res://scripts/geo.gd")
var active = false
var steering = 0.0
var wheel_spin = 0.0
var longitudinal = 0.0
var speed_kmh = 0.0
var throttle_value = 0.0
var grip = 1.0
var inertia = 1.0
var distance_driven = 0.0
var visual: Node3D
var wheels: Array = []
var front_pivots: Array = []
var brake_material: StandardMaterial3D
var engine: AudioStreamPlayer
var horn: AudioStreamPlayer
var lights_on = false
var lamps: Array = []
var main
var test_throttle = 0.0
var test_steer = 0.0
var test_brake = false
var test_control = false

func _ready() -> void:
    name="Touareg"
    collision_layer=2
    collision_mask=1
    floor_snap_length=0.4
    var c=CollisionShape3D.new();var sh=BoxShape3D.new();sh.size=Vector3(1.96,1.84,4.65);c.shape=sh;c.position=Vector3(0,.94,0);add_child(c)
    visual=Node3D.new();add_child(visual)
    _model()
    engine=AudioStreamPlayer.new();engine.stream=load("res://assets/engine.wav");engine.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;engine.stream.loop_end=int(engine.stream.get_length()*engine.stream.mix_rate);engine.volume_db=-15;add_child(engine)
    horn=AudioStreamPlayer.new();horn.stream=load("res://assets/horn.wav");horn.volume_db=-15;add_child(horn)

func _loft(sections: Array, material: Material) -> MeshInstance3D:
    var s=G.surface()
    for i in range(sections.size()-1):
        var a=sections[i];var b=sections[i+1]
        # z, lower half width, upper half width, bottom, top
        var av=[Vector3(-a[1],a[3],a[0]),Vector3(a[1],a[3],a[0]),Vector3(a[2],a[4],a[0]),Vector3(-a[2],a[4],a[0])]
        var bv=[Vector3(-b[1],b[3],b[0]),Vector3(b[1],b[3],b[0]),Vector3(b[2],b[4],b[0]),Vector3(-b[2],b[4],b[0])]
        for j in range(4):
            var k=(j+1)%4;var normal=(av[k]-av[j]).cross(bv[j]-av[j]).normalized()
            G.quad(s,av[j],av[k],bv[k],bv[j],normal)
        if i==0:G.quad(s,av[3],av[2],av[1],av[0],Vector3.FORWARD)
        if i==sections.size()-2:G.quad(s,bv[0],bv[1],bv[2],bv[3],Vector3.BACK)
    return G.mesh_node(visual,s,material)

func _model() -> void:
    var paint=G.mat(Color("101820"),.28);paint.metallic=.65
    var trim=G.mat(Color("080d10"),.78)
    var glass=G.mat(Color("416575"),.22);glass.metallic=.45
    var chrome=G.mat(Color("aebfc7"),.23);chrome.metallic=.85
    var tyre=G.mat(Color("181b1c"),.95)
    var head=G.mat(Color("dae9e5"),.15);head.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    brake_material=G.mat(Color("842b27"),.3)
    _loft([[-2.38,.84,.81,.53,1.06],[-1.87,.99,.94,.49,1.24],[-.9,1.0,.95,.49,1.28],[1.62,1.0,.95,.5,1.29],[2.35,.87,.86,.55,1.18]],paint)
    # The tall cabin and short bonnet are characteristic of the 7L Touareg.
    _loft([[-1.16,.89,.76,1.22,1.36],[-.52,.9,.78,1.23,1.96],[1.3,.9,.78,1.23,1.96],[1.97,.88,.75,1.2,1.65]],glass)
    G.box(visual,Vector3(0,2.0,.36),Vector3(1.6,.1,1.95),paint)
    for side in [-1,1]:
        G.box(visual,Vector3(side*.925,1.41,.32),Vector3(.08,.17,2.63),paint)
        G.box(visual,Vector3(side*.851,1.70,.22),Vector3(.09,.54,.15),paint)
        var ap=G.box(visual,Vector3(side*.83,1.69,-.79),Vector3(.09,.75,.11),paint);ap.rotation.x=-.72
        var cp=G.box(visual,Vector3(side*.82,1.70,1.57),Vector3(.1,.63,.15),paint);cp.rotation.x=.68
        G.box(visual,Vector3(side*.73,2.095,.35),Vector3(.065,.06,2.1),chrome)
        for z in [-.55,1.25]:G.box(visual,Vector3(side*.73,2.05,z),Vector3(.08,.11,.09),trim)
        G.box(visual,Vector3(side*1.08,1.43,-.75),Vector3(.27,.17,.29),paint)
        for z in [-.12,1.01]:G.box(visual,Vector3(side*.968,1.31,z),Vector3(.035,.05,.23),chrome)
        G.box(visual,Vector3(side*.99,.55,.1),Vector3(.07,.17,3.2),trim)
        for z in [-1.47,1.48]:
            var pivot=Node3D.new();visual.add_child(pivot);pivot.position=Vector3(side*.96,.47,z)
            if z<0:front_pivots.append(pivot)
            var spin=Node3D.new();pivot.add_child(spin);wheels.append(spin)
            var tire=G.cylinder(spin,Vector3.ZERO,.47,.30,tyre,16);tire.rotation.z=PI/2
            var rim=G.cylinder(spin,Vector3(side*.16,0,0),.29,.024,chrome,12);rim.rotation.z=PI/2
            var cap=G.cylinder(spin,Vector3(side*.178,0,0),.105,.035,trim,10);cap.rotation.z=PI/2
            for a in range(5):
                var spoke=G.box(spin,Vector3(side*.178,sin(a*TAU/5)*.16,cos(a*TAU/5)*.16),Vector3(.035,.07,.3),chrome)
                spoke.rotation.x=-a*TAU/5
    G.box(visual,Vector3(0,.66,-2.34),Vector3(1.69,.21,.13),trim)
    G.box(visual,Vector3(0,.74,2.34),Vector3(1.73,.19,.12),trim)
    G.box(visual,Vector3(0,1.00,-2.383),Vector3(.88,.34,.04),trim)
    for y in [.88,.97,1.06,1.15]:G.box(visual,Vector3(0,y,-2.411),Vector3(.84,.023,.016),chrome)
    var badge=G.cylinder(visual,Vector3(0,1.08,-2.43),.095,.02,chrome,16);badge.rotation.x=PI/2
    for side in [-1,1]:
        var h=G.ball(visual,Vector3(side*.66,1.11,-2.245),.205,head);h.scale=Vector3(1.3,.62,.35)
        var h2=G.ball(visual,Vector3(side*.59,.66,-2.36),.076,head);h2.scale.z=.2
        G.box(visual,Vector3(side*.72,1.13,2.34),Vector3(.27,.36,.04),brake_material)
        var spot=SpotLight3D.new();spot.position=Vector3(side*.66,1.1,-2.3);spot.light_color=Color("fff2ce");spot.light_energy=1.1;spot.spot_range=26;spot.spot_angle=32;spot.shadow_enabled=false;spot.visible=false;visual.add_child(spot);lamps.append(spot)
    for z in [-2.426,2.412]:
        G.box(visual,Vector3(0,.71,z),Vector3(.51,.115,.022),head)
        var plate=Label3D.new();plate.text="TL 2005";plate.font_size=36;plate.pixel_size=.0022;plate.modulate=Color("15222a");plate.outline_size=0;plate.position=Vector3(0,.715,z+(-.015 if z<0 else .015));plate.rotation.y=PI if z<0 else 0;visual.add_child(plate)
    # Interior is visible in cockpit camera. The windshield stays transparent by
    # hiding only the glass shell when cockpit mode is selected.
    var dashboard=G.box(visual,Vector3(0,1.30,-.70),Vector3(1.64,.24,.46),trim);dashboard.name="Dashboard"
    for x in [-.43,.43]:
        G.box(visual,Vector3(x,.99,.25),Vector3(.55,.17,.59),trim)
        var seat=G.box(visual,Vector3(x,1.30,.57),Vector3(.53,.69,.18),trim);seat.rotation.x=-.1
        G.box(visual,Vector3(x,1.70,.6),Vector3(.35,.24,.14),trim)
    var steering_wheel=G.cylinder(visual,Vector3(-.43,1.39,-.47),.19,.036,chrome,12);steering_wheel.rotation.x=1.1
    G.box(visual,Vector3(-.43,1.40,-.50),Vector3(.27,.035,.035),trim)

func cockpit_visibility(enabled: bool) -> void:
    for n in visual.get_children():
        if n is MeshInstance3D and n.material_override is StandardMaterial3D:
            var c = n.material_override.albedo_color
            if c.is_equal_approx(Color("416575")):n.visible=not enabled

func _physics_process(dt: float) -> void:
    var old=position
    var throttle=0.0;var steer_input=0.0;var handbrake=false
    if active:
        throttle=Input.get_axis("back","forward")
        steer_input=Input.get_axis("left","right")
        handbrake=Input.is_action_pressed("handbrake")
    if test_control:throttle=test_throttle;steer_input=test_steer;handbrake=test_brake
    throttle_value=throttle
    var forward = -global_basis.z
    var right = global_basis.x
    longitudinal=Vector3(velocity.x,0,velocity.z).dot(forward)
    var side_velocity=Vector3(velocity.x,0,velocity.z).dot(right)
    var max_steer=lerpf(.57,.22,clampf(absf(longitudinal)/29,0,1))
    steering=move_toward(steering,steer_input*max_steer,dt*1.7)
    var accel=4.4/maxf(inertia,.4)
    if throttle>0:
        longitudinal=move_toward(longitudinal,31.0,dt*(10.0 if longitudinal<-.4 else accel))
    elif throttle<0:
        longitudinal=move_toward(longitudinal,-8.0,dt*(10.0 if longitudinal>.4 else accel*.7))
    else:
        longitudinal=move_toward(longitudinal,0,dt*(.55+.004*longitudinal*longitudinal))
    if handbrake:longitudinal=move_toward(longitudinal,0,dt*3.4)
    if not active and not test_control:longitudinal=move_toward(longitudinal,0,dt*12)
    var yaw_change=-longitudinal*tan(steering)/2.86*dt
    rotation.y+=yaw_change
    var forward_new=-global_basis.z
    var right_new=global_basis.x
    # Relax lateral slip; handbrake reduces rear grip for controllable drifts.
    var planar=forward*longitudinal+right*side_velocity
    var slip=planar.dot(right_new)
    slip=lerpf(slip,0,1-exp(-dt*(1.3 if handbrake else 8.5)*grip))
    velocity.x=(forward_new*longitudinal+right_new*slip).x
    velocity.z=(forward_new*longitudinal+right_new*slip).z
    if not is_on_floor():velocity.y-=19.6*dt
    else:velocity.y=-.6
    move_and_slide()
    if main and not main.world.contains(global_position):
        global_position=old;velocity=Vector3.ZERO
        main.notify("Край первой карты. Вернись в район.")
    speed_kmh=Vector2(velocity.x,velocity.z).length()*3.6
    distance_driven+=Vector2(position.x-old.x,position.z-old.z).length()
    wheel_spin-=longitudinal*dt/.47
    for w in wheels:w.rotation.x=wheel_spin
    for p in front_pivots:p.rotation.y=-steering
    visual.rotation.z=lerpf(visual.rotation.z,steering*longitudinal*.007,dt*6)
    visual.rotation.x=lerpf(visual.rotation.x,throttle*.012,dt*5)
    brake_material.albedo_color=Color("ff4433") if handbrake or (throttle<0 and longitudinal>1) else Color("842b27")
    if active:
        if not engine.playing:engine.play()
        engine.pitch_scale=.7+absf(longitudinal)*.065+absf(throttle)*.10
        engine.volume_db=-19+absf(throttle)*5
    elif engine.playing:engine.stop()

func toggle_lights() -> void:
    lights_on=not lights_on
    for lamp in lamps:lamp.visible=lights_on

func reset_to(p: Vector3, yaw: float) -> void:
    global_position=p
    rotation=Vector3(0,yaw,0)
    velocity=Vector3.ZERO
    steering=0
    speed_kmh=0
    longitudinal=0
    visual.rotation=Vector3.ZERO
