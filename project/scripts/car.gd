extends CharacterBody3D
const G = preload("res://scripts/geo.gd")
const MAX_SPEED = 60.0 / 3.6
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
var steering_detail:Node3D
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
    G.merge_static_children(visual)
    for wheel in wheels:G.merge_static_children(wheel)
    engine=AudioStreamPlayer.new();engine.stream=load("res://assets/engine.wav");engine.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;engine.stream.loop_end=int(engine.stream.get_length()*engine.stream.mix_rate);engine.volume_db=-15;add_child(engine)
    horn=AudioStreamPlayer.new();horn.stream=load("res://assets/horn.wav");horn.volume_db=-15;add_child(horn)

func _loft(sections: Array, material: Material) -> MeshInstance3D:
    var s=G.surface()
    for i in range(sections.size()-1):
        var a=sections[i];var b=sections[i+1]
        # z, lower half width, upper half width, bottom, top
        var av=_body_ring(a);var bv=_body_ring(b)
        for j in range(8):
            var k=(j+1)%8;var normal=(av[k]-av[j]).cross(bv[j]-av[j]).normalized()
            G.quad(s,av[j],av[k],bv[k],bv[j],normal)
        for j in range(1,7):
            if i==0:G.tri(s,av[0],av[j+1],av[j],Vector3.FORWARD)
            if i==sections.size()-2:G.tri(s,bv[0],bv[j],bv[j+1],Vector3.BACK)
    return G.mesh_node(visual,s,material)

func _body_ring(a:Array) -> Array:
    var z=float(a[0]);var lo=float(a[1]);var hi=float(a[2]);var bottom=float(a[3]);var top=float(a[4]);var bevel=minf(.12,(top-bottom)*.2)
    return [Vector3(-lo+.09,bottom,z),Vector3(lo-.09,bottom,z),Vector3(lo,bottom+bevel,z),Vector3(hi,top-bevel,z),Vector3(hi-.08,top,z),Vector3(-hi+.08,top,z),Vector3(-hi,top-bevel,z),Vector3(-lo,bottom+bevel,z)]

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
        var ap=G.box(visual,Vector3(side*.83,1.69,-.79),Vector3(.09,.75,.11),paint);ap.rotation.x=.72
        var cp=G.box(visual,Vector3(side*.82,1.70,1.57),Vector3(.1,.63,.15),paint);cp.rotation.x=-.68
        G.box(visual,Vector3(side*.73,2.095,.35),Vector3(.065,.06,2.1),chrome)
        for z in [-.55,1.25]:G.box(visual,Vector3(side*.73,2.05,z),Vector3(.08,.11,.09),trim)
        G.box(visual,Vector3(side*1.08,1.43,-.75),Vector3(.27,.17,.29),paint)
        for z in [-.12,1.01]:G.box(visual,Vector3(side*.968,1.31,z),Vector3(.035,.05,.23),chrome)
        G.box(visual,Vector3(side*.99,.55,.1),Vector3(.07,.17,3.2),trim)
        for z in [-1.47,1.48]:
            var pivot=Node3D.new();visual.add_child(pivot);pivot.position=Vector3(side*.96,.47,z)
            if z<0:front_pivots.append(pivot)
            var spin=Node3D.new();pivot.add_child(spin);wheels.append(spin)
            var tire=G.cylinder(spin,Vector3.ZERO,.47,.30,tyre,40);tire.rotation.z=PI/2
            var rim=MeshInstance3D.new();var rim_mesh=TorusMesh.new();rim_mesh.inner_radius=.245;rim_mesh.outer_radius=.292;rim_mesh.rings=32;rim_mesh.ring_segments=10;rim.mesh=rim_mesh;rim.material_override=chrome;rim.position=Vector3(side*.16,0,0);rim.rotation.z=PI/2;spin.add_child(rim)
            var cap=G.cylinder(spin,Vector3(side*.178,0,0),.105,.035,trim,24);cap.rotation.z=PI/2
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
    _extra_details(paint,trim,chrome,tyre,head)
    # Interior is visible in cockpit camera. The windshield stays transparent by
    # hiding only the glass shell when cockpit mode is selected.
    var dashboard=G.box(visual,Vector3(0,1.30,-.70),Vector3(1.64,.24,.46),trim);dashboard.name="Dashboard"
    for x in [-.43,.43]:
        G.box(visual,Vector3(x,.99,.25),Vector3(.55,.17,.59),trim)
        var seat=G.box(visual,Vector3(x,1.30,.57),Vector3(.53,.69,.18),trim);seat.rotation.x=-.1
        G.box(visual,Vector3(x,1.70,.6),Vector3(.35,.24,.14),trim)
    steering_detail=Node3D.new();steering_detail.position=Vector3(-.43,1.42,-.40);steering_detail.rotation.x=1.12;visual.add_child(steering_detail)
    var ring=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.155;torus.outer_radius=.193;torus.rings=32;torus.ring_segments=12;ring.mesh=torus;ring.material_override=trim;steering_detail.add_child(ring)
    G.box(steering_detail,Vector3.ZERO,Vector3(.17,.065,.10),trim)
    for angle in [0,PI*.7,-PI*.7]:G.tube(steering_detail,Vector3.ZERO,Vector3(sin(angle)*.17,0,cos(angle)*.17),.019,chrome)
    for x in [-.53,-.34]:
        var dial=G.cylinder(visual,Vector3(x,1.47,-.605),.068,.009,head,32);dial.rotation.x=PI/2
        G.tube(visual,Vector3(x,1.47,-.596),Vector3(x-.032,1.50,-.596),.004,trim,8)
    G.box(visual,Vector3(.10,1.30,-.455),Vector3(.23,.16,.016),G.mat(Color("263e43")))
    for y in [1.18,1.12]:
        for x in [.03,.16]:var knob=G.cylinder(visual,Vector3(x,y,-.447),.023,.018,chrome,16);knob.rotation.x=PI/2
    G.box(visual,Vector3(.04,1.00,-.03),Vector3(.21,.32,.66),trim)
    G.tube(visual,Vector3(.02,1.10,-.11),Vector3(.02,1.24,-.14),.015,chrome)
    G.ellipsoid(visual,Vector3(.02,1.25,-.14),Vector3(.034,.036,.05),trim)

