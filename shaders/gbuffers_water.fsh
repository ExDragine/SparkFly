#version 120
#extension GL_EXT_gpu_shader4 : enable
const int shadowMapResolution = 2048; //[512 768 1024 1536 2048 3172 4096 8192]
varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;
varying vec3 binormal;
varying vec3 tangent;
varying vec3 viewVector;
varying float dist;
#define SCREENSPACE_REFLECTIONS	//can be really expensive at high resolutions/render quality, especially on ice 
//#define FULL_RES_DEPTH_BUFFER //if disabled, uses a 1/4 res depth buffer for better performance
#define SSR_STEPS 25 //[10 15 20 25 30 35 40 50 100 200 400]
#define PCF
#define MIN_LIGHT_AMOUNT 1.0 //[0.0 0.5 1.0 1.5 2.0 3.0 4.0 5.0]

#define TORCH_AMOUNT 1.0 //[0.0 0.5 0.75 1.0 1.2 1.4 1.6 1.8 2.0]
#define TORCH_R 1.0 //[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define TORCH_G 0.42 //[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.42 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define TORCH_B 0.11 //[0.0 0.05 0.1 0.11 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define SHADOW_MAP_BIAS 0.8

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow;
uniform sampler2D gaux2;
uniform sampler2D gaux1;
uniform sampler2D depthtex1;

uniform vec4 lightCol;
uniform vec3 sunVec;
uniform float frameTimeCounter;
uniform float lightPosSign;
uniform float near;
uniform float far;
uniform float moonIntensity;
uniform float sunIntensity;
uniform vec3 sunColor;
uniform vec3 nsunColor;
uniform vec3 upVec;
uniform float sunElevation;
uniform float fogAmount;
uniform vec2 texelSize;
uniform float rainStrength;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;
uniform int framemod8;
uniform int isEyeInWater;
#include "lib/color_transforms.glsl"
#include "lib/projections.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/waterBump.glsl"
#include "lib/clouds.glsl"
#include "lib/stars.glsl"
		const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);	
float interleaved_gradientNoise(float temporal){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)+temporal);
	return noise;
}
float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec3 rayTrace(vec3 dir,vec3 position,float dither){

    const float quality = SSR_STEPS;
    vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
       (-near -position.z) / dir.z : far*sqrt(3.);
    vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
    direction.xy = normalize(direction.xy);

    //get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
    float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);

	
    vec3 stepv = direction * mult / quality;
	

	
	
	vec3 spos = clipPosition + stepv*dither;
	float minZ = clipPosition.z;
	float maxZ = spos.z+stepv.z*0.5;
	spos.xy+=offsets[framemod8]*texelSize*0.5;
	//raymarch on a quarter res depth buffer for improved cache coherency
	#ifndef FULL_RES_DEPTH_BUFFER
	spos.xy*=0.25;
	stepv.xy*=0.25;
	#endif

    for (int i = 0; i < int(quality+1); i++) {
		#ifdef FULL_RES_DEPTH_BUFFER
			float sp=texelFetch2D(depthtex1,ivec2(spos.xy/texelSize),0).x;
		#endif
		#ifndef FULL_RES_DEPTH_BUFFER
			float spLin=texelFetch2D(gaux1,ivec2(spos.xy/texelSize),0).x;
			float sp=invLinZ(spLin*spLin*spLin);
		#endif
            if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)){
			#ifdef FULL_RES_DEPTH_BUFFER
				return vec3(spos.xy,sp);
			#endif
			#ifndef FULL_RES_DEPTH_BUFFER
				return vec3(spos.xy*4.0,sp);
			#endif
	        }
        spos += stepv;		
		//small bias
		minZ = maxZ-0.00004/ld(spos.z);
		maxZ += stepv.z;
    }

    return vec3(1.1);
}

