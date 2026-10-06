extends Node3D
const G = preload("res://scripts/geo.gd")
var data: Dictionary
var boundary = PackedVector2Array()
var roads: Array = []
var collision_count = 0
var sun: DirectionalLight3D
var environment: Environment
var batches = {}
var materials = {}
var spawn_pos = Vector3.ZERO
var spawn_yaw = 0.0
var tree_bodies:Array=[]
var poles:Array=[]

func _ready() -> void:
    data = JSON.parse_string(FileAccess.get_file_as_string("res://data/district.json"))
    for p in data.boundary: boundary.append(Vector2(p[0],p[1]))
    roads = data.roads
    var sp = data.spawn.car
    spawn_pos = Vector3(sp[0],sp[1],sp[2])
    spawn_yaw = data.spawn.yaw
    _lighting()
    _ground()
    _materials()
    _surface_materials()
    _streets()
    _buildings()
    _trees()
    _details()
    _facade_details()
    _finish_batches()

func _lighting() -> void:
    var envnode = WorldEnvironment.new()
    environment = Environment.new()
    environment.background_mode = Environment.BG_SKY
    var sky = Sky.new()
    var sm = ProceduralSkyMaterial.new()
    sm.sky_top_color = Color("527f9e")
    sm.sky_horizon_color = Color("c3d4d4")
    sm.ground_bottom_color = Color("82917a")
    sm.ground_horizon_color = Color("c3d4d4")
    sm.sky_curve = 0.2
    sky.sky_material = sm
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("bed1df")
    environment.ambient_light_energy = 0.43
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.fog_enabled = true
    environment.fog_light_color = Color("b4c7c8")
    environment.fog_density = 0.00125
    envnode.environment = environment
    add_child(envnode)
    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-47,-32,0)
    sun.light_color = Color("fff0d5")
    sun.light_energy = 1.15
    sun.shadow_enabled = false
    sun.directional_shadow_max_distance = 100
    add_child(sun)

func _ground() -> void:
    var ground = G.box(self,Vector3(-350,-0.15,-80),Vector3(3500,0.3,3500),G.mat(Color("768568")))
    var body = StaticBody3D.new()
    var shape = CollisionShape3D.new()
    var boxshape = BoxShape3D.new()
    boxshape.size = Vector3(3500,0.3,3500)
    shape.shape = boxshape
    body.position = ground.position
    body.add_child(shape)
    add_child(body)

func _materials() -> void:
    materials.asphalt = G.mat(Color("3c4449"))
    materials.path = G.mat(Color("a9a498"))
    materials.sidewalk = G.mat(Color("b0b2a7"))
    materials.line = G.mat(Color("dbd9bd"))
    materials.roof = G.mat(Color("657071"))
    materials.park = G.mat(Color("879a70"))
    materials.parking = G.mat(Color("777e7a"))
    materials.yellow = G.mat(Color("e7af50"))
    materials.trunk = G.mat(Color("695445"))
    var colors = ["d9ccb7","c0c6c3","d3bdad","c5c6b3","b0bfbd","d9d3bf"]
    for i in range(colors.size()):
        var m = G.mat(Color(colors[i]))
        # Windows are actual facade geometry in v0.2; keep plaster untextured.
        m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        materials["wall"+str(i)] = m
    var m2 = G.mat(Color("e5e6df"))
    # Shop windows and sign bands are modelled separately.
    materials.shop = m2
    materials.garage = G.mat(Color("b1aa99"))
    materials.detail=G.mat(Color("d4d5cd"))
    materials.dark=G.mat(Color("263c48"),.26)
    materials.blue=G.mat(Color("1c4374"))
    materials.red=G.mat(Color("b42d33"))
    materials.concrete=G.mat(Color("94948a"))

func _batch(kind: String, pos: Vector3) -> SurfaceTool:
    var key = kind+":"+str(int(floor(pos.x/120)))+":"+str(int(floor(pos.z/120)))
    if not batches.has(key): batches[key] = {"s":G.surface(),"kind":kind,"center":pos}
    return batches[key].s

