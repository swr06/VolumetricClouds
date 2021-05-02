#version 330 core

#define CHUNK_SIZE_X 64
#define CHUNK_SIZE_Y 64
#define CHUNK_SIZE_Z 64

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;
in vec3 v_RayDirection;
in vec3 v_RayOrigin;

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

void main()
{
    Ray r;
    r.Origin = v_RayOrigin;
    r.Direction = normalize(v_RayDirection);
    
	o_Color = GetSkyColorAt(r.Direction);
}