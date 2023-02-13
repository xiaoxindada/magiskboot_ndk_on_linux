#pragma once
#include <cstdint>

namespace rust {
void setup_klog() noexcept;

::std::int32_t print_rules_device() noexcept;
} // namespace rust