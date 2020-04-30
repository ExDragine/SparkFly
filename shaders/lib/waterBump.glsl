
float getWaterHeightmap(vec2 posxz,float waveM,float waveZ,float iswater){
	waveM*=697.;
	posxz*=waveZ*vec2(10.,5.);
	
	float radiance=2.39996;
	mat2 rotationMatrix=mat2(vec2(cos(radiance),-sin(radiance)),vec2(sin(radiance),cos(radiance)));
	
	float wave=0.;
	vec2 movement=abs(vec2(frameTimeCounter*.001*(iswater*2.-1.),0.))*waveM;
	
	float w=0.;
	for(int i=0;i<5;i++){
		posxz=rotationMatrix*posxz;
		wave+=(texture2D(noisetex,(posxz+movement)/800.*exp2(.8*i)).r)*exp2(-1.1*i);
		
		w+=exp2(-1.1*i);
	}
	
	return wave/w*mix(.1,1.,iswater*2-1);
}
vec3 getWaveHeight(vec2 posxz,float iswater){
	
	vec2 coord=posxz;
	
	float deltaPos=.25;
	
	float waveZ=mix(20.,.25,iswater);
	float waveM=mix(0.,4.,iswater);
	
	float h0=getWaterHeightmap(coord,waveM,waveZ,iswater);
	float h1=getWaterHeightmap(coord+vec2(deltaPos,0.),waveM,waveZ,iswater);
	float h3=getWaterHeightmap(coord+vec2(0.,deltaPos),waveM,waveZ,iswater);
	
	float xDelta=((h1-h0))/deltaPos*2.;
	float yDelta=((h3-h0))/deltaPos*2.;
	
	vec3 wave=normalize(vec3(xDelta,yDelta,1.-pow(abs(xDelta+yDelta),2.)));
	
	return wave;
}