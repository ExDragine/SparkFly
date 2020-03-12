#version 400 compatibility
//Render sky, volumetric clouds, direct lighting,Vertical bilateral blur for GI, applies GI
#extension GL_EXT_gpu_shader4 : enable
//#define SCREENSPACE_CONTACT_SHADOWS	//Raymarch towards the sun in screen-space, in order to cast shadows outside of the shadow map or at the contact of objects. Can get really expensive at high resolutions.
#define PCF //shadow filtering
//#define VPS //Variable penumbra shadows


#ifdef VPS
#undef PCF
#endif

#define MIN_LIGHT_AMOUNT 1.0 //[0.0 0.5 1.0 1.5 2.0 3.0 4.0 5.0]

#define TORCH_AMOUNT 1.0 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define TORCH_R 1.0 //[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define TORCH_G 0.42 //[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.42 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define TORCH_B 0.11 //[0.0 0.05 0.1 0.11 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define STAR_COLOR_R 88.0 //[0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0 91.0 92.0 93.0 94.0 95.0 96.0 97.0 98.0 99.0 100.0 101.0 102.0 103.0 104.0 105.0 106.0 107.0 108.0 109.0 110.0 111.0 112.0 113.0 114.0 115.0 116.0 117.0 118.0 119.0 120.0 121.0 122.0 123.0 124.0 125.0 126.0 127.0 128.0 129.0 130.0 131.0 132.0 133.0 134.0 135.0 136.0 137.0 138.0 139.0 140.0 141.0 142.0 143.0 144.0 145.0 146.0 147.0 148.0 149.0 150.0 151.0 152.0 153.0 154.0 155.0 156.0 157.0 158.0 159.0 160.0 161.0 162.0 163.0 164.0 165.0 166.0 167.0 168.0 169.0 170.0 171.0 172.0 173.0 174.0 175.0 176.0 177.0 178.0 179.0 180.0 181.0 182.0 183.0 184.0 185.0 186.0 187.0 188.0 189.0 190.0 191.0 192.0 193.0 194.0 195.0 196.0 197.0 198.0 199.0 200.0 201.0 202.0 203.0 204.0 205.0 206.0 207.0 208.0 209.0 210.0 211.0 212.0 213.0 214.0 215.0 216.0 217.0 218.0 219.0 220.0 221.0 222.0 223.0 224.0 225.0 226.0 227.0 228.0 229.0 230.0 231.0 232.0 233.0 234.0 235.0 236.0 237.0 238.0 239.0 240.0 241.0 242.0 243.0 244.0 245.0 246.0 247.0 248.0 249.0 250.0 251.0 252.0 253.0 254.0 255.0]
#define STAR_COLOR_G 98.0 //[0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0 91.0 92.0 93.0 94.0 95.0 96.0 97.0 98.0 99.0 100.0 101.0 102.0 103.0 104.0 105.0 106.0 107.0 108.0 109.0 110.0 111.0 112.0 113.0 114.0 115.0 116.0 117.0 118.0 119.0 120.0 121.0 122.0 123.0 124.0 125.0 126.0 127.0 128.0 129.0 130.0 131.0 132.0 133.0 134.0 135.0 136.0 137.0 138.0 139.0 140.0 141.0 142.0 143.0 144.0 145.0 146.0 147.0 148.0 149.0 150.0 151.0 152.0 153.0 154.0 155.0 156.0 157.0 158.0 159.0 160.0 161.0 162.0 163.0 164.0 165.0 166.0 167.0 168.0 169.0 170.0 171.0 172.0 173.0 174.0 175.0 176.0 177.0 178.0 179.0 180.0 181.0 182.0 183.0 184.0 185.0 186.0 187.0 188.0 189.0 190.0 191.0 192.0 193.0 194.0 195.0 196.0 197.0 198.0 199.0 200.0 201.0 202.0 203.0 204.0 205.0 206.0 207.0 208.0 209.0 210.0 211.0 212.0 213.0 214.0 215.0 216.0 217.0 218.0 219.0 220.0 221.0 222.0 223.0 224.0 225.0 226.0 227.0 228.0 229.0 230.0 231.0 232.0 233.0 234.0 235.0 236.0 237.0 238.0 239.0 240.0 241.0 242.0 243.0 244.0 245.0 246.0 247.0 248.0 249.0 250.0 251.0 252.0 253.0 254.0 255.0]
#define STAR_COLOR_B 187.0 //[0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0 13.0 14.0 15.0 16.0 17.0 18.0 19.0 20.0 21.0 22.0 23.0 24.0 25.0 26.0 27.0 28.0 29.0 30.0 31.0 32.0 33.0 34.0 35.0 36.0 37.0 38.0 39.0 40.0 41.0 42.0 43.0 44.0 45.0 46.0 47.0 48.0 49.0 50.0 51.0 52.0 53.0 54.0 55.0 56.0 57.0 58.0 59.0 60.0 61.0 62.0 63.0 64.0 65.0 66.0 67.0 68.0 69.0 70.0 71.0 72.0 73.0 74.0 75.0 76.0 77.0 78.0 79.0 80.0 81.0 82.0 83.0 84.0 85.0 86.0 87.0 88.0 89.0 90.0 91.0 92.0 93.0 94.0 95.0 96.0 97.0 98.0 99.0 100.0 101.0 102.0 103.0 104.0 105.0 106.0 107.0 108.0 109.0 110.0 111.0 112.0 113.0 114.0 115.0 116.0 117.0 118.0 119.0 120.0 121.0 122.0 123.0 124.0 125.0 126.0 127.0 128.0 129.0 130.0 131.0 132.0 133.0 134.0 135.0 136.0 137.0 138.0 139.0 140.0 141.0 142.0 143.0 144.0 145.0 146.0 147.0 148.0 149.0 150.0 151.0 152.0 153.0 154.0 155.0 156.0 157.0 158.0 159.0 160.0 161.0 162.0 163.0 164.0 165.0 166.0 167.0 168.0 169.0 170.0 171.0 172.0 173.0 174.0 175.0 176.0 177.0 178.0 179.0 180.0 181.0 182.0 183.0 184.0 185.0 186.0 187.0 188.0 189.0 190.0 191.0 192.0 193.0 194.0 195.0 196.0 197.0 198.0 199.0 200.0 201.0 202.0 203.0 204.0 205.0 206.0 207.0 208.0 209.0 210.0 211.0 212.0 213.0 214.0 215.0 216.0 217.0 218.0 219.0 220.0 221.0 222.0 223.0 224.0 225.0 226.0 227.0 228.0 229.0 230.0 231.0 232.0 233.0 234.0 235.0 236.0 237.0 238.0 239.0 240.0 241.0 242.0 243.0 244.0 245.0 246.0 247.0 248.0 249.0 250.0 251.0 252.0 253.0 254.0 255.0]
#define STAR_COLOR_R_STRENGTH 0.2 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0]
#define STAR_COLOR_G_STRENGTH 0.2 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0]
#define STAR_COLOR_B_STRENGTH 0.2 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0]
#define STAR_COLOR_STRENGTH 0.5 //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0]