func _extra_details(paint,trim,chrome,tyre,head) -> void:
    for side in [-1,1]:
        # Curved fender lips and separate door outlines.
        for wz in [-1.47,1.48]:
            for j in range(18):
                var a=PI*j/18;var b=PI*(j+1)/18
                G.tube(visual,Vector3(side*1.018,.47+sin(a)*.52,wz+cos(a)*.52),Vector3(side*1.018,.47+sin(b)*.52,wz+cos(b)*.52),.038,paint,10)
        for z in [-.58,.36,1.36]:G.tube(visual,Vector3(side*1.008,.67,z),Vector3(side*.95,1.34,z),.008,trim,8)
        G.tube(visual,Vector3(side*1.014,.78,-.95),Vector3(side*1.014,.78,1.0),.018,chrome)
        G.tube(visual,Vector3(side*.90,1.47,-.90),Vector3(side*.89,1.47,1.58),.018,chrome)
        G.box(visual,Vector3(side*1.093,1.44,-.587),Vector3(.19,.105,.012),chrome)
        G.box(visual,Vector3(side*1.093,1.395,-.895),Vector3(.18,.03,.012),head)
        G.box(visual,Vector3(side*.77,1.13,2.37),Vector3(.20,.07,.015),head)
        # Twin exhausts and rear reflectors.
        var exhaust=G.cylinder(visual,Vector3(side*.67,.47,2.28),.064,.27,chrome,24);exhaust.rotation.x=PI/2
        var hole=G.cylinder(visual,Vector3(side*.67,.47,2.423),.048,.005,trim,24);hole.rotation.x=PI/2
        G.box(visual,Vector3(side*.71,.69,2.415),Vector3(.15,.035,.013),brake_material)
        for z in [-2.04,2.02]:G.ellipsoid(visual,Vector3(side*.90,.80,z),Vector3(.014,.035,.045),trim)
    for spin in wheels:
        var side=1 if spin.get_parent().position.x>0 else -1
        # Brake rotor, hub bolts and circumferential tyre tread.
        var rotor=G.cylinder(spin,Vector3(side*.164,0,0),.24,.009,G.mat(Color("5e676d")),32);rotor.rotation.z=PI/2
        for j in range(5):
            var a=j*TAU/5
            G.ellipsoid(spin,Vector3(side*.206,sin(a)*.069,cos(a)*.069),Vector3(.015,.014,.014),chrome)
        for j in range(32):
            var a=j*TAU/32
            var tread=G.box(spin,Vector3(0,sin(a)*.471,cos(a)*.471),Vector3(.25,.019,.023),tyre);tread.rotation.x=-a
    G.tube(visual,Vector3(-.69,1.36,-1.145),Vector3(-.15,1.39,-1.115),.013,trim)
    G.tube(visual,Vector3(.10,1.36,-1.145),Vector3(.63,1.39,-1.115),.013,trim)
    G.tube(visual,Vector3(0,1.48,2.07),Vector3(.45,1.48,2.07),.013,trim)
    G.box(visual,Vector3(0,1.93,1.55),Vector3(1.59,.10,.27),paint)
    G.box(visual,Vector3(0,1.93,1.70),Vector3(.46,.04,.012),brake_material)
    G.box(visual,Vector3(.1,1.865,-.42),Vector3(.27,.10,.06),trim)
    for x in [-.47,.47]:G.box(visual,Vector3(x,1.88,-.49),Vector3(.40,.035,.21),trim)
    var label=Label3D.new();label.text="TOUAREG     R5 TDI";label.font=load("res://assets/DejaVuSans.ttf");label.font_size=40;label.pixel_size=.0024;label.position=Vector3(0,1.21,2.367);label.modulate=Color("d9e1e4");label.outline_size=0;visual.add_child(label)

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
    var accel=2.7/maxf(inertia,.4)
    if throttle>0:
        longitudinal=move_toward(longitudinal,MAX_SPEED,dt*(10.0 if longitudinal<-.4 else accel))
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
    var capped=Vector2(velocity.x,velocity.z).limit_length(MAX_SPEED)
    velocity.x=capped.x;velocity.z=capped.y
    var impact_velocity=velocity
    if not is_on_floor():velocity.y-=19.6*dt
    else:velocity.y=-.6
    move_and_slide()
    for i in range(get_slide_collision_count()):
        var contact=get_slide_collision(i)
        var object=contact.get_collider()
        if object and absf(contact.get_normal().y)<.5:
            if object.has_method("vehicle_hit"):
                object.vehicle_hit(impact_velocity)
                velocity.x*=.55;velocity.z*=.55
            elif object.has_meta("solid_tree"):
                velocity.x=0;velocity.z=0;longitudinal=0

    if main and not main.world.contains(global_position):
        global_position=old;velocity=Vector3.ZERO
        main.notify("Край первой карты. Вернись в район.")
    speed_kmh=Vector2(velocity.x,velocity.z).length()*3.6
    distance_driven+=Vector2(position.x-old.x,position.z-old.z).length()
    wheel_spin-=longitudinal*dt/.47
    for w in wheels:w.rotation.x=wheel_spin
    for p in front_pivots:p.rotation.y=-steering
    if steering_detail:steering_detail.rotation.y=-steering*2
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
