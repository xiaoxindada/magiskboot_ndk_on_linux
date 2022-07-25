# Magiskboot binary makefile by affggh & xiaoxindada
# Apatch 2.0

override CC = clang
override CXX = clang++
override STRIP = strip

override CFLAGS :=  $(CFLAGS) -Wall -Oz -static
override CXXFLAGS := $(CXXFLAGS) -std=c++2a -stdlib=libc++ -static
override LDFLAGS := $(LDFLAGS) -flto -lpthread -lrt -lz -static
override STRIPFLAGS := $(STRIPFLAGS) --strip-all
override INCLUDES := $(INCLUDES) -Isrc/include \
    -Isrc/external/dtc/libfdt \
    -Isrc/external/mincrypt/include \
    -Isrc/base/include \
    -Isrc/external/zopfli/src \
    -Isrc/external/zlib \
    -Isrc/external/bzip2 \
    -Isrc/external/xz/src/liblzma/api \
    -Isrc/external/lz4/lib

.PHONY: all

all: clean bin/magiskboot.exe bin/cygwin1.dll

LIBMAGISKBOOT_SRC = \
    src/boot/bootimg.cpp \
    src/boot/hexpatch.cpp \
    src/boot/compress.cpp \
    src/boot/format.cpp \
    src/boot/dtb.cpp \
    src/boot/ramdisk.cpp \
    src/boot/pattern.cpp \
    src/boot/cpio.cpp
LIBMAGISKBOOT_OBJ := $(patsubst %.cpp,obj/%.o,$(LIBMAGISKBOOT_SRC))

MAGISKBOOT_SRC = src/boot/main.cpp
MAGISKBOOT_OBJ := $(patsubst %.cpp,obj/%.o,$(MAGISKBOOT_SRC))

LIBBASE_SRC = \
    src/base/new.cpp \
    src/base/files.cpp \
    src/base/misc.cpp \
    src/base/selinux.cpp \
    src/base/logging.cpp \
    src/base/xwrap.cpp \
    src/base/stream.cpp
LIBBASE_OBJ := $(patsubst %.cpp,obj/%.o,$(LIBBASE_SRC))

LIBCOMPAT_SRC = src/base/compat/compat.cpp
LIBCOMPAT_OBJ := $(patsubst %.cpp,obj/%.o,$(LIBCOMPAT_SRC))

LIBMINCRYPT_SRC = \
    src/external/mincrypt/dsa_sig.c \
	src/external/mincrypt/p256.c \
	src/external/mincrypt/p256_ec.c \
	src/external/mincrypt/p256_ecdsa.c \
	src/external/mincrypt/rsa.c \
	src/external/mincrypt/sha.c \
	src/external/mincrypt/sha256.c
LIBMINCRYPT_OBJ = $(patsubst %.c,obj/%.o,$(LIBMINCRYPT_SRC))

