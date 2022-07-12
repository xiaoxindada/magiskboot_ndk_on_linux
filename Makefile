# Magiskboot binary makefile by affggh & xiaoxindada
# Apatch 2.0

override CC = clang
override CXX = clang++
override STRIP = strip

override CFLAGS :=  $(CFLAGS) -Wall -Oz -static
override CXXFLAGS := $(CXXFLAGS) -std=c++2a -stdlib=libc++ -static
override LDFLAGS := $(LDFLAGS) -flto -lpthread -lrt -lz -static
override STRIPFLAGS := $(STRIPFLAGS) --strip-all
override INCLUDES := $(INCLUDES) -Iinclude \
    -Iexternal/dtc/libfdt \
    -Iexternal/mincrypt/include \
    -Ibase/include \
    -Iexternal/zopfli/src \
    -Iexternal/zlib \
    -Iexternal/bzip2 \
    -Iexternal/xz/src/liblzma/api \
    -Iexternal/lz4/lib

.PHONY: all

all: clean bin/magiskboot.exe bin/cygwin1.dll

LIBMAGISKBOOT_SRC = \
    boot/bootimg.cpp \
    boot/hexpatch.cpp \
    boot/compress.cpp \
    boot/format.cpp \
    boot/dtb.cpp \
    boot/ramdisk.cpp \
    boot/pattern.cpp \
    boot/cpio.cpp
LIBMAGISKBOOT_OBJ := $(patsubst %.cpp,obj/%.o,$(LIBMAGISKBOOT_SRC))

MAGISKBOOT_SRC = boot/main.cpp
MAGISKBOOT_OBJ := $(patsubst %.cpp,obj/%.o,$(MAGISKBOOT_SRC))

LIBBASE_SRC = \
    base/new.cpp \
    base/files.cpp \
    base/misc.cpp \
    base/selinux.cpp \
    base/logging.cpp \
    base/xwrap.cpp \
    base/stream.cpp
LIBBASE_OBJ := $(patsubst %.cpp,obj/%.o,$(LIBBASE_SRC))

LIBCOMPAT_SRC = base/compat/compat.cpp
LIBCOMPAT_OBJ := $(patsubst %.cpp,obj/%.o,$(LIBCOMPAT_SRC))

LIBMINCRYPT_SRC = \
    external/mincrypt/dsa_sig.c \
	external/mincrypt/p256.c \
	external/mincrypt/p256_ec.c \
	external/mincrypt/p256_ecdsa.c \
	external/mincrypt/rsa.c \
	external/mincrypt/sha.c \
	external/mincrypt/sha256.c
LIBMINCRYPT_OBJ = $(patsubst %.c,obj/%.o,$(LIBMINCRYPT_SRC))

