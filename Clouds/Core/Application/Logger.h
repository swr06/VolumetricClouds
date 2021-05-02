#pragma once

#include <iostream>

namespace Clouds
{
	namespace Logger
	{
		void Log(const std::string& txt);
		void LogToFile(const std::string& txt);
	}
}