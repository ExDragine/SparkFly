#version 120
#extension GL_EXT_gpu_shader4:enable
/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

#define WAVY_PLANTS

#define SHADOW_MAP_BIAS .8
const float PI=3.1415927;
varying vec3 texcoord;
varying vec4 color;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

const float PI48=150.796447372;
float pi2wt=PI48*frameTimeCounter;

vec2 calcWave(in vec3 pos){
	
	float magnitude=abs(sin(dot(vec4(frameTimeCounter,pos),vec4(1.,.005,.005,.005)))*.5+.72)*.013;
	vec2 ret=(sin(pi2wt*vec2(.0063,.0015)*4.-pos.xz+pos.y*.05)+.1)*magnitude;
	
	return ret;
}

vec3 calcMovePlants(in vec3 pos){
	vec2 move1=calcWave(pos);
	float move1y=-length(move1);
	return vec3(move1.x,move1y,move1.y)*6.;
}

vec3 calcWaveLeaves(in vec3 pos,in float fm,in float mm,in float ma,in float f0,in float f1,in float f2,in float f3,in float f4,in float f5){
	
	float magnitude=abs(sin(dot(vec4(frameTimeCounter,pos),vec4(1.,.005,.005,.005)))*.5+.72)*.013;
	vec3 ret=(sin(pi2wt*vec3(.0063,.0224,.0015)*1.5-pos))*magnitude;
	
	return ret;
}

vec3 calcMoveLeaves(in vec3 pos,in float f0,in float f1,in float f2,in float f3,in float f4,in float f5,in vec3 amp1,in vec3 amp2){
	vec3 move1=calcWaveLeaves(pos,.0054,.0400,.0400,.0127,.0089,.0114,.0063,.0224,.0015)*amp1;
	return move1*6.;
}
vec4 BiasShadowProjection(in vec4 projectedShadowSpacePosition){
	
	vec2 pos=abs(projectedShadowSpacePosition.xy*1.165);
	vec2 posSQ=pos*pos;
	
	float dist=pow(posSQ.x*posSQ.x*posSQ.x+posSQ.y*posSQ.y*posSQ.y,1./6.);
	
	float distortFactor=(1.-SHADOW_MAP_BIAS)+dist*SHADOW_MAP_BIAS;
	
	projectedShadowSpacePosition.xy/=distortFactor*.92;
	
	return projectedShadowSpacePosition;
}
void main(){
	
	vec4 position=ftransform();
	bool istopv=gl_MultiTexCoord0.t<mc_midTexCoord.t;
	float lmcoord=(gl_MultiTexCoord1.y/255.)*(gl_MultiTexCoord1.y/255.);
	#ifdef WAVY_PLANTS
	if((mc_Entity.x==10001&&istopv)){
		position=shadowProjectionInverse*position;
		position=shadowModelViewInverse*position;
		vec3 worldpos=position.xyz+cameraPosition;
		position.xyz+=calcMovePlants(worldpos.xyz)*lmcoord;
		position=shadowModelView*position;
		position=shadowProjection*position;
	}
	
	if((mc_Entity.x==10003)){
		position=shadowProjectionInverse*position;
		position=shadowModelViewInverse*position;
		vec3 worldpos=position.xyz+cameraPosition;
		position.xyz+=calcMoveLeaves(worldpos.xyz,.0040,.0064,.0043,.0035,.0037,.0041,vec3(1.,.2,1.),vec3(.5,.1,.5))*lmcoord;
		position=shadowModelView*position;
		position=shadowProjection*position;
	}
	#endif
	
	gl_Position=BiasShadowProjection(position);
	gl_Position.z/=3.;
	color=gl_Color;
	texcoord.xy=gl_MultiTexCoord0.xy;
	
	texcoord.z=1.;
	if(mc_Entity.x==8||mc_Entity.x==9)texcoord.z=0.;
}
