#!/bin/bash
LOCALDIR=$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)

DEBUG=false

update_code() {
  rm -rf jni Magisk src
  git clone --recurse-submodules https://github.com/topjohnwu/Magisk.git Magisk
  [ $? != 0 ] && echo "GitHub network timeout" && exit 1

  # Create magisk config file
  local read_magisk_config_line=4
  local magisk_version=$(cd Magisk && git rev-parse --short=8 HEAD && cd $LOCALDIR)
  tail -n $read_magisk_config_line <Magisk/gradle.properties >magisk_config.prop
  echo "magisk.version=$magisk_version" >>magisk_config.prop

  rm -rf jni rust src
  mv Magisk/native/src/ src/
  rm -rf Magisk
  if [[ -d src ]]; then
    echo "Upstream code update success, see log: https://github.com/topjohnwu/Magisk/tree/master/native"
  else
    echo "Upstream code update failed"
    exit 1
  fi
}

copy_output() {
  cp -af bin/* out/
}

build() {
  rm -rf bin obj libs out
  mkdir -p out
  make -j$(nproc --all)

  if [ ! -f 'bin/magiskboot.exe' ]; then
    return 1
  else
    return 0
  fi
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
  echo "build success"
  exit 0
else
  echo "build failed"
  exit 1
fi