func _flat(poly: Array, y: float, kind: String) -> void:
    var p = PackedVector2Array()
    for x in poly:p.append(Vector2(x[0],x[1]))
    var ids = Geometry2D.triangulate_polygon(p)
    if ids.size()<3:return
    var s = _batch(kind,Vector3(p[0].x,0,p[0].y))
    for i in range(0,ids.size(),3):
        var a = p[ids[i]];var b = p[ids[i+1]];var c = p[ids[i+2]]
        G.tri(s,Vector3(a.x,y,a.y),Vector3(b.x,y,b.y),Vector3(c.x,y,c.y),Vector3.UP)

func _ribbon(points: Array, width: float, y: float, kind: String) -> void:
    # Mitered joins keep bends connected instead of leaving corner gaps.
    for i in range(points.size()-1):
        var a = Vector2(points[i][0],points[i][1]);var b = Vector2(points[i+1][0],points[i+1][1])
        var d = (b-a).normalized()
        if a.distance_to(b)<0.05:continue
        var n = Vector2(-d.y,d.x)
        var na = n;var nb = n
        if i>0:
            var prev = (a-Vector2(points[i-1][0],points[i-1][1])).normalized()
            na = (n+Vector2(-prev.y,prev.x)).normalized()
            na /= maxf(0.4,na.dot(n))
        if i<points.size()-2:
            var nex = (Vector2(points[i+2][0],points[i+2][1])-b).normalized()
            nb = (n+Vector2(-nex.y,nex.x)).normalized()
            nb /= maxf(0.4,nb.dot(n))
        var aa = a+na*width/2;var ab = a-na*width/2
        var ba = b+nb*width/2;var bb = b-nb*width/2
        var s = _batch(kind,Vector3(a.x,0,a.y))
        G.quad(s,Vector3(aa.x,y,aa.y),Vector3(ba.x,y,ba.y),Vector3(bb.x,y,bb.y),Vector3(ab.x,y,ab.y),Vector3.UP)

func _streets() -> void:
    for g in data.greens: _flat(g.polygon,0.015,"park")
    for p in data.parkings: _flat(p,0.035,"parking")
    for road in roads:
        var walk = road.kind in ["footway","path","steps","pedestrian"]
        if not walk and road.width>=6: _ribbon(road.points,road.width+4.2,0.022,"sidewalk")
        _ribbon(road.points,road.width,0.055 if not walk else 0.034,"path" if walk else "asphalt")
        if road.width>=9:
            for i in range(road.points.size()-1):
                var a = Vector2(road.points[i][0],road.points[i][1])
                var b = Vector2(road.points[i+1][0],road.points[i+1][1])
                var length = a.distance_to(b)
                var d = (b-a).normalized()
                var count = int(length/9)
                for j in range(count):
                    var p = a+d*(j*9+2)
                    _ribbon([[p.x,p.y],[p.x+d.x*3.8,p.y+d.y*3.8]],0.13,0.065,"line")

func _buildings() -> void:
    for b in data.buildings:
        var poly = b.polygon
        var height = float(b.height)
        var kind = "wall"+str(int(b.variant))
        if b.style=="garage":kind="garage"
        elif b.name in ["Тернополь","Причерноморье","Маяк"]:kind="shop"
        _flat(poly,height,"roof")
        var p2 = PackedVector2Array()
        for p in poly:p2.append(Vector2(p[0],p[1]))
        var clockwise = Geometry2D.is_polygon_clockwise(p2)
        for i in range(poly.size()):
            var a = Vector3(poly[i][0],0.05,poly[i][1]);var j = (i+1)%poly.size()
            var d = Vector3(poly[j][0],0.05,poly[j][1]);var edge = d-a
            var normal = Vector3(edge.z,0,-edge.x).normalized()
            if clockwise:normal=-normal
            var s = _batch(kind,a)
            G.quad(s,a,d,d+Vector3.UP*height,a+Vector3.UP*height,normal,Vector2(edge.length()/3.0,height/3.0))
        if b.name in ["Тернополь","Причерноморье","Маяк"]:
            var landmark = null
            for l in data.landmarks:
                if l.name==b.name:landmark=l
            if landmark and b.name!="Тернополь":
                G.label3(self,b.name.to_upper(),Vector3(landmark.position[0],height+2.6,landmark.position[1]),50)

