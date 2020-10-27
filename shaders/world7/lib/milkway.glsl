
mat3 rotationMatrix(vec3 axis,float angle)
{
    axis=normalize(axis);
    float s=sin(angle);
    float c=cos(angle);
    float oc=1.-c;
    
    return mat3(oc*axis.x*axis.x+c,oc*axis.x*axis.y-axis.z*s,oc*axis.z*axis.x+axis.y*s,
        oc*axis.x*axis.y+axis.z*s,oc*axis.y*axis.y+c,oc*axis.y*axis.z-axis.x*s,
    oc*axis.z*axis.x-axis.y*s,oc*axis.y*axis.z+axis.x*s,oc*axis.z*axis.z+c);
}

float hash(float n){
    return fract(sin(n)*758.5453);
}

float configurablenoise(vec3 x,float c1,float c2){
    vec3 p=floor(x);
    vec3 f=fract(x);
    f=f*f*(3.-2.*f);
    
    float n=p.x+p.y*c2+c1*p.z;
    return mix(mix(mix(hash(n+0.),hash(n+1.),f.x),
    mix(hash(n+c2),hash(n+c2+1.),f.x),f.y),
    mix(mix(hash(n+c1),hash(n+c1+1.),f.x),
    mix(hash(n+(c1+c2)),hash(n+(c1+c2)+1.),f.x),f.y),f.z);
    
}

float supernoise3dX(vec3 p){
    
    float a=configurablenoise(p,883.,971.);
    float b=configurablenoise(p+.5,113.,157.);
    return(a*b);
}

float fbmHI2d(vec2 p,float dx){
    // p *= 0.1;
    p*=1.2;
    //p += getWind(p * 0.2) * 6.0;
    float a=0.;
    float w=1.;
    float wc=0.;
    for(int i=0;i<5;i++){
        //p += noise(vec3(a));
        a+=clamp(2.*abs(.5-(supernoise3dX(vec3(p,1.))))*w,0.,1.);
        wc+=w;
        w*=.5;
        p=p*dx;
    }
    return a/wc;// + noise(p * 100.0) * 11;
}

float stars02(vec2 seed,float intensity){
    return smoothstep(1.-intensity*.9,(1.-intensity*.9)+.1,supernoise3dX(vec3(seed*500.,0.))*(.8+.2*supernoise3dX(vec3(seed*40.,0.))));
}
vec3 stars01(vec3 fragpos){
    float elevation=clamp(fragpos.y,0.,1.);
    vec2 uv=fragpos.xz/(1.+elevation);
    
    float intensityred=(1./(1.+30.*abs(uv.y)))*fbmHI2d(uv*30.,3.)*(1.-abs(uv.x));
    float intensitywhite=(1./(1.+20.*abs(uv.y)))*fbmHI2d(uv*30.+120.,3.)*(1.-abs(uv.x));
    float intensityblue=(1./(1.+20.*abs(uv.y)))*fbmHI2d(uv*30.+220.,3.)*(1.-abs(uv.x));
    float galaxydust=smoothstep(.1,.5,(1./(1.+20.*abs(uv.y)))*fbmHI2d(uv*40.+220.,3.)*(1.-abs(uv.x)));
    float galaxydust2=smoothstep(.1,.5,(1./(1.+20.*abs(uv.y)))*fbmHI2d(uv*100.+220.,3.)*(1.-abs(uv.x)));
    intensityred=1.-pow(1.-intensityred,3.)*.73;
    intensitywhite=1.-pow(1.-intensitywhite,3.)*.73;
    intensityblue=1.-pow(1.-intensityblue,3.)*.73;
    float redlights=stars02(uv,intensityred);
    float whitelights=stars02(uv,intensitywhite);
    float bluelights=stars02(uv,intensityblue);
    vec3 starscolor=vec3(.5961,.8078,.8471)*redlights+vec3(0.,0.,0.)*whitelights;
    vec3 dustinner=vec3(.7608,.8353,.9216);
    vec3 dustouter=vec3(0.,0.,0.);
    vec3 innermix=mix(dustinner,starscolor,1.-galaxydust);
    vec3 allmix=mix(dustouter,starscolor,galaxydust2);
    vec3 bloom=1.6*dustinner*(1./(1.+30.*abs(uv.y)))*fbmHI2d(uv*3.,3.)*(1.-abs(uv.x));
    vec3 color=mix(allmix,bloom,.7);
    float tmp=(worldTime>22975&&worldTime<12925)?0:1;
    if(worldTime<22975&&worldTime>12925){
        return(color/20)*abs(sin(worldTime/(1200*acos(-1.))))*tmp;
    }
    else{
        return color*0.;
    }
}

