#!/usr/bin/env python3
import errno
import os
import platform
import sys
import os.path as op
import shutil
import stat
import subprocess
import textwrap

LOCALDIR = op.realpath('.')
is_windows = os.name == 'nt'
is_ci = 'CI' in os.environ and os.environ['CI'] == 'true'
newline = '\n' if not is_windows else '\r\n'
os_name = platform.system()
EXE_EXT = '.exe' if is_windows else ''
native_gen_path = op.realpath(op.join(LOCALDIR, 'generated'))
rust_bin = op.join(op.join(LOCALDIR, 'ndk', 'toolchains', 'rust', 'bin'))
cargo = op.join(rust_bin, 'cargo' + EXE_EXT)
release = True

if not is_ci and is_windows:
    import colorama
    colorama.init()

# Global vars
STDOUT = None


def error(str):
    if is_ci:
        print(f'\n ! {str}\n')
    else:
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
    return subprocess.run(cmd, stdout=STDOUT, env=env)


def system(cmd):
    return subprocess.run(cmd, shell=True, stdout=STDOUT)


def cmd_out(cmd, env=None):
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env) \
                     .stdout.strip().decode('utf-8')


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


def dump_flags_header():
    global config
    config = {}
    for key, value in parse_props(op.join(LOCALDIR, 'magisk_config.prop')).items():
        if key.startswith('magisk.'):
            config[key[7:]] = value

    flag_txt = textwrap.dedent('''\
        #pragma once
        #define quote(s)            #s
        #define str(s)              quote(s)
        #define MAGISK_FULL_VER     MAGISK_VERSION "(" str(MAGISK_VER_CODE) ")"
        #define NAME_WITH_VER(name) str(name) " " MAGISK_FULL_VER
        ''')
    flag_txt += f'#define MAGISK_VERSION      "{config["version"]}"\n'
    flag_txt += f'#define MAGISK_VER_CODE     {config["versionCode"]}\n'
    flag_txt += f'#define MAGISK_DEBUG        {0}\n'

    mkdir_p(native_gen_path)
    write_if_diff(op.join(native_gen_path, 'flags.h'), flag_txt)


def dump_rust_header():
    os.chdir(op.join(LOCALDIR, 'src'))
    env = os.environ.copy()
    env['CARGO_BUILD_RUSTC'] = op.join(rust_bin, 'rustc' + EXE_EXT)

    # generate C++ bindings
    local_cargo_root = op.join(LOCALDIR, '.cargo')
    cxxbridge = op.join(local_cargo_root, 'bin', 'cxxbridge' + EXE_EXT)
    mkdir_p(native_gen_path)
    for p in ['base', 'boot', 'core', 'init', 'sepolicy']:
        text = cmd_out([cxxbridge, op.join(p, 'lib.rs')])
        write_if_diff(op.join(native_gen_path, f'{p}-rs.cpp'), text)
        text = cmd_out([cxxbridge, '--header', op.join(p, 'lib.rs')])
        write_if_diff(op.join(native_gen_path, f'{p}-rs.hpp'), text)

    os.chdir(LOCALDIR)


def gen_prebuilt_rust_libs():
    archs = ['armeabi-v7a', 'x86', 'arm64-v8a', 'x86_64']
    triples = ['armv7a-linux-androideabi', 'i686-linux-android',
               'aarch64-linux-android', 'x86_64-linux-android']

    os.chdir(op.join(LOCALDIR, 'src'))
    env = os.environ.copy()
    env['CARGO_BUILD_RUSTC'] = op.join(rust_bin, 'rustc' + EXE_EXT)
    rust_targets = ['magisk', 'magiskinit', 'magiskboot', 'magiskpolicy']
    targets = set(rust_targets)

    # Start building the actual build commands
    cmds = [cargo, 'build', '-Z', 'build-std=std,panic_abort',
            '-Z', 'build-std-features=panic_immediate_abort']
    for target in targets:
        cmds.append('-p')
        cmds.append(target)
    if release:
        cmds.append('-r')
        rust_out = 'release'

    os_name = platform.system().lower()
    llvm_bin = op.join(LOCALDIR, 'ndk', 'toolchains', 'llvm',
                       'prebuilt', f'{os_name}-x86_64', 'bin')
    env['TARGET_CC'] = op.join(llvm_bin, 'clang' + EXE_EXT)
    env['RUSTFLAGS'] = '-Clinker-plugin-lto'
    for (arch, triple) in zip(archs, triples):
        env['TARGET_CFLAGS'] = f'--target={triple}23'
        rust_triple = 'thumbv7neon-linux-androideabi' if triple.startswith(
            'armv7') else triple
        rm_rf('target')
        proc = execv([*cmds, '--target', rust_triple], env)
        if proc.returncode != 0:
            error('Build binary failed!')

        arch_out = op.join(LOCALDIR, 'src', 'prebuilt_libs', arch)
        rm_rf(arch_out)
        mkdir_p(arch_out)
        for tgt in targets:
            source = op.join('target', rust_triple, rust_out, f'lib{tgt}.a')
            target = op.join(arch_out, f'lib{tgt}-rs.a')
            mv(source, target)

    os.chdir(LOCALDIR)


def usage():
    print('''\
            %s [args]
            args:
                dump_flags_header
                dump_rust_header
                gen_prebuilt_rust_libs
        ''' % __file__)
    sys.exit(1)


if __name__ == '__main__':
    args = sys.argv
    if len(args) != 2:
        usage()
    if args[1] == "dump_flags_header":
        dump_flags_header()
    elif args[1] == "dump_rust_header":
        dump_rust_header()
    elif args[1] == "gen_prebuilt_rust_libs":
        gen_prebuilt_rust_libs()
    else:
        usage()