LIBLZMA_SRC = \
    external/xz/src/common/tuklib_cpucores.c \
    external/xz/src/common/tuklib_exit.c \
    external/xz/src/common/tuklib_mbstr_fw.c \
    external/xz/src/common/tuklib_mbstr_width.c \
    external/xz/src/common/tuklib_open_stdxxx.c \
    external/xz/src/common/tuklib_physmem.c \
    external/xz/src/common/tuklib_progname.c \
    external/xz/src/liblzma/check/check.c \
    external/xz/src/liblzma/check/crc32_fast.c \
    external/xz/src/liblzma/check/crc32_table.c \
    external/xz/src/liblzma/check/crc64_fast.c \
    external/xz/src/liblzma/check/crc64_table.c \
    external/xz/src/liblzma/check/sha256.c \
    external/xz/src/liblzma/common/alone_decoder.c \
    external/xz/src/liblzma/common/alone_encoder.c \
    external/xz/src/liblzma/common/auto_decoder.c \
    external/xz/src/liblzma/common/block_buffer_decoder.c \
    external/xz/src/liblzma/common/block_buffer_encoder.c \
    external/xz/src/liblzma/common/block_decoder.c \
    external/xz/src/liblzma/common/block_encoder.c \
    external/xz/src/liblzma/common/block_header_decoder.c \
    external/xz/src/liblzma/common/block_header_encoder.c \
    external/xz/src/liblzma/common/block_util.c \
    external/xz/src/liblzma/common/common.c \
    external/xz/src/liblzma/common/easy_buffer_encoder.c \
    external/xz/src/liblzma/common/easy_decoder_memusage.c \
    external/xz/src/liblzma/common/easy_encoder.c \
    external/xz/src/liblzma/common/easy_encoder_memusage.c \
    external/xz/src/liblzma/common/easy_preset.c \
    external/xz/src/liblzma/common/filter_buffer_decoder.c \
    external/xz/src/liblzma/common/filter_buffer_encoder.c \
    external/xz/src/liblzma/common/filter_common.c \
    external/xz/src/liblzma/common/filter_decoder.c \
    external/xz/src/liblzma/common/filter_encoder.c \
    external/xz/src/liblzma/common/filter_flags_decoder.c \
    external/xz/src/liblzma/common/filter_flags_encoder.c \
    external/xz/src/liblzma/common/hardware_cputhreads.c \
    external/xz/src/liblzma/common/hardware_physmem.c \
    external/xz/src/liblzma/common/index.c \
    external/xz/src/liblzma/common/index_decoder.c \
    external/xz/src/liblzma/common/index_encoder.c \
    external/xz/src/liblzma/common/index_hash.c \
    external/xz/src/liblzma/common/outqueue.c \
    external/xz/src/liblzma/common/stream_buffer_decoder.c \
    external/xz/src/liblzma/common/stream_buffer_encoder.c \
    external/xz/src/liblzma/common/stream_decoder.c \
    external/xz/src/liblzma/common/stream_encoder.c \
    external/xz/src/liblzma/common/stream_encoder_mt.c \
    external/xz/src/liblzma/common/stream_flags_common.c \
    external/xz/src/liblzma/common/stream_flags_decoder.c \
    external/xz/src/liblzma/common/stream_flags_encoder.c \
    external/xz/src/liblzma/common/vli_decoder.c \
    external/xz/src/liblzma/common/vli_encoder.c \
    external/xz/src/liblzma/common/vli_size.c \
    external/xz/src/liblzma/delta/delta_common.c \
    external/xz/src/liblzma/delta/delta_decoder.c \
    external/xz/src/liblzma/delta/delta_encoder.c \
    external/xz/src/liblzma/lz/lz_decoder.c \
    external/xz/src/liblzma/lz/lz_encoder.c \
    external/xz/src/liblzma/lz/lz_encoder_mf.c \
    external/xz/src/liblzma/lzma/fastpos_table.c \
    external/xz/src/liblzma/lzma/fastpos_tablegen.c \
    external/xz/src/liblzma/lzma/lzma2_decoder.c \
    external/xz/src/liblzma/lzma/lzma2_encoder.c \
    external/xz/src/liblzma/lzma/lzma_decoder.c \
    external/xz/src/liblzma/lzma/lzma_encoder.c \
    external/xz/src/liblzma/lzma/lzma_encoder_optimum_fast.c \
    external/xz/src/liblzma/lzma/lzma_encoder_optimum_normal.c \
    external/xz/src/liblzma/lzma/lzma_encoder_presets.c \
    external/xz/src/liblzma/rangecoder/price_table.c \
    external/xz/src/liblzma/rangecoder/price_tablegen.c \
    external/xz/src/liblzma/simple/arm.c \
    external/xz/src/liblzma/simple/armthumb.c \
    external/xz/src/liblzma/simple/ia64.c \
    external/xz/src/liblzma/simple/powerpc.c \
    external/xz/src/liblzma/simple/simple_coder.c \
    external/xz/src/liblzma/simple/simple_decoder.c \
    external/xz/src/liblzma/simple/simple_encoder.c \
    external/xz/src/liblzma/simple/sparc.c \
    external/xz/src/liblzma/simple/x86.c

LIBLZMA_INCLUDES = \
    -Iexternal/xz_config \
    -Iexternal/xz/src/common \
    -Iexternal/xz/src/liblzma/api \
    -Iexternal/xz/src/liblzma/check \
    -Iexternal/xz/src/liblzma/common \
    -Iexternal/xz/src/liblzma/delta \
    -Iexternal/xz/src/liblzma/lz \
    -Iexternal/xz/src/liblzma/lzma \
    -Iexternal/xz/src/liblzma/rangecoder \
    -Iexternal/xz/src/liblzma/simple \
    -Iexternal/xz/src/liblzma \
	-Iexternal/xz_config
LIBLZMA_OBJ = $(patsubst %.c,obj/lzma/%.o,$(LIBLZMA_SRC))

LIBBZ2_SRC = \
    external/bzip2/blocksort.c  \
    external/bzip2/huffman.c    \
    external/bzip2/crctable.c   \
    external/bzip2/randtable.c  \
    external/bzip2/compress.c   \
    external/bzip2/decompress.c \
    external/bzip2/bzlib.c
LIBBZ2_OBJ = $(patsubst %.c,obj/%.o,$(LIBBZ2_SRC))

LIBLZ4_SRC = \
    external/lz4/libs/lz4.c \
    external/lz4/libs/lz4frame.c \
    external/lz4/libs/lz4hc.c \
    external/lz4/libs/xxhash.c
LIBLZ4_OBJ = $(patsubst %.c,obj/%.o,$(LIBLZ4_SRC))

LIBZOPFLI_SRC = \
    external/zopfli/src/zopfli/blocksplitter.c \
    external/zopfli/src/zopfli/cache.c \
    external/zopfli/src/zopfli/deflate.c \
    external/zopfli/src/zopfli/gzip_container.c \
    external/zopfli/src/zopfli/hash.c \
    external/zopfli/src/zopfli/katajainen.c \
    external/zopfli/src/zopfli/lz77.c \
    external/zopfli/src/zopfli/squeeze.c \
    external/zopfli/src/zopfli/tree.c \
    external/zopfli/src/zopfli/util.c \
    external/zopfli/src/zopfli/zlib_container.c \
    external/zopfli/src/zopfli/zopfli_lib.c