func _trees() -> void:
    for t in data.trees:
        var body=StaticBody3D.new();body.set_meta("solid_tree",true)
        var col=CollisionShape3D.new();var shape=CylinderShape3D.new();shape.radius=.24;shape.height=3.6
        col.shape=shape;col.position.y=1.8;body.position=Vector3(t[0],0,t[1]);body.add_child(col);add_child(body);tree_bodies.append(body)
    # A handful of MultiMeshes for the entire district.
    var trunk = CylinderMesh.new();trunk.bottom_radius=.20;trunk.top_radius=.13;trunk.height=1;trunk.radial_segments=6;trunk.rings=1
    var canopy = SphereMesh.new();canopy.radius=1;canopy.height=2;canopy.radial_segments=16;canopy.rings=8
    for group in range(4):
        var list: Array = data.trees if group==0 else data.trees.filter(func(t):return int(t[3])==group-1)
        var mm = MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=trunk if group==0 else canopy
        mm.instance_count=list.size()
        var n = MultiMeshInstance3D.new();n.multimesh=mm
        var foliage = ["648059","748a60","8f995e"]
        n.material_override = materials.trunk if group==0 else G.mat(Color(foliage[group-1]))
        n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        for i in range(list.size()):
            var t = list[i];var h = float(t[2])
            var scale3 = Vector3(1,h*.55,1) if group==0 else Vector3(h*.31,h*.38,h*.31)
            var tr = Transform3D(Basis.IDENTITY.scaled(scale3),Vector3(t[0],h*.275 if group==0 else h*.68,t[1]))
            mm.set_instance_transform(i,tr)
        add_child(n)

func _details() -> void:
    var postmat = G.mat(Color("59656b"));var benchmat=G.mat(Color("76563c"))
    # Lamps along major roads, widely spaced for the low graphics preset.
    for road in roads:
        if road.width<7:continue
        var travelled = 0.0
        for i in range(road.points.size()-1):
            var a = Vector3(road.points[i][0],0,road.points[i][1]);var b = Vector3(road.points[i+1][0],0,road.points[i+1][1])
            var d = (b-a).normalized();var length = a.distance_to(b)
            var side = Vector3(-d.z,0,d.x)*(road.width/2+1.3)
            var at = 35.0-travelled
            while at<length:
                var p = a+d*at+side
                if contains(p):
                    var pole=preload("res://scripts/pole.gd").new();pole.position=p;pole.rotation.y=atan2(d.x,d.z);add_child(pole);poles.append(pole)
                at+=60
            travelled=fmod(travelled+length,60)

func _finish_batches() -> void:
    for key in batches:
        var b = batches[key]
        var n = G.mesh_node(self,b.s,materials[b.kind],180 if (b.kind in ["detail","dark","concrete","blue","red"] or str(b.kind).begins_with("window")) else (650 if str(b.kind).begins_with("wall") else 800))
        n.name = str(key).replace(":","_")
        if str(b.kind).begins_with("wall") or b.kind in ["shop","garage"]:
            var body=StaticBody3D.new();var shape=CollisionShape3D.new()
            var col=n.mesh.create_trimesh_shape();col.backface_collision=true
            shape.shape=col;body.add_child(shape);add_child(body);collision_count+=1
    batches.clear()

func contains(pos: Vector3) -> bool:
    return Geometry2D.is_point_in_polygon(Vector2(pos.x,pos.z),boundary)

