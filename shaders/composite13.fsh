#version 120
//6 Horizontal gaussian blurs and horizontal downsampling

varying vec2 texcoord;
uniform sampler2D colortex6;
uniform vec2 texelSize;

vec3 gauss1D(vec2 coord,vec2 dir,float alpha,int maxIT){
	vec4 tot=vec4(0.);
	float maxTC=.25;
	float minTC=0.;
	for(int i=-maxIT;i<maxIT+1;i++){
		float weight=exp(-i*i*alpha*4.);
		//here we take advantage of bilinear filtering for 2x less sample, as a side effect the gaussian won't be totally centered for small blurs
		vec2 spCoord=coord+dir*texelSize*(2.*i+.5);
		tot+=vec4(texture2D(colortex6,spCoord).rgb*float(spCoord.x>minTC&&spCoord.x<maxTC),1.)*weight;
	}
	return tot.rgb/tot.a;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main(){
	/* DRAWBUFFERS:6 */
	
	vec2 gaussDir=vec2(1.,0.);
	gl_FragData[0].rgb=vec3(0.);
	vec2 tc2=texcoord*vec2(2.,1.)/2.;
	if(tc2.x<1.&&tc2.y<1.)
	gl_FragData[0].xyz=gauss1D(tc2/2,gaussDir,.16,0);
	
	vec2 tc4=texcoord*vec2(4.,1.)/2.-vec2(.5+4.*texelSize.x,0.)*2.;
	if(tc4.x>0.&&tc4.y>0.&&tc4.x<1.&&tc4.y<1.)
	gl_FragData[0].xyz=gauss1D(tc4/2,gaussDir,.16,3);
	
	vec2 tc8=texcoord*vec2(8.,1.)/2.-vec2(.75+8.*texelSize.x,0.)*4.;
	if(tc8.x>0.&&tc8.y>0.&&tc8.x<1.&&tc8.y<1.)
	gl_FragData[0].xyz=gauss1D(tc8/2,gaussDir,.035,6);
	
	vec2 tc16=texcoord*vec2(8.,1./2.)-vec2(.875+12.*texelSize.x,0.)*8.;
	if(tc16.x>0.&&tc16.y>0.&&tc16.x<1.&&tc16.y<1.)
	gl_FragData[0].xyz=gauss1D(tc16/2,gaussDir,.0085,12);
	
	vec2 tc32=texcoord*vec2(16.,1./2.)-vec2(.9375+16.*texelSize.x,0.)*16.;
	if(tc32.x>0.&&tc32.y>0.&&tc32.x<1.&&tc32.y<1.)
	gl_FragData[0].xyz=gauss1D(tc32/2,gaussDir,.002,28);
	
	vec2 tc64=texcoord*vec2(32.,1./2.)-vec2(.96875+20.*texelSize.x,0.)*32.;
	if(tc64.x>0.&&tc64.y>0.&&tc64.x<1.&&tc64.y<1.)
	gl_FragData[0].xyz=gauss1D(tc64/2,gaussDir,.0005,60);
	
	gl_FragData[0].rgb=clamp(gl_FragData[0].rgb,0.,65000.);
}
