//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

float luma(vec3 color) {
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float A = 0.2;
float B = 0.25;
float C = 0.10;
float D = 0.35;
float E = 0.02;
float F = 0.3;

vec3 Tonemap_Filmic_UC2(vec3 linearColor, float linearWhite,
	float A, float B, float C, float D, float E, float F) {

	// Uncharted II configurable tonemapper.

	// A = shoulder strength
	// B = linear strength
	// C = linear angle
	// D = toe strength
	// E = toe numerator
	// F = toe denominator
	// Note: E / F = toe angle
	// linearWhite = linear white point value

	vec3 x = linearColor;
	vec3 color = ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
	
	x = vec3(linearWhite);
	vec3 white = ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
	
	return color / white;
}
vec3 Tonemap_Filmic_UC2Default(vec3 linearColor) {

	// Uncharted II fixed tonemapping formula.
	// Gives a warm and gritty image, saturated shadows and bleached highlights.

	return pow(Tonemap_Filmic_UC2(linearColor*4., 11.2, 0.22, 0.3, 0.1, 0.4, 0.025, 0.30),vec3(1.0/2.232));
}
vec3 reinhard(vec3 x){
x *= 1.66;
return pow(x/(1.0+x),vec3(1.0/2.2));
}
vec3 Tonemap_Aces(vec3 color) {

	// ACES filmic tonemapper with highlight desaturation ("crosstalk").
	// Based on the curve fit by Krzysztof Narkowicz.
	// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/

	const float slope = 12.0f; // higher values = slower rise.

	// Store grayscale as an extra channel.
	vec4 x = vec4(
		// RGB
		color.r, color.g, color.b,
		// Luminosity
		(color.r * 0.299) + (color.g * 0.587) + (color.b * 0.114)
	);
	
	// ACES Tonemapper
	const float a = 2.51f;
	const float b = 0.03f;
	const float c = 2.43f;
	const float d = 0.59f;
	const float e = 0.14f;

	vec4 tonemap = clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
	float t = x.a;
	
	t = t * t / (slope + t);

	// Return after desaturation step.
	return pow(mix(tonemap.rgb, tonemap.aaa, t),vec3(1.0/2.232));
}
vec3 ACESFilm( vec3 x )
{

    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
	vec3 r = (x*(a*x+b))/(x*(c*x+d)+e);

    return pow(r, vec3(1.0/2.232));
}

vec3 invACESFilm( vec3 r )
{
	r = toLinear(r);
	return (0.00617284 - 0.121399*r - 0.00205761 *sqrt(9 + 13702*r - 10127*r*r))/(-1.03292 + r);
}