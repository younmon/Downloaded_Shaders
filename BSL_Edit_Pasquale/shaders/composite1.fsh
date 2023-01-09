#version 120
#extension GL_ARB_shader_texture_lod : enable

/*
BSL Shaders by Capt Tatsu
https://www.bitslablab.com
*/

#define VL
#define VLStrength 1.00

const bool colortex1MipmapEnabled = true;

varying vec3 upVec;
varying vec3 sunVec;

varying vec2 texcoord;

uniform int isEyeInWater;
uniform int worldTime;

uniform float blindness;
uniform float rainStrength;
uniform float shadowFade;
uniform float timeAngle;
uniform float timeBrightness;
uniform float frameTimeCounter;

uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex0;

float eBS = eyeBrightnessSmooth.y/240.0;
float sunVisibility = clamp(dot(sunVec,upVec)+0.05,0.0,0.1)/0.1;

#include "lib/color/lightColor.glsl"

void main(){
	vec4 color = texture2D(colortex0,texcoord.xy);
	
	//Light Shafts
	#ifdef VL
	vec3 vl = texture2DLod(colortex1,texcoord.xy,1.5).rgb;
	float z = texture2D(depthtex0,texcoord.xy).r;
	
	float b = clamp(blindness*2.0-1.0,0.0,1.0);
	b = b*b;
	
	color.rgb += vl * vl * light * VLStrength * (0.5 * (1.0-rainStrength*eBS*0.875) * shadowFade * (1.0-b))*vec3(1.6,1.5,1.1);
	//color.rgb = vl * vl;
	#endif
	
/*DRAWBUFFERS:0*/
	gl_FragData[0] = color;
}
