#version 120
//Vertical bilateral blur for volumetric fog
varying vec2 texcoord;
uniform sampler2D depthtex0;
uniform sampler2D colortex0;
uniform float near;
uniform float far;
uniform vec2 texelSize;
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}


vec4 ssaoVL_blur(vec2 tex, vec2 dir,float cdepth)
{
	

	vec2 step = dir*texelSize;



	
	vec4 res = vec4(0.0);
	float total_weights = 0.;
	
		
		vec4 sp = texture2D(colortex0, tex - 2.0*step);
		float linD = abs(cdepth-ld(texture2D(depthtex0,tex - 2.0*step).x)*far);
		float ssaoThresh = linD < 7.5 ? 1.0 : 0.;
		float weight = (ssaoThresh);
		res += sp * weight;
		total_weights += weight;
	
		sp = texture2D(colortex0, tex - step);
		linD = abs(cdepth-ld(texture2D(depthtex0,tex - step).x)*far);
		ssaoThresh = linD < 7.5 ? 1.0 : 0.;
		weight = (ssaoThresh);
		res += sp * weight;
		total_weights += weight;
		
		sp = texture2D(colortex0, tex + step);
		linD = abs(cdepth-ld(texture2D(depthtex0,tex + step).x)*far);
		ssaoThresh = linD < 7.5 ? 1.0 : 0.;
		weight = (ssaoThresh);
		res += sp * weight;
		total_weights += weight;
		
		sp = texture2D(colortex0, tex + 2.*step);
		linD = abs(cdepth-ld(texture2D(depthtex0,tex + 2.*step).x)*far);
		ssaoThresh = linD < 7.5 ? 1.0 : 0.;
		weight = (ssaoThresh);
		res += sp * weight;
		total_weights += weight;
		

		
		res += texture2D(colortex0, texcoord);
		total_weights += 1.0;
		
	res /= total_weights;

	return res;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
void main() {
	
float Depth = texture2D(depthtex0, texcoord).x;


vec4 blur = vec4(0.);
	Depth = ld(Depth);
	blur = ssaoVL_blur(texcoord,vec2(0.0,1.0),Depth*far);


/* DRAWBUFFERS:0 */

gl_FragData[0]=blur;
gl_FragData[0].rgb = clamp(gl_FragData[0].rgb,0.0,65000.);
}
