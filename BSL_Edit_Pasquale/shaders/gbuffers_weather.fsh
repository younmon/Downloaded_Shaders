#version 120

/*
BSL Shaders by Capt Tatsu
https://www.bitslablab.com
*/

#define Weather
#define WeatherOpacity 1.00

varying vec2 lmcoord;
varying vec2 texcoord;

varying vec3 upVec;
varying vec3 sunVec;

uniform int isEyeInWater;
uniform int worldTime;

uniform float nightVision;
uniform float rainStrength;
uniform float timeAngle;
uniform float timeBrightness;
uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;

uniform sampler2D texture;
uniform sampler2D depthtex0;

float eBS = eyeBrightnessSmooth.y/240.0;
float sunVisibility = clamp(dot(sunVec,upVec)+0.05,0.0,0.1)/0.1;

vec3 toNDC(vec3 pos){
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = pos * 2. - 1.;
    vec4 fragpos = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragpos.xyz / fragpos.w;
}

#include "lib/color/lightColor.glsl"
#include "lib/color/torchColor.glsl"

void main(){
	vec4 albedo = vec4(0.0);
	
	#ifdef Weather
	//Texture
	albedo.a = texture2D(texture, texcoord.xy).a;
	
	if (albedo.a > 0.001){
		albedo.rgb = texture2D(texture, texcoord.xy).rgb;
		albedo.a *= 0.1 * rainStrength * length(albedo.rgb/3)*float(albedo.a > 0.1);
		albedo.rgb = sqrt(albedo.rgb);
		albedo.rgb *= (ambient + lmcoord.x * lmcoord.x * torch_c) * WeatherOpacity;
	}
	#endif
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
}