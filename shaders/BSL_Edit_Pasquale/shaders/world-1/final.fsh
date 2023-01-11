#version 120

/*
BSL Shaders by Capt Tatsu
https://www.bitslablab.com
*/

#define RPSupport
#define RPSReflection

#define About 0 //[0]

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

#ifdef RPSupport
#ifdef RPSReflection
const int colortex3Format = RGB8; //reflection information
const int gaux3Format = RGB16; //normals
const int gaux4Format = RGB16; //specular highlight
#endif
#endif

const float sunPathRotation = -30.0; //[-60.0 -55.0 -50.0 -45.0 -40.0 -35.0 -30.0 -25.0 -20.0 -15.0 -10.0 -5.0 0.0 5.0 10.0 15.0 20.0 25.0 30.0 35.0 40.0 45.0 50.0 55.0 60.0]
const int noiseTextureResolution = 512;
const bool shadowHardwareFiltering = true;
const float drynessHalflife = 25.0f;
const float wetnessHalflife = 400.0f;

varying vec2 texcoord;

uniform sampler2D colortex1;

void main(){
	
	vec3 color = texture2D(colortex1,texcoord.xy).rgb;
	
	#ifdef About
	#endif
	
	gl_FragColor = vec4(color,1.0);

}