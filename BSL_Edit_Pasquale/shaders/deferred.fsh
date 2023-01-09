#version 120
#extension GL_ARB_shader_texture_lod : enable

/*
BSL Shaders by Capt Tatsu
https://www.bitslablab.com
*/

#define AA 2 //[0 1 2]
#define AO
//#define BumpyEdge
//#define Celshade
#define Clouds
#define EmissiveRecolor
//#define Fog
#define FogRange 8 
//#define Puddles
#define ReflectionPrevious
#define RPSupport
#define RPSFormat 1 //[0 1 2 3]
#define RPSReflection

//#define WorldTimeAnimation
#define AnimationSpeed 1.00 

varying vec3 upVec;
varying vec3 sunVec;

varying vec2 texcoord;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float aspectRatio;
uniform float blindness;
uniform float far;
uniform float frameTimeCounter;
uniform float near;
uniform float nightVision;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle;
uniform float timeBrightness;
uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

#if defined RPSupport || defined Puddles
#if defined RPSReflection || defined Puddles
uniform sampler2D colortex3;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
#endif
#endif

#ifdef WorldTimeAnimation
float frametime = float(worldTime)/20.0*AnimationSpeed;
#else
float frametime = frameTimeCounter*AnimationSpeed;
#endif

float eBS = eyeBrightnessSmooth.y/240.0;
float sunVisibility = clamp(dot(sunVec,upVec)+0.05,0.0,0.1)/0.1;
float moonVisibility = clamp(dot(-sunVec,upVec)+0.05,0.0,0.1)/0.1;

float luma(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float ld(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

float gradNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameCounter/8.0);
}

#if defined RPSupport || defined Puddles
#if defined RPSReflection || defined Puddles
const int maxf = 4;				//number of refinements
const float stp = 0.5;			//size of one step for raytracing algorithm
const float ref = 0.1;			//refinement multiplier
const float inc = 1.0;			//increasement factor at each step

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}

vec4 raytrace(vec3 fragpos, vec3 normal, float dither) {
    vec4 color = vec4(0.0);
	#if AA == 2
	dither = fract(dither + frameTimeCounter*2.0);
	#endif

    vec3 start = fragpos;
    vec3 rvector = normalize(reflect(normalize(fragpos), normalize(normal)));
    vec3 vector = stp * rvector;
    vec3 oldpos = fragpos;
    fragpos += vector;
	vec3 tvector = vector;
    int sr = 0;
	float border = 0.0;
	vec3 pos = vec3(0.0);
    for(int i=0;i<18;i++){
        pos = nvec3(gbufferProjection * nvec4(fragpos)) * 0.5 + 0.5;
		if (pos.x < 0 || pos.x > 1 || pos.y < 0 || pos.y > 1 || pos.z < 0 || pos.z > 1) break;
		float depth = texture2D(depthtex0,pos.xy).r;
		vec3 spos = vec3(pos.st, depth);
        spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
        float err = abs(length(fragpos.xyz-spos.xyz));
		if (err < pow(length(vector)*pow(length(tvector),0.11),1.1)*1.1){

                sr++;
                if (sr >= maxf){
                    break;
                }
				tvector -=vector;
                vector *=ref;
		}
        vector *= inc;
        oldpos = fragpos;
        tvector += vector * (0.9375);
		fragpos = start + tvector;
    }
	
	if (pos.z <1.0-1e-5){
		border = clamp(1.0 - pow(cdist(pos.st), 200.0), 0.0, 1.0);
		color.a = float(texture2D(depthtex0,pos.xy).r < 1.0);
		if (color.a > 0.5) color.rgb = texture2D(colortex0, pos.st).rgb;
		color.rgb = clamp(color.rgb,vec3(0.0),vec3(8.0));
		color.a *= border;
	}
	
    return color;
}

vec4 raytraceRough(vec3 fragpos, vec3 normal, float dither, float r, vec2 noisecoord){
	r *= r;

	vec4 color = vec4(0.0);
	int steps = 1 + int(4 * r + (dither * 0.05));

	for(int i = 0; i < steps; i++){
		vec3 noise = vec3(texture2D(noisetex,noisecoord+0.1*i).xy*2.0-1.0,0.0);
		noise.xy *= 0.7*r*(i+1.0)/steps;
		noise.z = 1.0 - (noise.x * noise.x + noise.y * noise.y);

		vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
		mat3 tbnMatrix = mat3(tangent, cross(normal, tangent), normal);

		vec3 rnormal = normalize(tbnMatrix * noise);
		
		color += raytrace(fragpos,rnormal,dither);
	}
	color /= steps;
	
	return color;
}
uniform float wetness;
#endif
#endif

