#version 120

/*
BSL Shaders by Capt Tatsu
https://www.bitslablab.com
*/

/*
Note : gbuffers_basic, gbuffers_entities, gbuffers_hand, gbuffers_terrain, gbuffers_textured, and gbuffers_water contains mostly the same code. If you edited one of these files, you need to do the same thing for the rest of the file listed.
*/

#define AA 2 //[0 1 2]
//#define DisableTexture
#define EmissiveBrightness 1.00
//#define LightmapBanding
//#define Puddles

#define RPSupport
#define RPSReflection

#define ShadowColor
#define ShadowFilter

const int shadowMapResolution = 4096; //[1024 2048 3072 4096 8192]
const float shadowDistance = 256.0; //[128.0 256.0 512.0 1024.0]
const float shadowMapBias = 1.0-25.6/shadowDistance;

varying float mat;

varying vec2 lmcoord;
varying vec2 texcoord;

varying vec3 normal;
varying vec3 sunVec;
varying vec3 upVec;

varying vec4 color;

uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float shadowFade;
uniform float timeAngle;
uniform float timeBrightness;
uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

uniform sampler2DShadow shadowtex0;
#ifdef ShadowColor
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

float eBS = eyeBrightnessSmooth.y/240.0;
float sunVisibility = clamp(dot(sunVec,upVec)+0.05,0.0,0.1)/0.1;

vec3 lightVec = sunVec*(1.0-2.0*float(timeAngle > 0.5325 && timeAngle < 0.9675));

float luma(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float gradNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameCounter/8.0);
}

#include "lib/color/lightColor.glsl"
#include "lib/color/torchColor.glsl"
#include "lib/common/spaceConversion.glsl"

#if AA == 2
#include "lib/common/jitter.glsl"
#endif

