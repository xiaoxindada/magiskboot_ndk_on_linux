#include <cstdint>

namespace rust {
extern "C" {
void rust$cxxbridge1$setup_klog() noexcept;

::std::int32_t rust$cxxbridge1$print_rules_device() noexcept;
} // extern "C"

void setup_klog() noexcept {
  rust$cxxbridge1$setup_klog();
}

::std::int32_t print_rules_device() noexcept {
  return rust$cxxbridge1$print_rules_device();
}
} // namespace rust