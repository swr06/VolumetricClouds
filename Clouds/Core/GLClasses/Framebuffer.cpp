#include "Framebuffer.h"

#ifndef NULL
	#define NULL 0
#endif

namespace GLClasses
{
    Framebuffer::Framebuffer(unsigned int w, unsigned int h, bool hdr, bool has_depth_attachment) :
        m_FBO(0), m_FBWidth(w), m_FBHeight(h), m_IsHDR(hdr), m_HasDepthMap(has_depth_attachment)
    {
       // CreateFramebuffer();
    }

	Framebuffer::~Framebuffer()
	{
		glDeleteFramebuffers(1, &m_FBO);
	}

	void Framebuffer::CreateFramebuffer()
	{
        int w = m_FBWidth;
        int h = m_FBHeight;
        bool hdr = m_IsHDR;

        GLenum format = hdr ? GL_RGBA16F : GL_RGBA;
        GLenum type = hdr ? GL_FLOAT : GL_UNSIGNED_BYTE;

        glGenFramebuffers(1, &m_FBO);
        glBindFramebuffer(GL_FRAMEBUFFER, m_FBO);

        glGenTextures(1, &m_TextureAttachment);
        glBindTexture(GL_TEXTURE_2D, m_TextureAttachment);
        glTexImage2D(GL_TEXTURE_2D, 0, format, w, h, 0, GL_RGBA, type, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_TextureAttachment, 0);

        if (m_HasDepthMap)
        {
            glGenRenderbuffers(1, &m_DepthStencilBuffer);
            glBindRenderbuffer(GL_RENDERBUFFER, m_DepthStencilBuffer);
            glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, w, h);
            glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, m_DepthStencilBuffer);
        }
       
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        {
            Clouds::Logger::Log("Fatal error! Framebuffer creation failed!");
        }

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
	}

    
}