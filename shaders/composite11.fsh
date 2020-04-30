#version 120
//downsample 1st pass (half res) for bloom

varying vec2 texcoord;
uniform sampler2D colortex5;

uniform vec2 texelSize;

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main(){
	
	/* DRAWBUFFERS:3 */
	vec2 quarterResTC=(floor(gl_FragCoord.xy)*2.+.5)*texelSize;
	
	gl_FragData[0]=texture2D(colortex5,quarterResTC-.5*vec2(texelSize.x,texelSize.y))/4.*.5;
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+2.*vec2(texelSize.x,texelSize.y))/4.*.5;
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+vec2(-.5*texelSize.x,2.*texelSize.y))/4.*.5;
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+vec2(2.*texelSize.x,-.5*texelSize.y))/4.*.5;
	
	gl_FragData[0]+=texture2D(colortex5,quarterResTC-1.5*vec2(texelSize.x,texelSize.y))/4.*.125;
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+.5*vec2(texelSize.x,texelSize.y))*.125;
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+vec2(.5*texelSize.x,-1.5*texelSize.y))/2*.125;
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+vec2(-1.5*texelSize.x,.5*texelSize.y))/2*.125;
	
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+vec2(2.5*texelSize.x,-1.5*texelSize.y))/4.*.125;
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+vec2(2.5*texelSize.x,.5*texelSize.y))/2.*.125;
	
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+vec2(2.5*texelSize.x,2.5*texelSize.y))/4.*.125;
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+vec2(2.5*texelSize.x,.5*texelSize.y))/2.*.125;
	
	gl_FragData[0]+=texture2D(colortex5,quarterResTC+vec2(2.5*texelSize.x,-1.5*texelSize.y))/2.*.125;
	
	gl_FragData[0].rgb=clamp(gl_FragData[0].rgb,0.,65000.);
	
	if(max(gl_FragCoord.x*texelSize.x,gl_FragCoord.y*texelSize.y)>.5)gl_FragData[0].rgb=vec3(0.);
	
}
