#version 120
#extension GL_EXT_gpu_shader4:enable
varying vec2 texcoord;
varying vec3 ambientUp;
varying vec3 ambientLeft;
varying vec3 ambientRight;
varying vec3 ambientB;
varying vec3 ambientF;
varying vec3 ambientDown;
varying vec4 lightCol;

uniform float sunIntensity;
uniform vec3 sunPosition;
uniform float skyIntensity;
uniform float skyIntensityNight;
uniform float rainStrength;
uniform vec3 sunColor;
uniform vec3 nsunColor;
uniform mat4 gbufferModelViewInverse;

vec3 sunVec=normalize(mat3(gbufferModelViewInverse)*sunPosition);

#include "lib/sky_gradient.glsl"

vec3 coneSample(vec2 Xi)
{
	float r=sqrt(1.f-Xi.x*Xi.y);
	float phi=2*3.14159265359*Xi.y;
	
	return normalize(vec3(cos(phi)*r,sin(phi)*r,Xi.x)).xzy;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main(){
	
	gl_Position=ftransform();
	texcoord=gl_MultiTexCoord0.xy;
	
	ambientUp=vec3(0.);
	ambientLeft=vec3(0.);
	ambientRight=vec3(0.);
	ambientB=vec3(0.);
	ambientF=vec3(0.);
	ambientDown=vec3(0.);
	
	//integrate sky light (100samples is enough)
	for(int i=0;i<10;i++){
		for(int j=0;j<10;j++){
			vec2 ij=vec2(i,j)/10.*.9+.05;
			vec3 pos=coneSample(ij);
			
			vec3 samplee=getSkyColor(pos.xyz,sunVec,pos.y)/100.*vec3(1.,1.,1.);
			
			ambientUp+=samplee*(pos.y+abs(pos.x)/6.+abs(pos.z)/6.);
			ambientLeft+=samplee*(clamp(-pos.x,0.,1.)+clamp(pos.y/3.,0.,1.)+abs(pos.z)/6.);
			ambientRight+=samplee*(clamp(pos.x,0.,1.)+clamp(pos.y/3.,0.,1.)+abs(pos.z)/6.);
			ambientB+=samplee*(clamp(pos.z,0.,1.)+abs(pos.x)/6.+clamp(pos.y/3.,0.,1.));
			ambientF+=samplee*(clamp(-pos.z,0.,1.)+abs(pos.x)/6.+clamp(pos.y/3.,0.,1.));
			ambientDown+=samplee*(clamp(pos.y/3.,0.,1.)+abs(pos.x)/6.+abs(pos.z)/6.);
		}
	}
	
	//fake bounced sunlight
	vec3 bouncedSun=sunIntensity*sunColor*pow(clamp(sunVec.y*1.4,0.,1.),4.)/18./2.2;
	
	ambientUp+=bouncedSun*clamp(-sunVec.y+2.,0.,3.);
	ambientLeft+=bouncedSun*clamp(sunVec.x+2.,0.,3.);
	ambientRight+=bouncedSun*clamp(-sunVec.x+2.,0.,3.);
	ambientB+=bouncedSun*clamp(-sunVec.z+2.,0.,3.);
	ambientF+=bouncedSun*clamp(sunVec.z+2.,0.,3.);
	ambientDown+=bouncedSun*clamp(sunVec.y+2.,0.,3.);
	
	//fake bounced moonlight
	bouncedSun=(1.-sunIntensity)*vec3(.07,.12,.18)/7.5*pow(clamp(-sunVec.y*1.4,0.,1.),4.)/18./2.*10.*(1.-rainStrength*.5);
	
	ambientUp+=bouncedSun*clamp(sunVec.y+2.,0.,3.);
	ambientLeft+=bouncedSun*clamp(-sunVec.x+2.,0.,3.);
	ambientRight+=bouncedSun*clamp(sunVec.x+2.,0.,3.);
	ambientB+=bouncedSun*clamp(sunVec.z+2.,0.,3.);
	ambientF+=bouncedSun*clamp(-sunVec.z+2.,0.,3.);
	ambientDown+=bouncedSun*clamp(-sunVec.y+2.,0.,3.);
	
	lightCol.a=float(sunIntensity>0.)*2.-1.;
	lightCol.rgb=sunIntensity<=0.?(1.-sunIntensity)*vec3(.07,.12,.18)/7.5*(1.-rainStrength*.5):sunIntensity*sunColor*(1.-rainStrength*.8);
	
}