//Original star code : https://www.shadertoy.com/view/Md2SR3 , optimised

// Return random noise in the range [0.0, 1.0], as a function of x.
float hash12(vec2 p)
{
    vec3 p3=fract(vec3(p.xyx)*.1031);
    p3+=dot(p3,p3.yzx+19.19);
    return fract((p3.x+p3.y)*p3.z);
}
// Convert Noise2d() into a "star field" by stomping everthing below fThreshhold to zero.
float NoisyStarField(in vec2 vSamplePos,float fThreshhold)
{
    float StarVal=hash12(vSamplePos);
    StarVal=clamp(StarVal/(1.-fThreshhold)-fThreshhold/(1.-fThreshhold),0.,1.);
    
    return StarVal;
}

// Stabilize NoisyStarField() by only sampling at integer values.
float StableStarField(in vec2 vSamplePos,float fThreshhold)
{
    // Linear interpolation between four samples.
    // Note: This approach has some visual artifacts.
    // There must be a better way to "anti alias" the star field.
    float fractX=fract(vSamplePos.x);
    float fractY=fract(vSamplePos.y);
    vec2 floorSample=floor(vSamplePos);
    float v1=NoisyStarField(floorSample,fThreshhold);
    float v2=NoisyStarField(floorSample+vec2(0.,1.),fThreshhold);
    float v3=NoisyStarField(floorSample+vec2(1.,0.),fThreshhold);
    float v4=NoisyStarField(floorSample+vec2(1.,1.),fThreshhold);
    
    float StarVal=v1*(1.-fractX)*(1.-fractY)
    +v2*(1.-fractX)*fractY
    +v3*fractX*(1.-fractY)
    +v4*fractX*fractY;
    return StarVal;
}

float stars(vec3 fragpos){
    
    float elevation=clamp(fragpos.y,0.,1.);
    vec2 uv=fragpos.xz/(1.+elevation);
    
    return StableStarField(uv*700.,.999)*(.3-.3*rainStrength);
}