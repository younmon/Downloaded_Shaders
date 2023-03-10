vec3 getFogColor(vec3 fragpos){
vec3 fog_col = fog_c;
vec3 nfragpos = normalize(fragpos);
float lfragpos = length(fragpos)/(FogRange*8.0);
lfragpos = 1.0-exp(-lfragpos*lfragpos);

float NdotU = clamp(dot(nfragpos,upVec),0.0,1.0);
float NdotS = dot(nfragpos,sunVec)*0.5+0.5;

float lightmix = NdotS*NdotS*(1-NdotU)*pow(1.0-timeBrightness,3.0)*(1.0-rainStrength)*lfragpos*eBS;

fog_col = (mix(fog_col*(1.0-sqrt(lightmix)),light*sqrt(light),lightmix)*sunVisibility + light_n*0.4);
fog_col = mix(fog_col,weather*luma(ambient)*2.5,rainStrength)*0.3;

return pow(fog_col,vec3(1.125));
}

vec3 calcNormalFog(vec3 color, vec3 fragpos){
float fog = length(fragpos)/(FogRange*50.0*(sunVisibility*0.5+1.5))*(1.5*rainStrength+1.0)*eBS;
fog = 1.0-exp(-2.0*fog*mix(sqrt(fog),1.0,rainStrength));
return mix(color,getFogColor(fragpos),fog);
}

vec3 calcBlindFog(vec3 color, vec3 fragpos, float blindness){
	float b = clamp(blindness*2.0-1.0,0.0,1.0);
	b = b*b;
	float fog = length(fragpos)/(5.0/b);
	fog = (1.0-exp(-6.0*fog*fog*fog))*b;
	return mix(color,vec3(0.0),fog);
}

vec3 calcLavaFog(vec3 color, vec3 fragpos){
	float fog = length(fragpos)/2.0;
	fog = (1.0-exp(-4.0*fog*fog*fog));
	#ifdef EmissiveRecolor
	return mix(color,pow(Torch/TorchS,vec3(4.0))*2.0,fog);
	#else
	return mix(color,vec3(1.0,0.3,0.01),fog);
	#endif
}

vec3 calcFog(vec3 color, vec3 fragpos, float blindness){
	color = calcNormalFog(color, fragpos);
	if (isEyeInWater == 2.0) color = calcLavaFog(color, fragpos);
	if (blindness > 0.0) color = calcBlindFog(color, fragpos, blindness);
	return color;
}