#include "lib/color/lightColor.glsl"
#include "lib/color/skyColor.glsl"
#include "lib/color/torchColor.glsl"
#include "lib/color/waterColor.glsl"
#include "lib/common/ambientOcclusion.glsl"
#include "lib/common/celShading.glsl"
#include "lib/common/clouds.glsl"
#include "lib/common/dither.glsl"
#include "lib/common/fog.glsl"
#include "lib/common/sky.glsl"

void main(){
	vec4 color = texture2D(colortex0,texcoord.xy);
	float z = texture2D(depthtex0,texcoord.xy).r;
	
	//Dither
	float dither = bayer64(gl_FragCoord.xy);
	
	//NDC Coordinate
	vec4 fragpos = gbufferProjectionInverse * (vec4(texcoord.x, texcoord.y, z, 1.0) * 2.0 - 1.0);
	fragpos /= fragpos.w;
	
	if (z < 1.0){
		//Specular Reflection
		#if defined RPSupport || defined Puddles
		#if defined RPSReflection || defined Puddles
		float smoothness = texture2D(colortex3,texcoord.xy).r;
		float f0 = texture2D(colortex3,texcoord.xy).g;
		float skymap = texture2D(colortex3,texcoord.xy).b;
		vec3 normal = texture2D(colortex6,texcoord.xy).xyz*2.0-1.0;
		
		float fresnel = clamp(1.0 + dot(normal, normalize(fragpos.xyz)),0.0,1.0);
		fresnel = pow(fresnel, 5.0);
		fresnel = mix(f0, 1.0, fresnel) * smoothness * smoothness;
		
		#ifdef RPSRefRough
		vec2 noisecoord = texcoord.xy*vec2(viewWidth,viewHeight)/512.0;
		#if AA == 2
		noisecoord += fract(frameCounter*vec2(0.4,0.25));
		#endif
		#endif
		
		if (fresnel > 0.001){
			vec4 reflection = vec4(0.0);
			vec3 skyRef = vec3(0.0);

			#ifdef RPSRefRough
			if(smoothness > 0.95) reflection = raytrace(fragpos.xyz,normal,dither);
			else reflection = raytraceRough(fragpos.xyz,normal,dither,1.0-smoothness,noisecoord);
			#else
			reflection = raytrace(fragpos.xyz,normal,dither);
			#endif

			if(reflection.a < 1.0){
				vec3 skyRefPos = reflect(normalize(fragpos.xyz),normal);
				#ifdef RPSRefRough
				if(smoothness < 0.95){
					float r = 1.0-smoothness;
					r *= r;

					vec3 noise = vec3(texture2D(noisetex,noisecoord).xy*2.0-1.0,0.0);
					if(length(noise.xy) > 0) noise.xy /= length(noise.xy);
					noise.xy *= 0.7*r;
					noise.z = 1.0 - (noise.x * noise.x + noise.y * noise.y);

					vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
					mat3 tbnMatrix = mat3(tangent, cross(normal, tangent), normal);

					skyRefPos = reflect(normalize(fragpos.xyz),normalize(tbnMatrix * noise));
				}
				#endif
				if(f0 > 0.40){
				skyRef = getSkyColor(skyRefPos,light);
				}
				#ifdef Clouds
				vec4 cloud = drawCloud(skyRefPos*256.0, dither, skyRef, light, ambient);
				skyRef = mix(skyRef,cloud.rgb,cloud.a);
				#endif
				skyRef *= (4.0-3.0*eBS)*skymap;
			}

			reflection.rgb = mix(skyRef,reflection.rgb,reflection.a);
			if (f0 >= 0.8) reflection.rgb *= color.rgb*2.0;

			vec3 spec = texture2D(colortex7,texcoord.xy).rgb;
			spec = 4.0*spec/(1.0-spec)*fresnel;
			
			color.rgb = mix(color.rgb, reflection.rgb, fresnel)+spec;
		}
		#endif
		#endif
		
		//Ambient Occlusion
		#ifdef AO
		color.rgb *= dbao(depthtex0, dither);
		#endif
		
		//Blindness
		float b = clamp(blindness*2.0-1.0,0.0,1.0);
		b = b*b;
		if (blindness > 0.0) color.rgb *= 1.0-b;
	}
/*DRAWBUFFERS:04*/
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(z,0.0,0.0,0.0);
	#ifndef ReflectionPrevious
/*DRAWBUFFERS:045*/
	gl_FragData[2] = vec4(pow(color.rgb,vec3(0.125))*0.5,float(z < 1.0));
	#endif
}
