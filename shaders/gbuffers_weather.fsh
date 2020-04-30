#version 120

varying vec4 lmtexcoord;
varying vec4 color;

uniform sampler2D texture;

uniform vec4 lightCol;
uniform vec3 sunVec;

uniform vec2 texelSize;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform float rainStrength;

uniform mat4 gbufferProjectionInverse;

#define diagonal3(m)vec3((m)[0].x,(m)[1].y,m[2].z)
#define projMAD(m,v)(diagonal3(m)*(v)+(m)[3].xyz)
vec3 toLinear(vec3 sRGB){
	return sRGB*(sRGB*(sRGB*.305306011+.682171111)+.012522878);
}

vec3 toScreenSpaceVector(vec3 p){
	vec4 iProjDiag=vec4(gbufferProjectionInverse[0].x,gbufferProjectionInverse[1].y,gbufferProjectionInverse[2].zw);
	vec3 p3=p*2.-1.;
	vec4 fragposition=iProjDiag*p3.xyzz+gbufferProjectionInverse[3];
	return normalize(fragposition.xyz);
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main(){
	/* DRAWBUFFERS:2 */
	gl_FragData[0]=texture2D(texture,lmtexcoord.xy)*rainStrength;
	gl_FragData[0].a=clamp(gl_FragData[0].a-.1,0.,1.)*.5;
	vec3 albedo=toLinear(gl_FragData[0].rgb*color.rgb);
	vec3 ambient=skyIntensity*vec3(.5,.65,1.)*20.+skyIntensityNight*vec3(.08,.12,.18)*3.;
	
	vec3 light=ambient*lmtexcoord.w;
	gl_FragData[0].rgb=dot(albedo,vec3(1.))*light;
	
}