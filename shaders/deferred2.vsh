#version 120

varying vec2 texcoord;
varying vec4 lightCol;
uniform vec3 sunColor;
uniform float skyIntensity;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main(){
	
	gl_Position=ftransform();
	texcoord=gl_MultiTexCoord0.xy;
	lightCol.a=float(skyIntensity>0.)*2.-1.;
	lightCol.rgb=skyIntensity<=0.?(1.-skyIntensity)*vec3(.07,.12,.18)/15.:skyIntensity*sunColor;
}
