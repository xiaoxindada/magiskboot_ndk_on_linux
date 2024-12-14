#!/usr/bin/env python3
import argparse
import errno
import lzma
import multiprocessing
import os
from pathlib import Path
import platform
import sys
import os.path as op
import shutil
import stat
import subprocess
import tarfile
import textwrap
import wget

# Environment checks
if not sys.version_info >= (3, 8):
    error("Requires Python 3.8+")


def parse_props(file):
    props = {}
    with open(file, "r") as f:
        for line in [l.strip(" \t\r\n") for l in f]:
            if line.startswith("#") or len(line) == 0:
                continue
            prop = line.split("=")
            if len(prop) != 2:
                continue
            value = prop[1].strip(" \t\r\n")
            if len(value) == 0:
                continue
            props[prop[0].strip(" \t\r\n")] = value
    return props


def load_config():
    for key, value in parse_props("magisk_config.prop").items():
        if key.startswith("magisk."):
            config[key[7:]] = value


def error(str):
    print(f"\n\033[41m{str}\033[0m\n")
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


def cmd_out(cmd):
    return (
        subprocess.run(
            cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
        )
        .stdout.strip()
        .decode("utf-8")
    )


LOCALDIR = op.realpath(".")
cpu_count = multiprocessing.cpu_count()
os_name = "linux"
release = True

# Common constants
support_abis = {
    "armeabi-v7a": "thumbv7neon-linux-androideabi",
    "x86": "i686-linux-android",
    "arm64-v8a": "aarch64-linux-android",
    "x86_64": "x86_64-linux-android",
    "riscv64": "riscv64-linux-android",
}

# Environment checks and detection
is_windows = os.name == "nt"
EXE_EXT = ".exe" if is_windows else ""

default_targets = {"magiskboot"}
rust_targets = {"magiskboot"}
support_targets = default_targets

# Common paths
ndk_root = Path(LOCALDIR, "ndk")
native_out = Path(LOCALDIR, "out")
ndk_build = ndk_root / "ndk-build"
rust_bin = ndk_root / "toolchains" / "rust" / "bin"
llvm_bin = ndk_root / "toolchains" / "llvm" / "prebuilt" / f"{os_name}-x86_64" / "bin"
cargo = rust_bin / "cargo"
native_gen_path = native_out / "generated"
rust_out = native_out / "rust"

# Global vars
config = {}
archs = {"armeabi-v7a", "x86", "arm64-v8a", "x86_64"}
triples = map(support_abis.get, archs)
build_abis = dict(zip(archs, triples))

load_config()

def cp_output(source, target):
    system(f"cp -af {source} {target}")


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


def write_if_diff(file_name, text):
    rm(file_name)
    do_write = True
    if op.exists(file_name):
        with open(file_name, "r") as f:
            orig = f.read()
        do_write = orig != text
    if do_write:
        with open(file_name, "w") as f:
            print("Write %s" % file_name)
            f.write(text)


def dump_flag_header():
    flag_txt = textwrap.dedent(
        """\
        #pragma once
        #define quote(s)            #s
        #define str(s)              quote(s)
        #define MAGISK_FULL_VER     MAGISK_VERSION "(" str(MAGISK_VER_CODE) ")"
        #define NAME_WITH_VER(name) str(name) " " MAGISK_FULL_VER
        """
    )
    flag_txt += f'#define MAGISK_VERSION      "{config["version"]}"\n'
    flag_txt += f'#define MAGISK_VER_CODE     {config["versionCode"]}\n'
    flag_txt += f"#define MAGISK_DEBUG        {0 if release else 1}\n"

    mkdir_p(native_gen_path)
    write_if_diff(op.join(native_gen_path, "flags.h"), flag_txt)


def build_native():
    targets = support_targets
    print("* Building: " + " ".join(targets))

    if sccache := shutil.which("sccache"):
        os.environ["RUSTC_WRAPPER"] = sccache
        os.environ["NDK_CCACHE"] = sccache
        os.environ["CARGO_INCREMENTAL"] = "0"
    if ccache := shutil.which("ccache"):
        os.environ["NDK_CCACHE"] = ccache

    build_rust_src(targets)
    build_cpp_src(targets)