LIBZOPFLI_OBJ = $(patsubst %.c,obj/zopfli/%.o,$(LIBZOPFLI_SRC))

LIBFDT_SRC = \
    external/dtc/libfdt/fdt.c \
    external/dtc/libfdt/fdt_addresses.c \
    external/dtc/libfdt/fdt_empty_tree.c \
    external/dtc/libfdt/fdt_overlay.c \
    external/dtc/libfdt/fdt_ro.c \
    external/dtc/libfdt/fdt_rw.c \
    external/dtc/libfdt/fdt_strerror.c \
    external/dtc/libfdt/fdt_sw.c \
    external/dtc/libfdt/fdt_wip.c
LIBFDT_OBJ = $(patsubst %.c,obj/fdt/%.o,$(LIBFDT_SRC))

LIBZ_SRC = \
    external/zlib/adler32.c \
    external/zlib/compress.c \
    external/zlib/cpu_features.c \
    external/zlib/crc32.c \
    external/zlib/deflate.c \
    external/zlib/gzclose.c \
    external/zlib/gzlib.c \
    external/zlib/gzread.c \
    external/zlib/gzwrite.c \
    external/zlib/infback.c \
    external/zlib/inffast.c \
    external/zlib/inflate.c \
    external/zlib/inftrees.c \
    external/zlib/trees.c \
    external/zlib/uncompr.c \
    external/zlib/zutil.c
LIBZ_OBJ = $(patsubst %.c,obj/zlib/%.o,$(LIBZ_SRC))

obj/zlib/%.o: %.c
	@mkdir -p `dirname $@`
	@echo -e "\t    CC\t    $@"
	@$(CC) $(CFLAGS) $(INCLUDES) -UWIDECHAR -DHAVE_HIDDEN -DZLIB_CONST -Wall -Werror -Wno-unused -Wno-unused-parameter -c $< -o $@

obj/zopfli/%.o: %.c
	@mkdir -p `dirname $@`
	@echo -e "\t    CC\t    $@"
	@$(CC) $(CFLAGS) -Wall -Werror -Wno-unused -Wno-unused-parameter $(INCLUDES) -c $< -o $@

obj/fdt/%.o: %.c
	@mkdir -p `dirname $@`
	@echo -e "\t    CC\t    $@"
	@$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@    

obj/lzma/%.o: %.c
	@mkdir -p `dirname $@`
	@echo -e "\t    CC\t    $@"
	@$(CC) $(CFLAGS) -DHAVE_CONFIG_H -Wno-implicit-function-declaration $(INCLUDES) $(LIBLZMA_INCLUDES) -c $< -o $@

obj/%.o: %.c
	@mkdir -p `dirname $@`
	@echo -e "\t    CC\t    $@"
	@$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

obj/%.o: %.cc
	@mkdir -p `dirname $@`
	@echo -e "\t    CPP\t    $@"
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -fno-exceptions -c $< -o $@

obj/%.o: %.cpp
	@mkdir -p `dirname $@`
	@echo -e "\t    CPP\t    $@"
	@$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

bin/magiskboot.exe: libs/libmagiskboot.a libs/libbase.a libs/libcompat.a libs/libmincrypt.a \
                libs/liblzma.a libs/libbz2.a libs/liblz4.a libs/libzopfli.a libs/libfdt.a # libs/libz.a # Bug : zlib bug on cygwin, using LDFLAGS: -lz to fix it

	@mkdir -p `dirname $@`
	@echo -e "\t    LD\t    $@"
	@$(CXX) $(CXXFLAGS) $(INCLUDES) $^ -o $@ $(LDFLAGS)
	@echo -e "\t    STRIP\t    $@"
	@$(STRIP) $(STRIPFLAGS) $@

bin/cygwin1.dll:
	@mkdir -p `dirname $@`
	@echo -e "\t    COPY\t  $@"
	@cp /bin/cygwin1.dll $@

libs/libcygwin.a:
	@mkdir -p `dirname $@`
	@echo -e "\t    COPY\t  $@"
	@cp /libs/libcygwin.a $@

libs/libmagiskboot.a: $(MAGISKBOOT_OBJ) $(LIBMAGISKBOOT_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

libs/libcompat.a: $(LIBCOMPAT_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

libs/libbase.a: $(LIBBASE_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

libs/libmincrypt.a: $(LIBMINCRYPT_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

libs/liblzma.a: $(LIBLZMA_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

libs/libbz2.a: $(LIBBZ2_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

libs/liblz4.a: $(LIBLZ4_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

libs/libzopfli.a: $(LIBZOPFLI_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

libs/libfdt.a: $(LIBFDT_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

# Bug : Cygwin cannot use _wopen()
# So we use zlib on cygwin instead magiskboot external
libs/libz.a: $(LIBZ_OBJ)
	@mkdir -p `dirname $@`
	@echo -e "\t    AR\t    $@"
	@ar rcs $@ $^

clean:
	@echo -e "\t    RM\t    obj"
	@rm -rf obj
	@echo -e "\t    RM\t    bin"
	@rm -rf bin
	@echo -e "\t    RM\t    lib"
	@rm -rf lib