//area light approximation (from horizon zero dawn siggraph presentation)
float GetNoHSquared(float radiusTan, float NoL, float NoV, float VoL)
{
    // radiusCos can be precalculated if radiusTan is a directional light
    float radiusCos = inversesqrt(1.0 + radiusTan * radiusTan);
    
    // Early out if R falls within the disc
    float RoL = 2.0 * NoL * NoV - VoL;
    if (RoL >= radiusCos)
        return 1.0;

    float rOverLengthT = radiusCos * radiusTan * inversesqrt(1.0 - RoL * RoL);
    float NoTr = rOverLengthT * (NoV - RoL * NoL);
    float VoTr = rOverLengthT * (2.0 * NoV * NoV - 1.0 - RoL * VoL);

    // Calculate dot(cross(N, L), V). This could already be calculated and available.
    float triple = sqrt(clamp(1.0 - NoL * NoL - NoV * NoV - VoL * VoL + 2.0 * NoL * NoV * VoL,0.,1.));
    
    // Do one Newton iteration to improve the bent light vector
    float NoBr = rOverLengthT * triple, VoBr = rOverLengthT * (2.0 * triple * NoV);
    float NoLVTr = NoL * radiusCos + NoV + NoTr, VoLVTr = VoL * radiusCos + 1.0 + VoTr;
    float p = NoBr * VoLVTr, q = NoLVTr * VoLVTr, s = VoBr * NoLVTr;    
    float xNum = q * (-0.5 * p + 0.25 * VoBr * NoLVTr);
    float xDenom = p * p + s * ((s - 2.0 * p)) + NoLVTr * ((NoL * radiusCos + NoV) * VoLVTr * VoLVTr + 
                   q * (-0.5 * (VoLVTr + VoL * radiusCos) - 0.5));
    float twoX1 = 2.0 * xNum / (xDenom * xDenom + xNum * xNum);
    float sinTheta = twoX1 * xDenom;
    float cosTheta = 1.0 - twoX1 * xNum;
    NoTr = cosTheta * NoTr + sinTheta * NoBr; // use new T to update NoTr
    VoTr = cosTheta * VoTr + sinTheta * VoBr; // use new T to update VoTr
    
    // Calculate (N.H)^2 based on the bent light vector
    float newNoL = NoL * radiusCos + NoTr;
    float newVoL = VoL * radiusCos + VoTr;
    float NoH = NoV + newNoL;
    float HoH = 2.0 * newVoL + 2.0;
    return max(0.0, NoH * NoH / HoH);
}
//optimized ggx from jodie with area light approximation
float GGX (vec3 n, vec3 v, vec3 l, float r, float F0,float lightSize) {
  r*=r;r*=r;
  
  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp(dot(h,l)*hn,0.,1.);
  float dotNH = clamp(dot(h,n)*hn,0.,1.);
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNHsq = GetNoHSquared(lightSize,dotNL,dot(n,v),dot(v,l));
  
  float denom = dotNHsq * r - dotNHsq + 1.;
  float D = r / (3.141592653589793 * denom * denom);
  float F = F0 + (1. - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
}
const vec2 shadowOffsets[8] = vec2[8](vec2( -0.7071,  0.7071 ),
vec2( -0.0000, -0.8750 ),
vec2(  0.5303,  0.5303 ),
vec2( -0.6250, -0.0000 ),
vec2(  0.3536, -0.3536 ),
vec2( -0.0000,  0.3750 ),
vec2( -0.1768, -0.1768 ),
vec2( 0.1250,  0.0000 ));
float facos(float sx){
    float x = clamp(abs( sx ),0.,1.);
    float a = sqrt( 1. - x ) * ( -0.16882 * x + 1.56734 );
    return sx > 0. ? a : pi - a;
}	

#define SHADOW_MAP_BIAS 0.8
float calcDistort(vec2 worlpos){
	
	vec2 pos = worlpos * 1.165;
	vec2 posSQ = pos*pos;
	
	float distb = pow(posSQ.x*posSQ.x*posSQ.x + posSQ.y*posSQ.y*posSQ.y, 1.0 / 6.0);
	return 1.08695652/((1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS);
}	
	

	float bayer2(vec2 a){
	a = floor(a);
    return fract(dot(a,vec2(0.5,a.y*0.75)));
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}
float w0(float a)
{
    return (1.0/6.0)*(a*(a*(-a + 3.0) - 3.0) + 1.0);
}

float w1(float a)
{
    return (1.0/6.0)*(a*a*(3.0*a - 6.0) + 4.0);
}

float w2(float a)
{
    return (1.0/6.0)*(a*(a*(-3.0*a + 3.0) + 3.0) + 1.0);
}

float w3(float a)
{
    return (1.0/6.0)*(a*a*a);
}

float g0(float a)
{
    return w0(a) + w1(a);
}

float g1(float a)
{
    return w2(a) + w3(a);
}

float h0(float a)
{
    return -1.0 + w1(a) / (w0(a) + w1(a));
}

float h1(float a)
{
    return 1.0 + w3(a) / (w2(a) + w3(a));
}

float shadow2D_bicubic(sampler2DShadow tex, vec3 sc)
{
	vec2 uv = sc.xy*shadowMapResolution;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = vec2(iuv.x + h0x, iuv.y + h0y)/shadowMapResolution - 0.5/shadowMapResolution;
	vec2 p1 = vec2(iuv.x + h1x, iuv.y + h0y)/shadowMapResolution - 0.5/shadowMapResolution;
	vec2 p2 = vec2(iuv.x + h0x, iuv.y + h1y)/shadowMapResolution - 0.5/shadowMapResolution;
	vec2 p3 = vec2(iuv.x + h1x, iuv.y + h1y)/shadowMapResolution - 0.5/shadowMapResolution;
	
    return g0(fuv.y) * (g0x * shadow2D(tex, vec3(p0,sc.z)).x  +
                        g1x * shadow2D(tex, vec3(p1,sc.z)).x) +
           g1(fuv.y) * (g0x * shadow2D(tex, vec3(p2,sc.z)).x  +
                        g1x * shadow2D(tex, vec3(p3,sc.z)).x);
}
	#define PW_DEPTH 1. //[0.5 1.0 1.5 2.0 2.5 3.0]
	#define PW_POINTS 1 //[2 4 6 8 16 32]
	#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) fract(bayer64(.5*(a))*.25+bayer2(a))	
vec3 getParallaxDisplacement(vec3 posxz, float iswater,float bumpmult,vec3 viewVec) {
	float waveZ = mix(20.0,0.25,iswater);
	float waveM = mix(0.0,4.0,iswater);

	vec3 parallaxPos = posxz;
	vec2 vec = viewVector.xy * (1.0 / float(PW_POINTS)) * 22.0 * PW_DEPTH;
	float waterHeight = getWaterHeightmap(posxz.xz, waveM, waveZ, iswater) * 0.5;
parallaxPos.xz += waterHeight * vec;

	return parallaxPos;
	
}
										
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:2 */
void main() {
	
			vec2 tempOffset=offsets[framemod8];
	float iswater = normalMat.w;
	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	gl_FragData[0] = texture2D(texture, lmtexcoord.xy)*color;

	if (iswater > 0.4) {
		gl_FragData[0] = vec4(0.42,0.6,0.7,0.6);
		vec3 groundFragpos = toScreenSpace(vec3(gl_FragCoord.xy,texture2D(depthtex1,gl_FragCoord.xy*texelSize).x)*vec3(texelSize,1.0))-vec3(vec2(tempOffset)*texelSize*0.5,0.0);
		if (isEyeInWater==0) gl_FragData[0].a = 1.0-exp(-length(fragpos-groundFragpos)/2.5);
	}
	if (iswater > 0.9) {
		gl_FragData[0] = vec4(0.02,0.04,0.08,0.0)*2.;
		vec3 groundFragpos = toScreenSpace(vec3(gl_FragCoord.xy,texture2D(depthtex1,gl_FragCoord.xy*texelSize).x)*vec3(texelSize,1.0))-vec3(vec2(tempOffset)*texelSize*0.5,0.0);
		if (isEyeInWater==0) gl_FragData[0].a = 1.0-exp(-length(fragpos-groundFragpos)/2.5);

	}

	
		vec3 albedo = toLinear(gl_FragData[0].rgb);
		
		vec3 normal = normalMat.xyz;

		if (dot(normal,fragpos) > 0.0) discard;
		vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;

		if (iswater > 0.4){
		float bumpmult = 1.;
		if (iswater > 0.9) bumpmult = 1.;
		float parallaxMult = bumpmult;
		vec3 posxz = p3+cameraPosition;
		posxz.xz-=posxz.y;
				

		vec3 bump;

						mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
							tangent.z, binormal.z, normal.z);
		posxz.xyz = getParallaxDisplacement(posxz,iswater,bumpmult,normalize(tbnMatrix*fragpos));
		
		bump = normalize(getWaveHeight(posxz.xz,iswater));


		
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
							  
		normal = normalize(bump * tbnMatrix);
		}
		
		float NdotL = lightCol.a*dot(normal,sunVec);
		float NdotU = dot(upVec,normal);
		float diffuseSun = clamp(NdotL,0.0f,1.0f);
		float skyLight = (NdotU*0.33+1.0)*(1.0-rainStrength*0.8);
		
		vec3 direct = lightCol.rgb;

		float shading = 1.0;
		//compute shadows only if not backface
		if (diffuseSun > 0.001) {
			vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
			vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
			projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;
			
			//apply distortion
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;
			//do shadows only if on shadow map
			if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){
				float diffthresh = (facos(diffuseSun)*0.008+0.00008)/(distortFactor*distortFactor);	

				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5);
				
				#ifdef PCF

				float noise = interleaved_gradientNoise(tempOffset.x*0.5+0.5);

				vec2 offsetS = vec2(cos( noise*3.14159265359*2.0 ),sin( noise*3.14159265359*2.0 ));

				shading = shadow2D_bicubic(shadow,vec3(projectedShadowPosition + vec3(0.0,0.0,-diffthresh*1.2)));
				#endif

				
				#ifndef PCF
				projectedShadowPosition.z -= diffthresh;
				shading = shadow2D(shadow,vec3(projectedShadowPosition)).x;

				#endif
				
				direct *= shading;
			}

		}
		
		direct *= (diffuseSun*lmtexcoord.w)*10.;
	
		float torch_lightmap = ((lmtexcoord.z*lmtexcoord.z)*(lmtexcoord.z*lmtexcoord.z))*(lmtexcoord.z*20.)+lmtexcoord.z;
	
		vec3 ambient = (lightCol.a*sunElevation)*(-NdotL*0.45+0.9)*lightCol.rgb*0.6 + (skyLight*skyIntensity)*vec3(0.65,0.7,1.)*30. + skyIntensityNight*vec3(0.09,0.1,0.15)/1.5;
	
		vec3 diffuseLight = direct + (lmtexcoord.w)*ambient + vec3(TORCH_R,TORCH_G,TORCH_B)*torch_lightmap*0.8*TORCH_AMOUNT + 0.0006*MIN_LIGHT_AMOUNT;
		vec3 color = diffuseLight*albedo*1.4*0.1;
		
		
		if (iswater > 0.0){
			//not pbr ^^
		float f0 = iswater > 0.1?  0.04 : 0.2*(1.0-gl_FragData[0].a);
		
		float roughness = 0.1;

		float emissive = 0.0;
		float F0 = f0;
		
				vec3 reflectedVector = reflect(normalize(fragpos), normal);	
				float normalDotEye = dot(normal, normalize(fragpos));
				float fresnel = pow(clamp(1.0 + normalDotEye,0.0,1.0), 5.0) ;
				fresnel = fresnel+F0*(1.0-fresnel);
				/*
				if (dot(fragpos,normal)>0.0) {
				reflectedVector = mat3(gbufferModelViewInverse)*reflectedVector;
				reflectedVector.y = -reflectedVector.y;
				reflectedVector = mat3(gbufferModelView)*reflectedVector;
				}
				*/
				float sunSpec = GGX(normal,-normalize(fragpos),  lightCol.a*sunVec, roughness, f0,lightCol.a>0.0? 0.035 : 0.065)*0.01;
				

				vec3 wrefl = mat3(gbufferModelViewInverse)*reflectedVector;
				vec3 sky_c = getSkyColor(wrefl,mat3(gbufferModelViewInverse)*sunVec,wrefl.y)*lmtexcoord.w*lmtexcoord.w *1.4*(1.0-isEyeInWater)*(2.5-exp(-fogAmount*256.)*2.+fogAmount*100.*0.3);





				
				vec4 reflection = vec4(sky_c,0.);
				#ifdef SCREENSPACE_REFLECTIONS
				vec3 rtPos = rayTrace(reflectedVector,fragpos.xyz,interleaved_gradientNoise(frameTimeCounter*10.254));
				if (rtPos.z <1.05){
				
				vec4 fragpositionPrev = gbufferProjectionInverse * vec4(rtPos*2.-1.,1.);
				fragpositionPrev /= fragpositionPrev.w;
				
				vec3 sampleP = fragpositionPrev.xyz;
				fragpositionPrev = gbufferModelViewInverse * fragpositionPrev;


			
				vec4 previousPosition = fragpositionPrev + vec4(cameraPosition-previousCameraPosition,0.);
				previousPosition = gbufferPreviousModelView * previousPosition;
				previousPosition = gbufferPreviousProjection * previousPosition;
				previousPosition.xy = previousPosition.xy/previousPosition.w*0.5+0.5;
				reflection.a = clamp(1.0 - pow(cdist(previousPosition.st), 20.0), 0.0, 1.0);
				reflection.rgb = texture2D(gaux2,previousPosition.xy).rgb/10.;
				}
				#endif
				reflection.rgb = mix(sky_c, reflection.rgb, reflection.a);
				vec3 reflected= reflection.rgb*fresnel+shading*sunSpec* lightCol.rgb;

				float alpha0 = gl_FragData[0].a;
				vec3 specColor = mix(normalize(albedo+0.00001)*0.25,vec3(1.0/sqrt(3.)),1.0-alpha0*alpha0*alpha0*alpha0);
				
		//correct alpha channel with fresnel
		gl_FragData[0].a = -gl_FragData[0].a*fresnel+gl_FragData[0].a+fresnel;				
		gl_FragData[0].rgb =clamp(color*10./gl_FragData[0].a*alpha0*(1.0-fresnel)+reflected*10./gl_FragData[0].a,0.0,65100.0);
		if (gl_FragData[0].r > 65000.) gl_FragData[0].rgba = vec4(0.);
		}
		else 
		gl_FragData[0].rgb = color*10.;

		//gl_FragData[0].rgb /= 1.0-gl_FragData[0].a;
}