#include "NoiseRenderer.h"

namespace Clouds
{
	void RenderNoise(GLClasses::Texture3D& tex, int slices)
	{
		GLuint FBO = 0;
		GLClasses::Shader NoiseShader;

		float Vertices[] =
		{
			-1.0f,  1.0f,  0.0f, 1.0f, -1.0f, -1.0f,  0.0f, 0.0f,
			 1.0f, -1.0f,  1.0f, 0.0f, -1.0f,  1.0f,  0.0f, 1.0f,
			 1.0f, -1.0f,  1.0f, 0.0f,  1.0f,  1.0f,  1.0f, 1.0f
		};

		GLClasses::VertexBuffer VBO;
		GLClasses::VertexArray VAO;
		VAO.Bind();
		VBO.Bind();
		VBO.BufferData(sizeof(Vertices), Vertices, GL_STATIC_DRAW);
		VBO.VertexAttribPointer(0, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), 0);
		VBO.VertexAttribPointer(1, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));
		VAO.Unbind();

		NoiseShader.CreateShaderProgramFromFile("Core/Shaders/FBOVert.glsl", "Core/Shaders/NoiseFrag.glsl");
		NoiseShader.CompileShaders();

		glGenFramebuffers(1, &FBO);
		glBindFramebuffer(GL_FRAMEBUFFER, FBO);

		for (int i = 0; i < slices; i++)
		{
			glBindFramebuffer(GL_FRAMEBUFFER, FBO);
			glFramebufferTexture3D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_3D, tex.GetTextureID(), 0, i);
			glClear(GL_COLOR_BUFFER_BIT);

			NoiseShader.Use();
			NoiseShader.SetFloat("u_CurrentSlice", (float)i / (float)slices);
			
			VAO.Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			VAO.Unbind();
		}
	}
}