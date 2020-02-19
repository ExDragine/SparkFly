#version 120
//Horizontal bilateral blur for volumetric fog + Forward rendered objects + Draw volumetric fog
#extension GL_EXT_gpu_shader4 : enable



varying vec2 texcoord;
uniform sampler2D depthtex0;
uniform sampler2D colortex3;
uniform sampler2D colortex2;
uniform sampler2D colortex0;


uniform float far;
uniform float near;

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

void main() {
/* DRAWBUFFERS:3 */
float Depth = texture2D(depthtex0, texcoord).x;
	vec3 color = texture2D(colortex3,texcoord).rgb;
	vec4 transparencies = texture2D(colortex2,texcoord);
	color = color*(1.0-transparencies.a)+transparencies.rgb;

		vec4 vl = ssaoVL_blur(texcoord,vec2(1.0,0.0),ld(Depth)*far);
		color *= vl.a/50000.;
		color += vl.rgb;

	gl_FragData[0].rgb = color;
	gl_FragData[0].rgb = clamp(gl_FragData[0].rgb,0.0,65000.);

}