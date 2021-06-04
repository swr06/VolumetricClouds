#version 330 core

layout(location = 0) out vec3 o_Color;

in vec2 v_TexCoords;
in vec3 v_RayDirection;
in vec3 v_RayOrigin;

uniform sampler2D u_ComputedCloudTexture;
uniform float BoxSize;

vec3 GetSkyColorAt(vec3 rd) 
{
    vec3 unit_direction = normalize(rd);

    float t = 0.5f * (unit_direction.y + 1.0);
    return (1.0 - t) * vec3(1.0, 1.0, 1.0) +  t * vec3(0.5, 0.7, 1.0);
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

vec4 textureBicubic(sampler2D sampler, vec2 texCoords);

void main()
{
	vec2 Dist = RayBoxIntersect(vec3(-BoxSize, 50.0f, -BoxSize), vec3(BoxSize, 40.0f, BoxSize), v_RayOrigin, 1.0f / (v_RayDirection));
	bool Intersect = !(Dist.y == 0.0f);

	if (Intersect)
	{
		vec3 SampledCloudData = textureBicubic(u_ComputedCloudTexture, v_TexCoords).rgb;
		float CloudAt = SampledCloudData.x;
		float Transmittance = SampledCloudData.y;

		vec3 Sky = GetSkyColorAt(v_RayDirection);
		vec3 CloudColor = vec3(pow(CloudAt, 1.0f / 2.0f));

		vec3 TotalColor = vec3(Sky * (clamp(Transmittance, 0.0f, 1.0f)));
		TotalColor += CloudColor;
		o_Color = TotalColor;
	}

	else 
	{
		o_Color = GetSkyColorAt(v_RayDirection);
	}

	//o_Color = pow(o_Color, vec3(1.0f / 2.2f));
}

vec4 cubic(float v)
{
    vec4 n = vec4(1.0, 2.0, 3.0, 4.0) - v;
    vec4 s = n * n * n;
    float x = s.x;
    float y = s.y - 4.0 * s.x;
    float z = s.z - 4.0 * s.y + 6.0 * s.x;
    float w = 6.0 - x - y - z;
    return vec4(x, y, z, w) * (1.0/6.0);
}

vec4 textureBicubic(sampler2D sampler, vec2 texCoords)
{

   vec2 texSize = textureSize(sampler, 0);
   vec2 invTexSize = 1.0 / texSize;

   texCoords = texCoords * texSize - 0.5;


    vec2 fxy = fract(texCoords);
    texCoords -= fxy;

    vec4 xcubic = cubic(fxy.x);
    vec4 ycubic = cubic(fxy.y);

    vec4 c = texCoords.xxyy + vec2 (-0.5, +1.5).xyxy;

    vec4 s = vec4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
    vec4 offset = c + vec4 (xcubic.yw, ycubic.yw) / s;

    offset *= invTexSize.xxyy;

    vec4 sample0 = texture(sampler, offset.xz);
    vec4 sample1 = texture(sampler, offset.yz);
    vec4 sample2 = texture(sampler, offset.xw);
    vec4 sample3 = texture(sampler, offset.yw);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix(
       mix(sample3, sample2, sx), mix(sample1, sample0, sx)
    , sy);
}