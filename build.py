#!/usr/bin/env python3
import argparse
import errno
import lzma
import multiprocessing
import os
import platform
import sys
import os.path as op
import shutil
import stat
import subprocess
import tarfile
import textwrap
import wget


def parse_props(file):
    props = {}
    with open(file, 'r') as f:
        for line in [l.strip(' \t\r\n') for l in f]:
            if line.startswith('#') or len(line) == 0:
                continue
            prop = line.split('=')
            if len(prop) != 2:
                continue
            value = prop[1].strip(' \t\r\n')
            if len(value) == 0:
                continue
            props[prop[0].strip(' \t\r\n')] = value
    return props


def load_config():
    for key, value in parse_props("magisk_config.prop").items():
        if key.startswith('magisk.'):
            config[key[7:]] = value


def error(str):
    print(f'\n\033[41m{str}\033[0m\n')
    sys.exit(1)


def mv(source, target):
    try:
        shutil.move(source, target)
    except:
        pass


def cp(source, target):
    try:
        shutil.copyfile(source, target)
    except:
        pass


def cp_rf(source, target):
    shutil.copytree(source, target, copy_function=cp, dirs_exist_ok=True)


def rm(file):
    try:
        os.remove(file)
    except OSError as e:
        if e.errno != errno.ENOENT:
            raise


def rm_on_error(func, path, _):
    # Remove a read-only file on Windows will get "WindowsError: [Error 5] Access is denied"
    # Clear the "read-only" and retry
    os.chmod(path, stat.S_IWRITE)
    os.unlink(path)


def rm_rf(path):
    shutil.rmtree(path, ignore_errors=True, onerror=rm_on_error)


def mkdir(path, mode=0o755):
    try:
        os.mkdir(path, mode)
    except:
        pass


def mkdir_p(path, mode=0o755):
    os.makedirs(path, mode, exist_ok=True)


def execv(cmd, env=None):
    return subprocess.run(cmd, stdout=sys.stdout, env=env)


def system(cmd):
    return subprocess.run(cmd, shell=True, stdout=sys.stdout)


def cmd_out(cmd, env=None):
    return subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env).stdout.strip().decode("utf-8")


LOCALDIR = op.realpath('.')
cpu_count = multiprocessing.cpu_count()
archs = ["armeabi-v7a", "x86", "arm64-v8a", "x86_64"]
triples = [
    "armv7a-linux-androideabi",
    "i686-linux-android",
    "aarch64-linux-android",
    "x86_64-linux-android",
]
rust_targets = ["magiskboot"]
ndk_root = op.join(LOCALDIR, "ndk")
ndk_build = op.join(ndk_root, "ndk-build")
rust_bin = op.join(ndk_root, "toolchains", "rust", "bin")
cargo = op.join(rust_bin, "cargo")
local_cargo_root = op.join(LOCALDIR, '.cargo')
cxxbridge = op.join(local_cargo_root, 'bin', 'cxxbridge')
native_gen_path = op.realpath(op.join(LOCALDIR, "generated"))
release = True
config = {}
load_config()


def cp_output(source, target):
    system(f"cp -af {source} {target}")


def generate_binary_info(file):
    rm_rf(file)
    system(f"echo 'magisk.versionCode={config['versionCode']}' > {file}")
    system(f"echo 'md5' >> {file}")
    system(f"md5sum out/**/* >> {file}")


def xz(data):
    return lzma.compress(data, preset=9, check=lzma.CHECK_NONE)


def binary_dump(src, var_name, compressor=xz):
    out_str = f"constexpr unsigned char {var_name}[] = {{"
    for i, c in enumerate(compressor(src.read())):
        if i % 16 == 0:
            out_str += "\n"
        out_str += f"0x{c:02X},"
    out_str += "\n};\n"
    return out_str


def dump_bin_header():
    for arch in archs:
        mkdir_p(op.join(native_gen_path, arch))
        for tgt in ["libinit-ld.so", "libzygisk-ld.so"]:
            source = op.join(LOCALDIR, "libs", arch, tgt)
            target = op.join(native_gen_path, arch, tgt)
            mv(source, target)
    for arch in archs:
        preload = op.join(native_gen_path, arch, "libinit-ld.so")
        with open(preload, "rb") as src:
            text = binary_dump(src, "init_ld_xz")
        preload = op.join(native_gen_path, arch, "libzygisk-ld.so")
        with open(preload, "rb") as src:
            text += binary_dump(src, "zygisk_ld", compressor=lambda x: x)
        write_if_diff(op.join(native_gen_path, f"{arch}_binaries.h"), text)


def write_if_diff(file_name, text):
    rm(file_name)
    do_write = True
    if op.exists(file_name):
        with open(file_name, 'r') as f:
            orig = f.read()
        do_write = orig != text
    if do_write:
        with open(file_name, 'w') as f:
            print("Write %s" % file_name)
            f.write(text)


def dump_flags_header():
    flag_txt = textwrap.dedent('''\
        #pragma once
        #define quote(s)            #s
        #define str(s)              quote(s)
        #define MAGISK_FULL_VER     MAGISK_VERSION "(" str(MAGISK_VER_CODE) ")"
        #define NAME_WITH_VER(name) str(name) " " MAGISK_FULL_VER
        ''')
    flag_txt += f'#define MAGISK_VERSION      "{config["version"]}"\n'
    flag_txt += f'#define MAGISK_VER_CODE     {config["versionCode"]}\n'
    flag_txt += f'#define MAGISK_DEBUG        {0 if release else 1}\n'

    mkdir_p(native_gen_path)
    write_if_diff(op.join(native_gen_path, 'flags.h'), flag_txt)


