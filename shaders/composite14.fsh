#version 120
//6 Vertical gaussian blurs and vertical downsampling 


varying vec2 texcoord;
uniform sampler2D colortex6;
uniform vec2 texelSize;



vec3 gauss1D(vec2 coord,vec2 dir,float alpha,int maxIT){
	vec4 tot = vec4(0.);
	float maxTC = 0.25;
	float minTC = 0.;
	for (int i = -maxIT;i<maxIT+1;i++){
		float weight = exp(-i*i*alpha*4.0);
		vec2 spCoord = coord+dir*texelSize*(2.0*i+0.5);
		tot += vec4(texture2D(colortex6,spCoord).rgb*float(spCoord.y > minTC && spCoord.y < maxTC),1.0)*weight;
	}
	return  tot.rgb/tot.a;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {
/* DRAWBUFFERS:6 */


vec2 gaussDir = vec2(0.0,1.0);
gl_FragData[0].rgb = vec3(0.0);
vec2 tc2 = texcoord*vec2(2.0,1.);
if (tc2.x < 1.0 && tc2.y <1.0)
gl_FragData[0].xyz = gauss1D(texcoord/vec2(2.0,4.0),gaussDir,0.16,0);

vec2 tc4 = texcoord*vec2(4.0,2.)-vec2(0.5+4.0*texelSize.x,0.)*4.0;
if (tc4.x > 0.0 && tc4.y > 0.0 && tc4.x < 1.0 && tc4.y <1.0)
gl_FragData[0].xyz = gauss1D(texcoord/vec2(2.0,2.0),gaussDir,0.16,3);

vec2 tc8 = texcoord*vec2(8.0,4.)-vec2(0.75+8.*texelSize.x,0.)*8.0;
if (tc8.x > 0.0 && tc8.y > 0.0 && tc8.x < 1.0 && tc8.y <1.0)
gl_FragData[0].xyz = gauss1D(texcoord*vec2(1.0,2.0)/vec2(2.0,2.0),gaussDir,0.035,6);

vec2 tc16 = texcoord*vec2(16.0,8.)-vec2(0.875+12.*texelSize.x,0.)*16.0;
if (tc16.x > 0.0 && tc16.y > 0.0 && tc16.x < 1.0 && tc16.y <1.0)
gl_FragData[0].xyz = gauss1D(texcoord*vec2(1.0,4.0)/vec2(2.0,2.0),gaussDir,0.0085,12);

vec2 tc32 = texcoord*vec2(32.0,16.)-vec2(0.9375+16.*texelSize.x,0.)*32.0;
if (tc32.x > 0.0 && tc32.y > 0.0 && tc32.x < 1.0 && tc32.y <1.0)
gl_FragData[0].xyz = gauss1D(texcoord*vec2(1.0,8.0)/vec2(2.0,2.0),gaussDir,0.002,30);

vec2 tc64 = texcoord*vec2(64.0,32.)-vec2(0.96875+20.*texelSize.x,0.)*64.0;
if (tc64.x > 0.0 && tc64.y > 0.0 && tc64.x < 1.0 && tc64.y <1.0)
gl_FragData[0].xyz = gauss1D(texcoord*vec2(1.0,16.0)/vec2(2.0,2.0),gaussDir,0.0005,60);

gl_FragData[0].rgb = clamp(gl_FragData[0].rgb,0.0,65000.);
}