const int shadowMapResolution = 2048; //[512 768 1024 1536 2048 3172 4096 8192]

varying vec2 texcoord;
//ambient sky light is integrated in vertex shader for each block side
varying vec3 ambientUp;
varying vec3 ambientLeft;
varying vec3 ambientRight;
varying vec3 ambientB;
varying vec3 ambientF;
varying vec3 ambientDown;
//main light source color (rgb),used light source(1=sun,-1=moon)
varying vec4 lightCol;
uniform sampler2D colortex6;//sky texture from tp
uniform sampler2D colortex0;//clouds
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
uniform sampler2D depthtex1;//depth
uniform sampler2D noisetex;//rgb : water waves, alpha:perlin-worley noise
#ifdef VPS
uniform sampler2D shadow;
#endif
#ifndef VPS
uniform sampler2DShadow shadow;
#endif

uniform int worldTime;
uniform int worldDay;
uniform vec3 sunColor;
uniform vec3 nsunColor;
uniform int isEyeInWater;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform mat4 shadowProjectionInverse;
uniform float far;
uniform float near;
uniform float frameTimeCounter;
uniform float sunIntensity;
uniform float skyIntensity;
uniform float skyIntensityNight;
uniform float rainStrength;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec2 texelSize;
uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform int framemod8;
uniform float wetness;
		const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)


vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

vec3 toWorldSpace(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    return p3;
}

vec3 toWorldSpaceCamera(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    return p3 + cameraPosition;
}

vec3 toShadowSpace(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    return p3;
}

vec3 toShadowSpaceProjected(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    p3 = diagonal3(shadowProjection) * p3 + shadowProjection[3].xyz;

    return p3;
}


vec3 sunVec = normalize(mat3(gbufferModelViewInverse) *sunPosition);
#include "lib/color_transforms.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/clouds.glsl"
#include "lib/stars.glsl"
#include "lib/aurora.glsl"
#include "lib/rainbow.glsl"

vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}
float lengthVec (vec3 vec){
	return sqrt(dot(vec,vec));
}
#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)
float triangularize(float dither)
{
    float center = dither*2.0-1.0;
    dither = center*inversesqrt(abs(center));
    dither = max(-1.0,dither);
    return dither-fsign(center);
}
float interleaved_gradientNoise(float temp){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+temp);
}
vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
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
#define SHADOW_MAP_BIAS 0.8
float calcDistort(vec2 worlpos){

	vec2 pos = abs(worlpos * 1.165);
	vec2 posSQ = pos*pos;

	float distb = pow(posSQ.x*posSQ.x*posSQ.x + posSQ.y*posSQ.y*posSQ.y, 1.0 / 6.0);
	return 1.0/((1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS);
}
vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}
float linZ(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
	// l = (2*n)/(f+n-d(f-n))
	// f+n-d(f-n) = 2n/l
	// -d(f-n) = ((2n/l)-f-n)
	// d = -((2n/l)-f-n)/(f-n)

}
float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}

vec3 toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}
float bayer2(vec2 a){
	a = floor(a);
    return fract(dot(a,vec2(0.5,a.y*0.75)));
}

#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) fract(bayer64(.5*(a))*.25+bayer2(a)+offsets[framemod8].x*0.5+0.5)
float rayTraceShadow(vec3 dir,vec3 position,float dither,float translucent){

    const float quality = 16.;
    vec3 clipPosition = toClipSpace3(position);
	//prevents the ray from going behind the camera
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
       (-near -position.z) / dir.z : far*sqrt(3.);
    vec3 direction = toClipSpace3(position+dir*rayLength)-clipPosition;  //convert to clip space
    direction.xyz = direction.xyz/max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y);	//fixed step size




    vec3 stepv = direction *3. * clamp(MC_RENDER_QUALITY,1.,2.0);

	vec3 spos = clipPosition+vec3(offsets[framemod8]*vec2(texelSize.x,texelSize.y)*0.5,0.0)+stepv*dither;





	for (int i = 0; i < int(quality); i++) {
		spos += stepv;

		float sp = texture2D(depthtex1,spos.xy).x;
        if( sp < spos.z) {

			float dist = abs(linZ(sp)-linZ(spos.z))/linZ(spos.z);

			if (dist < 0.01 ) return translucent*exp2(position.z/8.);



	}

	}
    return 1.0;
}
float manualShadowFilter(vec2 center,vec2 offset, bool translucent, float diffthresh, float projectedShadowPosition){
	vec2 pos = center+offset;
	const float invShadowRes = 1.0 /shadowMapResolution;

	const float threshMul = 4096.;

	float thresh = diffthresh * (1.0+length(offset)/invShadowRes);



	thresh = thresh;
	//use a quasi-step function for normal shadows and a smooth depth gradient for translucent objects
	const float constStep = pow(2,-25.);
	float minDiffthesh = thresh*float(translucent) + constStep;
	float diffthresh0 = thresh-thresh*float(translucent);
	vec4 sampleS = textureGather( shadow, pos, 0)+diffthresh0;

	//way faster than conditionnal assignment
	vec4 shadow4 = clamp(-(sampleS-projectedShadowPosition),0.,minDiffthesh);


	//filter (same result as shadow2D)
	vec2 fuv = fract(pos*shadowMapResolution - 0.5);
	//fuv = (fuv*fuv)*(3.0-2.0*fuv);
    float temp0 = mix( shadow4.x, shadow4.y, fuv.x );
    float temp1 = mix( shadow4.w, shadow4.z, fuv.x );


    return mix( temp1, temp0, fuv.y )/minDiffthesh;



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

vec4 texture2D_bicubic(sampler2D tex, vec2 uv)
{
	vec4 texelSize = vec4(texelSize,1.0/texelSize);

	uv = uv*texelSize.zw;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) - 0.5) * texelSize.xy;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) - 0.5) * texelSize.xy;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) - 0.5) * texelSize.xy;

    return g0(fuv.y) * (g0x * texture2D(tex, p0)  +
                        g1x * texture2D(tex, p1)) +
           g1(fuv.y) * (g0x * texture2D(tex, p2)  +
                        g1x * texture2D(tex, p3));
}

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

