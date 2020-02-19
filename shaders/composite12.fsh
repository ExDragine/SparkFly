#version 120
//downsample 2nd pass (quarter res) for bloom

varying vec2 texcoord;
uniform sampler2D colortex3;

uniform vec2 texelSize;



//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

/* DRAWBUFFERS:6 */
vec2 quarterResTC = (floor(gl_FragCoord.xy)*2.+0.5)*texelSize;


		gl_FragData[0] = texture2D(colortex3,quarterResTC-0.5*vec2(texelSize.x,texelSize.y))/4.*0.5;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+2.0*vec2(texelSize.x,texelSize.y))/4.*0.5;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(-0.5*texelSize.x,2.0*texelSize.y))/4.*0.5;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(2.0*texelSize.x,-0.5*texelSize.y))/4.*0.5;
		
		gl_FragData[0] += texture2D(colortex3,quarterResTC-1.5*vec2(texelSize.x,texelSize.y))/4.*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+0.5*vec2(texelSize.x,texelSize.y))*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(0.5*texelSize.x,-1.5*texelSize.y))/2*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(-1.5*texelSize.x,0.5*texelSize.y))/2*0.125;

		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(2.5*texelSize.x,-1.5*texelSize.y))/4.*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(2.5*texelSize.x,0.5*texelSize.y))/2.*0.125;		
		
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(2.5*texelSize.x,2.5*texelSize.y))/4.*0.125;
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(2.5*texelSize.x,0.5*texelSize.y))/2.*0.125;				
		
		gl_FragData[0] += texture2D(colortex3,quarterResTC+vec2(2.5*texelSize.x,-1.5*texelSize.y))/2.*0.125;		

		gl_FragData[0].rgb = clamp(gl_FragData[0].rgb,0.0,65000.);



}