func nearest_road(pos: Vector3) -> Dictionary:
    var p = Vector2(pos.x,pos.z);var best = 1e20;var answer={"point":spawn_pos,"yaw":spawn_yaw,"distance":0.0,"name":"Краснодонская улица","width":10.0}
    for road in roads:
        if road.kind in ["footway","path","steps","pedestrian"]:continue
        for i in range(road.points.size()-1):
            var a=Vector2(road.points[i][0],road.points[i][1]);var b=Vector2(road.points[i+1][0],road.points[i+1][1])
            var q=Geometry2D.get_closest_point_to_segment(p,a,b);var dist=p.distance_squared_to(q)
            if dist<best and contains(Vector3(q.x,0,q.y)):
                best=dist
                var direction=(b-a).normalized()
                answer={"point":Vector3(q.x,.3,q.y),"yaw":atan2(-direction.x,-direction.y),"distance":sqrt(dist),"name":road.name,"width":road.width}
    return answer

func _detail_box(pos:Vector3,sz:Vector3,kind:String,yaw:float=0) -> void:
    var t=Transform3D(Basis(Vector3.UP,yaw),pos)
    var p=[]
    for v in [Vector3(-1,-1,-1),Vector3(1,-1,-1),Vector3(1,1,-1),Vector3(-1,1,-1),Vector3(-1,-1,1),Vector3(1,-1,1),Vector3(1,1,1),Vector3(-1,1,1)]:p.append(t*(v*sz/2))
    var s=_batch(kind,pos)
    for f in [[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]]:
        var normal=(p[f[1]]-p[f[0]]).cross(p[f[2]]-p[f[0]]).normalized()
        G.quad(s,p[f[0]],p[f[1]],p[f[2]],p[f[3]],normal)

