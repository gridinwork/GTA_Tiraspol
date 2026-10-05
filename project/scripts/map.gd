extends Control
var main
var expanded=false
var font=preload("res://assets/DejaVuSans.ttf")
var span=250.0
var center=Vector2.ZERO
var factor=1.0

func _ready() -> void:
    clip_contents=true
    mouse_filter=Control.MOUSE_FILTER_STOP if expanded else Control.MOUSE_FILTER_IGNORE

func _process(_dt: float) -> void:
    queue_redraw()

func _draw() -> void:
    if not main or not main.world:return
    var w=main.world
    var pos=main.car.global_position if main.driving else main.player.global_position
    if expanded:
        var bounds=w.data.bounds
        center=Vector2((bounds[0]+bounds[2])/2,(bounds[1]+bounds[3])/2)
        factor=minf((size.x-70)/(bounds[2]-bounds[0]),(size.y-70)/(bounds[3]-bounds[1]))
    else:
        center=Vector2(pos.x,pos.z)
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
    var q=_point(Vector2(pos.x,pos.z))
    var yaw=main.car.rotation.y if main.driving else main.player.visual.rotation.y
    var arrow=PackedVector2Array([Vector2(0,-9),Vector2(-6,6),Vector2(0,3),Vector2(6,6)])
    for i in range(arrow.size()):arrow[i]=q+arrow[i].rotated(-yaw)
    draw_colored_polygon(arrow,Color("faf4e8"))
    if main.waypoint!=Vector2.INF:
        var wp=_point(main.waypoint)
        draw_circle(wp,7,Color("ffb760"),false,2,true)
        draw_line(wp+Vector2(-11,0),wp+Vector2(11,0),Color("ffb760"),1)
        draw_line(wp+Vector2(0,-11),wp+Vector2(0,11),Color("ffb760"),1)
    draw_string(font,Vector2(size.x-23,23),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("f0e7d2"))
    draw_line(Vector2(size.x-17,29),Vector2(size.x-17,40),Color("f0e7d2"),2)
    draw_rect(Rect2(Vector2.ZERO,size),Color("768c86"),false,1)

func _point(p: Vector2) -> Vector2:
    return (p-center)*factor+size/2

func _gui_input(event: InputEvent) -> void:
    if not expanded:return
    if event is InputEventMouseButton and event.pressed:
        if event.button_index==MOUSE_BUTTON_LEFT:
            var p=(event.position-size/2)/factor+center
            if main.world.contains(Vector3(p.x,0,p.y)):
                main.waypoint=p
                main.notify("Метка поставлена. Расстояние показано на экране.")
        elif event.button_index==MOUSE_BUTTON_RIGHT:
            main.waypoint=Vector2.INF