def run_cargo_build():
    os.chdir(op.join(LOCALDIR, 'src'))
    targets = set(rust_targets)

    env = os.environ.copy()
    env['CARGO_BUILD_RUSTC'] = op.join(rust_bin, 'rustc')

    # Start building the actual build commands
    cmds = [cargo, 'build']
    for target in targets:
        cmds.append('-p')
        cmds.append(target)
    if release:
        cmds.append('-r')
        rust_out = 'release'
    else:
        rust_out = 'debug'

    os_name = platform.system().lower()
    llvm_bin = op.join(
        ndk_root, "toolchains", "llvm", "prebuilt", f"{os_name}-x86_64", "bin"
    )
    env["TARGET_CC"] = op.join(llvm_bin, "clang")
    env["RUSTFLAGS"] = "-Clinker-plugin-lto"
    for arch, triple in zip(archs, triples):
        env["TARGET_CFLAGS"] = f"--target={triple}23"
        rust_triple = (
            "thumbv7neon-linux-androideabi" if triple.startswith(
                "armv7") else triple
        )
        proc = execv([*cmds, "--target", rust_triple], env)
        if proc.returncode != 0:
            error("Build binary failed!")

        arch_out = op.join(native_gen_path, arch)
        mkdir_p(arch_out)
        for tgt in targets:
            source = op.join("target", rust_triple, rust_out, f"lib{tgt}.a")
            target = op.join(arch_out, f"lib{tgt}-rs.a")
            mv(source, target)

    os.chdir(LOCALDIR)


def setup_ndk():
    os_name = platform.system().lower()
    url = f"https://github.com/topjohnwu/ondk/releases/download/{config['ondkVersion']}/ondk-{config['ondkVersion']}-{os_name}.tar.gz"
    ndk_archive = url.split("/")[-1]
    print(f"Downloading {ndk_archive}")
    wget.download(url, ndk_archive)
    print(f"Extracting {ndk_archive}")
    with tarfile.open(ndk_archive, mode="r|gz") as tar:
        tar.extractall(LOCALDIR)
    if op.exists(f"ondk-{config['ondkVersion']}"):
        rm_rf(ndk_root)
        mv(f"ondk-{config['ondkVersion']}", ndk_root)

    print("* Patching static libs")
    for target in ["arm-linux-androideabi", "i686-linux-android"]:
        arch = target.split("-")[0]
        lib_dir = op.join(
            ndk_root,
            "toolchains",
            "llvm",
            "prebuilt",
            f"{os_name}-x86_64",
            "sysroot",
            "usr",
            "lib",
            f"{target}",
            "23",
        )
        if not op.exists(lib_dir):
            continue
        src_dir = op.join(LOCALDIR, "ndk-bins", arch)
        cp_rf(src_dir, lib_dir)


def run_ndk_build(flags):
    os.chdir(LOCALDIR)
    NDK_APPLICATION_MK = op.join(LOCALDIR, "src", "Application.mk")
    flags = f"NDK_PROJECT_PATH={LOCALDIR} NDK_APPLICATION_MK={NDK_APPLICATION_MK} {flags}"
    proc = system(f"{ndk_build} {flags} -j{cpu_count}")
    if proc.returncode != 0:
        error("Build binary failed!")


def build_binary():
    libs = op.join(LOCALDIR, "libs")
    out = op.join(LOCALDIR, "out")

    rm_rf(native_gen_path)
    rm_rf(out)
    mkdir_p(native_gen_path)
    mkdir_p(out)

    run_cargo_build()
    dump_flags_header()
    run_ndk_build("B_PRELOAD=1")
    dump_bin_header()
    run_ndk_build("B_BB=1")
    cp_output(f"{libs}/*", out)
    run_ndk_build("B_BOOT=1")
    cp_output(f"{libs}/*", out)
    generate_binary_info("out/magisk_version.txt")


def update_code():
    os.chdir(LOCALDIR)
    rm_rf("Magisk")
    rm_rf("src")
    if system("git clone --recurse-submodules https://github.com/topjohnwu/Magisk.git Magisk").returncode != 0:
        error("git clone failed!")

    # Generate magisk_config.prop
    magisk_version = cmd_out(
        f"cd Magisk && git rev-parse --short=8 HEAD && cd ..")
    system(
        f"tail -n 4 <Magisk/gradle.properties >magisk_config.prop && echo 'magisk.version={magisk_version}' >>magisk_config.prop")

    # Fix busybox git push missing header file
    system("rm -rf Magisk/native/src/external/busybox/include/.gitignore")

    # Fix path defined
    system("sed -i 's|out/generated|generated|g' Magisk/native/src/base/Android.mk")
    system("sed -i 's|\.\./out/\$(TARGET_ARCH_ABI)|\.\./generated/\$(TARGET_ARCH_ABI)|g' Magisk/native/src/Android-rs.mk")

    mv("Magisk/native/src", "src")
    rm_rf("Magisk")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Magiskboot build and update code script")
    parser.add_argument(
        "--build_binary", action="store_true", help="Build binary")
    parser.add_argument("--update_code",  action="store_true",
                        help="Upadte magisk code")
    args = parser.parse_args()

    if len(sys.argv) < 2:
        parser.print_help()

    if platform.system() == "Windwos":
        error("Windws is not support")

    if args.build_binary:
        if not op.exists(ndk_root):
            setup_ndk()
        build_binary()

    if args.update_code:
        update_code()
