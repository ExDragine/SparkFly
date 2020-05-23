#version 120
//Render sky, volumetric clouds, direct lighting
#extension GL_EXT_gpu_shader4:enable
//#define SCREENSPACE_CONTACT_SHADOWS	//Raymarch towards the sun in screen-space, in order to cast shadows outside of the shadow map or at the contact of objects. Can get really expensive at high resolutions.
#define SHADOW_FILTER_SAMPLE_COUNT 15// Number of samples used to filter the actual shadows [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107 108 109 110 111 112 113 114 115 116 117 118 119 120 ]
#define CAVE_LIGHT_LEAK_FIX// Hackish way to remove sunlight incorrectly leaking into the caves. Can inacurrately remove shadows in some places
//#define CLOUDS_SHADOWS
#define CLOUDS_SHADOWS_STRENGTH.5//[0.1 0.125 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.9 1.0]
#define CLOUDS_QUALITY.35//[0.1 0.125 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.9 1.0]

#define TORCH_R 1.0// [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define TORCH_G.4// [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define TORCH_B.12// [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
const bool shadowHardwareFiltering=true;

varying vec2 texcoord;

flat varying vec4 lightCol;//main light source color (rgb),used light source(1=sun,-1=moon)
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
flat varying vec3 WsunVec;
flat varying vec2 TAA_Offset;
flat varying float tempOffsets;

uniform sampler2D colortex0;//clouds
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
uniform sampler2D colortex4;//Skybox
uniform sampler2D colortex3;
uniform sampler2D colortex7;
uniform sampler2D colortex6;//Skybox
uniform sampler2D depthtex1;//depth
uniform sampler2D depthtex0;//depth
uniform sampler2D noisetex;//depth
uniform sampler2DShadow shadow;

uniform int heldBlockLightValue;
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;
uniform int worldDay;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;
uniform float far;
uniform float near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelView;

uniform vec2 texelSize;
uniform vec3 sunPosition;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform vec3 cameraPosition;
uniform int framemod8;
uniform vec3 sunVec;
uniform ivec2 eyeBrightnessSmooth;
#define diagonal3(m)vec3((m)[0].x,(m)[1].y,m[2].z)
#define projMAD(m,v)(diagonal3(m)*(v)+(m)[3].xyz)
vec3 toScreenSpace(vec3 p){
	vec4 iProjDiag=vec4(gbufferProjectionInverse[0].x,gbufferProjectionInverse[1].y,gbufferProjectionInverse[2].zw);
	vec3 p3=p*2.-1.;
	vec4 fragposition=iProjDiag*p3.xyzz+gbufferProjectionInverse[3];
	return fragposition.xyz/fragposition.w;
}
#include "lib/waterOptions.glsl"
#include "lib/Shadow_Params.glsl"
#include "lib/color_transforms.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/stars.glsl"
#include "lib/volumetricClouds.glsl"
#include "lib/waterBump.glsl"
#include "lib/aurora.glsl"
#include "lib/rainbow.glsl"
#include "lib/milkway.glsl"
#include "lib/galaxy.glsl"

vec3 normVec(vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}
float lengthVec(vec3 vec){
	return sqrt(dot(vec,vec));
}
#define fsign(a)(clamp((a)*1e35,0.,1.)*2.-1.)
float triangularize(float dither)
{
	float center=dither*2.-1.;
	dither=center*inversesqrt(abs(center));
	return clamp(dither-fsign(center),0.,1.);
}
float interleaved_gradientNoise(float temp){
	return fract(52.9829189*fract(.06711056*gl_FragCoord.x+.00583715*gl_FragCoord.y)+temp);
}
vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits=vec3(6.,6.,5.);
	vec3 exponent=floor(log2(color));
	return color+dither*exp2(-mantissaBits)*exp2(exponent);
}

