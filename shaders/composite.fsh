#version 120
//Volumetric fog rendering
#extension GL_EXT_gpu_shader4:enable

#define TONEMAP_ACES Tonemap_Aces//[Tonemap_Filmic_UC2 Tonemap_Filmic_UC2Default Tonemap_Aces ACESFilm invACESFilm]

#define VOLUMETRIC_LIGHT
#define VL_SAMPLES 4//[4 6 8 10 12 14 16 20 24 30 40 50]
#define SEA_LEVEL 65//[0 10 20 30 40 50 60 70 80 90 100 110 120 130 150 170 190 210 230]	//The volumetric light uses an altitude-based fog density, this is where fog density is the highest, adjust this value according to your world.
#define ATMOSPHERIC_DENSITY 2.5//[0.0 0.5 1.0 1.5 2.0 3.0 4.0 5.0]

varying vec2 texcoord;
uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2DShadow shadow;

uniform vec4 lightCol;
uniform vec3 sunColor;
uniform vec3 nsunColor;

uniform vec3 sunVec;
uniform float sunIntensity;
uniform float far;
uniform float skyIntensity;
uniform float skyIntensityNight;
uniform float fogAmount;
uniform float VFAmount;
uniform float rainStrength;
uniform ivec2 eyeBrightnessSmooth;
uniform float frameTimeCounter;
uniform int isEyeInWater;
#include "lib/color_transforms.glsl"
#include "lib/color_dither.glsl"
#include "lib/projections.glsl"
#include "lib/sky_gradient.glsl"
#define fsign(a)(clamp((a)*1e35,0.,1.)*2.-1.)

float interleaved_gradientNoise(){
	return fract(52.9829189*fract(.06711056*gl_FragCoord.x+.00583715*gl_FragCoord.y)+52.9829189*frameTimeCounter);
}
#define SHADOW_MAP_BIAS .8
float calcDistort(vec2 worlpos){
	
	vec2 pos=abs(worlpos*1.165);
	vec2 posSQ=pos*pos;
	
	float distb=pow(posSQ.x*posSQ.x*posSQ.x+posSQ.y*posSQ.y*posSQ.y,1./6.);
	return 1./((1.-SHADOW_MAP_BIAS)+distb*SHADOW_MAP_BIAS);
}

float phaseg(float x,float g){
	float g2=g*g;
	return(g2*-.25+.25)/exp2(log2(-2.*(g*x)+(1.+g2))*1.5);
}
float densityAtPos(in vec3 pos)
{
	
	pos/=18.;
	pos.xz*=.5;
	
	vec3 p=floor(pos);
	vec3 f=fract(pos);
	
	f=(f*f)*(3.-2.*f);
	
	vec2 uv=p.xz+f.xz+p.y*vec2(0.,193.);
	
	vec2 coord=uv/512.;
	
	vec2 xy=texture2D(noisetex,coord).yx;
	
	return mix(xy.r,xy.g,f.y);
}
float cloudVol(in vec3 pos){
	
	vec3 samplePos=pos*vec3(1.,1./16.,1.)+frameTimeCounter*vec3(.5,0.,.5)*5.;
	float coverage=mix(exp2(-(pos.y-SEA_LEVEL)*(pos.y-SEA_LEVEL)/12000.),1.,rainStrength*.3);
	float noise=densityAtPos(samplePos*12.);
	
	float cloud=pow(clamp(coverage-noise-.76,0.,1.),2.)*1200./.23/(coverage+.01)*VFAmount*600+coverage*coverage*80.*fogAmount;
	
	return cloud;
}
vec4 getVolumetricRays(float dither,vec3 fragpos){
	
	//project pixel position into projected shadowmap space
	vec3 wpos=mat3(gbufferModelViewInverse)*fragpos+gbufferModelViewInverse[3].xyz;
	vec3 fragposition=mat3(shadowModelView)*wpos+shadowModelView[3].xyz;
	fragposition=diagonal3(shadowProjection)*fragposition+shadowProjection[3].xyz;
	
	//project view origin into projected shadowmap space
	vec3 start=toShadowSpaceProjected(vec3(0.));
	
	//rayvector into projected shadow map space
	//we can use a projected vector because its orthographic projection
	//however we still have to send it to curved shadow map space every step
	vec3 dV=(fragposition-start)/VL_SAMPLES;
	vec3 dVWorld=(wpos-gbufferModelViewInverse[3].xyz)/VL_SAMPLES;
	float maxLength=min(length(dVWorld),far/5.)/length(dVWorld);
	
	//apply dither
	dV*=maxLength;
	dVWorld*=maxLength;
	vec3 progress=start.xyz+dV*dither;
	vec3 progressW=gbufferModelViewInverse[3].xyz+dVWorld*dither+cameraPosition;
	vec3 vL=vec3(0.);
	
	float SdotV=dot(sunVec,normalize(fragpos))*lightCol.a;
	float dL=length(dVWorld)*.015;
	float mie=max(phaseg(SdotV,.6)*1.5,3.*phaseg(SdotV,.1))*1.5;
	wpos.y=clamp(wpos.y,0.,1.);
	
	vec3 skyCol0=getSkyColor(vec3(0.,1.,0.),mat3(gbufferModelViewInverse)*sunVec,1.)*500.*sqrt(eyeBrightnessSmooth.y/255.)+nsunColor*skyIntensity*smoothstep(.9,1.,1.-sunIntensity)*15.*50.*vec3(.9,.95,1.)*sqrt(eyeBrightnessSmooth.y/255.);
	vec3 sunColor=lightCol.rgb*50.*vec3(.9,.95,1.);
	
	float mu=(1.-isEyeInWater)*.4*ATMOSPHERIC_DENSITY/250.;
	float muS=3.5*mu+isEyeInWater*50.;
	float muE=10.5*mu+isEyeInWater*1000.;
	float absorbance=1.;
	for(int i=0;i<VL_SAMPLES;i++){
		//project into biased shadowmap space
		float distortFactor=calcDistort(progress.xy);
		vec3 pos=vec3(progress.xy*distortFactor/.92,progress.z);
		float densityVol=cloudVol(progressW);
		float sh=1.;
		if(abs(pos.x)<1.-.5/2048.&&abs(pos.y)<1.-.5/2048){
			pos=pos*vec3(.5,.5,.5/3.)+.5;
			sh=shadow2D(shadow,pos).x;
		}
		float density=mix(densityVol,.01,isEyeInWater);
		vec3 vL0=(sunColor*sh+skyCol0)*muS*density*mix(vec3(1.),vec3(.32,.6,1.)*.1,isEyeInWater);
		vL+=(vL0-vL0*exp(-muE*density*dL))/(muE*density+.000001)*absorbance;
		absorbance*=exp2(-muE*density*dL);
		
		//advance the ray
		progress+=dV;
		progressW+=dVWorld;
	}
	
	return vec4(vL,absorbance*50000.);
	
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main(){
	/* DRAWBUFFERS:0 */
	float z=texture2D(depthtex0,texcoord).x;
	vec3 fragpos=toScreenSpace(vec3(texcoord,z));
	float noise=interleaved_gradientNoise();
	float fogFactorAbs=exp(-length(fragpos)*fogAmount*.3);
	vec4 vl=getVolumetricRays(noise,fragpos);
	
	gl_FragData[0]=clamp(vl,0.,65000.);
	
}