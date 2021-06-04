#version 330 core

layout (location = 1) out vec3 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_CurrentColorTexture;
uniform sampler2D u_CurrentPositionTexture;
uniform sampler2D u_PreviousColorTexture;
uniform sampler2D u_PreviousFramePositionTexture;

uniform mat4 u_PrevProjection;
uniform mat4 u_PrevView;

uniform float u_MixModifier = 0.8;

vec2 View;
vec2 Dimensions;
vec2 TexCoord;

vec2 Reprojection(vec3 pos) 
{
	vec3 WorldPos = pos;

	vec4 ProjectedPosition = u_PrevProjection * u_PrevView * vec4(WorldPos, 1.0f);
	ProjectedPosition.xyz /= ProjectedPosition.w;
	ProjectedPosition.xy = ProjectedPosition.xy * 0.5f + 0.5f;

	return ProjectedPosition.xy;
}

vec4 GetClampedColor(vec2 reprojected)
{
	ivec2 Coord = ivec2(v_TexCoords * Dimensions); 

	vec4 minclr = vec4(10000.0f); 
	vec4 maxclr = vec4(-10000.0f); 

	for(int x = -2; x <= 2; x++) 
	{
		for(int y = -2; y <= 2; y++) 
		{
			vec4 Sampled = texelFetch(u_CurrentColorTexture, Coord + ivec2(x,y), 0); 

			minclr = min(minclr, Sampled); 
			maxclr = max(maxclr, Sampled); 
		}
	}

	minclr -= 0.035f; 
	maxclr += 0.035f; 
	
	return clamp(texture(u_PreviousColorTexture, reprojected), minclr, maxclr); 

}

void main()
{
	Dimensions = textureSize(u_CurrentColorTexture, 0).xy;
	View = 1.0f / Dimensions;

	TexCoord = v_TexCoords;

	vec4 CurrentPosition = texture(u_CurrentPositionTexture, v_TexCoords).rgba;
	vec3 CurrentColor = texture(u_CurrentColorTexture, v_TexCoords).rgb;

	if (CurrentPosition.a > 0.0f)
	{
		vec2 PreviousCoord = Reprojection(CurrentPosition.xyz); 
		vec3 PrevColor = GetClampedColor(PreviousCoord).rgb;

		vec3 AverageColor;
		float ClosestDepth;

		vec2 velocity = (TexCoord - PreviousCoord.xy) * Dimensions;

		float BlendFactor = float(
			PreviousCoord.x > 0.0 && PreviousCoord.x < 1.0 &&
			PreviousCoord.y > 0.0 && PreviousCoord.y < 1.0
		);

		BlendFactor *= exp(-length(velocity)) * 0.9f;
		BlendFactor += 0.35;
		BlendFactor = clamp(BlendFactor, 0.01f, 0.98f);
		o_Color = mix(CurrentColor.xyz, PrevColor.xyz, BlendFactor);
	}

	else 
	{
		o_Color = texture(u_CurrentColorTexture, v_TexCoords).rgb;
	}
}

