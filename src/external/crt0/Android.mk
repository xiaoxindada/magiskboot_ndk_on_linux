LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := crt0

# -lc -lm is hardcoded in this variable, disable it
TARGET_LDLIBS :=

# Manually link the compiler runtime library
LOCAL_compiler_rt := $(shell $(TARGET_CC) -target $(LLVM_TRIPLE)$(TARGET_PLATFORM_LEVEL) --print-libgcc-file-name)

LOCAL_EXPORT_LDFLAGS := -static -nostartfiles -nodefaultlibs $(LOCAL_compiler_rt) -Wl,-wrap,abort_message
LOCAL_CFLAGS := -Wno-c99-designator

LOCAL_SRC_FILES := \
	malloc.c \
	mem.c \
	misc.c \
	nolibc.c \
	stdio.c \
	syscall.c \
	bionic/dirent.cpp \
	bionic/strerror.cpp \
	bionic/syscall-$(TARGET_ARCH).S \
	tinystdio/tinystdio.c

include $(BUILD_STATIC_LIBRARY)
