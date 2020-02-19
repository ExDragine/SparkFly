#version 120
//Temporal Anti-Aliasing + Dynamic exposure calculations (vertex shader)

#extension GL_EXT_gpu_shader4 : enable

#define TAA

#define FAST_TAA //disables bicubic resampling and closest velocity, improves fps especially at high resolutions

//TAA OPTIONS
//#define NO_CLIP	//introduces a lot of ghosting but the image will be sharper and without flickering (good for screenshots)
#define BLEND_FACTOR 0.1 //[0.01 0.02 0.03 0.04 0.05 0.06 0.08 0.1 0.12 0.14 0.16] higher values = more flickering but sharper image, lower values = less flickering but the image will be blurrier
#define BICUBIC_RESAMPLING //Can cause artifacts on high contrast edges, but looks way better in motion. Performance cost is a bit higher.
#define FAST_BICUBIC
#define MOTION_REJECTION 0.15 //[0.0 0.05 0.1 0.15 0.2 0.25 0.3] //Higher values=sharper image in motion at the cost of flickering
#define FLICKER_REDUCTION 0.92 //[0.0 0.85 0.9 0.92 0.94 0.96 0.98 1.0]  //Higher values = Blurrier image but greatly reduces flickering (0-1 range)
#define CLOSEST_VELOCITY //improves edge quality in motion at the cost of performance
#define SMOOTHESTSTEP_INTERPOLATION //Only if not using bicubic resampling, reduces blurring in motion but might cause some "wobbling" on the image

#ifdef FAST_TAA
	#undef BICUBIC_RESAMPLING
	#undef CLOSEST_VELOCITY
#endif

const int noiseTextureResolution = 32;

const float ambientOcclusionLevel = 0.42; //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
const float	sunPathRotation	= -40.;	//[0. -5. -10. -15. -20. -25. -30. -35. -40. -45. -50. -55. -60. -70. -80. -90.]

const int shadowMapResolution = 2048; //[512 768 1024 1536 2048 3172 4096 8192]
const float shadowDistance = 128.0;		//draw distance of shadows
const float shadowDistanceRenderMul = -1.;
const bool shadowHardwareFiltering = true;
/*
const int colortex0Format = RGBA16F;				// 1/4 res clouds (deferred->deferred6) VL (composite->composite4)
const int colortex1Format = RGBA16;					//terrain gbuffer (gbuffer->deferred6)
const int colortex2Format = RGBA16F;				//forward + transparencies (gbuffer->composite4)
const int colortex3Format = R11F_G11F_B10F;			//frame buffer (deferred6->composite6)
const int colortex4Format = RGBA16F;				//1/8 res shadow depth + shadow color + quarter res depth(deferred1->gbuffer water)
const int colortex5Format = R11F_G11F_B10F;			//TAA (everything)
const int colortex6Format = R11F_G11F_B10F;			//additionnal buffer for bloom (composite3->final)

*/
//no need to clear the buffers, saves a few fps
const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex2Clear = true;
const bool colortex3Clear = false;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const bool colortex6Clear = true;


varying vec2 texcoord;
varying float exposureA;
varying float avgBrightness;

uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D colortex3;
uniform float frameTimeCounter;
uniform float viewHeight;
uniform float viewWidth;
uniform int frameCounter;
uniform vec3 previousCameraPosition;
uniform float frameTime;
uniform float nightVision;
uniform mat4 gbufferPreviousModelView;
#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)
#include "lib/projections.glsl"

#include "lib/color_transforms.glsl"


//using white noise for color dithering : gives a somewhat more "filmic" look when noise is visible
float nrand( vec2 n )
{
	return fract(sin(dot(n.xy, vec2(12.9898, 78.233)))* 43758.5453);
}

float triangWhiteNoise( vec2 n )
{

	float t = fract( frameTimeCounter );
	float rnd = nrand( n + 0.07*t );

    float center = rnd*2.0-1.0;
    rnd = center*inversesqrt(abs(center));
    rnd = max(-1.0,rnd);
    return rnd-sign(center);
}
vec3 int8Dither(vec3 color,vec2 tc01){
	float dither = triangWhiteNoise(tc01);
	return color + dither*exp2(-8.0);
}

vec3 fp10Dither(vec3 color,vec2 tc01){
	float dither = triangWhiteNoise(tc01);
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}
vec3 fp10Dither2(vec3 color,vec2 tc01){
	float dither = nrand(tc01+0.07*fract(frameTimeCounter));
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}