float hash11(float p)
{
	vec3 p3  = fract(vec3(p) * 0.1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}
void main() {


	float z = texture2D(depthtex1,texcoord).x;
	vec2 tempOffset=offsets[framemod8];
	float noise = interleaved_gradientNoise(hash11(frameTimeCounter));

	vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(tempOffset)*texelSize*0.5,z));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);
	vec3 color;

	//sky
	if (z >=1.0){

			color = getSkyColor(np3,sunVec,np3.y)*0.5 + texture2D(colortex6,texcoord).rgb;
			vec4 cloud = texture2D_bicubic(colortex0,texcoord/4.0);
			if (np3.y > 0.){
			color += stars(np3)*vec3(STAR_COLOR_R*STAR_COLOR_R_STRENGTH,STAR_COLOR_G*STAR_COLOR_G_STRENGTH,STAR_COLOR_B*STAR_COLOR_B_STRENGTH)/255*(30*STAR_COLOR_STRENGTH*worldTime/12000);
			color = drawSun(dot(sunVec,np3),sunIntensity, nsunColor,color);
				}
			vec4 aurora_col = aurora(vec3(0,0,-6.7), np3);
			color = color+rainbow(np3);
			color = color*(1.-aurora_col.a)+aurora_col.rgb;
			color = color*cloud.a+cloud.rgb;
	}
	//land
	if (z<1.0) {
		p3 += gbufferModelViewInverse[3].xyz;

		vec4 data = texture2D(colortex1,texcoord);
		vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y));
		vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w));

		vec3 albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));
		vec3 normal = mat3(gbufferModelViewInverse) * decode(dataUnpacked0.yw);

		vec2 lightmap = dataUnpacked1.yz;
		lightmap *= lightmap;
		bool translucent = abs(dataUnpacked1.w-0.5) <0.01;

		float NdotL = lightCol.a*dot(normal,sunVec);

		float diffuseSun = clamp(NdotL,0.,1.0);
		float shading = 1.0;

		//custom shading model for translucent objects
		if (translucent) diffuseSun = diffuseSun+(0.5*-NdotL+0.5+abs(NdotL)*pow(clamp(lightCol.a*dot(np3,sunVec),0.0,1.),60.)*10.);

		//compute shadows only if not backface
		if (diffuseSun > 0.001) {

			vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
			projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

			//apply distortion
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor/0.92;
			//do shadows only if on shadow map
			if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 3.0){
				float diffthresh = translucent? 0.0005 : (facos(diffuseSun)*2.0+0.05)*0.014*0.06/distortFactor/distortFactor;

				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5);
				shading = 0.0;

				#ifdef VPS
					mat2 noiseM = mat2( cos( noise*3.14159265359*2.0 ), -sin( noise*3.14159265359*2.0 ),
					   sin( noise*3.14159265359*2.0 ), cos( noise*3.14159265359*2.0 )
						);
					shading = 0.0;
					const float mult = 14.;
					float avgBlockerDepth = 0.0;
					vec2 scales = vec2(0.0,50.);
					float blockerCount = 0.0;
					float rdMul = distortFactor*((mult+1.412)*0.2/shadowMapResolution);
					float diffthreshM = diffthresh*mult*0.003*distortFactor;
					for(int i = 0; i < 8; i++){
						vec2 offsetS = noiseM*distortFactor*0.2*shadowOffsets[i];

						vec4 d4 = textureGather( shadow, projectedShadowPosition.xy+offsetS*rdMul, 0);
						vec4 b4  = step(d4,vec4(projectedShadowPosition.z-length(offsetS)*diffthreshM-diffthreshM));

						blockerCount += dot(b4, vec4(1.0));
						avgBlockerDepth += dot( d4, b4 );
					}
					if (blockerCount >= 0.9)
						avgBlockerDepth /= blockerCount;
					else {
						avgBlockerDepth = projectedShadowPosition.z;
					}
					float ssample = max(projectedShadowPosition.z - avgBlockerDepth,0.0)*1000.*2.5/2;
					float avgdepth = clamp(ssample, scales.x, scales.y)/(scales.y);

					avgdepth = avgdepth*mult+1.;

						shading=0.0;
						for(int i = 0; i < 8; i++){
							vec2 offsetS = noiseM*avgdepth*distortFactor*0.2*shadowOffsets[i];

							float weight = 1.412+length(offsetS)*2.;
							shading += manualShadowFilter(projectedShadowPosition.xy,offsetS/shadowMapResolution, translucent, diffthresh, projectedShadowPosition.z);
						}

					shading = 1.0-shading/8.0;
				#endif


				#ifdef PCF

				mat2 noiseM = mat2( cos( noise*3.14159265359*2.0 ), -sin( noise*3.14159265359*2.0 ),
								   sin( noise*3.14159265359*2.0 ), cos( noise*3.14159265359*2.0 )
									);


				for(int i = 0; i < 8; i++){
					vec2 offsetS = shadowOffsets[i];

					float weight = 1.0+length(offsetS)*2.0*distortFactor*0.2;
					shading += shadow2D(shadow,vec3(projectedShadowPosition + vec3((noiseM*offsetS)*(distortFactor*0.2*2.0/shadowMapResolution),-diffthresh*weight))).x/8.0;
					}
				#endif

				#ifndef PCF
				#ifndef VPS
				projectedShadowPosition.z -= diffthresh*2.;
				shading = shadow2D(shadow,vec3(projectedShadowPosition)).x;
				#endif
				#endif
			}
		#ifdef SCREENSPACE_CONTACT_SHADOWS
			if (shading > 0.005){
			vec3 vec = lightCol.a*normalize(sunPosition);
			shading *= rayTraceShadow(vec,fragpos,bayer128(gl_FragCoord.xy),float(translucent));
			}
		#endif
		}

		//strong highlight near lightsource + soft light
		float torch_lightmap = ((lightmap.x*lightmap.x)*(lightmap.x*lightmap.x))*(lightmap.x*20.)+lightmap.x;


		//apply ambient light, which have been computed for each block side
		//interpolate between sides for non-blocks

		//make sure that the sum of the coefficients is equal to 1
		vec3 ambientCoefs = normal/dot(abs(normal),vec3(1.));

		vec3 ambientLight = ambientUp*clamp(ambientCoefs.y,0.,1.);
		ambientLight += ambientDown*clamp(-ambientCoefs.y,0.,1.);
		ambientLight += ambientRight*clamp(ambientCoefs.x,0.,1.);
		ambientLight += ambientLeft*clamp(-ambientCoefs.x,0.,1.);
		ambientLight += ambientB*clamp(ambientCoefs.z,0.,1.);
		ambientLight += ambientF*clamp(-ambientCoefs.z,0.,1.);





		//combine all light sources (direct+ambient+torch+minimum ambient)
		ambientLight = pow(lightmap.y,2.4)*(ambientLight*(1.06+float(translucent)*0.1))+ vec3(TORCH_R,TORCH_G,TORCH_B)*torch_lightmap*0.08*TORCH_AMOUNT+0.0006;


		//combine all light sources
		color = (lightCol.rgb*(shading*diffuseSun)*(isEyeInWater == 1? lightmap.y : 1.0) + ambientLight)*albedo*1.4;
		//color = ambientLight;

	}

	//dither output to avoid banding
	gl_FragData[0] = vec4(fp10Dither(color*10.,triangularize(noise)),1.);
/* DRAWBUFFERS:3 */
}
