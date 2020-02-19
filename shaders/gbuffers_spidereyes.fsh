#version 120

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/


varying vec4 color;
varying vec2 texcoord;

uniform sampler2D texture;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	vec4 albedo = texture2D(texture, texcoord);

	albedo *= color;

/* DRAWBUFFERS:2 */
	gl_FragData[0] = albedo;
	
}