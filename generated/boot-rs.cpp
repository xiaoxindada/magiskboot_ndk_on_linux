#include "compress.hpp"
#include <cstdint>

extern "C" {
bool cxxbridge1$decompress(const ::std::uint8_t *in_, ::std::uint64_t in_size, ::std::int32_t fd) noexcept {
  bool (*decompress$)(const ::std::uint8_t *, ::std::uint64_t, ::std::int32_t) = ::decompress;
  return decompress$(in_, in_size, fd);
}
} // extern "C"

namespace rust {
extern "C" {
bool rust$cxxbridge1$extract_boot_from_payload(const char *in_path, const char *out_path) noexcept;
} // extern "C"

bool extract_boot_from_payload(const char *in_path, const char *out_path) noexcept {
  return rust$cxxbridge1$extract_boot_from_payload(in_path, out_path);
}
} // namespace rust