#!/bin/bash
LOCALDIR=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)

DEBUG=false
ONDK_VERSION="r24.1"
ONDK_URL="https://github.com/topjohnwu/ondk/releases/download/$ONDK_VERSION/ondk-$ONDK_VERSION-linux.tar.gz"
ARCHIVE_NAME=${ONDK_URL##*/}
NDK_DIR="ondk-$ONDK_VERSION"

update_code() {
  rm -rf jni Magisk
  git clone --recurse-submodules https://github.com/topjohnwu/Magisk.git Magisk
  [ $? != 0 ] && echo "GitHub network timeout" && exit 1
  cp -af Magisk/native/jni jni
  cp -af Magisk/native/out/generated/* jni/include
  rm -rf Magisk
  if [ -d jni ]; then
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

copy_output() {
  cp -af libs/* out/
}

build() {
  rm -rf obj libs out
  mkdir -p out
  export NDK=${LOCALDIR}/ndk
  export PATH=${NDK}:${PATH}
  if [ $DEBUG = true ]; then
    echo "debug"
    ndk-build "B_BB=1"
    ndk-build "B_BOOT=1" "B_POLICY=1"
    exit 0
  fi
  ndk-build "B_BB=1" -j$(nproc --all)
  if [ $? = 0 ]; then
    copy_output
  else
    return 1
  fi
  ndk-build "B_BOOT=1" "B_POLICY=1" -j$(nproc --all)
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

if echo $@ | grep -q "setup"; then
  setup_ndk
fi

build
if [ $? = 0 ]; then
  echo "Output: $LOCALDIR/out"
  echo "magisk.versionCode=$magisk_versionCode" >$LOCALDIR/out/magisk_version.txt
  exit 0
else
  echo "build failed"
  exit 1
fi
