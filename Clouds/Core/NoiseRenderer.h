#pragma once

#include <iostream>
#include <string>
#include <glad/glad.h>

#include "GLClasses/Framebuffer.h"
#include "Texture3D.h"
#include "GLClasses/Shader.h"
#include "GLClasses/VertexArray.h"
#include "GLClasses/VertexBuffer.h"
#include "GLClasses/IndexBuffer.h"

namespace Clouds
{
	void RenderNoise(GLClasses::Texture3D& tex, int slices, bool detail = false);
}