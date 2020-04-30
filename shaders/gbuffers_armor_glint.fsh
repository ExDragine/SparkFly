#version 120
#extension GL_EXT_gpu_shader4:enable

const int shadowMapResolution=2048;//[512 768 1024 1536 2048 3172 4096 8192]

#define MIN_LIGHT_AMOUNT 1.0//[0.0 0.5 1.0 1.5 2.0 3.0 4.0 5.0]

#define TORCH_AMOUNT 1.0//[0.0 0.5 0.75 1.0 1.2 1.4 1.6 1.8 2.0]
#define TORCH_R 1.0//[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define TORCH_G .42//[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.42 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define TORCH_B .11//[0.0 0.05 0.1 0.11 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;

#define SHADOW_MAP_BIAS .8

uniform sampler2D texture;

uniform vec4 lightCol;
uniform vec3 sunVec;

uniform vec2 texelSize;
uniform float skyIntensityNight;
uniform float skyIntensity;
uniform float sunElevation;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB*(sRGB*(sRGB*.305306011+.682171111)+.012522878);
}

#define diagonal3(m)vec3((m)[0].x,(m)[1].y,m[2].z)
#define projMAD(m,v)(diagonal3(m)*(v)+(m)[3].xyz)
vec3 toScreenSpace(vec3 p){
	vec4 iProjDiag=vec4(gbufferProjectionInverse[0].x,gbufferProjectionInverse[1].y,gbufferProjectionInverse[2].zw);
	vec3 p3=p*2.-1.;
	vec4 fragposition=iProjDiag*p3.xyzz+gbufferProjectionInverse[3];
	return fragposition.xyz/fragposition.w;
}
float interleaved_gradientNoise(){
	vec2 coord=gl_FragCoord.xy;
	float noise=fract(52.9829189*fract(.06711056*coord.x+.00583715*coord.y));
	return noise;
}

float facos(float sx){
	float x=clamp(abs(sx),0.,1.);
	float a=sqrt(1.-x)*(-.16882*x+1.56734);
	return sx>0.?a:3.14159265359-a;
}
#define SHADOW_MAP_BIAS .8
float calcDistort(vec2 worlpos){
	
	vec2 pos=worlpos*1.165;
	vec2 posSQ=pos*pos;
	
	float distb=pow(posSQ.x*posSQ.x*posSQ.x+posSQ.y*posSQ.y*posSQ.y,1./6.);
	return 1.08695652/((1.-SHADOW_MAP_BIAS)+distb*SHADOW_MAP_BIAS);
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:2 */
void main(){
	
	gl_FragData[0]=texture2D(texture,lmtexcoord.xy);
	
	vec3 albedo=toLinear(gl_FragData[0].rgb*color.rgb);
	
	vec3 normal=normalMat.xyz;
	vec3 fragpos=toScreenSpace(gl_FragCoord.xyz*vec3(texelSize,1.));
	
	float NdotL=lightCol.a*dot(normal,sunVec);
	
	float diffuseSun=clamp(NdotL,0.f,1.f);
	
	vec3 direct=lightCol.rgb;
	
	direct*=(diffuseSun*lmtexcoord.w)*10.;
	
	float torch_lightmap=((lmtexcoord.z*lmtexcoord.z)*(lmtexcoord.z*lmtexcoord.z))*(lmtexcoord.z*20.)+lmtexcoord.z;
	
	vec3 ambient=(lightCol.a*sunElevation)*(-NdotL*.45+.9)*lightCol.rgb*.6+(1.2*skyIntensity)*vec3(.65,.7,1.)*30.+skyIntensityNight*vec3(.09,.1,.15)/1.5;
	
	vec3 diffuseLight=(lmtexcoord.w)*ambient+vec3(TORCH_R,TORCH_G,TORCH_B)*torch_lightmap*.08*TORCH_AMOUNT+.0006*MIN_LIGHT_AMOUNT;
	
	vec3 col=dot(diffuseLight,vec3(1./3))*albedo;
	
	gl_FragData[0].rgb=col*color.a;
	gl_FragData[0].a=0.;
	
}