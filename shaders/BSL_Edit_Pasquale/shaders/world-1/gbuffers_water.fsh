#version 120
#extension GL_ARB_shader_texture_lod : enable

/*
BSL Shaders by Capt Tatsu
https://www.bitslablab.com
*/

/*
Note : gbuffers_basic, gbuffers_entities, gbuffers_hand, gbuffers_terrain, gbuffers_textured, and gbuffers_water contains mostly the same code. If you edited one of these files, you need to do the same thing for the rest of the file listed.
*/

#define AA 2 //[0 1 2]
#define Clouds
#define Desaturation
#define DesaturationFactor 2.0 //[2.0 1.5 1.0 0.5 0.0]
//#define DisableTexture
#define EmissiveBrightness 1.00 //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define EmissiveRecolor
//#define Fog
#define FogRange 8 //[2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 18 20 22 24 26 28 30 32 36 40 44 48 52 56 60 64]
//#define LightmapBanding
#define Reflection
#define ReflectionPrevious

#define POMQuality 32 //[4 8 16 32 64 128 256 512]
#define POMDepth 1.00 //[0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00]
#define POMDistance 64.0 //[16.0 32.0 48.0 64.0 80.0 96.0 112.0 128.0]
#define RPSupport
#define RPSFormat 1 //[0 1 2 3]
//#define RPSPom
#define RPSReflection
//#define RPSRefRough

#define WaterNormals 2 //[0 1 2]
#define WaterParallax
#define WaterOctave 3 //[2 3 4 5 6 7 8]
#define WaterBump 2.75 //[0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00]
#define WaterLacunarity 2.00 //[1.25 1.30 1.35 1.40 1.45 1.50 1.55 1.60 1.65 1.70 1.75 1.80 1.85 1.90 1.95 2.00]
#define WaterPersistance 0.80 //[0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90]
#define WaterSize 350.0 //[150.0 200.0 250.0 300.0 350.0 400.0 450.0 500.0 550.0 600.0 650.0 700.0 750.0]
#define WaterSharpness 0.35 //[0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40]
#define WaterSpeed 2.50 //[0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00 3.50 4.00]

//#define WorldTimeAnimation
#define AnimationSpeed 1.00 //[0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.50 3.00 3.50 4.00 5.00 6.00 7.00 8.00]

varying float dist;
varying float mat;

varying vec2 lmcoord;
varying vec2 texcoord;

varying vec3 binormal;
varying vec3 normal;
varying vec3 tangent;
varying vec3 upVec;
varying vec3 viewVector;
varying vec3 wpos;

varying vec4 color;

#ifdef RPSupport
varying vec4 vtexcoordam;
varying vec4 vtexcoord;
#endif

uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindness;
uniform float far;
uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D noisetex;

#ifdef RPSupport
uniform sampler2D specular;
uniform sampler2D normals;
#endif

