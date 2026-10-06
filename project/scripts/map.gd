extends Control
var main
var expanded=false
var font=preload("res://assets/DejaVuSans.ttf")
var span=250.0
var center=Vector2.ZERO
var factor=1.0
var heading=0.0
var zoom=1.0
var pan=Vector2.ZERO
var dragging=false
var selected_address=""

func _ready() -> void:
    clip_contents=true
    mouse_filter=Control.MOUSE_FILTER_STOP if expanded else Control.MOUSE_FILTER_IGNORE

func _process(_dt: float) -> void:
    queue_redraw()

func _draw() -> void:
    if not main or not main.world or size.x<50 or size.y<50:return
    var w=main.world
    var pos=main.car.global_position if main.driving else main.player.global_position
    if expanded:
        var bounds=w.data.bounds
        center=Vector2((bounds[0]+bounds[2])/2,(bounds[1]+bounds[3])/2)+pan
        heading=0.0
        factor=minf((size.x-70)/(bounds[2]-bounds[0]),(size.y-70)/(bounds[3]-bounds[1]))*zoom
    else:
        center=Vector2(pos.x,pos.z)
        heading=main.car.rotation.y if main.driving else main.player.visual.rotation.y
        factor=minf(size.x,size.y)/(span*2)
    draw_rect(Rect2(Vector2.ZERO,size),Color("152b30"))
    for b in w.data.buildings:
        var points=PackedVector2Array()
        for p in b.polygon:points.append(_point(Vector2(p[0],p[1])))
        if points.size()>=3:draw_colored_polygon(points,Color("34484b"))
    for r in w.roads:
        var pts=PackedVector2Array()
        for p in r.points:pts.append(_point(Vector2(p[0],p[1])))
        var walk=r.kind in ["footway","path","steps"]
        draw_polyline(pts,Color("3b5355") if walk else Color("a0aca3"),maxf(1,r.width*factor),true)
    var border=PackedVector2Array()
    for p in w.boundary:border.append(_point(p))
    border.append(border[0])
    draw_polyline(border,Color("e0a050"),1.5,true)
    for l in w.data.landmarks:
        var q=_point(Vector2(l.position[0],l.position[1]))
        draw_circle(q,4,Color("ffc777"))
        if expanded:draw_string(font,q+Vector2(7,-5),l.name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f6e8ce"))
    var cp=_point(Vector2(main.car.position.x,main.car.position.z))
    if not main.driving:
        draw_rect(Rect2(cp-Vector2(3,5),Vector2(6,10)),Color("f7b466"))
    _draw_addresses()
    var q=_point(Vector2(pos.x,pos.z))
    var yaw=main.car.rotation.y if main.driving else main.player.visual.rotation.y
    var arrow=PackedVector2Array([Vector2(0,-9),Vector2(-6,6),Vector2(0,3),Vector2(6,6)])
    for i in range(arrow.size()):arrow[i]=q+arrow[i].rotated(heading-yaw)
    draw_colored_polygon(arrow,Color("faf4e8"))
    if main.waypoint!=Vector2.INF:
        var wp=_point(main.waypoint)
        draw_circle(wp,7,Color("ffb760"),false,2,true)
        draw_line(wp+Vector2(-11,0),wp+Vector2(11,0),Color("ffb760"),1)
        draw_line(wp+Vector2(0,-11),wp+Vector2(0,11),Color("ffb760"),1)
    var compass=size-Vector2(24,24)
    var north=Vector2(0,-13).rotated(heading)
    draw_circle(compass,19,Color("142327"))
    draw_line(compass,compass+north,Color("ffba67"),2,true)
    draw_string(font,compass+north+Vector2(-5,4),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
    if expanded:
        draw_string(font,Vector2(14,size.y-14),selected_address if not selected_address.is_empty() else "Колесо — масштаб · перетаскивание средней кнопкой · ЛКМ — адрес и метка",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f8cf8b"))
    draw_rect(Rect2(Vector2.ZERO,size),Color("768c86"),false,1)

func _point(p: Vector2) -> Vector2:
    return (p-center).rotated(heading)*factor+size/2

func _gui_input(event: InputEvent) -> void:
    if not expanded:return
    if event is InputEventMouseMotion and dragging:
        pan-=event.relative/factor
    if event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_MIDDLE:dragging=event.pressed
        if not event.pressed:return
        if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            var old=(event.position-size/2)/factor+center
            zoom=clampf(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8),1,8)
            var bounds=main.world.data.bounds
            var base=minf((size.x-70)/(bounds[2]-bounds[0]),(size.y-70)/(bounds[3]-bounds[1]))
            pan+=old-((event.position-size/2)/(base*zoom)+center)
        if event.button_index==MOUSE_BUTTON_LEFT:
            var p=(event.position-size/2)/factor+center
            selected_address=""
            for b in main.world.data.buildings:
                var poly=PackedVector2Array()
                for v in b.polygon:poly.append(Vector2(v[0],v[1]))
                if Geometry2D.is_point_in_polygon(p,poly):
                    selected_address=b.address.strip_edges() if not b.address.strip_edges().is_empty() else "Адрес не указан в OSM"
                    selected_address+=" · OSM "+str(int(b.id))
                    break
            if main.world.contains(Vector3(p.x,0,p.y)):
                main.waypoint=p
                main.notify("Метка поставлена. Расстояние показано на экране.")
        elif event.button_index==MOUSE_BUTTON_RIGHT:
            main.waypoint=Vector2.INF


func _draw_addresses() -> void:
    var occupied:Array[Rect2]=[]
    for road in main.world.roads:
        if road.name=="Дворовой проезд" or road.kind in ["footway","path","steps"]:continue
        var i=int(road.points.size()/2)
        var q=_point(Vector2(road.points[i][0],road.points[i][1]))
        var title=str(road.name).replace("улица","ул.")
        var width=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
        var rect=Rect2(q-Vector2(width/2,14),Vector2(width,18))
        if not Rect2(Vector2(10,10),size-Vector2(20,40)).encloses(rect):continue
        var clear=true
        for used in occupied:
            if used.intersects(rect.grow(12)):clear=false;break
        if clear:
            draw_rect(rect,Color(0.06,.12,.14,.85))
            draw_string(font,q+Vector2(-width/2,0),title,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffe1a7"))
            occupied.append(rect)
    if not expanded or zoom<1.6:return
    for b in main.world.data.buildings:
        var number=str(b.get("housenumber",""))
        if number.is_empty():continue
        var p=b.get("center",b.polygon[0]);var q=_point(Vector2(p[0],p[1]))
        var width=font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
        var rect=Rect2(q-Vector2(width/2,11),Vector2(width,15))
        if not Rect2(Vector2(8,8),size-Vector2(16,45)).encloses(rect):continue
        var clear=true
        for used in occupied:
            if used.intersects(rect.grow(2)):clear=false;break
        if clear:
            draw_string_outline(font,q+Vector2(-width/2,0),number,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color("17282d"))
            draw_string(font,q+Vector2(-width/2,0),number,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
            occupied.append(rect)
