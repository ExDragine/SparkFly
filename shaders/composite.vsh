#version 120
#extension GL_EXT_gpu_shader4 : enable

varying vec2 texcoord;


//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

void main() {

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.xy;

}
