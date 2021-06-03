#version 330 core


#define PI 3.14159265359
#define TAU (3.14159265359 * 2)

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;
in vec3 v_RayDirection;
in vec3 v_RayOrigin;

uniform float u_Time;
uniform int u_CurrentFrame;
uniform int u_SliceCount;
uniform vec2 u_Dimensions;

uniform sampler2D u_WorleyNoise;
uniform sampler3D u_CloudNoise;

uniform float u_Coverage;
uniform vec3 u_SunDirection;

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

float BoxSize = 80.0f;

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

float phase(float a)
{
	vec4 phaseParams = vec4(0.0f, 0.0f, 0.01f, 0.4f);
	float blend = 0.5f;
	float hgBlend = hg(a,phaseParams.x) * (1 - blend) + hg(a, -phaseParams.y) * blend;
	return phaseParams.z + hgBlend*phaseParams.w;
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
	vec3 StepVector = ldir * StepSize;

	float TotalDensity = 0.0f;
	vec3 CurrentPoint = p;

	for (int i = 0 ; i < StepCount ; i++)
	{
		float DensitySample = SampleDensity(CurrentPoint);
		TotalDensity += max(0.0f, DensitySample * StepSize);
		CurrentPoint += StepVector;
	}

	TotalDensity = exp(-TotalDensity);
	return TotalDensity;
}

float RaymarchCloud(vec3 p, vec3 dir, float tmin, float tmax)
{
	int StepCount = 10;
	float StepSize = tmax / float(StepCount);
	vec3 StepVector = normalize(dir) * StepSize;

	vec3 CurrentPoint = p;
	float Transmittance = 0.0f;

	for (int i = 0 ; i < StepCount ; i++)
	{
		float DensitySample = RaymarchLight(CurrentPoint);
		Transmittance += max(0.0f, DensitySample * StepSize);
		CurrentPoint += StepVector;
	}
	
	float TotalCloudDensity = exp2(-Transmittance);
	return TotalCloudDensity;
}

vec3 GetCloud(in Ray r)
{
	vec2 Dist = RayBoxIntersect(vec3(-BoxSize, 50.0f, -BoxSize), vec3(BoxSize, 40.0f, BoxSize), r.Origin, 1.0f / r.Direction);
	bool Intersect = !(Dist.y == 0.0f);

	float CosAngle = dot(normalize(v_RayDirection), normalize(u_SunDirection));
	float Phase = hgPhase(CosAngle, 0.6f);

	if (Intersect)
	{
		vec3 IntersectionPosition = r.Origin + (r.Direction * Dist.x);

	#ifdef DEBUG_NOISE
		return vec3(SampleNoise(IntersectionPosition).yzw);
	#else

		float DensityAt = RaymarchCloud(IntersectionPosition, r.Direction, Dist.x, Dist.y);

		vec3 Sky = GetSkyColorAt(r.Direction);
		vec3 CloudColor = vec3(DensityAt);
		CloudColor *= (Phase);

		return mix(CloudColor, Sky, clamp(1.0f - DensityAt, 0.0f, 1.0f));
	#endif
	}

	else 
	{
		return GetSkyColorAt(r.Direction);
	}
}

void main()
{
	vec3 ray_dir = normalize(v_RayDirection);
	if(dot(ray_dir, normalize(u_SunDirection)) > 0.9997f)
    {
        o_Color = vec3(1.0f, 1.0f, 0.0f);
		return;
    }

    Ray r;
    r.Origin = v_RayOrigin;
    r.Direction = normalize(v_RayDirection);
	
	o_Color = GetCloud(r);
}