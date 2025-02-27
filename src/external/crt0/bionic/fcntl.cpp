/*
 * Copyright (C) 2019 The Android Open Source Project
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <stdarg.h>
#include <fcntl.h>

extern "C" int sys_fcntl(int fd, int cmd, ...);
extern "C" int sys_fcntl64(int, int, ...);

int fcntl(int fd, int cmd, ...) {
  va_list args;
  va_start(args, cmd);
  // This is a bit sketchy for LP64, especially because arg can be an int,
  // but all of our supported 64-bit ABIs pass the argument in a register.
  void* arg = va_arg(args, void*);
  va_end(args);

  if (cmd == F_SETFD && (reinterpret_cast<uintptr_t>(arg) & ~FD_CLOEXEC) != 0) {
    return -1;
  }

#if defined(__LP64__)
  return sys_fcntl(fd, cmd, arg);
#else
  // For LP32 we use the fcntl64 system call to signal that we're using struct flock64.
  return sys_fcntl64(fd, cmd, arg);
#endif
}
