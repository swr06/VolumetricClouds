#version 330 core

#define PI 3.14159265359
#define TAU (3.14159265359 * 2)

#define Bayer4(a)   (Bayer2(  0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer8(a)   (Bayer4(  0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer16(a)  (Bayer8(  0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer32(a)  (Bayer16( 0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer64(a)  (Bayer32( 0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer128(a) (Bayer64( 0.5 * (a)) * 0.25 + Bayer2(a))
#define Bayer256(a) (Bayer128(0.5 * (a)) * 0.25 + Bayer2(a))

layout (location = 0) out vec4 o_Position;
layout (location = 1) out vec3 o_Data;

in vec2 v_TexCoords;
in vec3 v_RayDirection;
in vec3 v_RayOrigin;

uniform float u_Time;
uniform int u_CurrentFrame;
uniform int u_SliceCount;
uniform vec2 u_Dimensions;

uniform sampler2D u_WorleyNoise;
uniform sampler3D u_CloudNoise;
uniform sampler2D u_BlueNoise;

uniform float u_Coverage;
uniform vec3 u_SunDirection;
uniform float BoxSize;

struct Ray
{
	vec3 Origin;
	vec3 Direction;
};

vec3 GetSkyColorAt(vec3 rd) 
{
    vec3 unit_direction = normalize(rd);

    float t = 0.5f * (unit_direction.y + 1.0);
    return (1.0 - t) * vec3(1.0, 1.0, 1.0) +  t * vec3(0.5, 0.7, 1.0);
}

float ConvertValueRange(in float v, in vec2 r1, in vec2 r2)
{
	float ret = (((v - r1.x) * (r2.y - r2.x)) / (r1.y - r1.x)) + r2.x;
	return ret;
}

vec2 RayBoxIntersect(vec3 boundsMin, vec3 boundsMax, vec3 rayOrigin, vec3 invRaydir)
{
	vec3 t0 = (boundsMin - rayOrigin) * invRaydir;
	vec3 t1 = (boundsMax - rayOrigin) * invRaydir;
	vec3 tmin = min(t0, t1);
	vec3 tmax = max(t0, t1);
	
	float dstA = max(max(tmin.x, tmin.y), tmin.z);
	float dstB = min(tmax.x, min(tmax.y, tmax.z));
	
	// CASE 1: ray intersects box from outside (0 <= dstA <= dstB)
	// dstA is dst to nearest intersection, dstB dst to far intersection
	
	// CASE 2: ray intersects box from inside (dstA < 0 < dstB) 
	// dstA is the dst to intersection behind the ray, dstB is dst to forward intersection
	
	// CASE 3: ray misses box (dstA > dstB)
	
	float dstToBox = max(0, dstA);
	float dstInsideBox = max(0, dstB - dstToBox);
	return vec2(dstToBox, dstInsideBox);
}

float remap(float x, float a, float b, float c, float d)
{
    return (((x - a) / (b - a)) * (d - c)) + c;
}

vec4 SampleNoise(in vec3 p)
{
	vec4 sampled_noise = texture(u_CloudNoise, vec3(p.xzy * 0.01f)).rgba;
	return sampled_noise;
}

float SampleDensity(in vec3 point)
{
	vec4 sampled_noise;

	//vec2 uv = point.xz * 0.002;
	//int slice = (u_CurrentFrame / 6) % u_SliceCount;
	//float z = float(slice) / float(u_SliceCount); 
	//sampled_noise = texture(u_CloudNoise, vec3(uv, z)).rgba;


	sampled_noise = texture(u_CloudNoise, point.xzy * 0.01f).rgba;

	float perlinWorley = sampled_noise.x;
	vec3 worley = sampled_noise.yzw;
	float wfbm = worley.x * 0.625f +
	    		 worley.y * 0.125f +
	    		 worley.z * 0.25f; 
	
	float cloud = remap(perlinWorley, wfbm - 1.0f, 1.0f, 0.0f, 1.0f);
	cloud = remap(cloud, 1.0f - u_Coverage, 1.0f, 0.0f, 1.0f); 

	return cloud;
}

float hg(float a, float g) 
{
    float g2 = g * g;
    return (1.0f - g2) / (4 * PI * pow(1.0f + g2 - 2.0f * g * (a), 1.5));
}

vec3 Beer(in vec3 v)
{
	return exp(-v);
}

float Beer (in float v)
{
	return exp(-v);
}

float hgPhase(float x, float g)
{
    float g2 = g * g;
	return 0.25 * ((1.0 - g2) * pow(1.0 + g2 - 2.0*g*x, -1.5));
}

float phase2Lobes(float x)
{
    const float m = 0.6;
    const float gm = 0.8;
    
	float lobe1 = hgPhase(x, 0.8 * gm);
    float lobe2 = hgPhase(x, -0.5 * gm);
    
    return mix(lobe2, lobe1, m);
}