float facos(float sx){
	float x=clamp(abs(sx),0.,1.);
	return sqrt(1.-x)*(-.16882*x+1.56734);
}
vec3 decode(vec2 enc)
{
	vec2 fenc=enc*4-2;
	float f=dot(fenc,fenc);
	float g=sqrt(1-f/4.);
	vec3 n;
	n.xy=fenc*g;
	n.z=1-f/2;
	return n;
}

vec2 decodeVec2(float a){
	const vec2 constant1=65535./vec2(256.,65536.);
	const float constant2=256./255.;
	return fract(a*constant1)*constant2;
}
float linZ(float depth){
	return(2.*near)/(far+near-depth*(far-near));
	// l = (2*n)/(f+n-d(f-n))
	// f+n-d(f-n) = 2n/l
	// -d(f-n) = ((2n/l)-f-n)
	// d = -((2n/l)-f-n)/(f-n)
	
}
float invLinZ(float lindepth){
	return-((2.*near/lindepth)-far-near)/(far-near);
}

vec3 toClipSpace3(vec3 viewSpacePosition){
	return projMAD(gbufferProjection,viewSpacePosition)/-viewSpacePosition.z*.5+.5;
}
float bayer2(vec2 a){
	a=floor(a);
	return fract(dot(a,vec2(.5,a.y*.75)));
}

#define bayer4(a)(bayer2(.5*(a))*.25+bayer2(a))
#define bayer8(a)(bayer4(.5*(a))*.25+bayer2(a))
#define bayer16(a)(bayer8(.5*(a))*.25+bayer2(a))
#define bayer32(a)(bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)(bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a)fract(bayer64(.5*(a))*.25+bayer2(a)+tempOffsets)
float rayTraceShadow(vec3 dir,vec3 position,float dither,float translucent){
	
	const float quality=16.;
	vec3 clipPosition=toClipSpace3(position);
	//prevents the ray from going behind the camera
	float rayLength=((position.z+dir.z*far*sqrt(3.))>-near)?
	(-near-position.z)/dir.z:far*sqrt(3.);
	vec3 direction=toClipSpace3(position+dir*rayLength)-clipPosition;//convert to clip space
	direction.xyz=direction.xyz/max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y);//fixed step size
	
	vec3 stepv=direction*3.*clamp(MC_RENDER_QUALITY,1.,2.);
	
	vec3 spos=clipPosition+vec3(TAA_Offset*vec2(texelSize.x,texelSize.y)*.5,0.)+stepv*dither;
	
	for(int i=0;i<int(quality);i++){
		spos+=stepv;
		
		float sp=texture2D(depthtex1,spos.xy).x;
		if(sp<spos.z){
			
			float dist=abs(linZ(sp)-linZ(spos.z))/linZ(spos.z);
			
			if(dist<.01)return translucent*exp2(position.z/8.);
			
		}
		
	}
	return 1.;
}

float ld(float dist){
	return(2.*near)/(far+near-dist*(far-near));
}

vec2 tapLocation(int sampleNumber,int nb,float nbRot,float jitter,float distort)
{
	float alpha0=sampleNumber/nb;
	float alpha=(sampleNumber+jitter)/nb;
	float angle=jitter*6.28+alpha*4.*6.28;
	
	float sin_v,cos_v;
	
	sin_v=sin(angle);
	cos_v=cos(angle);
	
	return vec2(cos_v,sin_v)*sqrt(alpha);
}

