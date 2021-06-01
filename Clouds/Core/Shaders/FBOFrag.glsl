#version 330 core

layout(location = 0) out vec3 o_Color;
in vec2 v_TexCoords;

uniform sampler2D u_FramebufferTexture;

void main()
{
    vec3 SampledColor = texture(u_FramebufferTexture, v_TexCoords).rgb;
    o_Color = pow(SampledColor, vec3(1.0f / 2.2f)); // Gamma correction
}