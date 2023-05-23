#include "core.hpp"
#include <array>
#include <cstddef>
#include <cstdint>
#include <new>
#include <string>
#include <type_traits>

namespace rust {
inline namespace cxxbridge1 {
// #include "rust/cxx.h"

struct unsafe_bitcopy_t;

#ifndef CXXBRIDGE1_RUST_STRING
#define CXXBRIDGE1_RUST_STRING
class String final {
public:
  String() noexcept;
  String(const String &) noexcept;
  String(String &&) noexcept;
  ~String() noexcept;

  String(const std::string &);
  String(const char *);
  String(const char *, std::size_t);
  String(const char16_t *);
  String(const char16_t *, std::size_t);

  static String lossy(const std::string &) noexcept;
  static String lossy(const char *) noexcept;
  static String lossy(const char *, std::size_t) noexcept;
  static String lossy(const char16_t *) noexcept;
  static String lossy(const char16_t *, std::size_t) noexcept;

  String &operator=(const String &) &noexcept;
  String &operator=(String &&) &noexcept;

  explicit operator std::string() const;

  const char *data() const noexcept;
  std::size_t size() const noexcept;
  std::size_t length() const noexcept;
  bool empty() const noexcept;

  const char *c_str() noexcept;

  std::size_t capacity() const noexcept;
  void reserve(size_t new_cap) noexcept;

  using iterator = char *;
  iterator begin() noexcept;
  iterator end() noexcept;

  using const_iterator = const char *;
  const_iterator begin() const noexcept;
  const_iterator end() const noexcept;
  const_iterator cbegin() const noexcept;
  const_iterator cend() const noexcept;

  bool operator==(const String &) const noexcept;
  bool operator!=(const String &) const noexcept;
  bool operator<(const String &) const noexcept;
  bool operator<=(const String &) const noexcept;
  bool operator>(const String &) const noexcept;
  bool operator>=(const String &) const noexcept;

  void swap(String &) noexcept;

  String(unsafe_bitcopy_t, const String &) noexcept;

private:
  struct lossy_t;
  String(lossy_t, const char *, std::size_t) noexcept;
  String(lossy_t, const char16_t *, std::size_t) noexcept;
  friend void swap(String &lhs, String &rhs) noexcept { lhs.swap(rhs); }

  std::array<std::uintptr_t, 3> repr;
};
#endif // CXXBRIDGE1_RUST_STRING

#ifndef CXXBRIDGE1_RUST_OPAQUE
#define CXXBRIDGE1_RUST_OPAQUE
class Opaque {
public:
  Opaque() = delete;
  Opaque(const Opaque &) = delete;
  ~Opaque() = delete;
};
#endif // CXXBRIDGE1_RUST_OPAQUE

#ifndef CXXBRIDGE1_IS_COMPLETE
#define CXXBRIDGE1_IS_COMPLETE
namespace detail {
namespace {
template <typename T, typename = std::size_t>
struct is_complete : std::false_type {};
template <typename T>
struct is_complete<T, decltype(sizeof(T))> : std::true_type {};
} // namespace
} // namespace detail
#endif // CXXBRIDGE1_IS_COMPLETE

#ifndef CXXBRIDGE1_LAYOUT
#define CXXBRIDGE1_LAYOUT
class layout {
  template <typename T>
  friend std::size_t size_of();
  template <typename T>
  friend std::size_t align_of();
  template <typename T>
  static typename std::enable_if<std::is_base_of<Opaque, T>::value,
                                 std::size_t>::type
  do_size_of() {
    return T::layout::size();
  }
  template <typename T>
  static typename std::enable_if<!std::is_base_of<Opaque, T>::value,
                                 std::size_t>::type
  do_size_of() {
    return sizeof(T);
  }
  template <typename T>
  static
      typename std::enable_if<detail::is_complete<T>::value, std::size_t>::type
      size_of() {
    return do_size_of<T>();
  }
  template <typename T>
  static typename std::enable_if<std::is_base_of<Opaque, T>::value,
                                 std::size_t>::type
  do_align_of() {
    return T::layout::align();
  }
  template <typename T>
  static typename std::enable_if<!std::is_base_of<Opaque, T>::value,
                                 std::size_t>::type
  do_align_of() {
    return alignof(T);
  }
  template <typename T>
  static
      typename std::enable_if<detail::is_complete<T>::value, std::size_t>::type
      align_of() {
    return do_align_of<T>();
  }
};

template <typename T>
std::size_t size_of() {
  return layout::size_of<T>();
}

template <typename T>
std::size_t align_of() {
  return layout::align_of<T>();
}
#endif // CXXBRIDGE1_LAYOUT
} // namespace cxxbridge1
} // namespace rust

