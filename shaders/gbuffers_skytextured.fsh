#version 120

/*
!! DO NOT REMOVE !!
This code is from Chocapic13' shaders
Read the terms of modification and sharing before changing something below please !
!! DO NOT REMOVE !!
*/

/* DRAWBUFFERS:6 */

varying vec4 color;
varying vec2 texcoord;
//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB*(sRGB*(sRGB*.305306011+.682171111)+.012522878);
}

uniform sampler2D texture;
void main(){
	
	gl_FragData[0]=texture2D(texture,texcoord.xy)*color;
	gl_FragData[0].rgb=toLinear(gl_FragData[0].rgb)*2.;
}