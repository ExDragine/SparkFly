#version 120
#extension GL_EXT_gpu_shader4 : enable

#define TAA
#define SSAO //It is also recommended to reduce the ambientOcclusionLevel value with this enabled
#define SSAO_SAMPLES 7 //[4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32]
#define Variable_Penumbra_Shadows	//Makes the shadows more blurry the more distant they are to objects (costs fps)
#define VPS_Search_Samples 8 //The number of samples used to find occluders [4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32]
#define Min_Shadow_Filter_Radius 1.412	//If Variable_Penumbra_Shadows are not used, will be used as shadow filter size. [0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0 91.0 92.0 93.0 94.0 95.0 96.0 97.0 98.0 99.0 100.0 101.0 102.0 103.0 104.0 105.0 106.0 107.0 108.0 109.0 110.0 111.0 112.0 113.0 114.0 115.0 116.0 117.0 118.0 119.0 ]
#define Max_Shadow_Filter_Radius 30.0  //Not used if Variable_Penumbra_Shadows are not used. Will cause issues at too high values [0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0 91.0 92.0 93.0 94.0 95.0 96.0 97.0 98.0 99.0 100.0 101.0 102.0 103.0 104.0 105.0 106.0 107.0 108.0 109.0 110.0 111.0 112.0 113.0 114.0 115.0 116.0 117.0 118.0 119.0 ]
#define Max_Filter_Depth 20.0 //Distance to the occluder at which the shadow filter size reaches its maximum. [0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0 91.0 92.0 93.0 94.0 95.0 96.0 97.0 98.0 99.0 100.0 101.0 102.0 103.0 104.0 105.0 106.0 107.0 108.0 109.0 110.0 111.0 112.0 113.0 114.0 115.0 116.0 117.0 118.0 119.0 ]

flat varying float tempOffsets;
flat varying vec3 WsunVec;
flat varying vec2 TAA_Offset;
#include "lib/Shadow_Params.glsl"
uniform sampler2D depthtex1;
uniform sampler2D shadow;
uniform sampler2D colortex1;
uniform sampler2D colortex7;
uniform sampler2D noisetex;
uniform vec3 sunVec;
uniform vec2 texelSize;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform int frameCounter;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;
uniform float viewWidth;
uniform float viewHeight;

#define ffstep(x,y) clamp((y - x) * 1e35,0.0,1.0)
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
vec2 tapLocation(int sampleNumber,int nb, float nbRot,float jitter,float distort)
{
    float alpha = (sampleNumber+jitter)/nb;
    float angle = jitter*6.28+alpha * nbRot * 6.28;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*alpha;
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
vec3 decode (vec2 enc)
{
    vec2 fenc = enc*4-2;
    float f = dot(fenc,fenc);
    float g = sqrt(1-f/4.0);
    vec3 n;
    n.xy = fenc*g;
    n.z = 1-f/2;
    return n;
}

vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}
float hash13(vec3 p3)
{
	p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y);
}
float blueNoise(vec2 coord){
  return texelFetch2D(noisetex, ivec2(coord)%512, 0).a;
}
vec2 tapLocation(int sampleNumber, float spinAngle,int nb, float nbRot,float r0)
{
    float alpha = (float(sampleNumber*1.0f + r0) * (1.0 / (nb)));
    float angle = alpha * (nbRot * 6.28) + spinAngle*6.28;

    float ssR = alpha;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*ssR;
}

