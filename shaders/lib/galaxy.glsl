//CBS
//Parallax scrolling fractal galaxy.
//Inspired by JoshP's Simplicity shader: https://www.shadertoy.com/view/lslGWr

// http://www.fractalforums.com/new-theories-and-research/very-simple-formula-for-fractal-patterns/
float field(in vec3 p,float s){
    float strength=7.+.03*log(1.e-6+fract(sin(worldDay)*4373.11));
    float accum=s/4.;
    float prev=0.;
    float tw=0.;
    for(int i=0;i<26;++i){
        float mag=dot(p,p);
        p=abs(p)/mag+vec3(-.5,-.4,-1.5);
        float w=exp(-float(i)/7.);
        accum+=w*exp(-strength*pow(abs(mag-prev),2.2));
        tw+=w;
        prev=mag;
    }
    return max(0.,5.*accum/tw-.7);
}

// Less iterations for second layer
float field2(in vec3 p,float s){
    float strength=7.+.03*log(1.e-6+fract(sin(worldDay)*4373.11));
    float accum=s/4.;
    float prev=0.;
    float tw=0.;
    for(int i=0;i<18;++i){
        float mag=dot(p,p);
        p=abs(p)/mag+vec3(-.5,-.4,-1.5);
        float w=exp(-float(i)/7.);
        accum+=w*exp(-strength*pow(abs(mag-prev),2.2));
        tw+=w;
        prev=mag;
    }
    return max(0.,5.*accum/tw-.7);
}

vec3 nrand3(vec2 co)
{
    vec3 a=fract(cos(co.x*8.3e-3+co.y)*vec3(1.3e5,4.7e5,2.9e5));
    vec3 b=fract(sin(co.x*.3e-3+co.y)*vec3(8.1e5,1.e5,.1e5));
    vec3 c=mix(a,b,.5);
    return c;
}

vec4 galaxy(vec3 fragCoord){
    vec2 uv=fragCoord.xy;
    vec2 uvs=uv;
    vec3 p=vec3(uvs/4.,0)+vec3(1.,-1.3,0.);
    p+=.2*vec3(sin(worldDay/16.),sin(worldDay/12.),sin(worldDay/128.));
    
    float freqs[4];
    //Sound
    freqs[0]=.7;
    freqs[1]=.7;
    freqs[2]=.7;
    freqs[3]=.7;
    
    float t=field(p,freqs[2]);
    float v=(1.-exp((abs(uv.x)-1.)*6.))*(1.-exp((abs(uv.y)-1.)*6.));
    
    //Second Layer
    vec3 p2=vec3(uvs/(4.+sin(worldDay*.11)*.2+.2+sin(worldDay*.15)*.3+.4),1.5)+vec3(2.,-1.3,-1.);
    p2+=.25*vec3(sin(worldDay/16.),sin(worldDay/12.),sin(worldDay/128.));
    float t2=field2(p2,freqs[3]);
    vec4 c2=mix(.4,1.,v)*vec4(1.3*t2*t2*t2,1.8*t2*t2,t2*freqs[0],t2);
    
    //Let's add some stars
    //Thanks to http://glsl.heroku.com/e#6904.0
    vec2 seed=p.xy*2.;
    seed=floor(seed*fragCoord.x);
    vec3 rnd=nrand3(seed);
    vec4 starcolor=vec4(pow(rnd.y,40.));
    
    //Second Layer
    vec2 seed2=p2.xy*2.;
    seed2=floor(seed2*fragCoord.x);
    vec3 rnd2=nrand3(seed2);
    starcolor+=vec4(pow(rnd2.y,40.));
    
    vec4 color=mix(freqs[3]-.3,1.,v)*vec4(1.5*freqs[2]*t*t*t,1.2*freqs[1]*t*t,freqs[3]*t,1.)+c2+starcolor;
    return color/500;
}