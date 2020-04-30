#version 120
//Cloud godrays
#extension GL_EXT_gpu_shader4:enable
varying vec2 texcoord;
const int shadowMapResolution=2048;//[512 768 1024 1536 2048 3172 4096 8192]
uniform sampler2D colortex0;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform vec3 nsunColor;
uniform float skyIntensity;
uniform float skyIntensityNight;
#include "lib/projections.glsl"
#include "lib/sky_gradient.glsl"
vec3 sunVec=normalize(mat3(gbufferModelViewInverse)*sunPosition);
varying vec4 lightCol;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;
uniform float far;
uniform float near;
uniform float fogAmount;

float bayer2(vec2 a){
	a=floor(a);
	return fract(dot(a,vec2(.5,a.y*.75)));
}
#define bayer4(a)(bayer2(.5*(a))*.25+bayer2(a))
#define bayer8(a)(bayer4(.5*(a))*.25+bayer2(a))
#define bayer16(a)(bayer8(.5*(a))*.25+bayer2(a))
#define CLOUD_GODRAYS_STHENGHT .5//[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0]
float cdist(vec2 coord){
	vec2 vec=coord*2.-1.;
	float d=max(vec.x*vec.x,vec.y*vec.y);
	return clamp(1.-d*d,0.,1.);
}

vec2 clip_aabb(vec2 q,vec2 aabb_min,vec2 aabb_max)
{
	vec2 p_clip=.5*(aabb_max+aabb_min);
	vec2 e_clip=.5*(aabb_max-aabb_min)+.00000001;
	
	vec2 v_clip=q-vec2(p_clip);
	vec2 v_unit=v_clip.xy/e_clip;
	vec2 a_unit=abs(v_unit);
	float ma_unit=max(a_unit.x,a_unit.y);
	
	if(ma_unit>1.)
	return vec2(p_clip)+v_clip/ma_unit;
	else
	return q;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main(){
	/* DRAWBUFFERS:0 */
	vec3 fragpos=toScreenSpace(vec3(texcoord,1.));
	vec3 p3=mat3(gbufferModelViewInverse)*fragpos;
	vec3 np3=normalize(p3);
	
	float SdotE=dot(sunVec*lightCol.a,np3)*.5+.5;
	
	vec2 deltatexcoord=(toClipSpace3(fragpos+sunPosition/13.*lightCol.a).xy-texcoord.xy);
	
	vec2 noisetc=texcoord+deltatexcoord*bayer16(gl_FragCoord.xy);
	float gr=0.;
	float totalWeight=0.;
	for(int i=0;i<50;i++){
		gr+=mix(1.,(texture2D(colortex0,noisetc/4.).a*texture2D(colortex0,noisetc/4.).a*texture2D(colortex0,noisetc/4.).a*texture2D(colortex0,noisetc/4.).a),(SdotE)*cdist(noisetc));
		totalWeight+=1.;
		noisetc+=deltatexcoord;
	}
	
	vec3 skyCol=getSkyColor(np3,sunVec,np3.y);
	gl_FragData[0]=texture2D(colortex0,texcoord/4.)+vec4(vec3(gr/totalWeight)*skyCol*CLOUD_GODRAYS_STHENGHT*(1.+fogAmount*100.),0.);
}