void main(){
	//Texture
	vec4 albedo = texture2D(texture, texcoord) * color;
	
	if (albedo.a > 0.0){
		//NDC Coordinate
		#if AA == 2
		vec3 fragpos = toNDC(vec3(taaJitter(gl_FragCoord.xy/vec2(viewWidth,viewHeight),-0.5),gl_FragCoord.z));
		#else
		vec3 fragpos = toNDC(vec3(gl_FragCoord.xy/vec2(viewWidth,viewHeight),gl_FragCoord.z));
		#endif

		//World Space Coordinate
		vec3 worldpos = toWorld(fragpos);
		
		//Convert to linear color space
		albedo.rgb = pow(albedo.rgb, vec3(2.2));
		
		#ifdef DisableTexture
		albedo.rgb = vec3(0.5);
		#endif
		
		//Lightmap
		#ifdef LightmapBanding
		float torchmap = clamp(floor(lmcoord.x*14.999) / 14, 0.0, 1.0);
		float skymap = clamp(floor(lmcoord.y*14.999) / 14, 0.0, 1.0);
		#else
		float torchmap = clamp(lmcoord.x, 0.0, 1.0);
		float skymap = clamp(lmcoord.y, 0.0, 1.0);
		#endif
		
		//Shadows
		float shadow = 0.0;
		vec3 shadowcol = vec3(0.0);
		
		float NdotL = 1.0;
		
		//Apply diffuse (uncomment)
		//NdotL = clamp(dot(normal,lightVec)*1.01-0.01,0.0,1.0);
		
		worldpos = toShadow(worldpos);
		
		float distb = sqrt(worldpos.x * worldpos.x + worldpos.y * worldpos.y);
		float distortFactor = 1.0 - shadowMapBias + distb * shadowMapBias;
		
		worldpos.xy /= distortFactor;
		worldpos.z *= 0.2;
		worldpos = worldpos*0.5+0.5;
		
		if (skymap > 0.001){
			float diffthresh = 0.00004;
			float step = 1.0/shadowMapResolution;

			worldpos.z -= diffthresh;
			
			#if AA == 2
			float noise = gradNoise()*3.14;
			vec2 rot = vec2(cos(noise),sin(noise))*step;
			#endif
			
			#ifdef ShadowFilter
			#if AA == 2
			shadow = shadow2D(shadowtex0,vec3(worldpos.st+rot, worldpos.z)).x;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st-rot, worldpos.z)).x;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st, worldpos.z)).x*0.5;
			shadow*= 0.4;
			#else
			shadow = shadow2D(shadowtex0,vec3(worldpos.st, worldpos.z)).x*2.0;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st+vec2(step,0), worldpos.z)).x;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st+vec2(-step,0), worldpos.z)).x;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st+vec2(0,step), worldpos.z)).x;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st+vec2(0,-step), worldpos.z)).x;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st+vec2(step,step)*0.7, worldpos.z)).x;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st+vec2(step,-step)*0.7, worldpos.z)).x;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st+vec2(-step,step)*0.7, worldpos.z)).x;
			shadow+= shadow2D(shadowtex0,vec3(worldpos.st+vec2(-step,-step)*0.7, worldpos.z)).x;
			shadow*= 0.1;
			#endif
			#else
			shadow = shadow2D(shadowtex0,vec3(worldpos.st, worldpos.z)).x;
			#endif
			
			if (shadow < 0.999){
				#ifdef ShadowColor
					#ifdef ShadowFilter
					#if AA == 2
					shadowcol = texture2D(shadowcolor0,worldpos.st+rot).rgb*shadow2D(shadowtex1,vec3(worldpos.st+rot, worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st-rot).rgb*shadow2D(shadowtex1,vec3(worldpos.st-rot, worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st).rgb*shadow2D(shadowtex1,vec3(worldpos.st, worldpos.z)).x*0.5;
					shadowcol*= 0.4;
					#else
					shadowcol = texture2D(shadowcolor0,worldpos.st).rgb*shadow2D(shadowtex1,vec3(worldpos.st, worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st+vec2(step,0)).rgb*shadow2D(shadowtex1,vec3(worldpos.st+vec2(step,0), worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st+vec2(-step,0)).rgb*shadow2D(shadowtex1,vec3(worldpos.st+vec2(-step,0), worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st+vec2(0,step)).rgb*shadow2D(shadowtex1,vec3(worldpos.st+vec2(0,step), worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st+vec2(0,-step)).rgb*shadow2D(shadowtex1,vec3(worldpos.st+vec2(0,-step), worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st+vec2(step,step)*0.7).rgb*shadow2D(shadowtex1,vec3(worldpos.st+vec2(step,step)*0.7, worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st+vec2(step,-step)*0.7).rgb*shadow2D(shadowtex1,vec3(worldpos.st+vec2(step,step)*0.7, worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st+vec2(-step,step)*0.7).rgb*shadow2D(shadowtex1,vec3(worldpos.st+vec2(step,step)*0.7, worldpos.z)).x;
					shadowcol+= texture2D(shadowcolor0,worldpos.st+vec2(-step,-step)*0.7).rgb*shadow2D(shadowtex1,vec3(worldpos.st+vec2(step,step)*0.7, worldpos.z)).x;
					shadowcol*=0.1;
					#endif
					#else
					shadowcol = texture2D(shadowcolor0,worldpos.st).rgb*shadow2D(shadowtex1,vec3(worldpos.st, worldpos.z)).x;
					#endif
				#endif
			}
		}
		
		vec3 fullshading = max(vec3(shadow), shadowcol) * NdotL;
		float lightmult = (4.0-3.0*eBS);
		
		//Lighting Calculation
		vec3 scenelight = (mix(ambient, light, fullshading * (shadowFade * (1.0-0.95*rainStrength))) * lightmult)  * skymap * skymap;
		float newtorchmap = pow(torchmap,10.0)*(EmissiveBrightness+0.5)+(torchmap*0.7);
		
		vec3 blocklight = (newtorchmap * newtorchmap) * torch_c;
		float minlight = (0.009*screenBrightness + 0.001)*(1.0-eBS);
		
		vec3 finallight = scenelight + blocklight + nightVision + minlight;
		albedo.rgb /= sqrt(albedo.rgb * albedo.rgb + 1.0);
		albedo.rgb *= finallight;
	}
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
	#if defined RPSupport || defined Puddles
	#if defined RPSReflection || defined Puddles
/* DRAWBUFFERS:0367 */
	gl_FragData[1] = vec4(0.0,0.0,0.0,1.0);
	gl_FragData[2] = vec4(0.0,0.0,0.0,1.0);
	gl_FragData[3] = vec4(0.0,0.0,0.0,1.0);
	#endif
	#endif
}