
float getWaterHeightmap(vec2 posxz, float waveM, float waveZ, float iswater) {
    waveM *= 697.0;
    posxz *= waveZ * vec2(10.0,5.);

    float radiance = 2.39996;
    mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

    float wave = 0.0;
    vec2 movement = abs(vec2(frameTimeCounter * 0.001 * (iswater * 2.0 - 1.0),0.0)) * waveM;

	float w = 0.0;
	for (int i =0; i<5;i++){
	posxz = rotationMatrix  * posxz;
    wave += (texture2D(noisetex, (posxz + movement) / 800.0 * exp2(0.8*i)).r)*exp2(-1.1*i);
	
	w+=exp2(-1.1*i);
	}

    return wave/w*mix(0.1,1.0,iswater*2-1);
}
vec3 getWaveHeight(vec2 posxz, float iswater){

	vec2 coord = posxz;

		float deltaPos = 0.25;
		
		float waveZ = mix(20.0,0.25,iswater);
		float waveM = mix(0.0,4.0,iswater);

		float h0 = getWaterHeightmap(coord, waveM, waveZ, iswater);
		float h1 = getWaterHeightmap(coord + vec2(deltaPos,0.0), waveM, waveZ, iswater);
		float h3 = getWaterHeightmap(coord + vec2(0.0,deltaPos), waveM, waveZ, iswater);


		float xDelta = ((h1-h0))/deltaPos*2.;
		float yDelta = ((h3-h0))/deltaPos*2.;

		vec3 wave = normalize(vec3(xDelta,yDelta,1.0-pow(abs(xDelta+yDelta),2.0)));

		return wave;
}