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
#include "Core/GLClasses/Texture.h"
#include "Core/NoiseRenderer.h"
#include "Core/CloudFBO.h"

using namespace Clouds;
FPSCamera MainCamera(90.0f, (float)800.0f / (float)600.0f);
bool VSync = true;
float Coverage = 0.3f;
float SunTick = 16.0f;
float BoxSize = 140.0f;

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
		ImGui::SliderFloat("Sun Tick ", &SunTick, 0.1f, 256.0f);
		ImGui::SliderFloat("Box Size ", &BoxSize, 20.0f, 1000.0f);
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
	int NoiseSize = 96;

	RayTracerApp app;
	app.Initialize();

	GLClasses::VertexBuffer VBO;
	GLClasses::VertexArray VAO;

	GLClasses::Shader CloudShader;
	GLClasses::Shader Final;
	GLClasses::Shader TemporalFilter;

	GLClasses::Texture WorleyNoise;
	GLClasses::Texture3D CloudNoise;
	GLClasses::Texture BlueNoiseTexture;
	Clouds::CloudFBO CloudFBO_1;
	Clouds::CloudFBO CloudFBO_2;
	Clouds::CloudFBO CloudTemporalFBO1;
	Clouds::CloudFBO CloudTemporalFBO2;

	glm::mat4 CurrentProjection, CurrentView;
	glm::mat4 PreviousProjection, PreviousView;
	glm::vec3 CurrentPosition, PreviousPosition;

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
	Final.CreateShaderProgramFromFile("Core/Shaders/FinalVert.glsl", "Core/Shaders/FBOFrag.glsl");
	Final.CompileShaders();
	TemporalFilter.CreateShaderProgramFromFile("Core/Shaders/FBOVert.glsl", "Core/Shaders/TemporalFilter.glsl");
	TemporalFilter.CompileShaders();

	WorleyNoise.CreateTexture("Res/worley_noise_1.jpg", false);
	BlueNoiseTexture.CreateTexture("Res/blue_noise.png", false);

	app.SetCursorLocked(true);

	// Render noise into the 3D texture
	CloudNoise.CreateTexture(NoiseSize, NoiseSize, NoiseSize, nullptr);
	Clouds::RenderNoise(CloudNoise, NoiseSize);

	glm::vec3 SunDirection;
	float CloudResolution = 0.5f;

	while (!glfwWindowShouldClose(app.GetWindow()))
	{
		Clouds::CloudFBO& CloudTemporalFBO = (app.GetCurrentFrame() % 2 == 0) ? CloudTemporalFBO1 : CloudTemporalFBO2;
		Clouds::CloudFBO& PrevCloudTemporalFBO = (app.GetCurrentFrame() % 2 == 0) ? CloudTemporalFBO2 : CloudTemporalFBO1;
		Clouds::CloudFBO& CloudFBO = (app.GetCurrentFrame() % 2 == 0) ? CloudFBO_1 : CloudFBO_2;
		Clouds::CloudFBO& PrevCloudFBO = (app.GetCurrentFrame() % 2 == 0) ? CloudFBO_2 : CloudFBO_1;

		CloudTemporalFBO1.SetDimensions(app.GetWidth(), app.GetHeight());
		CloudTemporalFBO2.SetDimensions(app.GetWidth(), app.GetHeight());
		CloudFBO.SetDimensions(app.GetWidth() * CloudResolution, app.GetHeight() * CloudResolution);
		PrevCloudFBO.SetDimensions(app.GetWidth() * CloudResolution, app.GetHeight() * CloudResolution);

		// SunTick

		float time_angle = SunTick * 2.0f;
		glm::mat4 sun_rotation_matrix;

		sun_rotation_matrix = glm::rotate(glm::mat4(1.0f), glm::radians(time_angle), glm::vec3(0.0f, 0.0f, 1.0f));
		SunDirection = glm::vec3(sun_rotation_matrix * glm::vec4(1.0f));

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
			Final.Recompile();
			TemporalFilter.Recompile();
			Logger::Log("Recompiled!");
		}

		MainCamera.OnUpdate();
		MainCamera.Refresh();

		app.OnUpdate();

		// --------------------

		PreviousProjection = CurrentProjection;
		PreviousView = CurrentView;
		PreviousPosition = CurrentPosition;
		CurrentProjection = MainCamera.GetProjectionMatrix();
		CurrentView = MainCamera.GetViewMatrix();
		CurrentPosition = MainCamera.GetPosition();

		// ---------------------

		glDisable(GL_CULL_FACE);
		glDisable(GL_DEPTH_TEST);
		
		{
			glm::mat4 inv_view = glm::inverse(MainCamera.GetViewMatrix());
			glm::mat4 inv_projection = glm::inverse(MainCamera.GetProjectionMatrix());

			CloudFBO.Bind();
			CloudShader.Use();

			CloudShader.SetMatrix4("u_InverseView", inv_view);
			CloudShader.SetMatrix4("u_InverseProjection", inv_projection);
			CloudShader.SetInteger("u_WorleyNoise", 0);
			CloudShader.SetInteger("u_CloudNoise", 1);
			CloudShader.SetInteger("u_BlueNoise", 2);
			CloudShader.SetFloat("u_Time", glfwGetTime());
			CloudShader.SetFloat("u_Coverage", Coverage);
			CloudShader.SetFloat("BoxSize", BoxSize);
			CloudShader.SetInteger("u_CurrentFrame", app.GetCurrentFrame());
			CloudShader.SetInteger("u_SliceCount", NoiseSize);
			CloudShader.SetVector2f("u_Dimensions", glm::vec2(app.GetWidth(), app.GetHeight()));
			CloudShader.SetVector2f("u_VertDimensions", glm::vec2(app.GetWidth(), app.GetHeight()));
			CloudShader.SetVector3f("u_SunDirection", SunDirection);
			CloudShader.SetInteger("u_VertCurrentFrame", app.GetCurrentFrame());

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, WorleyNoise.GetTextureID());

			glActiveTexture(GL_TEXTURE1);
			glBindTexture(GL_TEXTURE_3D, CloudNoise.GetTextureID());

			glActiveTexture(GL_TEXTURE2);
			glBindTexture(GL_TEXTURE_2D, BlueNoiseTexture.GetTextureID());

			VAO.Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			VAO.Unbind();
		}

		// Temporally filter the clouds
		{
			TemporalFilter.Use();
			CloudTemporalFBO.Bind();

			TemporalFilter.SetInteger("u_CurrentColorTexture", 0);
			TemporalFilter.SetInteger("u_PreviousColorTexture", 1);
			TemporalFilter.SetInteger("u_CurrentPositionTexture", 2);
			TemporalFilter.SetInteger("u_PreviousFramePositionTexture", 3);
			TemporalFilter.SetInteger("u_PreviousCloudTexture", 4);
			TemporalFilter.SetMatrix4("u_PrevProjection", PreviousProjection);
			TemporalFilter.SetMatrix4("u_PrevView", PreviousView);
			TemporalFilter.SetFloat("u_MixModifier", 0.86f);

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, CloudFBO.GetCloudTexture());

			glActiveTexture(GL_TEXTURE1);
			glBindTexture(GL_TEXTURE_2D, PrevCloudTemporalFBO.GetCloudTexture());

			glActiveTexture(GL_TEXTURE2);
			glBindTexture(GL_TEXTURE_2D, CloudFBO.GetPositionTexture());

			glActiveTexture(GL_TEXTURE3);
			glBindTexture(GL_TEXTURE_2D, PrevCloudFBO.GetPositionTexture());

			glActiveTexture(GL_TEXTURE4);
			glBindTexture(GL_TEXTURE_2D, PrevCloudFBO.GetCloudTexture());

			VAO.Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			VAO.Unbind();
		}

		{
			Final.Use();
			glBindFramebuffer(GL_FRAMEBUFFER, 0);
			glViewport(0, 0, app.GetWidth(), app.GetHeight());

			Final.SetInteger("u_ComputedCloudTexture", 0);
			Final.SetVector3f("u_SunDirection", SunDirection);
			Final.SetMatrix4("u_InverseView", glm::inverse(MainCamera.GetViewMatrix()));
			Final.SetMatrix4("u_InverseProjection", glm::inverse(MainCamera.GetProjectionMatrix()));
			Final.SetMatrix4("u_ProjectionMatrix", (MainCamera.GetProjectionMatrix()));
			Final.SetMatrix4("u_ViewMatrix", (MainCamera.GetViewMatrix()));
			Final.SetFloat("BoxSize", BoxSize);

			{
				GLuint tex = CloudTemporalFBO.GetCloudTexture();
				glBindTexture(GL_TEXTURE_2D, tex);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
				glBindTexture(GL_TEXTURE_2D, 0);
			}

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, CloudTemporalFBO.GetCloudTexture());

			VAO.Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			VAO.Unbind();

			{
				GLuint tex = CloudTemporalFBO.GetCloudTexture();
				glBindTexture(GL_TEXTURE_2D, tex);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
				glBindTexture(GL_TEXTURE_2D, 0);
			}

		}

		app.FinishFrame();

		GLClasses::DisplayFrameRate(app.GetWindow(), "Clouds");
	}
}