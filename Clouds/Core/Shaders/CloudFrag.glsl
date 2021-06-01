#version 330 core

#define CHUNK_SIZE_X 64
#define CHUNK_SIZE_Y 64
#define CHUNK_SIZE_Z 64

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;
in vec3 v_RayDirection;
in vec3 v_RayOrigin;


uniform sampler2D u_WorleyNoise;


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

float SampleWorleyAt(in vec3 WorldPosition)
{
	 return texture(u_WorleyNoise, WorldPosition.xz * 0.025f).r;
}

vec3 GetCloud(in Ray r)
{
	float tmin, tmax;
    
	bool Intersect = RayBoxIntersect(vec3(-100.0f, 50.0f, -100.0f), vec3(100.0f, 40.0f, 100.0f), r.Origin, r.Direction, tmin, tmax);

	if (Intersect)
	{
		vec3 IntersectionPosition = r.Origin + (r.Direction * tmin);
		return vec3(SampleWorleyAt(IntersectionPosition));
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