vec3 BilateralFiltering(sampler2D tex,sampler2D depth,vec2 coord,float frDepth,float maxZ){
	vec4 sampled=vec4(texelFetch2D(tex,ivec2(coord),0).rgb,1.);
	
	return vec3(sampled.x,sampled.yz/sampled.w);
}
float blueNoise(){
	return fract(texelFetch2D(noisetex,ivec2(gl_FragCoord.xy)%512,0).a+1./1.6180339887*frameCounter);
}
float R2_dither(){
	vec2 alpha=vec2(.75487765,.56984026);
	return fract(alpha.x*gl_FragCoord.x+alpha.y*gl_FragCoord.y);
}
vec3 toShadowSpaceProjected(vec3 p3){
	p3=mat3(gbufferModelViewInverse)*p3+gbufferModelViewInverse[3].xyz;
	p3=mat3(shadowModelView)*p3+shadowModelView[3].xyz;
	p3=diagonal3(shadowProjection)*p3+shadowProjection[3].xyz;
	
	return p3;
}
void waterVolumetrics(inout vec3 inColor,vec3 rayStart,vec3 rayEnd,float estEndDepth,float estSunDepth,float rayLength,float dither,vec3 waterCoefs,vec3 scatterCoef,vec3 ambient,vec3 lightSource,float VdotL){
	inColor*=exp(-rayLength*waterCoefs);//No need to take the integrated value
	int spCount=rayMarchSampleCount;
	vec3 start=toShadowSpaceProjected(rayStart);
	vec3 end=toShadowSpaceProjected(rayEnd);
	vec3 dV=(end-start);
	//limit ray length at 32 blocks for performance and reducing integration error
	//you can't see above this anyway
	float maxZ=min(rayLength,32.)/(1e-8+rayLength);
	dV*=maxZ;
	rayLength*=maxZ;
	estEndDepth*=maxZ;
	estSunDepth*=maxZ;
	vec3 absorbance=vec3(1.);
	vec3 vL=vec3(0.);
	float phase=phaseg(VdotL,Dirt_Mie_Phase);
	float expFactor=11.;
	for(int i=0;i<spCount;i++){
		float d=(pow(expFactor,float(i+dither)/float(spCount))/expFactor-1./expFactor)/(1-1./expFactor);
		float dd=pow(expFactor,float(i+dither)/float(spCount))*log(expFactor)/float(spCount)/(expFactor-1.);
		vec3 spPos=start.xyz+dV*d;
		//project into biased shadowmap space
		float distortFactor=calcDistort(spPos.xy);
		vec3 pos=vec3(spPos.xy*distortFactor,spPos.z);
		float sh=1.;
		if(abs(pos.x)<1.-.5/2048.&&abs(pos.y)<1.-.5/2048){
			pos=pos*vec3(.5,.5,.5/6.)+.5;
			sh=shadow2D(shadow,pos).x;
		}
		vec3 ambientMul=exp(-estEndDepth*d*waterCoefs*1.1);
		vec3 sunMul=exp(-estSunDepth*d*waterCoefs);
		vec3 light=(sh*lightSource*8./150./3.*phase*sunMul+ambientMul*ambient)*scatterCoef;
		vL+=(light-light*exp(-waterCoefs*dd*rayLength))/waterCoefs*absorbance;
		absorbance*=exp(-dd*rayLength*waterCoefs);
	}
	inColor+=vL;
}

