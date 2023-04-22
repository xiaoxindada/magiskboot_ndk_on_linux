#!/bin/bash
LOCALDIR=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)
ONDK_VERSION=$(cat magisk_config.prop | grep "magisk.ondkVersion="| head -n 1 | cut -d "=" -f 2)
ONDK_URL="https://github.com/topjohnwu/ondk/releases/download/$ONDK_VERSION/ondk-$ONDK_VERSION-linux.tar.gz"
ARCHIVE_NAME=${ONDK_URL##*/}
NDK_DIR="ondk-$ONDK_VERSION"

update_code() {
  rm -rf jni Magisk
  git clone --recurse-submodules https://github.com/topjohnwu/Magisk.git Magisk
  [ $? != 0 ] && echo "GitHub network timeout" && exit 1

  # Create magisk config file
  local read_magisk_config_line=4
  local magisk_version=$(cd Magisk && git rev-parse --short=8 HEAD && cd $LOCALDIR)
  tail -n $read_magisk_config_line <Magisk/gradle.properties >magisk_config.prop
  echo "magisk.version=$magisk_version" >>magisk_config.prop

  rm -rf src
  mv Magisk/native/src src/
  rm -rf Magisk
  if [[ -d src ]]; then
    # Fix busybox git push missing header file
    [ -f "src/external/busybox/include/.gitignore" ] && rm -rf "src/external/busybox/include/.gitignore"
    # Generate magisk dynamic resources
    python3 gen_config.py "dump_flags_header"
    python3 gen_config.py "dump_rust_header"

    # Fix path defined
    sed -i 's|out/generated|src/include/generated|g' src/base/Android.mk
    sed -i 's|\.\./out/\$(TARGET_ARCH_ABI)|\.\./src/prebuilt_libs/\$(TARGET_ARCH_ABI)|g' src/Android-rs.mk # prebuilt_libs
    rm -rf src/include/generated
    mkdir -p src/include/generated
    cp -af generated/* src/include/generated/

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
  *) echo "unsupported archive!" && exit 1 ;;
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
  for target in 'arm-linux-androideabi' 'i686-linux-android'; do
    local os_name=$(echo $(uname) | tr [:upper:] [:lower:])
    local arch=$(echo ${target} | cut -d '-' -f 1)
    local lib_dir="ndk/toolchains/llvm/prebuilt/${os_name}-x86_64/sysroot/usr/lib/${target}/23"
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
  
  # prebuilt libs
  # sed -i 's|\.\./out/\$(TARGET_ARCH_ABI)|\.\./src/prebuilt_libs/\$(TARGET_ARCH_ABI)|g' src/Android-rs.mk
  python3 gen_config.py "gen_prebuilt_rust_libs"
  ndk-build "NDK_PROJECT_PATH=$LOCALDIR" "NDK_APPLICATION_MK=src/Application.mk" "B_BB=1" -j$(nproc --all)
  if [ $? = 0 ]; then
    copy_output
  else
    return 1
  fi
  ndk-build "NDK_PROJECT_PATH=$LOCALDIR" "NDK_APPLICATION_MK=src/Application.mk" "B_BOOT=1" -j$(nproc --all)
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
  magisk_versionCode=$(cat magisk_config.prop | grep "magisk.versionCode=" | cut -d "=" -f 2 | head -n 1)
  echo "Output: $LOCALDIR/out"
  echo "magisk.versionCode=$magisk_versionCode" >$LOCALDIR/out/magisk_version.txt
  echo "# md5" >>$LOCALDIR/out/magisk_version.txt
  md5sum $LOCALDIR/out/*/* | tee -a >>$LOCALDIR/out/magisk_version.txt
  exit 0
else
  echo "build failed"
  exit 1
fi
