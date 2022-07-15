namespace rust {
extern "C" {
void rust$cxxbridge1$setup_klog() noexcept;
} // extern "C"

void setup_klog() noexcept {
  rust$cxxbridge1$setup_klog();
}
} // namespace rust