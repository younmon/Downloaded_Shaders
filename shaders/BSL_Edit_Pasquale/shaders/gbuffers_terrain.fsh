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
#define Desaturation
#define DesaturationFactor 2.0 //[2.0 1.5 1.0 0.5 0.0]
//#define DisableTexture
#define EmissiveBrightness 1.00 //[0.00 0.05 0.10 0.15 0.20 0.25 0.30 0.35 0.40 0.45 0.50 0.55 0.60 0.65 0.70 0.75 0.80 0.85 0.90 0.95 1.00]
#define EmissiveRecolor
//#define LightmapBanding
#define POMQuality 32 //[4 8 16 32 64 128 256 512]
#define POMDepth 1.00 //[0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00]
#define POMDistance 64.0 //[16.0 32.0 48.0 64.0 80.0 96.0 112.0 128.0]
#define POMShadowAngle 2.0 //[0.5 1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0]
//#define Puddles
#define RPSupport
#define RPSFormat 1 //[0 1 2 3]
#define RPSReflection
//#define RPSPom
//#define RPSShadow
#define ShadowColor
#define ShadowFilter

const int shadowMapResolution = 4096; //[512 1024 2048 3072 4096 8192]
const float shadowDistance = 256.0; //[128.0 256.0]
const float shadowMapBias = 1.0-25.6/shadowDistance;

varying float mat;
varying float recolor;

varying vec2 lmcoord;
varying vec2 texcoord;

varying vec3 normal;
varying vec3 upVec;
varying vec3 sunVec;

varying vec4 color;

#ifdef RPSupport
varying float dist;
varying vec3 binormal;
varying vec3 tangent;
varying vec3 viewVector;
varying vec4 vtexcoordam;
varying vec4 vtexcoord;
#endif

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

#ifdef Puddles
uniform float wetness;
uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
#endif

uniform sampler2D texture;

#ifdef RPSupport
uniform sampler2D specular;
uniform sampler2D normals;
#endif

#ifdef Puddles
uniform sampler2D noisetex;
#endif

uniform sampler2DShadow shadowtex0;
#ifdef ShadowColor
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;
#endif

float eBS = eyeBrightnessSmooth.y/240.0;
float sunVisibility = clamp(dot(sunVec,upVec)+0.05,0.0,0.1)/0.105;
float moonVisibility = clamp(dot(-sunVec,upVec)+0.05,0.0,0.1)/0.1;

vec3 lightVec = sunVec*(1.0-2.0*float(timeAngle > 0.5325 && timeAngle < 0.9675));

float luma(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float gradNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameCounter/8.0);
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

#ifdef Puddles
float getPuddles(vec3 pos){
	pos = (pos + cameraPosition) * 0.005;

	float noise = texture2D(noisetex,pos.xz).r;
		  noise+= texture2D(noisetex,pos.xz*0.5).r*2.0;
		  noise+= texture2D(noisetex,pos.xz*0.25).r*4.0;
		  noise+= texture2D(noisetex,pos.xz*0.125).r*8.0;
		  noise+= texture2D(noisetex,pos.xz*0.0625).r*16.0;
		  noise = max(abs(noise-15.5)*1.6-1.0,0.0)*wetness;
		  noise /= sqrt(noise*noise+1.0);

	return clamp(noise,0.0,0.95);
}
#endif

#include "lib/color/lightColor.glsl"
#include "lib/color/torchColor.glsl"
#include "lib/common/spaceConversion.glsl"

#if defined RPSupport || defined Puddles
#include "lib/common/ggx.glsl"
#endif

#if AA == 2
#include "lib/common/jitter.glsl"
#endif

