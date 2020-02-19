#version 120

varying vec2 texcoord;
varying vec4 lightCol;
uniform vec3 nsunColor;
uniform float skyIntensity;
uniform float skyIntensityNight;
uniform float rainStrength;
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;
	lightCol.a = float(skyIntensity>0.0)*2.0-1.;
	lightCol.rgb = skyIntensity<=0.0? (1.0-skyIntensity)*vec3(0.07,0.12,0.18)/15.*(1.0-rainStrength*0.85):skyIntensity*nsunColor*50.;
}