//returns the projected coordinates of the closest point to the camera in the 3x3 neighborhood
vec3 closestToCamera3x3()
{
	vec2 texelSize = 1.0/vec2(viewWidth,viewHeight);
	vec2 du = vec2(texelSize.x, 0.0);
	vec2 dv = vec2(0.0, texelSize.y);

	vec3 dtl = vec3(texcoord,0.) + vec3(-texelSize, texture2D(depthtex0, texcoord - dv - du).x);
	vec3 dtc = vec3(texcoord,0.) + vec3( 0.0, -texelSize.y, texture2D(depthtex0, texcoord - dv).x);
	vec3 dtr = vec3(texcoord,0.) +  vec3( texelSize.x, -texelSize.y, texture2D(depthtex0, texcoord - dv + du).x);

	vec3 dml = vec3(texcoord,0.) +  vec3(-texelSize.x, 0.0, texture2D(depthtex0, texcoord - du).x);
	vec3 dmc = vec3(texcoord,0.) + vec3( 0.0, 0.0, texture2D(depthtex0, texcoord).x);
	vec3 dmr = vec3(texcoord,0.) + vec3( texelSize.x, 0.0, texture2D(depthtex0, texcoord + du).x);

	vec3 dbl = vec3(texcoord,0.) + vec3(-texelSize.x, texelSize.y, texture2D(depthtex0, texcoord + dv - du).x);
	vec3 dbc = vec3(texcoord,0.) + vec3( 0.0, texelSize.y, texture2D(depthtex0, texcoord + dv).x);
	vec3 dbr = vec3(texcoord,0.) + vec3( texelSize.x, texelSize.y, texture2D(depthtex0, texcoord + dv + du).x);

	vec3 dmin = dmc;

	dmin = dmin.z > dtc.z? dtc : dmin;
	dmin = dmin.z > dtr.z? dtr : dmin;

	dmin = dmin.z > dml.z? dml : dmin;
	dmin = dmin.z > dtl.z? dtl : dmin;
	dmin = dmin.z > dmr.z? dmr : dmin;

	dmin = dmin.z > dbl.z? dbl : dmin;
	dmin = dmin.z > dbc.z? dbc : dmin;
	dmin = dmin.z > dbr.z? dbr : dmin;

	return dmin;
}

//Modified texture interpolation from inigo quilez
vec4 smoothfilter(in sampler2D tex, in vec2 uv)
{
	vec2 textureResolution = vec2(viewWidth,viewHeight);
	uv = uv*textureResolution + 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = fract( uv );
	#ifndef SMOOTHESTSTEP_INTERPOLATION
	uv = iuv + (fuv*fuv)*(3.0-2.0*fuv);
	#endif
	#ifdef SMOOTHESTSTEP_INTERPOLATION
	uv = iuv + fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0);
	#endif
	uv = (uv - 0.5)/textureResolution;
	return texture2D( tex, uv);
}
//Due to low sample count we "tonemap" the inputs to preserve colors and smoother edges
vec3 weightedSample(sampler2D colorTex, vec2 texcoord){
	vec3 wsample = texture2D(colorTex,texcoord).rgb*0.017*exposureA;
	return wsample/(1.0+luma(wsample));

}


