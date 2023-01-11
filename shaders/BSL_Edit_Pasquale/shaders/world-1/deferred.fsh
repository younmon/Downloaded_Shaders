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
#define FogRange 8 //[2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 18 20 22 24 26 28 30 32 36 40 44 48 52 56 60 64]
#define ReflectionPrevious
#define RPSupport
#define RPSReflection
//#define RPSRefRough

//#define WorldTimeAnimation
#define AnimationSpeed 1.00 //[0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00 3.50 4.00 5.00 6.00 7.00 8.00]

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
uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D noisetex;

#ifdef RPSupport
#ifdef RPSReflection
uniform sampler2D colortex3;
uniform sampler2D colortex6;
#endif
#endif

#ifdef WorldTimeAnimation
float frametime = float(worldTime)/20.0*AnimationSpeed;
#else
float frametime = frameTimeCounter*AnimationSpeed;
#endif

float ld(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

#ifdef RPSupport
const int maxf = 4;				//number of refinements
const float stp = 1.2;			//size of one step for raytracing algorithm
const float ref = 0.25;			//refinement multiplier
const float inc = 2.0;			//increasement factor at each step

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
	dither = fract(dither + frameTimeCounter);
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
    for(int i=0;i<30;i++){
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
        tvector += vector * (dither * 0.125 + 0.9375);
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
	int steps = 1 + int(4 * r);

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
#endif

#include "lib/color/dimensionColor.glsl"
#include "lib/color/torchColor.glsl"
#include "lib/color/waterColor.glsl"
#include "lib/common/ambientOcclusion.glsl"
#include "lib/common/celShading.glsl"
#include "lib/common/dither.glsl"
#include "lib/common/fog.glsl"

void main(){
	vec4 color = texture2D(colortex0,texcoord.xy);
	float z = texture2D(depthtex0,texcoord.xy).r;
	
	//Dither
	#if defined AO || defined Clouds
	float dither = bayer64(gl_FragCoord.xy);
	#endif
	
	//NDC Coordinate
	vec4 fragpos = gbufferProjectionInverse * (vec4(texcoord.x, texcoord.y, z, 1.0) * 2.0 - 1.0);
	fragpos /= fragpos.w;
	
	if (z >= 1.0){
		//Replace sky
		color.rgb = nether_c * 0.005;

		//Lava Fog
		if (isEyeInWater == 2){
			#ifdef EmissiveRecolor
			color.rgb = pow(Torch/TorchS,vec3(4.0))*2.0;
			#else
			color.rgb = vec3(1.0,0.3,0.01);
			#endif
		}
		
		//Blindness
		float b = clamp(blindness*2.0-1.0,0.0,1.0);
		b = b*b;
		if (blindness > 0.0) color.rgb *= 1.0-b;
	}
	else{
		//Specular Reflection
		#ifdef RPSupport
		#ifdef RPSReflection
		float smoothness = texture2D(colortex3,texcoord.xy).r;
		smoothness = smoothness*sqrt(smoothness);
		float f0 = texture2D(colortex3,texcoord.xy).g;	
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
			vec3 skyRef = nether_c*0.01;

			#ifdef RPSRefRough
			if(smoothness > 0.95) reflection = raytrace(fragpos.xyz,normal,dither);
			else reflection = raytraceRough(fragpos.xyz,normal,dither,1.0-smoothness,noisecoord);
			#else
			reflection = raytrace(fragpos.xyz,normal,dither);
			#endif
			
			reflection.rgb = mix(skyRef,reflection.rgb,reflection.a);
			if (f0 >= 0.8) reflection.rgb *= color.rgb*2.0;
			
			color.rgb = mix(color.rgb, reflection.rgb, fresnel);
		}
		#endif
		#endif
		
		//Ambient Occlusion
		#ifdef AO
		color.rgb *= dbao(depthtex0, dither);
		#endif
		
		//Bumpy Edge
		#ifdef BumpyEdge
		color.rgb *= bumpyedge(depthtex0);
		#endif
		
		//Fog
		#ifdef Fog
		color.rgb = calcFog(color.rgb,fragpos.xyz, blindness);
		#endif
	}
	
	//Black Outline
	#ifdef Celshade
	color.rgb *= celshade(depthtex0, 0.0);
	#endif
	
/*DRAWBUFFERS:04*/
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(z,0.0,0.0,0.0);
	#ifndef ReflectionPrevious
/*DRAWBUFFERS:045*/
	gl_FragData[2] = vec4(pow(color.rgb,vec3(0.125))*0.5,float(z < 1.0));
	#endif
	#ifdef RPSupport
	#ifdef RPSReflection
/*DRAWBUFFERS:0451*/
	gl_FragData[3] = vec4(1.0);
	#endif
	#endif
}