LIBLZMA_SRC = \
    src/external/xz/src/common/tuklib_cpucores.c \
    src/external/xz/src/common/tuklib_exit.c \
    src/external/xz/src/common/tuklib_mbstr_fw.c \
    src/external/xz/src/common/tuklib_mbstr_width.c \
    src/external/xz/src/common/tuklib_open_stdxxx.c \
    src/external/xz/src/common/tuklib_physmem.c \
    src/external/xz/src/common/tuklib_progname.c \
    src/external/xz/src/liblzma/check/check.c \
    src/external/xz/src/liblzma/check/crc32_fast.c \
    src/external/xz/src/liblzma/check/crc32_table.c \
    src/external/xz/src/liblzma/check/crc64_fast.c \
    src/external/xz/src/liblzma/check/crc64_table.c \
    src/external/xz/src/liblzma/check/sha256.c \
    src/external/xz/src/liblzma/common/alone_decoder.c \
    src/external/xz/src/liblzma/common/alone_encoder.c \
    src/external/xz/src/liblzma/common/auto_decoder.c \
    src/external/xz/src/liblzma/common/block_buffer_decoder.c \
    src/external/xz/src/liblzma/common/block_buffer_encoder.c \
    src/external/xz/src/liblzma/common/block_decoder.c \
    src/external/xz/src/liblzma/common/block_encoder.c \
    src/external/xz/src/liblzma/common/block_header_decoder.c \
    src/external/xz/src/liblzma/common/block_header_encoder.c \
    src/external/xz/src/liblzma/common/block_util.c \
    src/external/xz/src/liblzma/common/common.c \
    src/external/xz/src/liblzma/common/easy_buffer_encoder.c \
    src/external/xz/src/liblzma/common/easy_decoder_memusage.c \
    src/external/xz/src/liblzma/common/easy_encoder.c \
    src/external/xz/src/liblzma/common/easy_encoder_memusage.c \
    src/external/xz/src/liblzma/common/easy_preset.c \
    src/external/xz/src/liblzma/common/filter_buffer_decoder.c \
    src/external/xz/src/liblzma/common/filter_buffer_encoder.c \
    src/external/xz/src/liblzma/common/filter_common.c \
    src/external/xz/src/liblzma/common/filter_decoder.c \
    src/external/xz/src/liblzma/common/filter_encoder.c \
    src/external/xz/src/liblzma/common/filter_flags_decoder.c \
    src/external/xz/src/liblzma/common/filter_flags_encoder.c \
    src/external/xz/src/liblzma/common/hardware_cputhreads.c \
    src/external/xz/src/liblzma/common/hardware_physmem.c \
    src/external/xz/src/liblzma/common/index.c \
    src/external/xz/src/liblzma/common/index_decoder.c \
    src/external/xz/src/liblzma/common/index_encoder.c \
    src/external/xz/src/liblzma/common/index_hash.c \
    src/external/xz/src/liblzma/common/outqueue.c \
    src/external/xz/src/liblzma/common/stream_buffer_decoder.c \
    src/external/xz/src/liblzma/common/stream_buffer_encoder.c \
    src/external/xz/src/liblzma/common/stream_decoder.c \
    src/external/xz/src/liblzma/common/stream_encoder.c \
    src/external/xz/src/liblzma/common/stream_encoder_mt.c \
    src/external/xz/src/liblzma/common/stream_flags_common.c \
    src/external/xz/src/liblzma/common/stream_flags_decoder.c \
    src/external/xz/src/liblzma/common/stream_flags_encoder.c \
    src/external/xz/src/liblzma/common/vli_decoder.c \
    src/external/xz/src/liblzma/common/vli_encoder.c \
    src/external/xz/src/liblzma/common/vli_size.c \
    src/external/xz/src/liblzma/delta/delta_common.c \
    src/external/xz/src/liblzma/delta/delta_decoder.c \
    src/external/xz/src/liblzma/delta/delta_encoder.c \
    src/external/xz/src/liblzma/lz/lz_decoder.c \
    src/external/xz/src/liblzma/lz/lz_encoder.c \
    src/external/xz/src/liblzma/lz/lz_encoder_mf.c \
    src/external/xz/src/liblzma/lzma/fastpos_table.c \
    src/external/xz/src/liblzma/lzma/fastpos_tablegen.c \
    src/external/xz/src/liblzma/lzma/lzma2_decoder.c \
    src/external/xz/src/liblzma/lzma/lzma2_encoder.c \
    src/external/xz/src/liblzma/lzma/lzma_decoder.c \
    src/external/xz/src/liblzma/lzma/lzma_encoder.c \
    src/external/xz/src/liblzma/lzma/lzma_encoder_optimum_fast.c \
    src/external/xz/src/liblzma/lzma/lzma_encoder_optimum_normal.c \
    src/external/xz/src/liblzma/lzma/lzma_encoder_presets.c \
    src/external/xz/src/liblzma/rangecoder/price_table.c \
    src/external/xz/src/liblzma/rangecoder/price_tablegen.c \
    src/external/xz/src/liblzma/simple/arm.c \
    src/external/xz/src/liblzma/simple/armthumb.c \
    src/external/xz/src/liblzma/simple/ia64.c \
    src/external/xz/src/liblzma/simple/powerpc.c \
    src/external/xz/src/liblzma/simple/simple_coder.c \
    src/external/xz/src/liblzma/simple/simple_decoder.c \
    src/external/xz/src/liblzma/simple/simple_encoder.c \
    src/external/xz/src/liblzma/simple/sparc.c \
    src/external/xz/src/liblzma/simple/x86.c

