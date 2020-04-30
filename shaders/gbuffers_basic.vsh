#version 120
#extension GL_EXT_gpu_shader4:enable
#define TAA

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

uniform vec2 texelSize;
uniform int framemod8;
const vec2[8]offsets=vec2[8](vec2(1./8.,-3./8.),
vec2(-1.,3.)/8.,
vec2(5.,1.)/8.,
vec2(-3,-5.)/8.,
vec2(-5.,5.)/8.,
vec2(-7.,-1.)/8.,
vec2(3,7.)/8.,
vec2(7.,-7.)/8.);
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main(){
	lmtexcoord.xy=(gl_MultiTexCoord0).xy;
	
	vec2 lmcoord=gl_MultiTexCoord1.xy/255.;
	lmtexcoord.zw=lmcoord*lmcoord;
	
	gl_Position=ftransform();
	color=gl_Color;
	
	normalMat=vec4(normalize(gl_NormalMatrix*gl_Normal),1.);
	#ifdef TAA
	gl_Position.xy+=offsets[framemod8]*gl_Position.w*texelSize;
	#endif
}