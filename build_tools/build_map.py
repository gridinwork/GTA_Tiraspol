"""Rebuild the prototype map from the bundled OpenStreetMap extract.
Requires Python 3, numpy and shapely. Not needed to play the game.
Screenshot alignment is approximate, based on visible street junctions.
All coordinates in the game are metres; X east, Z south.
"""
import gzip, json, math, random, xml.etree.ElementTree as ET
from pathlib import Path
from shapely.geometry import Polygon, LineString, Point

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / 'project' / 'data'
LAT0, LON0 = 46.8358948, 29.6659691
MX, MY = 111320 * math.cos(math.radians(LAT0)), 111320
def project(lon, lat): return [(lon-LON0)*MX, (LAT0-lat)*MY]
def pixel(x,y):
    # Kakhovskaya / Krasnodonskaya junction is the reference anchor.
    q=project(29.6610868,46.8325004)
    return [q[0]+(x-913)*1.35,q[1]+(y-831)*1.35]
contour_px = [(550,117),(578,105),(620,105),(655,113),(709,141),(763,181),
 (815,207),(866,236),(914,266),(947,302),(985,323),(1023,337),(1072,367),
 (1102,387),(1127,391),(1176,430),(1211,451),(1240,470),(1272,501),
 (1304,528),(1301,557),(1287,590),(1272,622),(1250,657),(1216,691),
 (1184,731),(1149,772),(1119,807),(1089,831),(1054,851),(1008,874),
 (944,877),(890,879),(854,871),(818,855),(785,827),(752,802),(734,787),
 (725,753),(716,712),(699,663),(682,616),(674,573),(659,521),(644,484),
 (617,438),(594,408),(563,376),(562,337),(560,301),(545,265),(542,240),
 (547,203),(547,161)]
boundary = [pixel(*p) for p in contour_px]
area = Polygon(boundary)
# A 35 m visual skirt avoids clipping buildings exactly at the drawn marker.
visual = area.buffer(35)
root=ET.parse(gzip.open(HERE/'source_map.osm.gz', 'rb')).getroot()
nodes={n.get('id'):project(float(n.get('lon')),float(n.get('lat'))) for n in root.findall('node')}
def tags(e): return {t.get('k'):t.get('v') for t in e.findall('tag')}
def coords(e): return [nodes[n.get('ref')] for n in e.findall('nd') if n.get('ref') in nodes]
def rounded(p): return [[round(x,2),round(y,2)] for x,y in p]
roads=[]; buildings=[]; landmarks=[]; greens=[]; parkings=[]
widths={'primary':13,'secondary':12,'tertiary':10,'residential':6.5,'unclassified':6,'service':4.2,'living_street':5,'track':3,'footway':1.8,'path':1.4,'pedestrian':3,'steps':1.5}
for w in root.findall('way'):
    t=tags(w); pts=coords(w); wid=int(w.get('id'))
    if len(pts)<2: continue
    if t.get('highway') in widths and t.get('area')!='yes':
        line=LineString(pts).intersection(visual)
        if line.is_empty: continue
        parts=list(line.geoms) if hasattr(line,'geoms') else [line]
        for part in parts:
            if part.geom_type!='LineString' or part.length<2:continue
            typ=t['highway'];width=widths[typ]
            if t.get('oneway')=='yes' and typ=='tertiary': width=7
            roads.append({'id':wid,'points':rounded(part.coords),'width':width,'kind':typ,'name':t.get('name:ru',t.get('name','Дворовой проезд')),'oneway':t.get('oneway','no')})
    if len(pts)<4 or pts[0]!=pts[-1]:continue
    poly=Polygon(pts).buffer(0)
    if poly.geom_type!='Polygon' or not poly.intersects(visual):continue
    if t.get('building') and poly.area>9:
        poly=poly.simplify(.35,preserve_topology=True)
        rng=random.Random(wid)
        levels=t.get('building:levels','')
        known=True
        try: levels=float(levels.split(';')[0])
        except (ValueError,IndexError):
            known=False
            levels=5 if poly.area>320 and t.get('building') not in ['garages','garage','shed','retail','industrial','warehouse'] else 1
        levels=max(1,min(16,levels));height=levels*2.9+1
        try: height=float(t.get('height','').replace(' m',''))
        except ValueError:pass
        name=t.get('name:ru',t.get('name',''))
        if len(name)>45:name=''
        typ='apartments' if levels>=3 else ('commercial' if name or t.get('shop') else 'house')
        if t.get('building') in ['garage','garages','shed']:typ='garage'
        item={'id':wid,'polygon':rounded(list(poly.exterior.coords)[:-1]),'height':round(height,1),'levels':levels,'levels_known':known,'style':typ,'variant':rng.randrange(6),'name':name,'street':t.get('addr:street',''),'housenumber':t.get('addr:housenumber',''),'center':[round(poly.centroid.x,2),round(poly.centroid.y,2)],'address':(t.get('addr:street','')+' '+t.get('addr:housenumber','')).strip(),'reference_status':'facade_reference_reviewed' if wid==136387817 else 'needs_photos'}
        buildings.append(item)
        if name in ['Тернополь','Причерноморье','Маяк']:
            landmarks.append({'name':name,'position':[round(poly.centroid.x,2),round(poly.centroid.y,2)],'height':height,'building_id':wid})
    if t.get('landuse') in ['grass','meadow','recreation_ground'] or t.get('leisure') in ['park','garden','playground'] or t.get('natural') in ['wood','scrub','grassland']:
        greens.append({'polygon':rounded(list(poly.exterior.coords)[:-1]),'kind':t.get('leisure',t.get('natural','grass'))})
    if t.get('amenity')=='parking':parkings.append(rounded(list(poly.exterior.coords)[:-1]))
# Deterministic trees in free areas, away from buildings and driveable streets.
from shapely.ops import unary_union
obstacles=unary_union([Polygon(b['polygon']).buffer(2.5) for b in buildings]+[LineString(r['points']).buffer(r['width']/2+2.5) for r in roads]+[Polygon(p) for p in parkings])
rng=random.Random(2005);trees=[]
minx,minz,maxx,maxz=visual.bounds
for _ in range(5500):
    p=Point(rng.uniform(minx,maxx),rng.uniform(minz,maxz))
    if area.contains(p) and not obstacles.contains(p):
        if any((p.x-x)**2+(p.y-z)**2<35 for x,z,_,_ in trees):continue
        trees.append([round(p.x,2),round(p.y,2),round(rng.uniform(4.5,8.5),2),rng.randrange(3)])
        if len(trees)>=640:break
# Spawn on the northbound Krasnodonskaya carriageway, beside Ternopol.
spawn=project(29.665858,46.835755)
result={'title':'Тирасполь · Балка','version':'0.2.0','origin':{'latitude':LAT0,'longitude':LON0},'metres_per_unit':1,'boundary':rounded(boundary),'bounds':[round(x,2) for x in visual.bounds],'spawn':{'car':[round(spawn[0],2),.3,round(spawn[1],2)],'yaw':-0.64},'roads':roads,'buildings':buildings,'landmarks':landmarks,'greens':greens,'parkings':parkings,'trees':trees,'source':'© OpenStreetMap contributors, ODbL 1.0','alignment':'Approximate alignment to user-drawn screenshot; not a survey. Heights without OSM levels are estimated.'}
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'district.json').write_text(json.dumps(result,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
print(f'{len(roads)} street/path sections, {len(buildings)} buildings, {len(trees)} trees, {area.area/1e6:.3f} km2')
print('bounds',visual.bounds,'spawn',spawn,'landmarks',landmarks)
