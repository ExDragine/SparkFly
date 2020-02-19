#version 120
#extension GL_EXT_gpu_shader4 : enable

#define PCF
#define MIN_LIGHT_AMOUNT 1.0 //[0.0 0.5 1.0 1.5 2.0 3.0 4.0 5.0]

#define TORCH_AMOUNT 1.0 //[0.0 0.5 0.75 1. 1.2 1.4 1.6 1.8 2.0]
#define TORCH_R 1.0 //[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define TORCH_G 0.42 //[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.42 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define TORCH_B 0.11 //[0.0 0.05 0.1 0.11 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

const int shadowMapResolution = 2048; //[512 768 1024 1536 2048 3172 4096 8192]


varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

#define SHADOW_MAP_BIAS 0.8

uniform sampler2D texture;
uniform sampler2DShadow shadow;

uniform vec4 lightCol;
uniform vec3 sunVec;
uniform vec3 upVec;

uniform vec2 texelSize;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform float sunElevation;
uniform float rainStrength;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
float interleaved_gradientNoise(float temporal){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)+temporal);
	return noise;
}

#ifdef PCF
const vec2 shadowOffsets[4] = vec2[4](vec2( 0.1250,  0.0000 ),
vec2( -0.1768, -0.1768 ),
vec2( -0.0000,  0.3750 ),
vec2(  0.3536, -0.3536 )
);
#endif
float facos(float sx){
    float x = clamp(abs( sx ),0.,1.);
    float a = sqrt( 1. - x ) * ( -0.16882 * x + 1.56734 );
    return sx > 0. ? a : 3.14159265359 - a;
}	
#define SHADOW_MAP_BIAS 0.8
float calcDistort(vec2 worlpos){
	
	vec2 pos = worlpos * 1.165;
	vec2 posSQ = pos*pos;
	
	float distb = pow(posSQ.x*posSQ.x*posSQ.x + posSQ.y*posSQ.y*posSQ.y, 1.0 / 6.0);
	return 1.08695652/((1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS);
}	
			
vec2 tapLocation(int sampleNumber, float spinAngle,int nb, float nbRot)
{
	float startJitter = (spinAngle/6.28);
    float alpha = sqrt(sampleNumber + startJitter/nb );
    float angle = alpha * (nbRot * 6.28) + spinAngle*2.;

    float ssR = alpha;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);
	
    return vec2(cos_v, sin_v)*ssR;
}	
uniform int framemod8;
uniform int framecouter;
		const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);
									
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
						
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:2 */
void main() {

	gl_FragData[0] = color;
	vec2 tempOffset=offsets[framemod8];
	
	if (gl_FragData[0].a>0.1){
		vec3 albedo = toLinear(gl_FragData[0].rgb*color.rgb);
		
		vec3 normal = normalMat.xyz;
		vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));



		float NdotL = lightCol.a*dot(normal,sunVec);
		float NdotU = dot(upVec,normal);
		float diffuseSun = clamp(NdotL,0.0f,1.0f);
		float skyLight = (NdotU*0.4+1.0)*(1.0-rainStrength*0.8);
		vec3 direct = lightCol.rgb;


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
				const float sr = 1024./shadowMapResolution;
				float diffthresh = (facos(diffuseSun)*0.006*sr+0.00006*sr)/(distortFactor*distortFactor);	

				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/3.0) + vec3(0.5,0.5,0.5);
				
				#ifdef PCF

				float noise = interleaved_gradientNoise(tempOffset.x*0.5+0.5);


				vec2 offsetS = vec2(cos( noise*3.14159265359*2.0 ),sin( noise*3.14159265359*2.0 ));

				float shading = shadow2D_bicubic(shadow,vec3(projectedShadowPosition + vec3(0.0,0.0,-diffthresh*1.2)));
				#endif

				
				#ifndef PCF
				projectedShadowPosition.z -= diffthresh;
				float shading = shadow2D(shadow,vec3(projectedShadowPosition)).x;

				#endif
				
				direct *= shading;
			}

		}
		
		direct *= (diffuseSun*lmtexcoord.w)*10.;
	
		float torch_lightmap = ((lmtexcoord.z*lmtexcoord.z)*(lmtexcoord.z*lmtexcoord.z))*(lmtexcoord.z*20.)+lmtexcoord.z;
	
		vec3 ambient = (lightCol.a*sunElevation)*(-NdotL*0.45+0.9)*lightCol.rgb*0.6 + (skyLight*skyIntensity)*vec3(0.65,0.7,1.)*30. + skyIntensityNight*vec3(0.09,0.1,0.15)/1.5;
	
		vec3 diffuseLight = direct + (lmtexcoord.w)*ambient + vec3(TORCH_R,TORCH_G,TORCH_B)*torch_lightmap*0.8*TORCH_AMOUNT + 0.0006*MIN_LIGHT_AMOUNT;

		vec3 color = diffuseLight*albedo*1.4;
		
		gl_FragData[0].rgb = color;
	}



}