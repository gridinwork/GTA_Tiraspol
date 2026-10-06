extends RefCounted
const G=preload("res://scripts/geo.gd")
const TYPES=["Запорожец ЗАЗ-968М","Жигули ВАЗ-2106","Москвич-2140","Лада Веста"]

static func build(parent:Node3D,kind:int,color:Color) -> Array:
    var paint=G.mat(color,.3);paint.metallic=.35
    var chrome=G.mat(Color("aeb8bf"),.22);chrome.metallic=.8
    var rubber=G.mat(Color("161b20"),.9);var glass=G.mat(Color("29424e"),.17);glass.metallic=.6
    var light=G.mat(Color("e8dfb6"),.2);var red=G.mat(Color("ae2929"),.35)
    var modern=kind==3;var small=kind==0
    var length=3.72 if small else (4.41 if modern else 4.16)
    var width=1.58 if small else (1.77 if modern else 1.62)
    var wheelbase=2.16 if small else 2.52
    var body=G.box(parent,Vector3(0,.78,0),Vector3(width,.52,length),paint)
    # Distinct silhouette: rear-engine two-door ZAZ, boxy classics, longer Vesta.
    var cab_z=.03 if small else .12
    G.box(parent,Vector3(0,1.29,cab_z),Vector3(width*.85,.55,1.83 if small else 2.02),glass)
    G.box(parent,Vector3(0,1.59,cab_z+.04),Vector3(width*.78,.075,1.65),paint)
    for side in [-1,1]:
        for z in [-.86,.22,.98]:
            if small and z==.22:continue
            var pillar=G.box(parent,Vector3(side*width*.43,1.30,z),Vector3(.065,.58,.075),paint)
            if z<0:pillar.rotation.x=.24
        G.box(parent,Vector3(side*(width/2+.012),.83,.1),Vector3(.024,.025,length*.82),chrome)
        for z in ([-.02] if small else [-.08,.76]):
            G.box(parent,Vector3(side*(width/2+.02),1.02,z),Vector3(.025,.035,.15),chrome)
            G.tube(parent,Vector3(side*(width/2+.01),.55,z+.35),Vector3(side*(width/2+.01),1.04,z+.35),.006,rubber,8)
        G.box(parent,Vector3(side*(width/2+.09),1.12,-.74),Vector3(.20,.12,.17),paint if modern else chrome)
        if small:
            for j in range(8):G.box(parent,Vector3(side*(width/2+.018),1.00,.94+j*.065),Vector3(.02,.018,.04),rubber)
        if modern:
            G.tube(parent,Vector3(side*.68,.54,-1.65),Vector3(side*.76,.89,-.91),.028,chrome)
            G.tube(parent,Vector3(side*.76,.89,-.91),Vector3(side*.69,.71,.2),.02,chrome)
    for z in [-length/2-.045,length/2+.045]:G.box(parent,Vector3(0,.56,z),Vector3(width+.05,.13,.12),paint if modern else chrome)
    var front=-length/2-.016
    G.box(parent,Vector3(0,.88,front),Vector3(.78,.28,.035),rubber)
    for y in [.80,.88,.96]:G.box(parent,Vector3(0,y,front-.026),Vector3(.73,.017,.014),chrome)
    for side in [-1,1]:
        if kind in [0,1]:
            for offset in ([0.0,.19] if kind==1 else [0.0]):
                var lamp=G.cylinder(parent,Vector3(side*(.55-offset),.96,front-.045),.09,.04,light,24);lamp.rotation.x=PI/2
        else:
            var lamp=G.box(parent,Vector3(side*.56,.97,front-.03),Vector3(.34 if modern else .27,.12 if modern else .18,.04),light)
            if modern:lamp.rotation.z=side*.13
        G.box(parent,Vector3(side*.60,.80,front-.02),Vector3(.12,.06,.04),G.mat(Color("d59135")))
        G.box(parent,Vector3(side*.58,.89,length/2+.022),Vector3(.28,.20,.04),red)
    var plate=Label3D.new();plate.text=["ЗАЗ 968","ВАЗ 2106","М 2140","LADA"][kind];plate.font=load("res://assets/DejaVuSans.ttf");plate.font_size=32;plate.pixel_size=.003;plate.position=Vector3(0,.67,length/2+.076);plate.outline_size=0;parent.add_child(plate)
    var wheels=[]
    for side in [-1,1]:
        for z in [-wheelbase/2,wheelbase/2]:
            var pivot=Node3D.new();parent.add_child(pivot);pivot.position=Vector3(side*(width/2-.04),.34,z);wheels.append(pivot)
            var tire=G.cylinder(pivot,Vector3.ZERO,.34,.22,rubber,24);tire.rotation.z=PI/2
            var rim=G.cylinder(pivot,Vector3(side*.12,0,0),.21,.02,chrome,20);rim.rotation.z=PI/2
            if modern:
                for j in range(5):
                    var a=j*TAU/5
                    G.tube(pivot,Vector3(side*.137,0,0),Vector3(side*.137,sin(a)*.19,cos(a)*.19),.020,rubber,8)
            G.merge_static_children(pivot)
    G.merge_static_children(parent)
    return wheels
