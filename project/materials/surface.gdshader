shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
uniform vec4 base_color:source_color=vec4(.4,.4,.4,1.0);
uniform float scale=18.0;
uniform float variation=.10;
uniform float roughness_value=.9;
varying vec3 world_pos;
float hash(vec3 p){return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453);}
void vertex(){world_pos=VERTEX;}
void fragment(){float grain=hash(floor(world_pos*scale));float patches=hash(floor(world_pos*.8));ALBEDO=base_color.rgb*(1.0+variation*(grain-.5)+variation*.5*(patches-.5));ROUGHNESS=roughness_value;}