//from : https://gist.github.com/TheRealMJP/c83b8c0f46b63f3a88a5986f4fa982b1
vec4 SampleTextureCatmullRom(sampler2D tex, vec2 uv, vec2 texSize )
{
    // We're going to sample a a 4x4 grid of texels surrounding the target UV coordinate. We'll do this by rounding
    // down the sample location to get the exact center of our "starting" texel. The starting texel will be at
    // location [1, 1] in the grid, where [0, 0] is the top left corner.
    vec2 samplePos = uv * texSize;
    vec2 texPos1 = floor(samplePos - 0.5) + 0.5;

    // Compute the fractional offset from our starting texel to our original sample location, which we'll
    // feed into the Catmull-Rom spline function to get our filter weights.
    vec2 f = samplePos - texPos1;

    // Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
    // These equations are pre-expanded based on our knowledge of where the texels will be located,
    // which lets us avoid having to evaluate a piece-wise function.
    vec2 w0 = f * ( -0.5 + f * (1.0 - 0.5*f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5*f);
    vec2 w2 = f * ( 0.5 + f * (2.0 - 1.5*f) );
    vec2 w3 = f * f * (-0.5 + 0.5 * f);

    // Work out weighting factors and sampling offsets that will let us use bilinear filtering to
    // simultaneously evaluate the middle 2 samples from the 4x4 grid.
    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / (w1 + w2);

    // Compute the final UV coordinates we'll use for sampling the texture
    vec2 texPos0 = texPos1 - vec2(1.0);
    vec2 texPos3 = texPos1 + vec2(2.0);
    vec2 texPos12 = texPos1 + offset12;

    texPos0 /= texSize;
    texPos3 /= texSize;
    texPos12 /= texSize;

    vec4 result = vec4(0.0);
    result += texture2D(tex, vec2(texPos0.x,  texPos0.y)) * w0.x * w0.y;
    result += texture2D(tex, vec2(texPos12.x, texPos0.y)) * w12.x * w0.y;
    result += texture2D(tex, vec2(texPos3.x,  texPos0.y)) * w3.x * w0.y;

    result += texture2D(tex, vec2(texPos0.x,  texPos12.y)) * w0.x * w12.y;
    result += texture2D(tex, vec2(texPos12.x, texPos12.y)) * w12.x * w12.y;
    result += texture2D(tex, vec2(texPos3.x,  texPos12.y)) * w3.x * w12.y;

    result += texture2D(tex, vec2(texPos0.x,  texPos3.y)) * w0.x * w3.y;
    result += texture2D(tex, vec2(texPos12.x, texPos3.y)) * w12.x * w3.y;
    result += texture2D(tex, vec2(texPos3.x,  texPos3.y)) * w3.x * w3.y;

    return result;
}
//approximation from SMAA presentation from siggraph 2016
vec3 FastCatmulRom(sampler2D colorTex, vec2 texcoord, vec4 rtMetrics)
{
    vec2 position = rtMetrics.zw * texcoord;
    vec2 centerPosition = floor(position - 0.5) + 0.5;
    vec2 f = position - centerPosition;
    vec2 f2 = f * f;
    vec2 f3 = f * f2;

    float c = 0.9;
    vec2 w0 =        -c  * f3 +  2.0 * c         * f2 - c * f;
    vec2 w1 =  (2.0 - c) * f3 - (3.0 - c)        * f2         + 1.0;
    vec2 w2 = -(2.0 - c) * f3 + (3.0 -  2.0 * c) * f2 + c * f;
    vec2 w3 =         c  * f3 -                c * f2;

    vec2 w12 = w1 + w2;
    vec2 tc12 = rtMetrics.xy * (centerPosition + w2 / w12);
    vec3 centerColor = texture2D(colorTex, vec2(tc12.x, tc12.y)).rgb;

    vec2 tc0 = rtMetrics.xy * (centerPosition - 1.0);
    vec2 tc3 = rtMetrics.xy * (centerPosition + 2.0);
    vec4 color = vec4(texture2D(colorTex, vec2(tc12.x, tc0.y )).rgb, 1.0) * (w12.x * w0.y ) +
                   vec4(texture2D(colorTex, vec2(tc0.x,  tc12.y)).rgb, 1.0) * (w0.x  * w12.y) +
                   vec4(centerColor,                                      1.0) * (w12.x * w12.y) +
                   vec4(texture2D(colorTex, vec2(tc3.x,  tc12.y)).rgb, 1.0) * (w3.x  * w12.y) +
                   vec4(texture2D(colorTex, vec2(tc12.x, tc3.y )).rgb, 1.0) * (w12.x * w3.y );
	return color.rgb/color.a;

}


vec3 toClipSpace3Prev(vec3 viewSpacePosition) {
    return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 TAA_hq(){
	//Samples current frame 3x3 neighboorhood
	vec3 albedoCurrent0 = weightedSample(colortex3, texcoord);
    vec3 albedoCurrent1 = weightedSample(colortex3, texcoord + vec2(1.0/viewWidth,1.0/viewHeight));
	vec3 albedoCurrent2 = weightedSample(colortex3, texcoord + vec2(1.0/viewWidth,-1.0/viewHeight));
	vec3 albedoCurrent3 = weightedSample(colortex3, texcoord + vec2(-1.0/viewWidth,-1.0/viewHeight));
	vec3 albedoCurrent4 = weightedSample(colortex3, texcoord + vec2(-1.0/viewWidth,1.0/viewHeight));
	vec3 albedoCurrent5 = weightedSample(colortex3, texcoord + vec2(0.0/viewWidth,1.0/viewHeight));
	vec3 albedoCurrent6 = weightedSample(colortex3, texcoord + vec2(0.0/viewWidth,-1.0/viewHeight));
	vec3 albedoCurrent7 = weightedSample(colortex3, texcoord + vec2(-1.0/viewWidth,0.0/viewHeight));
	vec3 albedoCurrent8 = weightedSample(colortex3, texcoord + vec2(1.0/viewWidth,0.0/viewHeight));

	//use velocity from the nearest texel from camera in a 3x3 box in order to improve edge quality in motion
	#ifdef CLOSEST_VELOCITY
	vec3 closestToCamera = closestToCamera3x3();
	#endif

	#ifndef CLOSEST_VELOCITY
	vec3 closestToCamera = vec3(texcoord,texture2D(depthtex0,texcoord).x);
	#endif

	//reproject previous frame
	vec3 fragposition = toScreenSpace(closestToCamera);
	fragposition = mat3(gbufferModelViewInverse) * fragposition + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * fragposition + gbufferPreviousModelView[3].xyz;
	previousPosition = toClipSpace3Prev(previousPosition);
	vec2 velocity = previousPosition.xy - closestToCamera.xy;
	previousPosition.xy = texcoord + velocity;

	//to reduce error propagation caused by interpolation during history resampling, we will introduce back some aliasing in motion
	vec2 d = 0.5-abs(fract(previousPosition.xy*vec2(viewWidth,viewHeight)-texcoord*vec2(viewWidth,viewHeight))-0.5);
	#ifdef SMOOTHESTSTEP_INTERPOLATION
	d = d*d*d*(d*(d*6.0-15.0)+10.0);
	#endif
	#ifdef BICUBIC_RESAMPLING
	d = d*d*d*(d*(d*6.0-15.0)+10.0);
	#endif
	#ifndef SMOOTHESTSTEP_INTERPOLATION
	#ifndef BICUBIC_RESAMPLING
	d = d*d*(3.0-2.0*d);
	#endif
	#endif
	float mixFactor = (d.x+d.y)*MOTION_REJECTION;

	//reject history if off-screen
	if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0) mixFactor = 1.0;

	//Sample history
	#ifndef BICUBIC_RESAMPLING
	vec3 albedoPrev = smoothfilter(colortex5, previousPosition.xy).xyz*0.017*exposureA;
	albedoPrev /= 1.0+luma(albedoPrev);
	#endif
	#ifdef BICUBIC_RESAMPLING
	#ifdef FAST_BICUBIC
	vec3 albedoPrev = FastCatmulRom(colortex5, previousPosition.xy,vec4(1.0/viewWidth,1.0/viewHeight,viewWidth,viewHeight)).xyz*0.017*exposureA;
	#else
	vec3 albedoPrev = SampleTextureCatmullRom(colortex5, previousPosition.xy,vec2(viewWidth,viewHeight)).xyz*0.017*exposureA;
	#endif
	albedoPrev /= 1.0+luma(albedoPrev);
	#endif


	#ifndef NO_CLIP
	//Assuming the history color is a blend of the 3x3 neighborhood, we clamp the history to the min and max of each channel in the 3x3 neighborhood
	vec3 cMax = max(max(max(albedoCurrent0,albedoCurrent1),albedoCurrent2),max(albedoCurrent3,max(albedoCurrent4,max(albedoCurrent5,max(albedoCurrent6,max(albedoCurrent7,albedoCurrent8))))));
	vec3 cMin = min(min(min(albedoCurrent0,albedoCurrent1),albedoCurrent2),min(albedoCurrent3,min(albedoCurrent4,min(albedoCurrent5,min(albedoCurrent6,min(albedoCurrent7,albedoCurrent8))))));

	vec3 finalcAcc = clamp(albedoPrev,cMin,cMax);

	//increases blending factor if history is far away from aabb, reduces ghosting at the cost of some flickering
	float isclamped = abs(luma(albedoPrev)-luma(finalcAcc))/luma(cMax)*4.;

	//reduces blending factor if current texel is far from history, reduces flickering
	float lumDiff2 = abs(luma(albedoPrev)-luma(albedoCurrent0))/luma(cMax)*1.25;
	lumDiff2 = 1.0-clamp(lumDiff2*lumDiff2,0.,1.)*FLICKER_REDUCTION;

	//Blend current pixel with clamped history
	vec3 supersampled =  mix(finalcAcc,albedoCurrent0,clamp(BLEND_FACTOR*lumDiff2+isclamped+mixFactor+0.01,0.,1.));
	#endif


	#ifdef NO_CLIP
	vec3 supersampled =  mix(albedoPrev,albedoCurrent0,clamp(BLEND_FACTOR,0.,1.));
	#endif

	//De-tonemap
	return supersampled/(1.0-luma(supersampled))/0.017/exposureA;
}
#ifdef FAST_TAA

#endif
void main() {

/* DRAWBUFFERS:5 */
gl_FragData[0].a = 1.0;
	#ifdef TAA
	vec3 color = TAA_hq();
	gl_FragData[0].rgb = clamp(fp10Dither(color,texcoord),0.,65000.);
	#endif
	#ifndef TAA
	vec3 color = clamp(fp10Dither(texture2D(colortex3,texcoord).rgb,texcoord),0.,65000.);
	gl_FragData[0].rgb = color;
	color*=0.017*exposureA;
	#endif
	//Export exposure value on one pixel of the temporal buffer
	if(gl_FragCoord.x < 1.0 && gl_FragCoord.y <1.0) gl_FragData[0].rgb = fp10Dither2(vec3(exposureA*exposureA*exposureA,avgBrightness,0.),vec2(0.5));




}


