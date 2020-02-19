#version 120
//Downsampling depth buffer
#extension GL_EXT_gpu_shader4 : enable
varying vec2 texcoord;

uniform sampler2D depthtex1;


uniform float viewWidth;
uniform float viewHeight;

uniform float far;
uniform float near;
#include "lib/projections.glsl"


float linZ(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
/* DRAWBUFFERS:4 */
ivec2 halfResTC = ivec2(floor(gl_FragCoord.xy)*4.);
gl_FragData[0] = vec4(0.);

//generates a quarter res depth buffer
	gl_FragData[0].x = linZ(texelFetch2D(depthtex1,halfResTC,0).x);
	gl_FragData[0].x = pow(gl_FragData[0].x,1.0/3.0);
}