void ssao(inout float occlusion,vec3 fragpos,float mulfov,float dither,vec3 normal)
{
	ivec2 pos = ivec2(gl_FragCoord.xy);
	const float tan70 = tan(70.*3.14/180.);
	float mulfov2 = gbufferProjection[1][1]/tan70;

	const float PI = 3.14159265;
	const float samplingRadius = 0.712;
	float angle_thresh = 0.05;




	float rd = mulfov2*0.04;
	//pre-rotate direction
	float n = 0.;

	occlusion = 0.0;

	vec2 acc = -vec2(TAA_Offset)*texelSize*0.5;
	float mult = (dot(normal,normalize(fragpos))+1.0)*0.5+0.5;

	vec2 v = fract(vec2(dither,interleaved_gradientNoise()) + (frameCounter%10000) * vec2(0.75487765, 0.56984026));
	for (int j = 0; j < SSAO_SAMPLES ;j++) {

			vec2 sp = tapLocation(j,v.x,SSAO_SAMPLES,3.,v.y);
			vec2 sampleOffset = sp*rd;
			ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset*vec2(viewWidth,viewHeight));
			if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth && offset.y < viewHeight ) {
				vec3 t0 = toScreenSpace(vec3(offset*texelSize+acc+0.5*texelSize,texelFetch2D(depthtex1,offset,0).x));

				vec3 vec = t0.xyz - fragpos;
				float dsquared = dot(vec,vec);
				if (dsquared > 1e-5){
					if (dsquared < fragpos.z*fragpos.z*0.04*0.04*mulfov2*2.*1.412){
						float NdotV = clamp(dot(vec*inversesqrt(dsquared), normalize(normal)),0.,1.);
						occlusion += NdotV;
					}
					n += 1.0;
				}
			}
		}



		occlusion = clamp(1.0-occlusion/n*2.0,0.,1.0);
		//occlusion = mult;

}


void main() {
/* DRAWBUFFERS:3 */
	vec2 texcoord = ((gl_FragCoord.xy))*texelSize;
	gl_FragData[0] = vec4(Min_Shadow_Filter_Radius,1.0,0.0,0.0);
	float z = texture2D(depthtex1,texcoord).x;
	vec2 tempOffset=TAA_Offset;
	if (z < 1.0){

		vec4 data = texture2D(colortex1,texcoord);
		vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y));
		vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w));
		vec3 normal = mat3(gbufferModelViewInverse) * decode(dataUnpacked0.yw);

		bool translucent = abs(dataUnpacked1.w-0.5) <0.01;
		bool hand = abs(dataUnpacked1.w-0.75) <0.01;
		if (!hand){
			float NdotL = clamp(dot(normal,WsunVec),0.0,1.0);
			if (translucent) {
				NdotL = 0.9;
			}

				float bn = blueNoise(gl_FragCoord.xy);
				float noise = fract(bn + frameCounter/1.6180339887);
				vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(tempOffset)*texelSize*0.5,z));
				#ifdef Variable_Penumbra_Shadows
					if (NdotL > 0.001) {
					vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
					vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
					projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

					//apply distortion
					float distortFactor = calcDistort(projectedShadowPosition.xy);
					projectedShadowPosition.xy *= distortFactor;
					//do shadows only if on shadow map
					if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0){
						const float threshMul = max(2048.0/shadowMapResolution*shadowDistance/128.0,0.95);
						float distortThresh = (sqrt(1.0-NdotL*NdotL)/NdotL+0.7)/distortFactor;
						float diffthresh =  translucent? 0.00014/15.0 : distortThresh/7500.0*threshMul;
						projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);


						const float mult = Max_Shadow_Filter_Radius;
						float avgBlockerDepth = 0.0;
						vec2 scales = vec2(0.0,Max_Filter_Depth);
						float blockerCount = 0.0;
						float rdMul = distortFactor*(1.0+mult)*d0*k/shadowMapResolution;
						float diffthreshM = diffthresh*mult*distortFactor*d0*k;
						for(int i = 0; i < VPS_Search_Samples; i++){
							vec2 offsetS = tapLocation(i,VPS_Search_Samples, 2.0,noise,0.0);

							float d = texelFetch2D( shadow, ivec2((projectedShadowPosition.xy+offsetS*rdMul)*shadowMapResolution),0).x;
							float b  = ffstep(d,projectedShadowPosition.z-i*diffthreshM/VPS_Search_Samples-diffthreshM);

							blockerCount += b;
							avgBlockerDepth += d * b;
						}
						if (blockerCount >= 0.9)
							avgBlockerDepth /= blockerCount;
						else {
							avgBlockerDepth = projectedShadowPosition.z;
						}
						float ssample = max(projectedShadowPosition.z - avgBlockerDepth,0.0)*1500.0;
						float avgdepth = clamp(ssample, scales.x, scales.y)/(scales.y)*(mult-Min_Shadow_Filter_Radius)+Min_Shadow_Filter_Radius;

						gl_FragData[0].r = avgdepth;
					}
				}
			#endif
			float ao= 1.0;
			#ifdef SSAO
				ssao(ao,fragpos,1.0,noise,decode(dataUnpacked0.yw));
				gl_FragData[0].g = ao;
			#endif
		}

}
}
