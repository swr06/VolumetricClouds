#include <iostream>

#include "Core/Application/Application.h"
#include "Core/GLClasses/VertexArray.h"
#include "Core/GLClasses/VertexBuffer.h"
#include "Core/GLClasses/IndexBuffer.h"
#include "Core/GLClasses/Shader.h"
#include "Core/FpsCamera.h"
#include "Core/GLClasses/Fps.h"
#include "Core/GLClasses/Texture.h"
#include "Core/Texture3D.h"
#include "Core/NoiseRenderer.h"

using namespace Clouds;
FPSCamera MainCamera(90.0f, (float)800.0f / (float)600.0f);
bool VSync = true;
float Coverage = 0.3f;

class RayTracerApp : public Application
{
public:

	RayTracerApp()
	{
		m_Width = 800;
		m_Height = 600;
	}

	void OnUserCreate(double ts) override
	{

	}

	void OnUserUpdate(double ts) override
	{

	}

	void OnImguiRender(double ts) override
	{
		ImGui::Text("Player Position : %f, %f, %f", MainCamera.GetPosition().x, MainCamera.GetPosition().y, MainCamera.GetPosition().z);
		ImGui::Text("Camera Front : %f, %f, %f", MainCamera.GetFront().x, MainCamera.GetFront().y, MainCamera.GetFront().z);
		ImGui::SliderFloat("Cloud coverage", &Coverage, 0.1f, 1.0f);
	}

	void OnEvent(Event e) override
	{
		if (e.type == EventTypes::MouseMove && GetCursorLocked())
		{
			MainCamera.UpdateOnMouseMovement(GetCursorX(), GetCursorY());
		}

		if (e.type == EventTypes::KeyPress && e.key == GLFW_KEY_F1)
		{
			this->SetCursorLocked(!this->GetCursorLocked());
		}

		if (e.type == EventTypes::KeyPress && e.key == GLFW_KEY_V)
		{
			VSync = !VSync;
		}

		if (e.type == EventTypes::WindowResize)
		{
			MainCamera.SetAspect((float)e.wx / (float)e.wy);
		}
	}

};

int main()
{
	int NoiseSize = 256;

	RayTracerApp app;
	app.Initialize();

	GLClasses::VertexBuffer VBO;
	GLClasses::VertexArray VAO;
	GLClasses::Shader CloudShader;
	GLClasses::Texture WorleyNoise;
	GLClasses::Texture3D CloudNoise;


	float Vertices[] =
	{
		-1.0f,  1.0f,  0.0f, 1.0f, -1.0f, -1.0f,  0.0f, 0.0f,
		 1.0f, -1.0f,  1.0f, 0.0f, -1.0f,  1.0f,  0.0f, 1.0f,
		 1.0f, -1.0f,  1.0f, 0.0f,  1.0f,  1.0f,  1.0f, 1.0f
	};

	VAO.Bind();
	VBO.Bind();
	VBO.BufferData(sizeof(Vertices), Vertices, GL_STATIC_DRAW);
	VBO.VertexAttribPointer(0, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), 0);
	VBO.VertexAttribPointer(1, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));
	VAO.Unbind();

	CloudShader.CreateShaderProgramFromFile("Core/Shaders/CloudVert.glsl", "Core/Shaders/CloudFrag.glsl");
	CloudShader.CompileShaders();
	WorleyNoise.CreateTexture("Res/worley_noise_1.jpg", false);

	app.SetCursorLocked(true);

	// Render noise into the 3D texture
	CloudNoise.CreateTexture(NoiseSize, NoiseSize, NoiseSize, nullptr);
	Clouds::RenderNoise(CloudNoise, NoiseSize);

	while (!glfwWindowShouldClose(app.GetWindow()))
	{
		glfwSwapInterval((int)VSync);

		float camera_speed = 0.185f;

		if (glfwGetKey(app.GetWindow(), GLFW_KEY_W) == GLFW_PRESS)
		{
			// Take the cross product of the MainCamera's right and up.
			MainCamera.ChangePosition(MainCamera.GetFront() * camera_speed);
		}

		if (glfwGetKey(app.GetWindow(), GLFW_KEY_S) == GLFW_PRESS)
		{
			MainCamera.ChangePosition(-MainCamera.GetFront() * camera_speed);
		}

		if (glfwGetKey(app.GetWindow(), GLFW_KEY_A) == GLFW_PRESS)
		{
			MainCamera.ChangePosition(-(MainCamera.GetRight() * camera_speed));
		}

		if (glfwGetKey(app.GetWindow(), GLFW_KEY_D) == GLFW_PRESS)
		{
			MainCamera.ChangePosition(MainCamera.GetRight() * camera_speed);
		}

		if (glfwGetKey(app.GetWindow(), GLFW_KEY_SPACE) == GLFW_PRESS)
		{
			MainCamera.ChangePosition(MainCamera.GetUp() * camera_speed);
		}

		if (glfwGetKey(app.GetWindow(), GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS)
		{
			MainCamera.ChangePosition(-(MainCamera.GetUp() * camera_speed));
		}

		if (glfwGetKey(app.GetWindow(), GLFW_KEY_F2) == GLFW_PRESS)
		{
			CloudShader.Recompile();
			Logger::Log("Recompiled!");
		}

		MainCamera.OnUpdate();
		MainCamera.Refresh();

		app.OnUpdate();

		// ---------------------

		glDisable(GL_CULL_FACE);
		glDisable(GL_DEPTH_TEST);

		glm::mat4 inv_view = glm::inverse(MainCamera.GetViewMatrix());
		glm::mat4 inv_projection = glm::inverse(MainCamera.GetProjectionMatrix());

		CloudShader.Use();

		CloudShader.SetMatrix4("u_InverseView", inv_view);
		CloudShader.SetMatrix4("u_InverseProjection", inv_projection);
		CloudShader.SetInteger("u_WorleyNoise", 0);
		CloudShader.SetInteger("u_CloudNoise", 1);
		CloudShader.SetFloat("u_Time", glfwGetTime());
		CloudShader.SetFloat("u_Coverage", Coverage);
		CloudShader.SetInteger("u_CurrentFrame", app.GetCurrentFrame());
		CloudShader.SetInteger("u_SliceCount", NoiseSize);
		CloudShader.SetVector2f("u_Dimensions", glm::vec2(app.GetWidth(), app.GetHeight()));

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, WorleyNoise.GetTextureID());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_3D, CloudNoise.GetTextureID());

		VAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		VAO.Unbind();

		app.FinishFrame();

		GLClasses::DisplayFrameRate(app.GetWindow(), "Clouds");
	}
}