float luma(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

#ifdef WorldTimeAnimation
float frametime = float(worldTime)/20.0*AnimationSpeed;
#else
float frametime = frameTimeCounter*AnimationSpeed;
#endif

float waterH(vec3 pos, vec3 fpos) {
	float noise = 0;

	float mult = clamp((-dot(normalize(normal),normalize(fpos)))*8.0,0.0,1.0)/sqrt(sqrt(max(dist,4.0)));
	float lacunarity = 1.0;
	float persistance = 1.0;
	float weight = 0.0;
	
	if (mult > 0.01){
		#if WaterNormals == 1
		noise  = texture2D(noisetex,(pos.xz+vec2(frametime)*0.5-pos.y*0.2)/512.0* 1.1).r*1.0;
		noise += texture2D(noisetex,(pos.xz-vec2(frametime)*0.5-pos.y*0.2)/512.0* 1.5).r*0.8;
		noise -= texture2D(noisetex,(pos.xz+vec2(frametime)*0.5+pos.y*0.2)/512.0* 2.5).r*0.6;
		noise += texture2D(noisetex,(pos.xz-vec2(frametime)*0.5-pos.y*0.2)/512.0* 5.0).r*0.4;
		noise -= texture2D(noisetex,(pos.xz+vec2(frametime)*0.5+pos.y*0.2)/512.0* 8.0).r*0.2;
		noise *= mult;
		#endif
		#if WaterNormals == 2
		for(int i = 0; i < WaterOctave; i++){
			float mult = (mod(i,2))*2.0-1.0;
			noise += texture2D(noisetex,(pos.xz+vec2(frametime)*WaterSpeed*0.5*mult+pos.y*0.2*mult)/WaterSize * lacunarity).r*persistance*mult;
			if (i==0) noise = -noise;
			weight += persistance;
			lacunarity *= WaterLacunarity;
			persistance *= WaterPersistance;
		}
		noise *= mult * WaterBump / weight * WaterSize / 450.0;
		#endif
	}

	return noise;
}

vec3 getParallaxWaves(vec3 posxz, vec3 viewVector,vec3 fragpos) {
	vec3 parallaxPos = posxz;
	float waveH = (waterH(posxz,fragpos.xyz)-0.5)*0.2;
	
	for(int i = 0; i < 4; i++){
		parallaxPos.xz += waveH*(viewVector.xy)/dist;
		waveH = (waterH(parallaxPos,fragpos.xyz)-0.5)*0.2;
	}
	return parallaxPos;
}

const int maxf = 4;				//number of refinements
const float stp = 1.2;			//size of one step for raytracing algorithm
const float ref = 0.1;			//refinement multiplier
const float inc = 1.8;			//increasement factor at each step

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
		float depth = texture2D(gaux1, pos.st).r;
		vec3 spos = vec3(pos.st, depth);
        spos = nvec3(gbufferProjectionInverse * nvec4(spos * 2.0 - 1.0));
        float err = abs(length(fragpos.xyz-spos.xyz));
		if (err < pow(length(vector)*pow(length(tvector),0.11),1.1)*1.5){
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
		#ifdef ReflectionPrevious
		//Previous frame reprojection from Chocapic13
		vec4 fragpositionPrev = gbufferProjectionInverse * vec4(pos*2.0-1.0,1.);
		fragpositionPrev /= fragpositionPrev.w;
		
		fragpositionPrev = gbufferModelViewInverse * fragpositionPrev;

		vec4 previousPosition = fragpositionPrev + vec4(cameraPosition-previousCameraPosition,0.0);
		previousPosition = gbufferPreviousModelView * previousPosition;
		previousPosition = gbufferPreviousProjection * previousPosition;
		previousPosition.xy = previousPosition.xy/previousPosition.w*0.5+0.5;
		
		color.a = texture2D(gaux2, previousPosition.st).a;
		//color.a = 1.0;
		if (color.a > 0.5){
			color.rgb = texture2D(gaux2, previousPosition.st).rgb;
			color.rgb = pow(color.rgb*2.0,vec3(8.0));
		}
		#else
		color.a = texture2D(gaux2, pos.st).a;
		//color.a = 1.0;
		if (color.a > 0.5){
			color.rgb = texture2D(gaux2, pos.st).rgb;
			color.rgb = pow(color.rgb*2.0,vec3(8.0));
		}
		#endif
		
		border = clamp(1.0 - pow(cdist(pos.st), 200.0), 0.0, 1.0);
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

#ifdef RPSupport
vec2 dcdx = dFdx(texcoord.xy);
vec2 dcdy = dFdy(texcoord.xy);

vec4 readTexture(vec2 coord){
	return texture2DGradARB(texture,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}
vec4 readNormal(vec2 coord){
	return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}

float mincoord = 1.0/4096.0;
#endif

#include "lib/color/dimensionColor.glsl"
#include "lib/color/torchColor.glsl"
#include "lib/color/waterColor.glsl"
#include "lib/common/dither.glsl"
#include "lib/common/fog.glsl"
#include "lib/common/spaceConversion.glsl"

#if AA == 2
#include "lib/common/jitter.glsl"
#endif

void main(){
	//Texture
	vec4 albedo = texture2D(texture, texcoord) * vec4(color.rgb,1.0);
	
	#ifdef RPSupport
	vec2 newcoord = vtexcoord.st*vtexcoordam.pq+vtexcoordam.st;
	vec2 coord = vtexcoord.st;
	float pomfade = clamp((dist-POMDistance)/32.0,0.0,1.0);
	
	#ifdef RPSPOM
	if (dist < POMDistance+32.0){
		vec3 normalmap = readNormal(vtexcoord.st).xyz*2.0-1.0;
		float normalcheck = normalmap.x + normalmap.y + normalmap.z;
		if (viewVector.z < 0.0 && readNormal(vtexcoord.st).a < (1.0-1.0/POMQuality) && normalcheck > -2.999){
			vec2 interval = viewVector.xy * 0.05 * (1.0-pomfade) * POMDepth /  (-viewVector.z * POMQuality);
			for (int i = 0; i < POMQuality; i++) {
				if (readNormal(coord).a < 1.0-float(i)/POMQuality) coord = coord+interval;
				else break;
			}
			if (coord.t < mincoord) {
				if (readTexture(vec2(coord.s,mincoord)).a == 0.0) {
					coord.t = mincoord;
					discard;
				}
			}
			newcoord = fract(coord.st)*vtexcoordam.pq+vtexcoordam.st;
			albedo = texture2DGradARB(texture, newcoord,dcdx,dcdy) * vec4(color.rgb,1.0);
		}
	}

	float smoothness = 0.0;
	float f0 = 0.0;
	#endif
	#endif
	
	vec3 rawalbedo = vec3(1.0);
	
	if (albedo.a > 0.0){
		//NDC Coordinate
		#if AA == 2
		vec3 fragpos = toNDC(vec3(taaJitter(gl_FragCoord.xy/vec2(viewWidth,viewHeight),-0.5),gl_FragCoord.z));
		#else
		vec3 fragpos = toNDC(vec3(gl_FragCoord.xy/vec2(viewWidth,viewHeight),gl_FragCoord.z));
		#endif
		
		//World Space Coordinate
		vec3 worldpos = toWorld(fragpos);
		
		//Normal Mapping
		vec3 newnormal = normal;
		vec3 normalmap = vec3(0.0,0.0,1.0);
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);
							  
		#if WaterNormals == 1 || WaterNormals == 2
		if (mat > 0.98 && mat < 1.02){
			vec3 posxz = wpos.xyz;
			#ifdef WaterParallax
			posxz = getParallaxWaves(posxz,viewVector,fragpos.xyz);
			#endif
			
			#if WaterNormals == 2
			float deltaPos = WaterSharpness;
			#else
			float deltaPos = 0.1;
			#endif
			#ifdef WaterDistantWave
			deltaPos += 0.3*clamp(dist/64.0-0.25,0.0,1.0);
			#endif
			float h0 = waterH(posxz,fragpos.xyz);
			float h1 = waterH(posxz + vec3(deltaPos,0.0,0.0),fragpos.xyz);
			float h2 = waterH(posxz + vec3(-deltaPos,0.0,0.0),fragpos.xyz);
			float h3 = waterH(posxz + vec3(0.0,0.0,deltaPos),fragpos.xyz);
			float h4 = waterH(posxz + vec3(0.0,0.0,-deltaPos),fragpos.xyz);
			
			float xDelta = ((h1-h0)+(h0-h2))/deltaPos;
			float yDelta = ((h3-h0)+(h0-h4))/deltaPos;
			
			normalmap = vec3(xDelta,yDelta,1.0-xDelta*xDelta-yDelta*yDelta);
			
			float bumpmult = 0.03;	
			
			normalmap = normalmap * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
			
			newnormal = clamp(normalize(normalmap * tbnMatrix),vec3(-1.0),vec3(1.0));
		}
		#endif
		#ifdef RPSupport
		if (mat < 0.02 || mat > 1.98){
			normalmap = texture2DGradARB(normals,newcoord.xy,dcdx,dcdy).xyz*2.0-1.0;
			if (texture2DGradARB(normals,newcoord.xy,dcdx,dcdy).a > 0.01) newnormal = normalize(normalmap * tbnMatrix);
		}
		#endif

		//Specular Mapping
		#ifdef RPSupport
		vec4 specularmap = texture2D(specular,texcoord.xy);

		#if RPSFormat == 0	//Old
		smoothness = specularmap.r;
		f0 = 0.02;
		#endif
		#if RPSFormat == 1	//PBR
		smoothness = specularmap.r;
		f0 = specularmap.g*specularmap.g;
		#endif
		#if RPSFormat == 2	//PBR + Emissive
		smoothness = specularmap.r;
		f0 = specularmap.g*specularmap.g;
		#endif
		#if RPSFormat == 3	//Continuum
		smoothness = sqrt(specularmap.b);
		f0 = specularmap.r*specularmap.r;
		#endif
		#if RPSFormat == 4	//LAB-PBR
		smoothness = 1.0-pow(1.0-specularmap.r,2.0);
		f0 = specularmap.g*specularmap.g;
		#endif
		#endif
		
		//Convert to linear color space
		albedo.rgb = pow(albedo.rgb, vec3(2.2));
		
		#ifdef DisableTexture
		albedo.rgb = vec3(0.5);
		#endif
		
		//Lightmap
		#ifdef LightmapBanding
		float torchmap = clamp(floor(lmcoord.x*14.999 * (0.75 + 0.25 * color.a)) / 14, 0.0, 1.0);
		float skymap = clamp(floor(lmcoord.y*14.999 * (0.75 + 0.25 * color.a)) / 14, 0.0, 1.0);
		#else
		float torchmap = clamp(lmcoord.x, 0.0, 1.0);
		float skymap = clamp(lmcoord.y, 0.0, 1.0);
		#endif
		
		//Material Flag
		float water = float(mat > 0.98 && mat < 1.02);
		float translucent = float(mat > 1.98 && mat < 2.02);
		
		#ifndef WaterVanilla
		if (water > 0.5){
			albedo = vec4(water_c * cmult, water_a);
			albedo.rgb *= albedo.rgb;
		}
		#endif
		
		rawalbedo = mix(vec3(1.0), albedo.rgb, sqrt(albedo.a))*(1.0-pow(albedo.a,64.0));
		
		//Shadows
		float quarterNdotU = clamp(0.25 * dot(normal, upVec) + 0.75,0.5,1.0);
		quarterNdotU *= quarterNdotU;
		
		//Lighting Calculation
		vec3 scenelight = nether_c*0.1;
		float newtorchmap = pow(torchmap,10.0)*(EmissiveBrightness+0.5)+(torchmap*0.7);
		
		vec3 blocklight = (newtorchmap * newtorchmap) * torch_c;
		#ifdef LightmapBanding
		scenelight *= floor(color.a*4.0+0.8)/4.0;
		float minlight = (0.009*screenBrightness + 0.001)*floor(color.a*4.0+0.8)/4.0;
		float ao = 1.0;
		#else
		float minlight = (0.009*screenBrightness + 0.001);
		float ao = color.a;
		#endif
		
		vec3 finallight = (scenelight + blocklight + nightVision + minlight) * ao;

		#ifdef RPSupport
		#if RPSFormat == 2
		finallight += albedo.rgb * luma(albedo.rgb) * (specularmap.b * 4.0 / quarterNdotU);
		#endif
		#endif

		albedo.rgb /= sqrt(albedo.rgb * albedo.rgb + 1.0);
		albedo.rgb *= finallight * quarterNdotU;
		
		#ifdef Desaturation
		float desat = clamp(sqrt(torchmap), DesaturationFactor * 0.4, 1.0);
		vec3 desat_c = nether_c*0.2*(1.0-desat);
		albedo.rgb = mix(luma(albedo.rgb)*desat_c*10.0,albedo.rgb,desat);
		#endif
		
		float fresnel = pow(clamp(1.0 + dot(newnormal, normalize(fragpos.xyz)),0.0,1.0),5.0);
		vec3 skyRef = nether_c * 0.01 * clamp(1.0-isEyeInWater,0.0,1.0);
		float dither = bayer64(gl_FragCoord.xy);

		if (water > 0.5 || (translucent > 0.5 && albedo.a < 0.95)){
			vec4 reflection = vec4(0.0);
			
			fresnel = (fresnel*0.98 + 0.02) * max(1.0-isEyeInWater*0.75*water,0.25) * (1.0-translucent*0.5);
			
			#ifdef Reflection
			reflection = raytrace(fragpos.xyz,newnormal,dither);
			#endif
			
			reflection.rgb = mix(skyRef,reflection.rgb,reflection.a);
			
			albedo.rgb = mix(albedo.rgb,max(reflection.rgb,vec3(0.0)),fresnel);
			albedo.a = mix(albedo.a,1.0,fresnel);
		}else{
			#ifdef RPSupport
			fresnel = mix(f0, 1.0, fresnel) * smoothness * smoothness;

			#ifdef RPSRefRough
			vec2 noisecoord = gl_FragCoord.xy/512.0;
			#if AA == 2
			noisecoord += fract(frameCounter*vec2(0.4,0.25));
			#endif
			#endif

			#ifdef RPSReflection
			if(fresnel > 0.001){
				vec4 reflection = vec4(0.0);
				
				#ifdef RPSRefRough
				if(smoothness > 0.95) reflection = raytrace(fragpos.xyz,newnormal,dither);
				else reflection = raytraceRough(fragpos.xyz,newnormal,dither,1.0-smoothness,noisecoord);
				#else
				reflection = raytrace(fragpos.xyz,newnormal,dither);
				#endif

				reflection.rgb = mix(skyRef,reflection.rgb,reflection.a);
				
				if (f0 >= 0.8) reflection.rgb *= albedo.rgb * 20.0;
				
				albedo.rgb = mix(albedo.rgb,reflection.rgb,fresnel);
				albedo.a = mix(albedo.a,1.0,fresnel);
			}
			#endif
			#endif
		}
		
		//Fog
		#ifdef Fog
		albedo.rgb = calcFog(albedo.rgb, fragpos.xyz, blindness);
		if (isEyeInWater == 1) albedo.a = mix(albedo.a,1.0,min(length(fragpos)/wfogrange,1.0));
		#endif
	}
	
/* DRAWBUFFERS:01 */

	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(rawalbedo,1.0);
}