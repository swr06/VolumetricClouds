#version 330 core

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

bool RayBoxIntersect(const vec3 boxMin, const vec3 boxMax, vec3 r0, vec3 rD, out float t_min, out float t_max) 
{
	vec3 inv_dir = 1.0f / rD;
	vec3 tbot = inv_dir * (boxMin - r0);
	vec3 ttop = inv_dir * (boxMax - r0);
	vec3 tmin = min(ttop, tbot);
	vec3 tmax = max(ttop, tbot);
	vec2 t = max(tmin.xx, tmin.yz);
	float t0 = max(t.x, t.y);
	t = min(tmax.xx, tmax.yz);
	float t1 = min(t.x, t.y);
	t_min = t0;
	t_max = t1;
	return t1 > max(t0, 0.0);
}

float remap(float x, float a, float b, float c, float d)
{
    return (((x - a) / (b - a)) * (d - c)) + c;
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

float RaymarchCloud(vec3 p, vec3 dir, float tmin, float tmax)
{
	int StepCount = 20;
	float StepSize = tmax / float(StepCount);
	vec3 StepVector = normalize(dir) * StepSize;

	float TotalDensity = 0.0f;
	vec3 CurrentPoint = p;
	float StepMultiplier = 0.1f;

	for (int i = 0 ; i < StepCount ; i++)
	{
		float DensitySample = SampleDensity(CurrentPoint);
		TotalDensity += DensitySample;
		CurrentPoint += StepVector * StepMultiplier;
	}

	TotalDensity /= StepCount;
	//TotalDensity = exp(-TotalDensity);
	return TotalDensity;
}

vec3 GetCloud(in Ray r)
{
	float tmin, tmax;
    
	float BoxSize = 100.0f;
	bool Intersect = RayBoxIntersect(vec3(-BoxSize, 50.0f, -BoxSize), vec3(BoxSize, 40.0f, BoxSize), r.Origin, r.Direction, tmin, tmax);

	if (Intersect)
	{
		vec3 IntersectionPosition = r.Origin + (r.Direction * tmin);
		float DensityAt = RaymarchCloud(IntersectionPosition, r.Direction, tmin, tmax);

		vec3 Sky = GetSkyColorAt(r.Direction);
		vec3 CloudColor = vec3(DensityAt);
		CloudColor *= vec3(1.5f);

		return mix(CloudColor, Sky, clamp(1.0f - DensityAt, 0.0f, 1.0f));
	}

	else 
	{
		return GetSkyColorAt(r.Direction);
	}
}

void main()
{
    Ray r;
    r.Origin = v_RayOrigin;
    r.Direction = normalize(v_RayDirection);
	
	o_Color = GetCloud(r);
}