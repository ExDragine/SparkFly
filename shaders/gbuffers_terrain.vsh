#version 120
#extension GL_EXT_gpu_shader4 : enable

#define TAA
#define WAVY_PLANTS
#define SEPARATE_AO
//#define POM
//#define USE_LUMINANCE_AS_HEIGHTMAP	//Can generate POM on any texturepack (may look weird in some cases)

#ifndef USE_LUMINANCE_AS_HEIGHTMAP
#ifndef MC_NORMAL_MAP
#undef POM
#endif
#endif

#ifdef POM
#define MC_NORMAL_MAP
#endif

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;
#ifdef POM
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;
#endif

#ifdef MC_NORMAL_MAP
varying vec4 tangent;
attribute vec4 at_tangent; 
#endif

uniform float frameTimeCounter;
const float PI48 = 150.796447372;
float pi2wt = PI48*frameTimeCounter;
attribute vec4 mc_Entity;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
attribute vec4 mc_midTexCoord;
uniform vec3 cameraPosition;
uniform vec2 texelSize;
uniform int framemod8;
		const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);


vec2 calcWave(in vec3 pos) {
	
    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec2 ret = (sin(pi2wt*vec2(0.0063,0.0015)*4. - pos.xz + pos.y*0.05)+0.1)*magnitude;
	
    return ret;
}

vec3 calcMovePlants(in vec3 pos) {
    vec2 move1 = calcWave(pos );
	float move1y = -length(move1);
   return vec3(move1.x,move1y,move1.y)*6.;
}

vec3 calcWaveLeaves(in vec3 pos, in float fm, in float mm, in float ma, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5) {

    float magnitude = abs(sin(dot(vec4(frameTimeCounter, pos),vec4(1.0,0.005,0.005,0.005)))*0.5+0.72)*0.013;
	vec3 ret = (sin(pi2wt*vec3(0.0063,0.0224,0.0015)*1.5 - pos))*magnitude;
	
    return ret;
}

vec3 calcMoveLeaves(in vec3 pos, in float f0, in float f1, in float f2, in float f3, in float f4, in float f5, in vec3 amp1, in vec3 amp2) {
    vec3 move1 = calcWaveLeaves(pos      , 0.0054, 0.0400, 0.0400, 0.0127, 0.0089, 0.0114, 0.0063, 0.0224, 0.0015) * amp1;
    return move1*6.;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	lmtexcoord.xy = (gl_MultiTexCoord0).xy;
	#ifdef POM
	vec2 midcoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = lmtexcoord.xy-midcoord;
	vtexcoordam.pq  = abs(texcoordminusmid)*2;
	vtexcoordam.st  = min(lmtexcoord.xy,midcoord-texcoordminusmid);
	vtexcoord.xy    = sign(texcoordminusmid)*0.5+0.5;
	#endif
	vec2 lmcoord = gl_MultiTexCoord1.xy/255.;
	lmtexcoord.zw = lmcoord;

	gl_Position = ftransform();
	color = gl_Color;

	bool istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t;
	#ifdef MC_NORMAL_MAP
		tangent = vec4(normalize(gl_NormalMatrix *at_tangent.rgb),at_tangent.w);
	#endif

	normalMat = vec4(normalize(gl_NormalMatrix *gl_Normal),mc_Entity.x == 10004 || mc_Entity.x == 10003 || mc_Entity.x == 10001 ? 0.0:1.0);	
	#ifdef WAVY_PLANTS
		if ((mc_Entity.x == 10001&&istopv)) {
		vec4 position = gl_ModelViewMatrix * gl_Vertex;
		position = gbufferModelViewInverse * position;
		vec3 worldpos = position.xyz + cameraPosition;
		position.xyz += calcMovePlants(worldpos.xyz)*lmtexcoord.w;
		position = gbufferModelView * position;	
		gl_Position = gl_ProjectionMatrix * position;
		}
		
		if ((mc_Entity.x == 10003)) {
		vec4 position = gl_ModelViewMatrix * gl_Vertex;
		position = gbufferModelViewInverse * position;
		vec3 worldpos = position.xyz + cameraPosition;
		position.xyz += calcMoveLeaves(worldpos.xyz, 0.0040, 0.0064, 0.0043, 0.0035, 0.0037, 0.0041, vec3(1.0,0.2,1.0), vec3(0.5,0.1,0.5))*lmtexcoord.w;
		position = gbufferModelView * position;	
		gl_Position = gl_ProjectionMatrix * position;
		}
	#endif
	#ifdef SEPARATE_AO
	lmtexcoord.z *= sqrt(color.a);
	lmtexcoord.w *= color.a;
	#else
	color.rgb*=color.a;
	#endif
	#ifdef TAA
	gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
	#endif
}