def run_cargo(cmds, triple="aarch64-linux-android"):
    llvm_bin = op.join(
        ndk_root, "toolchains", "llvm", "prebuilt", f"{os_name}-x86_64", "bin"
    )
    env = os.environ.copy()
    env["PATH"] = f'{rust_bin}{os.pathsep}{env["PATH"]}'
    env["CARGO_BUILD_RUSTC"] = op.join(rust_bin, "rustc" + EXE_EXT)
    env["RUSTFLAGS"] = "-Clinker-plugin-lto"
    env["TARGET_CC"] = op.join(llvm_bin, "clang" + EXE_EXT)
    env["TARGET_CFLAGS"] = f"--target={triple}23"
    return execv([cargo, *cmds], env)

def build_rust_src(targets: set):
    targets = targets.copy()
    if "resetprop" in targets:
        targets.add("magisk")
    targets = targets & rust_targets

    os.chdir(Path(LOCALDIR, "src"))

    # Start building the build commands
    cmds = ["build", "-p", ""]
    if release:
        cmds.append("-r")
        profile = "release"
    else:
        profile = "debug"

    for triple in build_abis.values():
        cmds.append("--target")
        cmds.append(triple)

    for tgt in targets:
        cmds[2] = tgt
        proc = run_cargo(cmds)
        if proc.returncode != 0:
            error("Build binary failed!")

    os.chdir(Path(LOCALDIR))

    for arch, triple in build_abis.items():
        arch_out = native_out / arch
        arch_out.mkdir(mode=0o755, exist_ok=True)
        for tgt in targets:
            source = rust_out / triple / profile / f"lib{tgt}.a"
            target = arch_out / f"lib{tgt}-rs.a"
            mv(source, target)


def build_cpp_src(targets: set):
    dump_flag_header()

    cmds = []
    clean = False

    if "magisk" in targets:
        cmds.append("B_MAGISK=1")
        clean = True

    if "magiskpolicy" in targets:
        cmds.append("B_POLICY=1")
        clean = True

    if "magiskinit" in targets:
        cmds.append("B_PRELOAD=1")

    if "resetprop" in targets:
        cmds.append("B_PROP=1")

    if cmds:
        run_ndk_build(cmds)

    cmds.clear()

    if "magiskinit" in targets:
        cmds.append("B_INIT=1")

    if "magiskboot" in targets:
        cmds.append("B_BOOT=1")

    if cmds:
        cmds.append("B_CRT0=1")
        run_ndk_build(cmds)

    if clean:
        pass


def run_cargo_build():
    targets = set(rust_targets)

    if len(targets) == 0:
        return

    # Start building the actual build commands
    cmds = ["build", "-p", ""]
    if release:
        profile = "release"
    else:
        profile = "debug"

    for triple in build_abis.values():
        cmds.append("--target")
        cmds.append(triple)

    for arch, triple in zip(archs, triples):
        rust_triple = (
            "thumbv7neon-linux-androideabi" if triple.startswith("armv7") else triple
        )
        cmds[-1] = rust_triple

        for target in targets:
            cmds[2] = target
            proc = run_cargo(cmds, triple)
            if proc.returncode != 0:
                error("Build binary failed!")

        arch_out = op.join(native_gen_path, arch)
        mkdir_p(arch_out)
        for tgt in targets:
            source = rust_out / triple / profile / f"lib{tgt}.a"
            target = op.join(arch_out, f"lib{tgt}-rs.a")
            mv(source, target)


def setup_ndk():
    ndk_ver = config["ondkVersion"]
    url = f"https://github.com/topjohnwu/ondk/releases/download/{config['ondkVersion']}/ondk-{config['ondkVersion']}-{os_name}.tar.xz"
    ndk_archive = url.split("/")[-1]
    ondk_path = Path(LOCALDIR, f"ondk-{ndk_ver}")

    if not os.path.isfile(ndk_archive):
        print(f"Downloading {ndk_archive}")
        wget.download(url, ndk_archive)
    print(f"Extracting {ndk_archive}")
    with tarfile.open(ndk_archive, mode="r|xz") as tar:
        tar.extractall(LOCALDIR)
    if op.exists(ondk_path):
        rm_rf(ndk_root)
        mv(ondk_path, ndk_root)


