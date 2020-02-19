#version 120

uniform sampler2D tex;

varying vec3 texcoord;
varying vec4 color;


void main() {

	vec4 texrgb = texture2D(tex, texcoord.st)*color;


	gl_FragData[0] = vec4(normalize(texrgb.rgb)*pow(length(texrgb.rgb),1/2.2) ,texture2D(tex, texcoord.st).a)*texcoord.z;

}