func _facade_details() -> void:
    for b in data.buildings:
        if b.style=="garage":continue
        var poly=PackedVector2Array()
        for p in b.polygon:poly.append(Vector2(p[0],p[1]))
        var h=float(b.height);var levels=int(b.levels)
        var center=b.get("center",b.polygon[0])
        if levels>=3:
            for vent in range(3):_detail_box(Vector3(center[0]+vent*2,h+.45,center[1]),Vector3(.8,.9,.65),"concrete")
        var is_store=b.name=="Тернополь"
        var sign_added=false
        for i in range(poly.size()):
            var av=poly[i];var bv=poly[(i+1)%poly.size()]
            var d=(bv-av).normalized();var length=av.distance_to(bv)
            if length<5:continue
            var normal=Vector2(d.y,-d.x)
            if Geometry2D.is_point_in_polygon((av+bv)/2+normal*.3,poly):normal=-normal
            var n=Vector3(normal.x,0,normal.y)
            var base=Vector3(av.x,0,av.y);var along=Vector3(d.x,0,d.y)
            var yaw=-atan2(d.y,d.x)
            for y in [.32,h-.14]:_detail_box(base+along*length/2+n*.08+Vector3.UP*y,Vector3(length,.23,.22),"concrete",yaw)
            if is_store:
                for spec in [[2.8,.75,"blue"],[2.28,.18,"red"],[h-.38,.25,"blue"]]:
                    _detail_box(base+along*length/2+n*.12+Vector3.UP*spec[0],Vector3(length,spec[1],.24),spec[2],yaw)
            for floor_index in range(1,levels):_detail_box(base+along*length/2+n*.025+Vector3.UP*(floor_index*h/levels),Vector3(length,.04,.055),"concrete",yaw)
            _detail_box(base+along*.4+n*.12+Vector3.UP*h/2,Vector3(.12,h,.12),"concrete",yaw)
            var bays=int(length/3.1)
            for j in range(bays):
                var p=base+along*((j+.5)*length/bays)+n*.09
                for floor_i in range(levels):
                    var y=1.55+floor_i*(h/levels)
                    var width=2.6 if is_store else 1.48
                    var wh=1.9 if is_store else 1.46
                    _detail_box(p+Vector3.UP*y,Vector3(width+.18,wh+.18,.15),"detail",yaw)
                    _detail_box(p+n*.10+Vector3.UP*y,Vector3(width,wh,.12),"window"+str((int(b.id)+j+floor_i)%4),yaw)
                    _detail_box(p+n*.18+Vector3.UP*y,Vector3(.055,wh,.06),"detail",yaw)
                    _detail_box(p+n*.20+Vector3.UP*(y-wh/2),Vector3(width+.25,.10,.35),"detail",yaw)
                    if not is_store and (j+floor_i+int(b.id))%9==0:
                        _detail_box(p+along*.9+n*.37+Vector3.UP*(y-.2),Vector3(.63,.47,.50),"detail",yaw)
                    if not is_store and levels>=3 and j%3==1 and floor_i>0:
                        _detail_box(p+n*.59+Vector3.UP*(y-.77),Vector3(2.3,.15,1.1),"concrete",yaw)
                        _detail_box(p+n*1.08+Vector3.UP*(y-.3),Vector3(2.3,.86,.09),"detail",yaw)
                        for side in [-1,1]:_detail_box(p+along*side*1.1+n*.60+Vector3.UP*(y-.3),Vector3(.08,.86,1),"detail",yaw)
                if j%5==2 or (is_store and j%6==1):
                    _detail_box(p+n*.23+Vector3.UP*.95,Vector3(1.35,1.9,.16),"dark",yaw)
                    _detail_box(p+n*.75+Vector3.UP*2.08,Vector3(2,.14,1.7),"concrete",yaw)
                    for stair in range(3):_detail_box(p+n*(.35+stair*.3)+Vector3.UP*(.24-stair*.07),Vector3(1.9,.12,.45),"concrete",yaw)
            if is_store and length>25 and normal.x>.55 and not sign_added:
                sign_added=true
                var sign=Label3D.new();sign.text="ТЕРНОПОЛЬ";sign.font=load("res://assets/DejaVuSans.ttf");sign.font_size=96;sign.pixel_size=.028;sign.modulate=Color("18437b");sign.outline_size=0
                sign.position=base+along*length/2+n*.25+Vector3.UP*(h+.7);sign.rotation.y=atan2(n.x,n.z);add_child(sign)
        var addr=str(b.get("address","")).strip_edges()
        if not addr.is_empty():
            var a=poly[0];var z=poly[1];var mid=(a+z)/2;var dir=(z-a).normalized();var n=Vector2(dir.y,-dir.x)
            if Geometry2D.is_point_in_polygon(mid+n*.2,poly):n=-n
            var plaque=Label3D.new();plaque.font=load("res://assets/DejaVuSans.ttf");plaque.text=addr;plaque.font_size=40;plaque.pixel_size=.008;plaque.position=Vector3(mid.x+n.x*.28,2.6,mid.y+n.y*.28);plaque.rotation.y=atan2(n.x,n.y);plaque.visibility_range_end=45;plaque.outline_size=5;add_child(plaque)

func _surface_materials() -> void:
    for kind in ["asphalt","sidewalk","wall0","wall1","wall2","wall3","wall4","wall5","concrete","roof"]:
        var original=materials[kind]
        var m=ShaderMaterial.new();m.shader=load("res://materials/surface.gdshader")
        m.set_shader_parameter("base_color",original.albedo_color)
        m.set_shader_parameter("scale",34.0 if kind=="asphalt" else 12.0)
        m.set_shader_parameter("variation",.25 if kind=="asphalt" else .12)
        materials[kind]=m
    for i in range(4):
        var glass=G.mat([Color("263c48"),Color("4c615e"),Color("746e58"),Color("303e50")][i],.23)
        glass.metallic=.32;materials["window"+str(i)]=glass
