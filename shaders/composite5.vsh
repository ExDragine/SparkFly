#version 120
#extension GL_EXT_gpu_shader4:enable
#define Exposure_Speed 1.25//[0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 4.0 5.0]

varying vec2 texcoord;
varying float exposureA;
varying float avgBrightness;

uniform sampler2D colortex5;
uniform float frameTimeCounter;
uniform float frameTime;
uniform float nightVision;
#define fsign(a)(clamp((a)*1e35,0.,1.)*2.-1.)
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
float luma(vec3 color){
	return sqrt(dot(color*color,vec3(.299,.587,.114)));
}

vec2 tapLocation(int sampleNumber,int nb,float nbRot)
{
	float alpha=float(sampleNumber+fract(frameTimeCounter))/nb;
	float angle=(frameTimeCounter+alpha)*(nbRot*6.28);
	
	float ssR=alpha;
	float sin_v,cos_v;
	
	sin_v=sin(angle);
	cos_v=cos(angle);
	
	return vec2(cos_v,sin_v)*ssR;
}
void main(){
	
	gl_Position=ftransform();
	texcoord=gl_MultiTexCoord0.xy;
	float avgLuma=0.;
	float m2=0.;
	int n=200;
	
	for(int i=0;i<n;i++){
		vec2 tc=tapLocation(i,n,30.)*.3+.5;
		float cLuma=luma(texture2D(colortex5,tc).xyz);
		avgLuma+=cLuma;
		m2+=cLuma*cLuma;
		
	}
	avgLuma=avgLuma/n;
	m2=m2/n;
	float sigma=sqrt(m2-avgLuma*avgLuma);
	float cMin=avgLuma-sigma;
	float cMax=avgLuma+sigma;
	vec2 avgExp=vec2(0.);
	for(int i=0;i<n;i++){
		vec2 tc=tapLocation(i,n,30.)*.3+.5;
		float cLuma=luma(texture2D(colortex5,tc).xyz);
		avgExp+=vec2(pow(cLuma,1/2.2),1.);
		
	}
	avgExp.x=pow(avgExp.x/avgExp.y,2.2);
	
	avgBrightness=clamp(mix(avgExp.x,texelFetch2D(colortex5,ivec2(0),0).g,.95),.00003051757,65000.);
	float targetExposure=.27*pow(avgBrightness,-1./(2.2-nightVision*.6));
	float currentExposure=clamp(pow(texelFetch2D(colortex5,ivec2(0),0).r,1./3.),.03125,3.5*(1.+nightVision*19.));
	
	float a=.05;
	float rad=sqrt(currentExposure*a);
	float rtarget=sqrt(targetExposure*a);
	float dir=sign(rtarget-rad);
	float dist=abs(rtarget-rad);
	float maxApertureChange=.0002*frameTime/.016666*Exposure_Speed;
	
	maxApertureChange*=1.+nightVision*4.;
	rad=rad+dir*min(dist,maxApertureChange);
	
	float exposureF=clamp(rad*rad/a,.03125,3.5*(1.+nightVision*19.));
	exposureA=exposureF;
}