void main(){
	//Texture
	vec4 albedo = texture2D(texture, texcoord) * vec4(color.rgb,1.0);
	vec3 newnormal = normal;
	
	#ifdef RPSupport
	vec2 newcoord = vtexcoord.st*vtexcoordam.pq+vtexcoordam.st;
	vec2 coord = vtexcoord.st;
	float pomfade = clamp((dist-POMDistance)/32.0,0.0,1.0);
	
	#ifdef RPSPOM
	if (dist < POMDistance+32.0){
		vec3 normalmap = readNormal(vtexcoord.st).xyz*2.0-1.0;
		float normalcheck = normalmap.x + normalmap.y + normalmap.z;
		if (viewVector.z < 0.0 && readNormal(vtexcoord.st).a < (1.0-1.0/POMQuality) && normalcheck > -2.999){
			vec2 interval = viewVector.xy * 0.05 * (1.0-pomfade) * POMDepth / (-viewVector.z * POMQuality);
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
	#endif
	#endif
	
	#if defined RPSupport || defined Puddles
	float smoothness = 0.0;
	float f0 = 0.0;
	float skymapmod = 0.0;
	vec3 rawalbedo = vec3(0.0);
	vec3 spec = vec3(0.0);
	#endif
	
	if (albedo.a > 0.0){
		//NDC Coordinate
		#if AA == 2
		vec3 fragpos = toNDC(vec3(taaJitter(gl_FragCoord.xy/vec2(viewWidth,viewHeight),-0.5),gl_FragCoord.z));
		#else
		vec3 fragpos = toNDC(vec3(gl_FragCoord.xy/vec2(viewWidth,viewHeight),gl_FragCoord.z));
		#endif
		
		//World Space Coordinate
		vec3 worldpos = toWorld(fragpos);

		//Emissive Recolor
		#ifdef EmissiveRecolor
		vec3 rawtorch_c = Torch*Torch/TorchS;
		if (recolor > 0.9){
			float ec = clamp(pow(length(albedo.rgb),1.4),0.0,2.2);
			albedo.rgb = clamp(ec*rawtorch_c*0.25+ec*0.25,vec3(0.0),vec3(2.2));
		}
		if (mat > 2.98 && mat < 3.02){
			float ec = clamp(pow(length(albedo.rgb),1.4),0,2.2);
			albedo.rgb = clamp(ec*rawtorch_c*0.6+ec*0.015,vec3(0),vec3(2.2));
		}
		#else
		if (recolor > 0.9) albedo.rgb *=  0.5 * luma(albedo.rgb) + 0.25;
		#endif
		
		//Normal Mapping
		#ifdef RPSupport
		vec3 normalmap = texture2DGradARB(normals,newcoord.xy,dcdx,dcdy).xyz*2.0-1.0;
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
							tangent.z, binormal.z, normal.z);
		
		if (normalmap.x + normalmap.y + normalmap.z > -2.999) newnormal = normalize(normalmap * tbnMatrix);
		#endif

		//Specular Mapping
		#ifdef RPSupport
		vec4 specularmap = texture2DGradARB(specular,newcoord.xy,dcdx,dcdy);

		#if RPSFormat == 0	//Old
		smoothness = specularmap.r;
		f0 = float(mat > 3.98 && mat < 4.02)*0.785+0.02;
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

		rawalbedo = albedo.rgb;
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
		float foliage = float(mat > 0.98 && mat < 1.02);
		float emissive = float(mat > 1.98 && mat < 2.02) * EmissiveBrightness;
		float lava = float(mat > 2.98 && mat < 3.02);

		//Puddles
		#ifdef Puddles
		float NdotU = clamp(dot(newnormal, upVec),0.0,1.0);

		float puddles = getPuddles(worldpos) * NdotU * wetness;
		puddles *= clamp(skymap * 32.0 - 31.0, 0.0, 1.0);

		smoothness = mix(smoothness, 1.0, puddles);
		f0 = max(f0, puddles * 0.02);
		#endif
		
		//Shadows
		float shadow = 0.0;
		vec3 shadowcol = vec3(0.0);
		
		float NdotL = clamp(dot(newnormal,lightVec)*1.01-0.01,0.0,1.0);
		float quarterNdotU = clamp(0.25 * dot(newnormal, upVec) + 0.75,0.5,1.0);
		quarterNdotU *= quarterNdotU;
		if (foliage > 0.5) quarterNdotU *= 1.8;
		
		worldpos = toShadow(worldpos);
		
		float distb = sqrt(worldpos.x * worldpos.x + worldpos.y * worldpos.y);
		float distortFactor = 1.0 - shadowMapBias + distb * shadowMapBias;
		
		worldpos.xy /= distortFactor;
		worldpos.z *= 0.2;
		worldpos = worldpos*0.5+0.5;

		float doShadow = float(worldpos.x > -1.0 && worldpos.x < 1.0 && worldpos.y > -1.0 && worldpos.y < 1.0);
		
		if ((NdotL > 0.0 || foliage > 0.5) && skymap > 0.001){
			if (doShadow > 0.5){
			float NdotLm = NdotL * 0.99 + 0.01;
			float diffthresh = (6.0 *distortFactor * distortFactor * sqrt(1.0 - NdotLm *NdotLm) / NdotLm * pow(shadowDistance/256.0, 2.0) + 0.05) / shadowMapResolution;
			float step = 1.0/shadowMapResolution;
			
			if (foliage > 0.5){
				diffthresh = 0.0002;
				step = 0.0009765625;
			}

			worldpos.z -= diffthresh;
			
			#if AA == 2
			float noise = gradNoise()*3.1;
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
			} else shadow = 0.5;
		}
		
		float sss = pow(clamp(dot(normalize(fragpos.xyz),lightVec),0.0,1.0),25.0) * (1.0-rainStrength);

		//RPS Parallax Shadows
		#ifdef RPSupport
		#ifdef RPSShadow
		if (dist < POMDistance+32.0 && skymap > 0.0 && NdotL > 0.0){
			float height = texture2DGradARB(normals,newcoord.xy,dcdx,dcdy).a;
			float parallaxshadow = 1.0;
			if (height < (1.0-1.0/POMQuality)){
				vec3 parallaxdir = (tbnMatrix * lightVec);
				parallaxdir.xy *= 0.1 * POMShadowAngle * POMDepth;
				float step = 1.28/POMQuality;
				
				for(int i = 0; i < POMQuality/4; i++){
					float currz = height + parallaxdir.z * step * i;
					float offsetheight = texture2DGradARB(normals,fract(coord.st+parallaxdir.xy*i*step)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy).a;
					parallaxshadow *= clamp(1.0-(offsetheight-currz)*40.0,0.0,1.0);
					if (parallaxshadow < 0.01) break;
				}
				
				parallaxshadow = mix(parallaxshadow,1.0,pomfade);
				NdotL *= parallaxshadow;
			}
		}
		#endif
		#endif
		
		vec3 fullshading = max(vec3(shadow), shadowcol) * max(NdotL, foliage) * (3.0 * sss * foliage + 1.0);
		float lightmult = (4.0-3.0*eBS);
		
		//Lighting Calculation
		vec3 scenelight = (mix(ambient*color.a, light, fullshading * (shadowFade * (1.0-0.95*rainStrength))) * lightmult)  * skymap * skymap;
		float newtorchmap = pow(torchmap,10.0)*(EmissiveBrightness+0.5)+(torchmap*0.7);
		
		vec3 blocklight = (newtorchmap * newtorchmap) * torch_c;
		#ifdef LightmapBanding
		float minlight = (0.009*screenBrightness + 0.001)*floor(color.a*4.0+0.999)/4.0*(1.0-eBS);
		float ao = 1.0;
		#else
		float minlight = (0.009*screenBrightness + 0.001)*(1.0-eBS);
		float ao = color.a;
		#endif
		
		#ifdef RPSupport
		#if RPSFormat == 2
		emissive = specularmap.b;
		#endif
		#endif
		vec3 emissivelight = albedo.rgb * luma(albedo.rgb) * ((emissive + lava) * 4.0 / quarterNdotU);
		
		vec3 finallight = (scenelight + blocklight + nightVision + minlight) * ao + emissivelight;
		albedo.rgb /= sqrt(albedo.rgb * albedo.rgb + 1.0);
		albedo.rgb *= finallight * quarterNdotU;

		#ifdef Puddles
		albedo.rgb *= 1.0-0.25*puddles;
		#endif
		
		#ifdef Desaturation
		float desat = clamp(max(sqrt(sqrt(length(fullshading/3)))*skymap,skymap)*sunVisibility*(1-rainStrength*0.4) + sqrt(torchmap + emissive), DesaturationFactor * 0.3, 1.0);
		vec3 desat_c = mix(vec3(0.1),mix(weather*0.5, light_n/(LightNS*LightNS), (1.0 - sunVisibility)*(1.0 - rainStrength)),sqrt(skymap))*(1.0-desat);
		albedo.rgb = mix(luma(albedo.rgb)*desat_c*10.0,albedo.rgb,desat);
		#endif
		
		//RPSupport Reflection
		#if defined RPSupport || defined Puddles
		skymapmod = clamp(skymap*9-8.2,0.0,1.0);
		
		if (dot(fullshading,fullshading) > 0.0){
			vec3 metalcol = mix(vec3(1.0), pow(rawalbedo, vec3(2.2)),float(f0 >= 0.8));
			vec3 light_me = mix(light_m,light_a,mefade);
			vec3 speccol = mix(sqrt(light_n),mix(light_me,light_d*sqrt(light_me),timeBrightness),sunVisibility);

			spec = pow(speccol,vec3(1.0-0.5*f0)) * max(vec3(shadow), shadowcol) * shadowFade * skymap * metalcol * (1.0 - rainStrength);
			spec *= GGX(newnormal,normalize(fragpos.xyz),lightVec,1.0-smoothness,f0);
			albedo.rgb += spec;
		}
		#endif
	}
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
	#if defined RPSupport || defined Puddles
	#if defined RPSReflection || defined Puddles
/* DRAWBUFFERS:0367 */
	gl_FragData[1] = vec4(smoothness,f0,skymapmod,1.0);
	gl_FragData[2] = vec4(newnormal*0.5+0.5,1.0);
	gl_FragData[3] = vec4(spec/(4.0+spec),1.0);
	#endif
	#endif
}