namespace rust {
  struct MagiskD;
}

namespace rust {
#ifndef CXXBRIDGE1_STRUCT_rust$MagiskD
#define CXXBRIDGE1_STRUCT_rust$MagiskD
struct MagiskD final : public ::rust::Opaque {
  ::std::int32_t get_log_pipe() const noexcept;
  void close_log_pipe() const noexcept;
  void setup_logfile() const noexcept;
  ~MagiskD() = delete;

private:
  friend ::rust::layout;
  struct layout {
    static ::std::size_t size() noexcept;
    static ::std::size_t align() noexcept;
  };
};
#endif // CXXBRIDGE1_STRUCT_rust$MagiskD
} // namespace rust

extern "C" {
void cxxbridge1$get_prop_rs(const char *name, bool persist, ::rust::String *return$) noexcept {
  ::rust::String (*get_prop_rs$)(const char *, bool) = ::get_prop_rs;
  new (return$) ::rust::String(get_prop_rs$(name, persist));
}

void cxxbridge1$rust_test_entry() noexcept;

void cxxbridge1$android_logging() noexcept;

void cxxbridge1$magisk_logging() noexcept;

void cxxbridge1$zygisk_logging() noexcept;
} // extern "C"

namespace rust {
extern "C" {
void rust$cxxbridge1$daemon_entry() noexcept;

void rust$cxxbridge1$zygisk_entry() noexcept;
::std::size_t rust$cxxbridge1$MagiskD$operator$sizeof() noexcept;
::std::size_t rust$cxxbridge1$MagiskD$operator$alignof() noexcept;

const ::rust::MagiskD *rust$cxxbridge1$get_magiskd() noexcept;

::std::int32_t rust$cxxbridge1$MagiskD$get_log_pipe(const ::rust::MagiskD &self) noexcept;

void rust$cxxbridge1$MagiskD$close_log_pipe(const ::rust::MagiskD &self) noexcept;

void rust$cxxbridge1$MagiskD$setup_logfile(const ::rust::MagiskD &self) noexcept;
} // extern "C"
} // namespace rust

void rust_test_entry() noexcept {
  cxxbridge1$rust_test_entry();
}

void android_logging() noexcept {
  cxxbridge1$android_logging();
}

void magisk_logging() noexcept {
  cxxbridge1$magisk_logging();
}

void zygisk_logging() noexcept {
  cxxbridge1$zygisk_logging();
}

namespace rust {
void daemon_entry() noexcept {
  rust$cxxbridge1$daemon_entry();
}

void zygisk_entry() noexcept {
  rust$cxxbridge1$zygisk_entry();
}

::std::size_t MagiskD::layout::size() noexcept {
  return rust$cxxbridge1$MagiskD$operator$sizeof();
}

::std::size_t MagiskD::layout::align() noexcept {
  return rust$cxxbridge1$MagiskD$operator$alignof();
}

const ::rust::MagiskD &get_magiskd() noexcept {
  return *rust$cxxbridge1$get_magiskd();
}

::std::int32_t MagiskD::get_log_pipe() const noexcept {
  return rust$cxxbridge1$MagiskD$get_log_pipe(*this);
}

void MagiskD::close_log_pipe() const noexcept {
  rust$cxxbridge1$MagiskD$close_log_pipe(*this);
}

void MagiskD::setup_logfile() const noexcept {
  rust$cxxbridge1$MagiskD$setup_logfile(*this);
}
} // namespace rust