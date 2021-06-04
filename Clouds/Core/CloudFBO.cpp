#include "CloudFBO.h"

namespace Clouds
{
	CloudFBO::CloudFBO(uint32_t w, uint32_t h)
	{
		m_Width = w;
		m_Height = h;
	}

	CloudFBO::~CloudFBO()
	{
		DeleteEverything();
	}

	void CloudFBO::SetDimensions(uint32_t w, uint32_t h)
	{
		if (w != m_Width || h != m_Height)
		{
			DeleteEverything();
			m_Width = w;
			m_Height = h;
			GenerateFramebuffers();
		}
	}

	void CloudFBO::GenerateFramebuffers()
	{
		GLenum DrawBuffers[2] = {
			GL_COLOR_ATTACHMENT0,
			GL_COLOR_ATTACHMENT1
		};

		glGenFramebuffers(1, &m_FBO);
		glBindFramebuffer(GL_FRAMEBUFFER, m_FBO);

		glGenTextures(1, &m_PositionTexture);
		glBindTexture(GL_TEXTURE_2D, m_PositionTexture);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, m_Width, m_Height, 0, GL_RGBA, GL_FLOAT, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_PositionTexture, 0);

		glGenTextures(1, &m_CloudData);
		glBindTexture(GL_TEXTURE_2D, m_CloudData);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, m_Width, m_Height, 0, GL_RGB, GL_FLOAT, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D, m_CloudData, 0);

		glDrawBuffers(2, DrawBuffers);

		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
		{
			Logger::Log("Geometry Render buffer is not complete!\n\tWIDTH : " +
				std::to_string(m_Width) + "\n\tHEIGHT : " + std::to_string(m_Height));
		}

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

	void CloudFBO::DeleteEverything()
	{
		glDeleteFramebuffers(1, &m_FBO);
		glDeleteTextures(1, &m_PositionTexture);
		glDeleteTextures(1, &m_CloudData);
		m_FBO = 0;
		m_PositionTexture = 0;
		m_CloudData = 0;
	}
}