LIBLZMA_INCLUDES = \
    -Isrc/external/xz_config \
    -Isrc/external/xz/src/common \
    -Isrc/external/xz/src/liblzma/api \
    -Isrc/external/xz/src/liblzma/check \
    -Isrc/external/xz/src/liblzma/common \
    -Isrc/external/xz/src/liblzma/delta \
    -Isrc/external/xz/src/liblzma/lz \
    -Isrc/external/xz/src/liblzma/lzma \
    -Isrc/external/xz/src/liblzma/rangecoder \
    -Isrc/external/xz/src/liblzma/simple \
    -Isrc/external/xz/src/liblzma \
	-Isrc/external/xz_config
LIBLZMA_OBJ = $(patsubst %.c,obj/lzma/%.o,$(LIBLZMA_SRC))

LIBBZ2_SRC = \
    src/external/bzip2/blocksort.c  \
    src/external/bzip2/huffman.c    \
    src/external/bzip2/crctable.c   \
    src/external/bzip2/randtable.c  \
    src/external/bzip2/compress.c   \
    src/external/bzip2/decompress.c \
    src/external/bzip2/bzlib.c
LIBBZ2_OBJ = $(patsubst %.c,obj/%.o,$(LIBBZ2_SRC))

LIBLZ4_SRC = \
    src/external/lz4/lib/lz4.c \
    src/external/lz4/lib/lz4frame.c \
    src/external/lz4/lib/lz4hc.c \
    src/external/lz4/lib/xxhash.c
LIBLZ4_OBJ = $(patsubst %.c,obj/%.o,$(LIBLZ4_SRC))

LIBZOPFLI_SRC = \
    src/external/zopfli/src/zopfli/blocksplitter.c \
    src/external/zopfli/src/zopfli/cache.c \
    src/external/zopfli/src/zopfli/deflate.c \
    src/external/zopfli/src/zopfli/gzip_container.c \
    src/external/zopfli/src/zopfli/hash.c \
    src/external/zopfli/src/zopfli/katajainen.c \
    src/external/zopfli/src/zopfli/lz77.c \
    src/external/zopfli/src/zopfli/squeeze.c \
    src/external/zopfli/src/zopfli/tree.c \
    src/external/zopfli/src/zopfli/util.c \
    src/external/zopfli/src/zopfli/zlib_container.c \
    src/external/zopfli/src/zopfli/zopfli_lib.c
LIBZOPFLI_OBJ = $(patsubst %.c,obj/zopfli/%.o,$(LIBZOPFLI_SRC))

LIBFDT_SRC = \
    src/external/dtc/libfdt/fdt.c \
    src/external/dtc/libfdt/fdt_addresses.c \
    src/external/dtc/libfdt/fdt_empty_tree.c \
    src/external/dtc/libfdt/fdt_overlay.c \
    src/external/dtc/libfdt/fdt_ro.c \
    src/external/dtc/libfdt/fdt_rw.c \
    src/external/dtc/libfdt/fdt_strerror.c \
    src/external/dtc/libfdt/fdt_sw.c \
    src/external/dtc/libfdt/fdt_wip.c
LIBFDT_OBJ = $(patsubst %.c,obj/fdt/%.o,$(LIBFDT_SRC))

LIBZ_SRC = \
    src/external/zlib/adler32.c \
    src/external/zlib/compress.c \
    src/external/zlib/cpu_features.c \
    src/external/zlib/crc32.c \
    src/external/zlib/deflate.c \
    src/external/zlib/gzclose.c \
    src/external/zlib/gzlib.c \
    src/external/zlib/gzread.c \
    src/external/zlib/gzwrite.c \
    src/external/zlib/infback.c \
    src/external/zlib/inffast.c \
    src/external/zlib/inflate.c \
    src/external/zlib/inftrees.c \
    src/external/zlib/trees.c \
    src/external/zlib/uncompr.c \
    src/external/zlib/zutil.c
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
	@echo -e "\t    RM\t    libs"
	@rm -rf libs
