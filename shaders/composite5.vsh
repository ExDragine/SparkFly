#version 120
#extension GL_EXT_gpu_shader4 : enable

#define BASE_FOG_AMOUNT 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0 10.0 20.0 30.0 50.0 100.0 150.0 200.0]  Base fog amount amount (does not change the "cloudy" fog)
#define CLOUDY_FOG_AMOUNT 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0]
#define FOG_TOD_MULTIPLIER 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0] //Influence of time of day on fog amount
#define FOG_RAIN_MULTIPLIER 1.0 //[0.0 0.2 0.4 0.6 0.8 1.0 1.25 1.5 1.75 2.0 3.0 4.0 5.0] //Influence of rain on fog amount

flat varying vec4 lightCol;
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
flat varying float tempOffsets;
flat varying float fogAmount;
flat varying float VFAmount;

uniform sampler2D colortex4;
uniform float sunElevation;
uniform float rainStrength;
uniform int isEyeInWater;
uniform int frameCounter;
uniform int worldTime;
#include "/lib/util.glsl"
float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	tempOffsets = HaltonSeq2(frameCounter%10000);
	gl_Position = ftransform();
	gl_Position.xy = (gl_Position.xy*0.5+0.5)*0.51*2.0-1.0;
	vec3 sc = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	vec3 avgAmbient = texelFetch2D(colortex4,ivec2(11,37),0).rgb;
	ambientUp = texelFetch2D(colortex4,ivec2(0,37),0).rgb;
	ambientDown = texelFetch2D(colortex4,ivec2(1,37),0).rgb;
	ambientLeft = texelFetch2D(colortex4,ivec2(2,37),0).rgb;
	ambientRight = texelFetch2D(colortex4,ivec2(3,37),0).rgb;
	ambientB = texelFetch2D(colortex4,ivec2(4,37),0).rgb;
	ambientF = texelFetch2D(colortex4,ivec2(5,37),0).rgb;


	lightCol.a = float(sunElevation > 1e-5)*2-1.;
	lightCol.rgb = sc;
	lightCol.rgb *= (1.0-rainStrength*0.9);

	float modWT = (worldTime%24000)*1.0;

	float fogAmount0 = 1/3000.+FOG_TOD_MULTIPLIER*(1/180.*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.))*(clamp(modWT-11000.,0.,2000.0)/2000.+(1.0-clamp(modWT,0.,3000.0)/3000.)) + 1/200.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.));
	VFAmount = CLOUDY_FOG_AMOUNT*(fogAmount0*fogAmount0+FOG_RAIN_MULTIPLIER*1.8/20000.*rainStrength);
	fogAmount = BASE_FOG_AMOUNT*(fogAmount0+max(FOG_RAIN_MULTIPLIER*1/10.*rainStrength , FOG_TOD_MULTIPLIER*1/50.*clamp(modWT-13000.,0.,1000.0)/1000.*(1.0-clamp(modWT-23000.,0.,1000.0)/1000.)));

}
