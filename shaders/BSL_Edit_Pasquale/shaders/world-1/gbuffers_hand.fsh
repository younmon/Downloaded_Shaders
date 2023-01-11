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
#define RPSupport
#define RPSFormat 1 //[0 1 2 3]
#define RPSReflection
//#define RPSPom

varying float isMainHand;

varying vec2 lmcoord;
varying vec2 texcoord;

varying vec3 normal;
varying vec3 upVec;

varying vec4 color;

#ifdef RPSupport
varying float dist;
varying vec3 binormal;
varying vec3 tangent;
varying vec3 viewVector;
varying vec4 vtexcoordam;
varying vec4 vtexcoord;
#endif

uniform int heldItemId;
uniform int heldItemId2;
uniform int isEyeInWater;
uniform int worldTime;

uniform float frameTimeCounter;
uniform float nightVision;
uniform float rainStrength;
uniform float screenBrightness; 
uniform float viewWidth;
uniform float viewHeight;

uniform ivec2 eyeBrightnessSmooth;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform sampler2D texture;

#ifdef RPSupport
uniform sampler2D specular;
uniform sampler2D normals;
#endif

float luma(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
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
#include "lib/common/spaceConversion.glsl"

void main(){
	//Texture
	vec4 albedo = texture2D(texture, texcoord) * color;
	vec3 newnormal = normal;
	
	#ifdef RPSupport
	vec2 newcoord = vtexcoord.st*vtexcoordam.pq+vtexcoordam.st;
	vec2 coord = vtexcoord.st;
	
	#ifdef RPSPOM
	vec3 normalmap = readNormal(vtexcoord.st).xyz*2.0-1.0;
	float normalcheck = normalmap.x + normalmap.y + normalmap.z;
	if (viewVector.z < 0.0 && readNormal(vtexcoord.st).a < (1.0-1.0/POMQuality) && normalcheck > -2.999){
		vec2 interval = viewVector.xy * 0.05 * POMDepth / (-viewVector.z * POMQuality);
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
		albedo = texture2DGradARB(texture, newcoord,dcdx,dcdy) * color;
	}
	#endif
	
	float smoothness = 0.0;
	float f0 = 0.0;
	vec3 rawalbedo = vec3(0.0);
	#endif
	
	if (albedo.a > 0.0){
		//NDC Coordinate
		vec3 fragpos = toNDC(vec3(gl_FragCoord.xy/vec2(viewWidth,viewHeight),gl_FragCoord.z+0.38));
		
		//World Space Coordinate
		vec3 worldpos = toWorld(fragpos);
		
		float doRecolor = float((heldItemId  == 89.0 || heldItemId  == 138.0 || heldItemId  == 169.0 || heldItemId  == 213.0) && isMainHand > 0.5);
			  doRecolor+= float((heldItemId2  == 89.0 || heldItemId2  == 138.0 || heldItemId2  == 169.0 || heldItemId2 == 213.0) && isMainHand < 0.5);
		#ifdef EmissiveRecolor
		vec3 rawtorch_c = Torch*Torch/TorchS;
		if (doRecolor > 0.5){
			float ec = clamp(pow(length(albedo.rgb),1.4),0.0,2.2);
			albedo.rgb = clamp(ec*rawtorch_c*0.25+ec*0.25,vec3(0.0),vec3(2.2));
		}
		#else
		if (doRecolor > 0.5) albedo.rgb *= 0.5 * luma(albedo.rgb) + 0.25;
		#endif
		
		//Normal Mapping
		#ifdef RPSupport
		vec3 normalmap = texture2DGradARB(normals,newcoord.xy,dcdx,dcdy).xyz*2.0-1.0;
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
							tangent.z, binormal.z, normal.z);
		
		newnormal = normalize(normalmap * tbnMatrix);
		#endif
		
		//Specular Mapping
		#ifdef RPSupport
		vec4 specularmap = texture2DGradARB(specular,newcoord.xy,dcdx,dcdy);

		#if RPSFormat == 0	//Old
		smoothness = specularmap.r;
		f0 = float((heldItemId == 41.0 || heldItemId == 42.0 || heldItemId == 71.0 || heldItemId == 145.0) && isMainHand > 0.5);
		f0 += float((heldItemId2 == 41.0 || heldItemId2 == 42.0 || heldItemId2 == 71.0 || heldItemId2 == 145.0) && isMainHand < 0.5);
		f0 = f0*0.785+0.02;
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
		
		#ifdef RPSupport
		vec3 rawalbedo = vec3(0.0);
		#endif
		
		//Lightmap
		#ifdef LightmapBanding
		float torchmap = clamp(floor(lmcoord.x*14.999) / 14, 0.0, 1.0);
		float skymap = clamp(floor(lmcoord.y*14.999) / 14, 0.0, 1.0);
		#else
		float torchmap = clamp(lmcoord.x, 0.0, 1.0);
		float skymap = clamp(lmcoord.y, 0.0, 1.0);
		#endif
		
		//Magma Block Handlight
		torchmap = max(torchmap,float(heldItemId == 213));
		
		//Shadows
		float quarterNdotU = clamp(0.25 * dot(normal, upVec) + 0.75,0.5,1.0);
		quarterNdotU *= quarterNdotU;
		
		//Lighting Calculation
		vec3 scenelight = nether_c*0.1;
		float newtorchmap = pow(torchmap,10.0)*(EmissiveBrightness+0.5)+(torchmap*0.7);
		
		vec3 blocklight = (newtorchmap * newtorchmap) * torch_c;
		float minlight = (0.009*screenBrightness + 0.001);
		
		float emissive = 0.0;
		#ifdef RPSupport
		#if RPSFormat == 2
		emissive = specularmap.b;
		#endif
		#endif
		vec3 emissivelight = albedo.rgb * luma(albedo.rgb) * (emissive * 4.0 / quarterNdotU);
		
		vec3 finallight = scenelight + blocklight + emissivelight + nightVision + minlight;
		albedo.rgb /= sqrt(albedo.rgb * albedo.rgb + 1.0);
		albedo.rgb *= finallight * quarterNdotU;
		
		#ifdef Desaturation
		float desat = clamp(sqrt(torchmap) + emissive, DesaturationFactor * 0.4, 1.0);
		vec3 desat_c = nether_c*0.2*(1.0-desat);
		albedo.rgb = mix(luma(albedo.rgb)*desat_c*10.0,albedo.rgb,desat);
		#endif
	}
	
/* DRAWBUFFERS:0 */
	gl_FragData[0] = albedo;
	#ifdef RPSupport
	#ifdef RPSReflection
/* DRAWBUFFERS:036 */
	gl_FragData[1] = vec4(smoothness,f0,0.0,1.0);
	gl_FragData[2] = vec4(newnormal*0.5+0.5,1.0);
	#endif
	#endif
}