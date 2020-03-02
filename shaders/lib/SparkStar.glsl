float random(vec2 ab)
{
    float f=(cos(dot(ab,vec2(21.9898,78.233)))*43758.5453);
    return fract(f);
}

float noise(in vec2 xy)
{
    vec2 ij=floor(xy);
    vec2 uv=xy-ij;
    uv=uv*uv*(3.-2.*uv);
    
    float a=random(vec2(ij.x,ij.y));
    float b=random(vec2(ij.x+1.,ij.y));
    float c=random(vec2(ij.x,ij.y+1.));
    float d=random(vec2(ij.x+1.,ij.y+1.));
    float k0=a;
    float k1=b-a;
    float k2=c-a;
    float k3=a-b-c+d;
    return(k0+k1*uv.x+k2*uv.y+k3*uv.x*uv.y);
}

vec4 SparkStar(in vec3 np3){

    vec2 position=np3.yz;
    vec4 fragColor=vec4(1.);
    float color=pow(noise(np3.xy),40.)*20.;
    
    float r1=noise(np3.xy*noise(vec2(sin(worldTime))));
    float r2=noise(np3.xy*noise(vec2(cos(worldTime),sin(worldTime))));
    float r3=noise(np3.xy*noise(vec2(sin(worldTime),cos(worldTime))));
    fragColor=vec4(vec3(color*r1,color*r2,color*r3),0.5);
    
    return vec4(fragColor);
}