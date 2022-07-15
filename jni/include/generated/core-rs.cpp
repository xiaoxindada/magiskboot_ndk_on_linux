extern "C" {
void cxxbridge1$rust_test_entry() noexcept;

void cxxbridge1$android_logging() noexcept;

void cxxbridge1$magisk_logging() noexcept;

void cxxbridge1$zygisk_logging() noexcept;
} // extern "C"

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