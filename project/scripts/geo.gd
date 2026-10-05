extends RefCounted

static func mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var node = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = material
    node.position = pos
    parent.add_child(node)
    return node

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material, vertices: int = 12, top: float = -1.0) -> MeshInstance3D:
    var n = MeshInstance3D.new()
    var m = CylinderMesh.new()
    m.top_radius = radius if top < 0 else top
    m.bottom_radius = radius
    m.height = height
    m.radial_segments = vertices
    m.rings = 1
    n.mesh = m
    n.material_override = material
    n.position = pos
    parent.add_child(n)
    return n

static func ball(parent: Node3D, pos: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var n = MeshInstance3D.new()
    var m = SphereMesh.new()
    m.radius = radius
    m.height = radius * 2
    m.radial_segments = 12
    m.rings = 6
    n.mesh = m
    n.material_override = material
    n.position = pos
    parent.add_child(n)
    return n

static func surface() -> SurfaceTool:
    var s = SurfaceTool.new()
    s.begin(Mesh.PRIMITIVE_TRIANGLES)
    return s

static func tri(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, ua: Vector2 = Vector2.ZERO, ub: Vector2 = Vector2.RIGHT, uc: Vector2 = Vector2.ONE) -> void:
    s.set_normal(normal); s.set_uv(ua); s.add_vertex(a)
    s.set_normal(normal); s.set_uv(ub); s.add_vertex(b)
    s.set_normal(normal); s.set_uv(uc); s.add_vertex(c)

static func quad(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, uvsize: Vector2 = Vector2.ONE) -> void:
    tri(s,a,b,c,normal,Vector2.ZERO,Vector2(uvsize.x,0),uvsize)
    tri(s,a,c,d,normal,Vector2.ZERO,uvsize,Vector2(0,uvsize.y))

static func mesh_node(parent: Node3D, s: SurfaceTool, material: Material, distance: float = 0) -> MeshInstance3D:
    var n = MeshInstance3D.new()
    n.mesh = s.commit()
    n.material_override = material
    if distance > 0:
        n.visibility_range_end = distance
        n.visibility_range_end_margin = 40
    parent.add_child(n)
    return n

static func label3(parent: Node3D, title: String, pos: Vector3, size: int = 40) -> Label3D:
    var l = Label3D.new()
    l.text = title
    l.font_size = size
    l.pixel_size = 0.025
    l.position = pos
    l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    l.no_depth_test = false
    l.modulate = Color("f5ecd6")
    l.outline_modulate = Color("202b35")
    l.outline_size = 6
    l.visibility_range_end = 160
    parent.add_child(l)
    return l
