# crt0

Part of the [Magisk](https://github.com/topjohnwu/Magisk) project.

An extremely rudimentary libc with its sole purpose being to build the smallest possible executable for Magisk.<br>
A lot of code in this project is modified from various sources.

- `bionic`: https://android.googlesource.com/platform/bionic.git/+/refs/heads/main/libc/
- `dlmalloc`: http://gee.cs.oswego.edu/pub/misc/malloc.c
- `nolibc`: https://github.com/torvalds/linux/tree/master/tools/include/nolibc
- `tinystdio`: https://github.com/vladcebo/TinyStdio
- `linux_syscall_support.h`: https://chromium.googlesource.com/linux-syscall-support
- Other copied functions have its source commented above its code
