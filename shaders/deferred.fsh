#version 120
//Quarter Res volumetric clouds
#extension GL_EXT_gpu_shader4 : enable


varying vec2 texcoord;

uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform vec3 sunVec;
uniform vec3 nsunColor;
uniform float sunIntensity;
uniform float skyIntensity;
uniform float skyIntensityNight;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float far;
uniform float near;
uniform float rainStrength;
uniform vec2 texelSize;
uniform int frameCounter;
uniform int framemod8;
varying vec4 lightCol;
#include "lib/projections.glsl"
#include "lib/sky_gradient.glsl"
float cloud_height = 1500.;
float maxHeight = 4000.;
const int maxIT_clouds = 75; 
float center = cloud_height*0.5+maxHeight*0.5;
float difcenter = maxHeight-center;

vec4 smoothfilter(in sampler2D tex, in vec2 uv)
{
	const float textureResolution = 32.;
	uv = uv*textureResolution + 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );
	uv = iuv + (fuv*fuv)*(3.0-2.0*fuv); 
	uv = uv/textureResolution - 0.5/textureResolution;
	return texture2D( tex, uv);
}

//3D noise from 2d texture
float densityAtPos(in vec3 pos)
{

	pos /= 18.;
	pos.xz *= 0.5;
	

	vec3 p = floor(pos);
	vec3 f = fract(pos);
	
	f = (f*f) * (3.-2.*f);

	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);

	vec2 coord =  uv / 512.0;
	//The y channel has an offset to avoid using two textures fetches 
	vec2 xy = texture2D(noisetex, coord).yx;

	return mix(xy.r,xy.g, f.y);
}

//High altitude cloud layer
float cloudVolST(in vec3 pos){
	float mult = clamp(1.0-abs(pos.y-5500)/100.,0.0,1.0);

	
	vec3 samplePos = pos*vec3(1.0,1./32.,1.0)/4+frameTimeCounter*vec3(0.6,0.,0.4)*150;
	float coverage = 1.0-clamp(1.0-0.6*abs(sin(dot(samplePos.xz,vec2(0.05,0.6)/1000.)))+0.4*rainStrength+0.15,0.0,1.0);
	float noise = densityAtPos(samplePos);
	noise += densityAtPos(samplePos*2)*0.5;
	noise += densityAtPos(samplePos*4.)*0.25;
	noise += densityAtPos(samplePos*8.)*0.125;
	
	float cloud = pow(clamp(noise/1.875-coverage*0.6-0.12,0.0,1.0),3.)*3.*mult;
	
return cloud;
}
//Cloud without 3D noise, is used to exit early lighting calculations if there is no cloud
float cloudCov(in vec3 pos,vec3 samplePos){
	float mult = abs(pos.y-center)/difcenter;

	float coverage = clamp(texture2D(noisetex,samplePos.xz/20000.).b*1.-0.5+0.25*rainStrength,0.0,1.0);



	float cloud = coverage-pow(mult,5.0)*0.4;
	
	
return cloud;
}
//Erode cloud with 3d Perlin-worley noise, actual cloud value
float cloudVol(in vec3 pos,in vec3 samplePos,in float cov){
	//Less erosion on bottom of the cloud
	float mult2 = (pos.y-1500)/2500+rainStrength*0.5;
	float noise = 1.0-densityAtPos(samplePos*10.);
	noise += 0.5-densityAtPos(samplePos*31.)*0.3;	

	float cloud = pow(clamp(cov-noise*0.1*(0.6+mult2*3.),0.0,1.0),2.2)*1.6;
	
return cloud;
}
//Low quality cloud, noise is replaced by the average noise value, used for shadowing 
float cloudVolLQ(in vec3 pos){
	float mult = abs(pos.y-center)/difcenter;
	float mult2 = (pos.y-1500)/2500+rainStrength*0.5;
	
	vec3 samplePos = pos*vec3(1.0,1./32.,1.0)/4+frameTimeCounter*vec3(0.5,0.,0.5)*50.;
	float coverage = clamp(texture2D(noisetex,samplePos.xz/20000.).b*1.-0.5+0.25*rainStrength,0.0,1.0);




	float cloud = pow(clamp(coverage-0.12*(0.6+mult2*3.)-pow(mult,5.0)*0.4,0.0,1.0),2.2)*1.6;
	
	
return cloud;
}

