#define SkyBrightness 2.0 //[3.0 2.5 2.0 1.5 1.0]

vec3 getSkyColor(vec3 fragpos, vec3 light){
vec3 sky_col = sky_c;
vec3 nfragpos = normalize(fragpos);

float NdotU = clamp(dot(nfragpos,upVec),0.0,1.0);
float NdotS = dot(nfragpos,sunVec)*0.5+0.5;

float n = 3.0*((1.0-NdotS)*sunVisibility*(1.0-rainStrength)*(1.0-0.5*timeBrightness))+SkyBrightness;
float horizon = pow(1.0-abs(NdotU),n)*(0.5*sunVisibility+0.3)*(1-rainStrength*0.75);
float lightmix = (NdotS*NdotS*(1-NdotU)*pow(1.0-timeBrightness,3.0) + horizon*0.075*timeBrightness)*sunVisibility*(1.0-rainStrength);

#ifdef SkyVanilla
sky_col = mix(fog_c,sky_col,NdotU);
#endif

float mult = 0.05+(0.1*rainStrength)+horizon;

sky_col = (mix(sky_col*pow(max(1-lightmix,0.0),2.0),pow(light,vec3(1.5))*3.4,lightmix)*sunVisibility + light_n*0.4);
sky_col = mix(sky_col,weather*luma(ambient)*4.0,rainStrength)*mult;

return pow(sky_col,vec3(1.125));
}