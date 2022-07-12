#!/bin/bash
LOCALDIR=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)

DEBUG=false

update_code() {
  rm -rf jni Magisk
  git clone --recurse-submodules https://github.com/topjohnwu/Magisk.git Magisk
  [ $? != 0 ] && echo "GitHub network timeout" && exit 1

  # Create magisk config file
  local read_magisk_config_line=4
  local magisk_version=$(cd Magisk && git rev-parse --short=8 HEAD && cd $LOCALDIR)
  tail -n $read_magisk_config_line <Magisk/gradle.properties >magisk_config.prop
  sed -i "s|magisk.ondkVersion=.*|magisk.ondkVersion=${ONDK_VERSION}|" magisk_config.prop
  echo "magisk.version=$magisk_version" >>magisk_config.prop

  cp -af Magisk/native/jni jni
  rm -rf Magisk
  if [ -d jni ]; then
    # Fix busybox git push missing header file
    [ -f "jni/external/busybox/include/.gitignore" ] && rm -rf "jni/external/busybox/include/.gitignore"

    echo "Upstream code update success, see log: https://github.com/topjohnwu/Magisk/tree/master/native"
  else
    echo "Upstream code update failed"
    exit 1
  fi
}

extract_archive() {
  local archive="$1"
  local extract_dir="$2"
  local suffix=$(echo $archive | grep -oE "zip$|tar$|tar.gz$")
  local cmd=""

  mkdir -p $extract_dir
  case $suffix in
  "zip") cmd="7za x $archive -o$extract_dir" ;;
  "tar") cmd="tar -xf $archive -C $extract_dir" ;;
  "tar.gz") cmd="tar -zxf $archive -C $extract_dir" ;;
  *) echo "unsupported archive" && exit 1 ;;
  esac

  eval $cmd
}

setup_ndk() {
  wget "${ONDK_URL}" -O "${ARCHIVE_NAME}"
  echo "extract ${ARCHIVE_NAME} ..."
  extract_archive "${ARCHIVE_NAME}" "${LOCALDIR}"
  [ -d $NDK_DIR ] && rm -rf ndk && mv -f $NDK_DIR ndk

  # Re-based on Magisk/build.py
  # Fix duplicate symbol
  echo "Patching static libs ..."
  for target in 'aarch64-linux-android' 'arm-linux-androideabi' 'i686-linux-android' 'x86_64-linux-android'; do
    local os_name=$(echo $(uname) | tr [:upper:] [:lower:])
    local arch=$(echo ${target} | cut -d '-' -f 1)
    local lib_dir="ndk/toolchains/llvm/prebuilt/${os_name}-x86_64/sysroot/usr/lib/${target}/21"
    local src_dir="ndk-bins/21/${arch}"

    cp -af $src_dir/* $lib_dir/
  done
}

regen_flags_h() {
  local modify_file=$(grep -ril "out/generated" jni | head -n 1)
  local magisk_versionCode=$(cat magisk_config.prop | grep "magisk.versionCode=" | cut -d "=" -f 2 | head -n 1)
  local magisk_version=$(cat magisk_config.prop | grep "magisk.version=" | cut -d "=" -f 2 | head -n 1)

  # Create flags.h
  rm -rf "generated/flags.h"
  cat >>"generated/flags.h" <<EOF
#pragma once
#define quote(s)            #s
#define str(s)              quote(s)
#define MAGISK_FULL_VER     MAGISK_VERSION "(" str(MAGISK_VER_CODE) ")"
#define NAME_WITH_VER(name) str(name) " " MAGISK_FULL_VER
#define MAGISK_VERSION      "$magisk_version"
#define MAGISK_VER_CODE     $magisk_versionCode
#define MAGISK_DEBUG        0
EOF

  [ -n "$modify_file" ] && sed -i 's|out/generated|jni/include/generated|g' $modify_file
  rm -rf jni/include/generated
  mkdir -p jni/include/generated
  cp -af generated/* jni/include/generated/
}

copy_output() {
  cp -af jni/bin/* out/
}

build() {
  rm -rf out jni/{obj,bin,libs}
  mkdir -p out
  
  echo "patch_flags_h ..."
  patch_flags_h

  if [ $? = 0 ]; then
    copy_output
  else
    return 1
  fi

  return 0
}

apply_patches() {
  for p in patches/public/*; do
    if ! git am -3 <$p; then
      patch -p1 <$p
    fi
  done
}

if echo $@ | grep -q "patch"; then
  apply_patches
  exit 0
fi

if echo $@ | grep -q "update_code"; then
  update_code
  exit 0
fi



build
if [ $? = 0 ]; then
  magisk_versionCode=$(cat magisk_config.prop | grep "magisk.versionCode=" | cut -d "=" -f 2 | head -n 1)
  echo "Output: $LOCALDIR/out"
  echo "magisk.versionCode=$magisk_versionCode" >$LOCALDIR/out/magisk_version.txt
  exit 0
else
  echo "build failed"
  exit 1
fi