float bayer2(vec2 a){
	a = floor(a);
    return fract(dot(a,vec2(0.5,a.y*0.75)));
}
#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  fract(bayer8( .5*(a))*.25+bayer2(a)+frameTimeCounter*51.9652)
//Mie phase function
float phaseg(float x, float g){
    float g2 = g * g;
    return ( g2 * -.25 + .25) / exp2( log2(-2. * (g * x) + (1. + g2)) * 1.5 );
}
vec4 renderClouds(vec3 fragpositi, vec3 color,float dither) {
	
		
		//setup ray in projected shadow map space
		bool land = false;

		float SdotU = dot(normalize(fragpositi.xyz),sunVec);
		float z2 = length(fragpositi);
		float z = -fragpositi.z;
		
		
		//project pixel position into projected shadowmap space
		vec4 fragposition = gbufferModelViewInverse*vec4(fragpositi,1.0);
		
		vec3 worldV = normalize(fragposition.rgb);
		//worldV.y -= -length(worldV.xz)/sqrt(-length(worldV.xz/earthRad)*length(worldV.xz/earthRad)+earthRad);
		
		//project view origin into projected shadowmap space
		vec4 start = (gbufferModelViewInverse*vec4(0.0,0.0,0.,1.));
		vec3 dV_view = worldV;

		
		vec3 progress_view = dV_view*dither+cameraPosition;
		
		float vL = 0.0;
		float total_extinction = 1.0;

	float mult = 500.0;
	float startY = 0.0;
	
	float distW = length(worldV);
	worldV = normalize(worldV)*30000. + cameraPosition; //makes max cloud distance not dependant of render distance
	dV_view = normalize(dV_view);
	
	//3 ray setup cases : below cloud plane, in cloud plane and above cloud plane
	if (cameraPosition.y <= cloud_height){
		startY = cloud_height;	
		float maxHeight2 = min(cloud_height,worldV.y);	//stop ray when intersecting before cloud plane end
		
		//setup ray to start at the start of the cloud plane and end at the end of the cloud plane
		dV_view *= (maxHeight-maxHeight2)/dV_view.y/maxIT_clouds;
		vec3 startOffset = dV_view*dither;

		progress_view = startOffset + cameraPosition + dV_view*(maxHeight2-cameraPosition.y)/(dV_view.y);
	

		if (worldV.y < cloud_height) return vec4(0.,0.,0.,1.);	//don't trace if no intersection is possible
	}
	
	if (cameraPosition.y > cloud_height && cameraPosition.y < maxHeight){
		if (dV_view.y <= 0.0) {
		startY = cameraPosition.y;			
		float maxHeight2 = max(cloud_height,worldV.y);	//stop ray when intersecting before cloud plane end
		
		//setup ray to start at eye position and end at the end of the cloud plane
		dV_view *= abs(maxHeight2-startY)/abs(dV_view.y)/maxIT_clouds;

		progress_view = dV_view*dither + cameraPosition;

		}
		else
		if (dV_view.y > 0.0) {		
		startY = cameraPosition.y;			
		float maxHeight2 = min(maxHeight,worldV.y);	//stop ray when intersecting before cloud plane end
		
		//setup ray to start at eye position and end at the end of the cloud plane
		dV_view *= abs(maxHeight2-startY)/abs(dV_view.y)/maxIT_clouds;

		progress_view = dV_view*dither + cameraPosition;

		}

		
	}
	
	if (cameraPosition.y >= maxHeight){
		startY = maxHeight;			
		float maxHeight2 = max(maxHeight,worldV.y);	//stop ray when intersecting before cloud plane end

		//setup ray to start at eye position and end at the end of the cloud plane
		dV_view *= -abs(maxHeight2-startY)/abs(dV_view.y)/maxIT_clouds;
		progress_view = dV_view*dither + cameraPosition + dV_view*(maxHeight2-cameraPosition.y)/dV_view.y;
		mult = length(dV_view)/50.;
		if (worldV.y > maxHeight) return vec4(0.,0.,0.,1.);	//don't trace if intersection is impossible
	}


	vec3 dV_Sun = mat3(gbufferModelViewInverse)*sunVec*240.;
	
	mult = length(dV_view);
	
	float cdensity = 4.0;
	color = vec3(0.0);
	
	total_extinction = 1.0;
	float SdotV = dot(sunVec,normalize(fragpositi));	
	float mieDay = max(phaseg(SdotV,0.7)*1.5,3.*phaseg(SdotV,0.1))*1.5;
	float mieNight = max(phaseg(-SdotV,0.7)*1.5,3.*phaseg(-SdotV,0.1))*1.5;

	vec3 sunContribution = mieDay*nsunColor*skyIntensity*(1.0-rainStrength*0.9)*50.;
	vec3 moonContribution = mieNight*vec3(0.07,0.12,0.18)/15.*(1.0-rainStrength*0.9)*skyIntensityNight*10.;
	vec3 skyCol0 = (skyIntensity*lightCol.rgb*0.15+getSkyColor(vec3(0.,1.,0.0),mat3(gbufferModelViewInverse)*sunVec,1.));

	
	for (int i=0;i<maxIT_clouds;i++) {
	vec3 samplePos = progress_view*vec3(1.0,1./32.,1.0)/4+frameTimeCounter*vec3(0.5,0.,0.5)*50.;
		float coverageSP = cloudCov(progress_view,samplePos);
		if (coverageSP>0.00){
			float cloud = cloudVol(progress_view,samplePos,coverageSP);
			if (cloud > 0.0005){
			float muS = mix(0.0000000001,0.04,cloud)*cdensity;
			float muE = mix(0.0000000001,0.04,cloud)*cdensity;



			float muEshD = 0.0;
			for (int j=1;j<6;j++){ 
				float cloudS=cloudVolLQ(vec3(progress_view+dV_Sun*j));
				muEshD += mix(0.0000000001,0.04,cloudS)*cdensity;
				
				}	
			float muEshN = 0.0;
			for (int j=1;j<6;j++){ 
				float cloudS=cloudVolLQ(vec3(progress_view-dV_Sun*j));
				muEshN += mix(0.0000000001,0.04,cloudS)*cdensity;
				
				}
			float sunShadow = exp(-240.*muEshD); 
			float moonShadow = exp(-240.*muEshN); 
			vec3 S = vec3(sunContribution*sunShadow+moonShadow*moonContribution+skyCol0)*muS;
			
			vec3 Sint=(S - S * exp(-mult*muE)) / (muE);
			color += Sint*total_extinction;
			total_extinction *= exp(-muE*mult);

			
			if (total_extinction < 1/250.) break;
			}
		}

		progress_view += dV_view;
	}
	progress_view = cameraPosition+dV_view/abs(dV_view.y)*(5500.0-cameraPosition.y);

	cdensity = 2.0;
	float cosY = normalize(dV_view).y;
	mult *= smoothstep(0.15,0.2,cosY);

		float cloud = abs(cloudVolST(progress_view));
	if (cloud > 0.0001){
		float muS = mix(0.0000000001,0.04,cloud)*cdensity;
		float muE = mix(0.0000000001,0.04,cloud)*cdensity;


			float muEshD = 0.0;
			for (int j=1;j<6;j++){ 
				float cloudS=cloudVolST(vec3(progress_view+dV_Sun*j));
				muEshD += mix(0.0000000001,0.04,cloudS)*cdensity;
				
				}	
			float muEshN = 0.0;
			for (int j=1;j<6;j++){ 
				float cloudS=cloudVolST(vec3(progress_view-dV_Sun*j));
				muEshN += mix(0.0000000001,0.04,cloudS)*cdensity;
				
				}
			float sunShadow = exp(-240.*muEshD); 
			float moonShadow = exp(-240.*muEshN); 
			vec3 S = vec3(sunContribution*sunShadow+moonShadow*moonContribution+skyCol0)*muS;
		
		vec3 Sint=(S - S * exp(-mult*muE)) / (muE);
		color += Sint*total_extinction;
		total_extinction *= exp(-muE*mult);

		

	}
	
	return mix(vec4(color,clamp(total_extinction*1.01-0.01,0.0,1.0)),vec4(0.0,0.0,0.0,1.0),1-smoothstep(0.02,0.15,cosY));

		
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
	/* DRAWBUFFERS:0 */
	int frame = frameCounter%16;
	ivec2 offset = ivec2(frame%4,int(frame/4));
	vec2 halfResTC = vec2(floor(gl_FragCoord.xy)*4.+2.);
	vec3 fragpos = toScreenSpace(vec3(halfResTC*texelSize,1.0));
	gl_FragData[0] = renderClouds(fragpos,vec3(0.),bayer16(gl_FragCoord.xy));
}