float Bayer2(vec2 a) 
{
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

int BLUE_NOISE_IDX = 0;

float GetBlueNoise()
{
	BLUE_NOISE_IDX++;
	vec2 txc =  vec2(BLUE_NOISE_IDX / 256, mod(BLUE_NOISE_IDX, 256));
	return texelFetch(u_BlueNoise, ivec2(txc), 0).r;
}

float RaymarchLight(vec3 p)
{
	int StepCount = 4;
	vec3 ldir = normalize(vec3(u_SunDirection.x, u_SunDirection.y, u_SunDirection.z));

	float tmin, tmax;
	vec2 Dist = RayBoxIntersect(vec3(-BoxSize, 50.0f, -BoxSize), vec3(BoxSize, 40.0f, BoxSize), p, 1.0f / ldir);
	bool Intersect = !(Dist.y == 0.0f);
	
	if (!Intersect)
	{
		return 1.0f;
	}
	
	tmin = Dist.x;
	tmax = Dist.y;

	float StepSize = tmax / float(StepCount);

	float TotalDensity = 0.0f;
	vec3 CurrentPoint = p;

	for (int i = 0 ; i < StepCount ; i++)
	{
		float Dither = GetBlueNoise();

		float DensitySample = SampleDensity(CurrentPoint);
		TotalDensity += max(0.0f, DensitySample * StepSize);
		CurrentPoint += ldir * (StepSize * Dither);
	}

	float LightTransmittance = exp(-TotalDensity);

	float Darken = 0.2f;
	LightTransmittance = Darken + LightTransmittance * (1.0f - Darken);

	return LightTransmittance;
}

float RaymarchCloud(vec3 p, vec3 dir, float tmin, float tmax, out float Transmittance)
{
	int StepCount = 7;
	float StepSize = tmax / float(StepCount);

	vec3 CurrentPoint = p;
	float AccumulatedLightEnergy = 0.0f;
	Transmittance = 1.0f;
	float CosAngle = max(0.0f, pow(dot(normalize(v_RayDirection), normalize(u_SunDirection)), 2.0f));
	float Phase = hgPhase(CosAngle, 0.5f);

	for (int i = 0 ; i < StepCount ; i++)
	{
		float Dither = GetBlueNoise();

		float DensitySample = SampleDensity(CurrentPoint);
		float LightMarchSample = RaymarchLight(CurrentPoint);
		AccumulatedLightEnergy += DensitySample * StepSize * LightMarchSample * Transmittance * (Phase * 1.01f);
		Transmittance *= exp(-DensitySample * StepSize);

		CurrentPoint += normalize(dir) * (StepSize * (Dither));

		if (Transmittance < 0.01f)
		{
			break;
		}
	}
	
	float TotalCloudDensity = AccumulatedLightEnergy;
	return TotalCloudDensity;
}

void ComputeCloudData(in Ray r)
{
	vec2 Dist = RayBoxIntersect(vec3(-BoxSize, 50.0f, -BoxSize), vec3(BoxSize, 40.0f, BoxSize), r.Origin, 1.0f / r.Direction);
	bool Intersect = !(Dist.y == 0.0f);

	if (Intersect)
	{
		vec3 IntersectionPosition = r.Origin + (r.Direction * Dist.x);
		o_Position.xyz = IntersectionPosition;
		o_Position.w = Dist.y;

		float Transmittance = 1.0f;
		float CloudAt = RaymarchCloud(IntersectionPosition, r.Direction, Dist.x, Dist.y, Transmittance);
		CloudAt = max(CloudAt, 0.0f);
		Transmittance = max(Transmittance, 0.0f);
		o_Data = vec3(CloudAt, Transmittance, 0.0f);
	}
}

void main()
{
	//int res = u_CurrentFrame % 2 == 0 ? 1 : 0;
	//
	//if (int(gl_FragCoord.x + gl_FragCoord.y) % 2 == res)
	//{
	//	o_Position = vec4(0.0f);
	//	o_Data = vec3(0.0f);
	//
	//	return;
	//}

	o_Position = vec4(0.0f);
	o_Data = vec3(0.0f);

	int RNG_SEED;
	RNG_SEED = int(gl_FragCoord.x) + int(gl_FragCoord.y) * int(u_Dimensions.x) * int(u_Time * 1000);

	RNG_SEED ^= RNG_SEED << 13;
    RNG_SEED ^= RNG_SEED >> 17;
    RNG_SEED ^= RNG_SEED << 5;

	BLUE_NOISE_IDX += RNG_SEED;
	BLUE_NOISE_IDX = BLUE_NOISE_IDX % (255 * 255);
	
    Ray r;
    r.Origin = v_RayOrigin;
    r.Direction = normalize(v_RayDirection);
	
	ComputeCloudData(r);
}