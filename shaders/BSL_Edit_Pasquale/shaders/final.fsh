#version 120

/*
BSL Shaders by Capt Tatsu
https://www.bitslablab.com
*/

//#define Puddles
#define RPSupport
#define RPSReflection

#define Sharpen 3 

//Buffer Format
const int R11F_G11F_B10F = 0;
const int RGB10_A2 = 1;
const int RGBA16 = 2;
const int RGB16 = 3;
const int RGB8 = 4;
const int R32F = 5;
const int R16 = 6;

const int colortex0Format = R11F_G11F_B10F; //main
const int colortex1Format = RGB8; //raw translucent, bloom
const int colortex2Format = RGBA16; //temporal stuff

const int gaux1Format = R32F; //depth
const int gaux2Format = RGB10_A2; //reflection image

#if defined RPSupport || defined Puddles
#if defined RPSReflection || defined Puddles
const int colortex3Format = RGB8; //reflection information
const int gaux3Format = RGB16; //normals
const int gaux4Format = RGB16; //specular highlight
#endif
#endif

const float sunPathRotation = -30.0; 
const int noiseTextureResolution = 256;
const bool shadowHardwareFiltering = true;
const float drynessHalflife = 25.0f;
const float wetnessHalflife = 400.0f;

varying vec2 texcoord;

#if Sharpen > 0
uniform float viewWidth;
uniform float viewHeight;
#endif

uniform sampler2D colortex1;

void main(){
	
	vec3 color = texture2D(colortex1,texcoord.xy).rgb;

	#if Sharpen > 0
	vec2 view = 1.0 / vec2(viewWidth,viewHeight);
	color *= Sharpen * 0.1 + 1.0;
	color -= texture2D(colortex1,texcoord.xy+vec2(1.0,0.0)*view).rgb * Sharpen * 0.025;
	color -= texture2D(colortex1,texcoord.xy+vec2(0.0,1.0)*view).rgb * Sharpen * 0.025;
	color -= texture2D(colortex1,texcoord.xy+vec2(-1.0,0.0)*view).rgb * Sharpen * 0.025;
	color -= texture2D(colortex1,texcoord.xy+vec2(0.0,-1.0)*view).rgb * Sharpen * 0.025;
	#endif
	
	gl_FragColor = vec4(color,1.0);

}