def run_ndk_build(cmds: list):
    os.chdir(Path(LOCALDIR))
    cmds.append("NDK_PROJECT_PATH=.")
    cmds.append("NDK_APPLICATION_MK=src/Application.mk")
    cmds.append(f"APP_ABI={' '.join(build_abis.keys())}")
    cmds.append(f"-j{cpu_count}")
    if not release:
        cmds.append("MAGISK_DEBUG=1")
    proc = execv([ndk_build, *cmds])
    if proc.returncode != 0:
        error("Build binary failed!")
    move_gen_bins()


def move_gen_bins():
    for arch in build_abis.keys():
        arch_dir = Path(LOCALDIR, "libs", arch)
        out_dir = Path(LOCALDIR, "out", arch)
        for source in arch_dir.iterdir():
            target = out_dir / source.name
            mv(source, target)
            rm(Path(out_dir, f"lib{source.name}-rs.a"))

    rm_rf(rust_out)
    rm_rf(native_gen_path)
    
    with open(Path(native_out, "magisk_version.txt"), "w") as f:
        f.write(f"magisk.versionCode={config['versionCode']}\n")
    

def build_cpp_src(targets: set):
    dump_flag_header()

    cmds = []
    clean = False

    if "magisk" in targets:
        cmds.append("B_MAGISK=1")
        clean = True

    if "magiskpolicy" in targets:
        cmds.append("B_POLICY=1")
        clean = True

    if "magiskinit" in targets:
        cmds.append("B_PRELOAD=1")

    if "resetprop" in targets:
        cmds.append("B_PROP=1")

    if cmds:
        run_ndk_build(cmds)

    cmds.clear()

    if "magiskinit" in targets:
        cmds.append("B_INIT=1")

    if "magiskboot" in targets:
        cmds.append("B_BOOT=1")

    if cmds:
        cmds.append("B_CRT0=1")
        run_ndk_build(cmds)

    if clean:
        pass


def run_cargo(cmds):
    env = os.environ.copy()
    env["PATH"] = f'{rust_bin}{os.pathsep}{env["PATH"]}'
    env["CARGO_BUILD_RUSTC"] = str(rust_bin / f"rustc{EXE_EXT}")
    env["CARGO_BUILD_RUSTFLAGS"] = f"-Z threads={cpu_count}"
    return execv([cargo, *cmds], env)


def update_code():
    os.chdir(LOCALDIR)
    rm_rf("Magisk")
    rm_rf("src")
    if (
        system(
            "git clone --recurse-submodules https://github.com/topjohnwu/Magisk.git Magisk"
        ).returncode
        != 0
    ):
        error("git clone failed!")

    # Generate magisk_config.prop
    magisk_version = cmd_out(f"cd Magisk && git rev-parse --short=8 HEAD && cd ..")
    system(
        f"tail -n 4 <Magisk/gradle.properties >magisk_config.prop && echo 'magisk.version={magisk_version}' >>magisk_config.prop"
    )

    # Fix path defined
    system(
        r"sed -i 's|\.\./\.\./\.\./tools/keys/|\.\./\.\./tools/keys/|g' Magisk/native/src/boot/sign.rs"
    )

    mv("Magisk/native/src", "src")
    rm_rf("Magisk")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Magiskboot build and update code script"
    )
    parser.add_argument("--build_binary", action="store_true", help="Build binary")
    parser.add_argument("--update_code", action="store_true", help="Upadte magisk code")
    args = parser.parse_args()

    if len(sys.argv) < 2:
        parser.print_help()

    if is_windows:
        error("Windws is not support")

    if args.build_binary:
        if not op.exists(ndk_root):
            setup_ndk()
        build_native()

    if args.update_code:
        update_code()
