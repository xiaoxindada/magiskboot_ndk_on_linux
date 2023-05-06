#pragma once
#include <cstdint>

namespace rust {
bool extract_boot_from_payload(const char *in_path, const char *out_path) noexcept;
} // namespace rust