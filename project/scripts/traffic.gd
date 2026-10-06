extends Node3D
const ACTOR=preload("res://scripts/traffic_actor.gd")
var main
var edges:Array=[]
var walk_edges:Array=[]
var outgoing={}
var walk_outgoing={}
var cars:Array=[]
var people:Array=[]
var clock=0.0
var density=1
var rng=RandomNumberGenerator.new()

func _ready() -> void:
    rng.seed=96821062140
    for road in main.world.roads:
        if road.width<6.0 or road.kind in ["footway","path","steps","pedestrian"]:continue
        for i in range(road.points.size()-1):
            var a=Vector3(road.points[i][0],.12,road.points[i][1]);var b=Vector3(road.points[i+1][0],.12,road.points[i+1][1])
            if a.distance_to(b)<5 or not main.world.contains((a+b)/2):continue
            _edge(a,b,road.width,false)
            if road.oneway!="yes":_edge(b,a,road.width,false)
            _edge(a,b,road.width,true);_edge(b,a,road.width,true)
    set_density(density)

func _key(p:Vector3) -> String:
    return str(roundi(p.x))+":"+str(roundi(p.z))

func _edge(a:Vector3,b:Vector3,width:float,walking:bool) -> void:
    var edge={"a":_key(a),"b":_key(b),"start":a,"end":b,"width":width}
    var list=walk_edges if walking else edges;var graph=walk_outgoing if walking else outgoing
    list.append(edge)
    if not graph.has(edge.a):graph[edge.a]=[]
    graph[edge.a].append(edge)

func edge_point(edge:Dictionary,t:float,walking:bool) -> Vector3:
    var direction=(edge.end-edge.start).normalized()
    var right=Vector3(-direction.z,0,direction.x)
    return edge.start.lerp(edge.end,t)+right*(edge.width/2+1.15 if walking else minf(edge.width*.24,2.2))

func next_edge(edge:Dictionary,walking:bool) -> Dictionary:
    var graph=walk_outgoing if walking else outgoing
    var choices=graph.get(edge.b,[]).filter(func(e):return e.b!=edge.a)
    if choices.is_empty():choices=graph.get(edge.b,[])
    if choices.is_empty():return {"a":edge.b,"b":edge.a,"start":edge.end,"end":edge.start,"width":edge.width}
    return choices[rng.randi_range(0,choices.size()-1)]

func set_density(value:int) -> void:
    density=clampi(value,0,2)
    for actor in cars+people:remove_child(actor);actor.queue_free()
    cars.clear();people.clear()
    if density==0 or edges.is_empty():return
    for i in range(8 if density==1 else 16):_spawn(false,i)
    for i in range(12 if density==1 else 24):_spawn(true,i)

func _spawn(walking:bool,index:int) -> void:
    var actor=ACTOR.new();actor.manager=self;actor.pedestrian=walking;actor.model_type=index%4
    add_child(actor);(people if walking else cars).append(actor)
    relocate(actor,true)

func relocate(actor,initial:bool=false) -> void:
    var focus=main.car.position if main.driving else main.player.position
    var list=walk_edges if actor.pedestrian else edges
    var nearby=list.filter(func(e):return ((e.start+e.end)/2).distance_to(focus)<(260 if initial else 350))
    if nearby.is_empty():nearby=list
    for attempt in range(60):
        var e=nearby[rng.randi_range(0,nearby.size()-1)];var p=edge_point(e,rng.randf_range(.12,.82),actor.pedestrian)
        if not main.world.contains(p) or p.distance_to(main.car.position)<18:continue
        var clear=true
        for other in cars+people:
            if other!=actor and other.position.distance_to(p)<(3 if actor.pedestrian else 10):clear=false;break
        if not clear:continue
        var shape=SphereShape3D.new();shape.radius=.5 if actor.pedestrian else 2.4
        var query=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=p+Vector3.UP*2.6;query.collision_mask=1
        if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():continue
        actor.edge=e;actor.position=p;actor.rotation.y=atan2(-(e.end-e.start).x,-(e.end-e.start).z) if not actor.pedestrian else 0
        actor.velocity=Vector3.ZERO;actor.speed=0;actor.blocked_time=0;return
    actor.edge={}

func _process(dt:float) -> void:
    clock+=dt
    var focus=main.car.position if main.driving else main.player.position
    for actor in cars+people:
        var distance=actor.position.distance_to(focus)
        actor.visible=distance<230
        actor.set_physics_process(distance<320 and not actor.edge.is_empty())
        if distance>420:relocate(actor)
