#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
using namespace metal;

// World-space shading keeps the aggregate, paint wear and wet patches attached
// to the road while the user orbits the car. No per-frame bitmap generation.
static float hash21(float2 p) { return fract(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
static float noise21(float2 p) {
    float2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+float2(1,0)),f.x),mix(hash21(i+float2(0,1)),hash21(i+1),f.x),f.y);
}

[[visible]] void mitsuOutdoorGround(realitykit::surface_parameters p) {
    constexpr sampler s(coord::normalized,address::repeat,filter::linear,mip_filter::linear);
    float4 config=p.uniforms().custom_parameter();
    float2 world=p.geometry().world_position().xz;
    float kind=config.w; // asphalt=0, grass=1, gravel=2, paint=3
    float2 uv=world/(kind>0.5 && kind<1.5 ? 5.0:3.2);
    half3 base=p.textures().base_color().sample(s,uv).rgb;
    if(kind>0.5 && kind<1.5)base*=half3(0.34,0.46,0.30);
    if(kind<0.5)base*=0.72h;
    half3 normal=realitykit::unpack_normal(p.textures().normal().sample(s,uv).rgb);
    float rough=kind>0.5 ? 0.93:float(p.textures().roughness().sample(s,uv).r);
    float coarse=noise21(world*0.32),fine=noise21(world*110);
    float wet=0,puddle=0;
    if(config.x>1.5 && config.x<2.5) {
        wet=0.72;
        puddle=smoothstep(0.53,0.72,coarse)*0.92;
        if(kind>0.5 && kind<2.5)puddle*=0.14;
        base*=half(0.54-puddle*0.16);
        rough=mix(0.36,0.075,puddle);
        normal=normalize(mix(normal,half3(0,0,1),half(puddle*0.90)));
    }
    if(kind>1.5 && kind<2.5)base=mix(base,half3(0.22,0.19,0.14),half(0.30));
    if(kind>2.5) {
        float wear=smoothstep(0.23,0.50,fine)*(0.65+0.35*coarse);
        base=mix(base,half3(0.72,0.72,0.65),half(wear));
        rough=wet>0 ? 0.30:0.85;
    }
    if(config.x>2.5 && config.x<3.5) {
        // Salted wheel paths and uneven powder across the shoulders/verges.
        float track=min(abs(world.x-0.765),abs(world.x+0.765));
        float snow=kind>0.5 && kind<1.5 ? 0.97:mix(0.24,0.90,smoothstep(0.14,0.32,track));
        snow*=0.88+0.12*noise21(world*3.0);
        base=mix(base,half3(0.78,0.83,0.87),half(snow));rough=0.96;
    }
    float distance=length((p.uniforms().model_to_view()*float4(p.geometry().model_position(),1)).xyz);
    float density=config.x>3.5 ? 0.045:(config.x>1.5 ? 0.004:0.0005);
    float fog=1-exp(-max(0.0,distance-8.0)*density);
    half3 fogColor=config.y>0.5 ? half3(0.013,0.021,0.035):half3(0.42,0.48,0.51);
    p.surface().set_base_color(base*half(1-fog));
    p.surface().set_emissive_color(fogColor*half(fog));
    p.surface().set_specular(0.5h);
    p.surface().set_normal(float3(normal));
    p.surface().set_roughness(half(clamp(rough,0.07,1.0)));
    p.surface().set_metallic(0);
    p.surface().set_clearcoat(half(wet*0.65));
    p.surface().set_clearcoat_roughness(half(0.08+puddle*0.06));
}

[[visible]] void mitsuContactShadow(realitykit::surface_parameters p) {
    float2 uv=(p.geometry().uv0()-0.5)*2;
    float edge=1-smoothstep(0.46,1.0,max(abs(uv.x),abs(uv.y)));
    half opacity=half(edge*0.34);
    if(opacity<0.001h)discard_fragment();
    p.surface().set_emissive_color(half3(0.008,0.012,0.014)*opacity);
    p.surface().set_opacity(opacity);
}

// One shared mesh and GPU geometry modifier animate all precipitation. Every
// fragment uses the same local fade as the ground, rather than a hard volume edge.
[[visible]] void mitsuLocalPrecipitationMotion(realitykit::geometry_parameters p) {
    float4 config=p.uniforms().custom_parameter();
    float3 original=p.geometry().model_position();
    float2 center=round(original.xz*10.0)*0.1;
    float seed=hash21(center+13.7);
    bool snow=config.y>0.5;
    float phase=fract(seed+config.x*(snow ? 0.72:6.5)/3.8);
    float height=3.8*(1-phase);
    float3 location=float3(center.x,height,center.y);
    location.x+=snow ? sin(config.x*0.7+seed*30.0)*0.13:(1-phase)*0.12;
    location.z+=snow ? cos(config.x*0.5+seed*19.0)*0.09:0;
    float4x4 view=p.uniforms().model_to_view();
    float3 right=normalize(float3(view[0][0],0,view[2][0]));
    float3 up=snow ? normalize(float3(view[0][1],view[1][1],view[2][1])):float3(0,1,0);
    float2 corner=p.geometry().uv0()-0.5;
    float width=snow ? 0.027+seed*0.018:0.009;
    float length=snow ? width:0.13+seed*0.06;
    float3 position=location+right*corner.x*width+up*corner.y*length;
    p.geometry().set_model_position_offset(position-original);
}

[[visible]] void mitsuLocalPrecipitation(realitykit::surface_parameters p) {
    float4 config=p.uniforms().custom_parameter();
    float3 position=p.geometry().world_position();
    float2 uv=p.geometry().uv0()*2-1;
    bool snow=config.y>0.5;
    float shape=snow ? 1-smoothstep(0.15,1.0,length(uv)):
        pow(max(0.0,1-abs(uv.x)),1.5)*(1-smoothstep(0.45,1.0,abs(uv.y)));
    float vertical=smoothstep(0.02,0.23,position.y)*(1-smoothstep(2.5,3.8,position.y));
    constexpr sampler maskSampler(coord::normalized,address::clamp_to_edge,filter::linear);
    // Exactly the same GPU mask that composites the ground into the canvas.
    float coverage=1-p.textures().custom().sample(maskSampler,position.xz/float2(30,24)+0.5).r;
    float opacity=shape*coverage*vertical*(snow ? 0.82:0.48);
    if(opacity<0.001)discard_fragment();
    half3 color=snow ? half3(0.80,0.86,0.94):half3(0.34,0.41,0.48);
    if(config.z>0.5)color*=0.62h;
    p.surface().set_emissive_color(color*half(opacity));
    p.surface().set_opacity(half(opacity));
}