float waterCaustics(vec3 wPos){
	vec2 pos=(wPos.xz+wPos.y)*4.;
	vec2 movement=vec2(-.02*frameTimeCounter);
	float caustic=0.;
	float weightSum=0.;
	float radiance=2.39996;
	mat2 rotationMatrix=mat2(vec2(cos(radiance),-sin(radiance)),vec2(sin(radiance),cos(radiance)));
	for(int i=0;i<5;i++){
		vec2 displ=texture2D(noisetex,pos/32.+movement).bb*2.-1.;
		pos=rotationMatrix*pos;
		caustic+=pow(.5+sin(dot((pos+vec2(1.74*frameTimeCounter))*exp2(.8*i)+displ*3.,vec2(.5)))*.5,6.)*exp2(-.8*i)/1.41;
		weightSum+=exp2(-.8*i);
	}
	return caustic*weightSum;
}
void main(){
	float dirtAmount=Dirt_Amount;
	vec3 waterEpsilon=vec3(Water_Absorb_R,Water_Absorb_G,Water_Absorb_B);
	vec3 dirtEpsilon=vec3(Dirt_Absorb_R,Dirt_Absorb_G,Dirt_Absorb_B);
	vec3 totEpsilon=dirtEpsilon*dirtAmount+waterEpsilon;
	vec3 scatterCoef=dirtAmount*vec3(Dirt_Scatter_R,Dirt_Scatter_G,Dirt_Scatter_B)/pi;
	float z0=texture2D(depthtex0,texcoord).x;
	float z=texture2D(depthtex1,texcoord).x;
	vec2 tempOffset=TAA_Offset;
	float noise=blueNoise();
	
	vec3 fragpos=toScreenSpace(vec3(texcoord-vec2(tempOffset)*texelSize*.5,z));
	vec3 p3=mat3(gbufferModelViewInverse)*fragpos;
	vec3 np3=normVec(p3);
	
	//sky
	if(z>=1.){
		vec3 color=vec3(0.);
		vec4 cloud=texture2D_bicubic(colortex0,texcoord*CLOUDS_QUALITY);
		if(np3.y>0.){
			color+=stars(np3);
			color+=drawSun(dot(lightCol.a*WsunVec,np3),0,lightCol.rgb/150.,vec3(0.));
		}
		color+=skyFromTex(np3,colortex4)/150.+toLinear(texture2D(colortex1,texcoord).rgb)/10.*3.*ffstep(.985,-dot(lightCol.a*WsunVec,np3));
		color=color*cloud.a+cloud.rgb;
		vec4 aurora_col=aurora(vec3(0,0,-6.7),np3);
		vec4 galaxy_col=galaxy(np3);
		color=color+galaxy_col.rgb;
		color=color+stars01(np3);
		//vec4 milkway_color=mainImage(np3);
		//color=color+milkway_color.rgb;
		color=color+rainbow(np3);
		color=color*(1.-aurora_col.a)+aurora_col.rgb;
		color=color*cloud.a+cloud.rgb;
		gl_FragData[0].rgb=clamp(fp10Dither(color*8./3.*(1.-rainStrength*.4),triangularize(noise)),0.,65000.);
		//if (gl_FragData[0].r > 65000.) 	gl_FragData[0].rgb = vec3(0.0);
		vec4 trpData=texture2D(colortex7,texcoord);
		bool iswater=texture2D(colortex7,texcoord).a>.99;
		if(iswater){
			vec3 fragpos0=toScreenSpace(vec3(texcoord-vec2(tempOffset)*texelSize*.5,z0));
			float Vdiff=distance(fragpos,fragpos0);
			float VdotU=np3.y;
			float estimatedDepth=Vdiff*abs(VdotU);//assuming water plane
			float estimatedSunDepth=estimatedDepth/abs(WsunVec.y);//assuming water plane
			
			vec3 lightColVol=lightCol.rgb*(.91-pow(1.-WsunVec.y,5.)*.86);//fresnel
			vec3 ambientColVol=ambientUp*8./150./3.*.84*2./pi*eyeBrightnessSmooth.y/240.;
			if(isEyeInWater==0)
			waterVolumetrics(gl_FragData[0].rgb,fragpos0,fragpos,estimatedDepth,estimatedSunDepth,Vdiff,noise,totEpsilon,scatterCoef,ambientColVol,lightColVol,dot(np3,WsunVec));
		}
	}
	//land
	else{
		p3+=gbufferModelViewInverse[3].xyz;
		
		vec4 trpData=texture2D(colortex7,texcoord);
		bool iswater=texture2D(colortex7,texcoord).a>.99;
		
		vec4 data=texture2D(colortex1,texcoord);
		vec4 dataUnpacked0=vec4(decodeVec2(data.x),decodeVec2(data.y));
		vec4 dataUnpacked1=vec4(decodeVec2(data.z),decodeVec2(data.w));
		
		vec3 albedo=toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));
		vec3 normal=mat3(gbufferModelViewInverse)*decode(dataUnpacked0.yw);
		
		vec2 lightmap=dataUnpacked1.yz;
		bool translucent=abs(dataUnpacked1.w-.5)<.01;
		bool hand=abs(dataUnpacked1.w-.75)<.01;
		bool emissive=abs(dataUnpacked1.w-.9)<.01;
		float NdotL=dot(normal,WsunVec);
		
		float diffuseSun=clamp(NdotL,0.,1.);
		float shading=1.;
		
		//custom shading model for translucent objects
		if(translucent){
			albedo*=1.1;
			diffuseSun=mix(max(phaseg(dot(np3,WsunVec),.45)*1.52,3.*phaseg(dot(np3,WsunVec),.1))*3.1415,diffuseSun,.35);
		}
		vec3 filtered=vec3(1.412,1.,0.);
		if(!hand){
			filtered=texture2D(colortex3,texcoord).rgb;
		}
		//compute shadows only if not backfacing the sun
		if(diffuseSun>.001){
			
			vec3 projectedShadowPosition=mat3(shadowModelView)*p3+shadowModelView[3].xyz;
			projectedShadowPosition=diagonal3(shadowProjection)*projectedShadowPosition+shadowProjection[3].xyz;
			
			//apply distortion
			float distortFactor=calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy*=distortFactor;
			//do shadows only if on shadow map
			if(abs(projectedShadowPosition.x)<1.-1.5/shadowMapResolution&&abs(projectedShadowPosition.y)<1.-1.5/shadowMapResolution&&abs(projectedShadowPosition.z)<6.){
				float rdMul=filtered.x*distortFactor*d0*k/shadowMapResolution;
				const float threshMul=max(2048./shadowMapResolution*shadowDistance/128.,.95);
				float distortThresh=(sqrt(1.-diffuseSun*diffuseSun)/diffuseSun+.7)/distortFactor;
				float diffthresh=translucent?.00014:distortThresh/6000.*threshMul;
				projectedShadowPosition=projectedShadowPosition*vec3(.5,.5,.5/6.)+vec3(.5,.5,.5);
				shading=0.;
				for(int i=0;i<SHADOW_FILTER_SAMPLE_COUNT;i++){
					vec2 offsetS=tapLocation(i,SHADOW_FILTER_SAMPLE_COUNT,0.,noise,0.);
					
					float weight=1.+(i+noise)*rdMul/SHADOW_FILTER_SAMPLE_COUNT*shadowMapResolution;
					shading+=shadow2D(shadow,vec3(projectedShadowPosition+vec3(rdMul*offsetS,-diffthresh*weight))).x/SHADOW_FILTER_SAMPLE_COUNT;
				}
			}
			if(shading>.005){
				#ifdef SCREENSPACE_CONTACT_SHADOWS
				vec3 vec=lightCol.a*sunVec;
				shading*=rayTraceShadow(vec,fragpos,noise,float(translucent));
				#endif
				#ifdef CLOUDS_SHADOWS
				vec3 pos=p3+cameraPosition+gbufferModelViewInverse[3].xyz;
				vec3 cloudPos=pos+WsunVec/abs(WsunVec.y)*(2500.-cameraPosition.y);
				shading*=mix(1.,exp(-20.*cloudVolLQ(cloudPos)),mix(CLOUDS_SHADOWS_STRENGTH,1.,rainStrength));
				#endif
			}
			#ifdef CAVE_LIGHT_LEAK_FIX
			shading=mix(0.,shading,clamp(eyeBrightnessSmooth.y/255.+lightmap.y,0.,1.));
			#endif
		}
		
		vec3 ambientCoefs=normal/dot(abs(normal),vec3(1.));
		
		vec3 ambientLight=ambientUp*clamp(ambientCoefs.y,0.,1.);
		ambientLight+=ambientDown*clamp(-ambientCoefs.y,0.,1.);
		ambientLight+=ambientRight*clamp(ambientCoefs.x,0.,1.);
		ambientLight+=ambientLeft*clamp(-ambientCoefs.x,0.,1.);
		ambientLight+=ambientB*clamp(ambientCoefs.z,0.,1.);
		ambientLight+=ambientF*clamp(-ambientCoefs.z,0.,1.);
		ambientLight*=(1.+rainStrength*.2);
		vec3 directLightCol=lightCol.rgb;
		vec3 custom_lightmap=texture2D(colortex4,(lightmap*15.+.5+vec2(0.,19.))*texelSize).rgb*8./150./3.;
		if(emissive||(hand&&heldBlockLightValue>.1))
		custom_lightmap.y=pow(clamp(albedo.r-.35,0.,1.)/.65*.65+.35,2.)*1.4;
		if((iswater&&isEyeInWater==0)||(!iswater&&isEyeInWater==1)){
			
			vec3 fragpos0=toScreenSpace(vec3(texcoord-vec2(tempOffset)*texelSize*.5,z0));
			float Vdiff=distance(fragpos,fragpos0);
			float VdotU=np3.y;
			float estimatedDepth=Vdiff*abs(VdotU);//assuming water plane
			if(isEyeInWater==1){
				Vdiff=length(fragpos);
				estimatedDepth=clamp((15.5-lightmap.y*16.)/15.5,0.,1.);
				estimatedDepth*=estimatedDepth*estimatedDepth*32.;
				#ifndef lightMapDepthEstimation
				estimatedDepth=max(Water_Top_Layer-(cameraPosition.y+p3.y),0.);
				#endif
			}
			
			float estimatedSunDepth=estimatedDepth/abs(WsunVec.y);//assuming water plane
			directLightCol*=exp(-totEpsilon*estimatedSunDepth)*(.91-pow(1.-WsunVec.y,5.)*.86);
			float caustics=waterCaustics(mat3(gbufferModelViewInverse)*fragpos+gbufferModelViewInverse[3].xyz+cameraPosition);
			directLightCol*=mix(caustics,1.,exp(-.3*estimatedSunDepth)*.5+.5);
			
			ambientLight*=exp(-totEpsilon*estimatedDepth*1.1)*.8*8./150./3.;
			if(isEyeInWater==0){
				ambientLight*=custom_lightmap.x/(8./150./3.);
				ambientLight+=custom_lightmap.z;
			}
			else
			ambientLight+=custom_lightmap.z*70.*exp(-totEpsilon*16.);
			
			ambientLight*=mix(caustics,1.,.87);
			ambientLight+=custom_lightmap.y*vec3(TORCH_R,TORCH_G,TORCH_B);
			
			//combine all light sources
			gl_FragData[0].rgb=((shading*diffuseSun)/pi*8./150./3.*directLightCol.rgb+filtered.y*ambientLight)*albedo;
			//Bruteforce integration is probably overkill
			vec3 lightColVol=lightCol.rgb*(.91-pow(1.-WsunVec.y,5.)*.86);//fresnel
			vec3 ambientColVol=ambientUp*8./150./3.*.84*2./pi/240.*eyeBrightnessSmooth.y;
			if(isEyeInWater==0)
			waterVolumetrics(gl_FragData[0].rgb,fragpos0,fragpos,estimatedDepth,estimatedSunDepth,Vdiff,noise,totEpsilon,scatterCoef,ambientColVol,lightColVol,dot(np3,WsunVec));
			//gl_FragData[0].rgb *= exp(-Vdiff * totEpsilon);
			//	gl_FragData[0].rgb += (ambientUp*8./150./3. + custom_lightmap.z + lightCol.rgb*0.5) * ;
			//	gl_FragData[0].rgb = vec3(caustics);
		}
		else{
			ambientLight=ambientLight*custom_lightmap.x+custom_lightmap.y*vec3(TORCH_R,TORCH_G,TORCH_B)+custom_lightmap.z;
			
			//combine all light sources
			gl_FragData[0].rgb=((shading*diffuseSun)/pi*8./150./3.*directLightCol.rgb+filtered.y*ambientLight)*albedo;
			//	gl_FragData[0].rgb = filtered.yyy;
			//waterVolumetrics(gl_FragData[0].rgb, vec3(0.0), fragpos, 0.0, 0.0, length(fragpos), noise, waterEpsilon, ambientUp*8./150./3. + custom_lightmap.z, lightCol.rgb);
		}
	}
	
	/* DRAWBUFFERS:3 */
}
