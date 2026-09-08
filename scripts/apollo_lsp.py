#!/usr/bin/env python3
"""Export Apollo's evaluated make configuration without compiling or linking."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

if sys.platform == 'win32':
    if sys.stdout is not None:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    if sys.stderr is not None:
        sys.stderr.reconfigure(encoding='utf-8', errors='replace')

EXTENSIONS = {'.c', '.cc', '.cpp', '.cxx', '.m', '.mm'}


def run(args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          errors='replace', timeout=90, **kwargs).stdout


def read_json(path):
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n', encoding='utf-8')
    temporary.replace(path)


def profile_ready(root, profile):
    directory = root / '.cache/lsp' / profile
    status = directory / 'status.json'
    return (directory / 'compile_commands.json').is_file() and status.is_file() and read_json(status).get('ready', False)


def config_options(root, platform):
    base = root / 'config_base.ini'
    if not base.exists():
        base = root / 'config.ini'
        print('Using legacy config.ini defaults (config_base.ini is absent).')
    settings = read_json(base)['pack_info']['settings']
    settings.update(read_json(root / ('config_' + platform + '.ini'))['pack_info']['settings'])
    settings['online_build'] = 'false'
    settings['platform'] = platform
    spec = importlib.util.spec_from_file_location('apollo_defines', root / 'build_tools/convert_build_options_to_defines.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    options = []
    for key, value in settings.items():
        option = module.param2define(key, str(value))
        if option:
            options.append(option)
    return options


def toolchain(root, platform, arch):
    core = root / 'core/u3player_core/build_tools'
    scripts = {'mac': ('MacConfig.sh', 'mac_init_env'), 'ios': ('iOSConfig.sh', 'ios_init_env'),
               'android': ('AndroidConfig.sh', 'android_init_env'), 'ohos': ('OhosConfig.sh', 'ohos_init_env')}
    filename, function = scripts[platform]
    env = os.environ.copy()
    ndk = Path(env.get('ANDROID_NDK', '/nonexistent'))
    if platform == 'android' and not list(ndk.glob('toolchains/llvm/prebuilt/*/bin/aarch64-linux-android21-clang')):
        ndks = list((Path.home() / 'Library/Android/sdk/ndk').glob('*'))
        if not ndks:
            raise RuntimeError('Set ANDROID_NDK to the installed Android NDK.')
        ndks.sort(key=lambda p: tuple(int(x) for x in p.name.split('.')))
        env['ANDROID_NDK'] = str(ndks[-1])
        print('Using installed NDK: ' + env['ANDROID_NDK'])
    # These existing functions only select compiler paths and flags; no build pipeline is sourced.
    command = 'source "$1"; "$2" "$3"; printf "\\nLSP_CC=%s\\nLSP_CXX=%s\\nLSP_FLAGS=%s\\nLSP_SYSROOT=%s\\n" "$CC" "$CXX" "$CPU_FLAGS $CFLAGS" "$SYSROOT"'
    output = run(['bash', '-c', command, 'apollo-lsp', str(core / filename), function, arch], env=env)
    values = dict(line.split('=', 1) for line in output.splitlines() if line.startswith('LSP_'))
    cc, cxx = shlex.split(values['LSP_CC']), shlex.split(values['LSP_CXX'])
    flags = shlex.split(values['LSP_FLAGS'])
    if platform in ('mac', 'ios'):
        sdk = 'macosx' if platform == 'mac' else ('iphonesimulator' if arch == 'x86_64' else 'iphoneos')
        for compiler, name in ((cc, 'clang'), (cxx, 'clang++')):
            if compiler[0] == 'xcrun':
                del compiler[:4]
            else:
                del compiler[:1]
            compiler.insert(0, run(['xcrun', '--sdk', sdk, '--find', name]).strip())
        flags += ['-isysroot', run(['xcrun', '--sdk', sdk, '--show-sdk-path']).strip()]
    if not Path(cc[0]).is_file() or not Path(cxx[0]).is_file():
        raise RuntimeError('Compiler not found: ' + shlex.join(cc))
    return cc, cxx, flags


def export_make(root, platform, arch):
    cc, cxx, flags = toolchain(root, platform, arch)
    options = config_options(root, platform)
    flags += ['-D' + p for p in options if ' ' not in p and '"' not in p]
    env = dict(os.environ, CFLAGS=shlex.join(flags))
    command = ['make', '-s', '-f', 'sdk-cxx/makefile', '-f', str(Path(__file__).with_suffix('.mk')),
               'apollo_lsp_export', 'PROJECT_ROOT_PATH=' + str(root), 'ARCH=' + arch,
               'TOOLCHAIN=clang', 'CC=' + shlex.join(cc), 'CXX=' + shlex.join(cxx), 'DEPENDS=']
    modern = root / 'core/u3player_core/build_tools/utils_compiler_flags.sh'
    if not modern.exists():
        legacy = root / 'core/u3player_core/build_tools/compile_utils.sh'
        if not legacy.exists():
            raise RuntimeError('Neither compiler flag filter is available in the core checkout.')
        command.append('flags_filter=$(shell source $(PROJECT_ROOT_PATH)/core/u3player_core/build_tools/compile_utils.sh && $$flags_filter $(1))')
        print('Using legacy core compile_utils.sh for the renamed makefile dependency.')
    command += options
    output = run(command, cwd=root, env=env)
    directory = root / '.cache/lsp' / (platform + '-' + arch)
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'make-export.log').write_text(output, encoding='utf-8')
    values, overrides = {}, {}
    for line in output.splitlines():
        if not line.startswith('APOLLO_LSP_'):
            continue
        key, value = line[len('APOLLO_LSP_'):].split('=', 1)
        if key == 'OVERRIDE':
            source, value = value.split('|', 1)
            overrides[source] = shlex.split(value)
        else:
            values[key] = value
    entries = []
    for source in dict.fromkeys(shlex.split(values['SOURCES'])):
        extension = Path(source).suffix
        if extension not in EXTENSIONS:
            continue
        cpp = extension in {'.cc', '.cpp', '.cxx', '.mm'}
        arguments = shlex.split(values['CXX' if cpp else 'CC'])
        arguments += overrides.get(source, []) + shlex.split(values['CXXFLAGS' if cpp else 'CFLAGS'])
        if extension in {'.m', '.mm'}:
            arguments += ['-fobjc-arc']
        path = (root / source).resolve()
        if not path.is_file():
            raise RuntimeError('Build references missing source: ' + str(path))
        entries.append({'directory': str(root), 'file': str(path), 'arguments': arguments + ['-c', str(path)]})
    if not entries:
        raise RuntimeError('The makefile exported no translation units.')
    write_json(directory / 'compile_commands.json', entries)
    print(str(directory) + ': ' + str(len(entries)) + ' build-derived commands')
    return directory


def export_xcode(root):
    project = root / 'sdk-ios/u3playersdk/u3playersdk.xcodeproj'
    targets = json.loads(run(['xcodebuild', '-project', str(project), '-configuration', 'Debug',
                              '-sdk', 'iphoneos', '-showBuildSettings', '-json'], cwd=root))
    data = json.loads(run(['plutil', '-convert', 'json', '-o', '-', str(project / 'project.pbxproj')]))
    objects = data['objects']
    source_root = project.parent
    paths = {}

    def visit(identifier, parent):
        obj = objects[identifier]
        tree = obj.get('sourceTree', '<group>')
        if tree == 'SOURCE_ROOT':
            parent = source_root
        elif tree not in ('<group>', '<absolute>'):
            return
        path = (parent / obj.get('path', '')).resolve()
        paths[identifier] = path
        for child in obj.get('children', []):
            visit(child, path)

    visit(objects[data['rootObject']]['mainGroup'], source_root)
    entries = []
    for target in targets:
        settings = target['buildSettings']
        flags = ['-arch', 'arm64', '-isysroot', settings['SDKROOT'],
                 '-miphoneos-version-min=' + settings['IPHONEOS_DEPLOYMENT_TARGET']]
        flags += ['-D' + value for value in shlex.split(settings.get('GCC_PREPROCESSOR_DEFINITIONS', ''))]
        for key, prefix in [('HEADER_SEARCH_PATHS', '-I'), ('USER_HEADER_SEARCH_PATHS', '-iquote'),
                            ('FRAMEWORK_SEARCH_PATHS', '-F')]:
            for value in shlex.split(settings.get(key, '')):
                path = (source_root / value.removesuffix('/**')).resolve()
                paths_to_add = [path]
                if value.endswith('/**') and path.is_dir():
                    paths_to_add += sorted(p for p in path.rglob('*') if p.is_dir())
                for include in paths_to_add:
                    flags += [prefix, str(include)]
        if settings.get('CLANG_ENABLE_MODULES') == 'YES':
            flags += ['-fmodules']
        compiler = run(['xcrun', '--sdk', 'iphoneos', '--find', 'clang++']).strip()
        native_target = next(o for o in objects.values() if o.get('isa') == 'PBXNativeTarget' and o['name'] == target['target'])
        for phase_id in native_target['buildPhases']:
            phase = objects[phase_id]
            if phase['isa'] != 'PBXSourcesBuildPhase':
                continue
            for build_id in phase['files']:
                build = objects[build_id]
                path = paths.get(build.get('fileRef'))
                if not path or path.suffix not in EXTENSIONS:
                    continue
                if not path.is_file():
                    print('Xcode references missing source: ' + str(path))
                    continue
                cpp = path.suffix in {'.cc', '.cpp', '.cxx', '.mm'}
                language = {'.m': 'objective-c', '.mm': 'objective-c++'}.get(path.suffix, 'c++' if cpp else 'c')
                arguments = [compiler, '-x', language] + flags
                if cpp:
                    arguments += ['-std=' + settings.get('CLANG_CXX_LANGUAGE_STANDARD', 'c++17')]
                if settings.get('CLANG_ENABLE_OBJC_ARC') == 'YES' and path.suffix in {'.m', '.mm'}:
                    arguments += ['-fobjc-arc']
                arguments += shlex.split(settings.get('OTHER_CPLUSPLUSFLAGS' if cpp else 'OTHER_CFLAGS', ''))
                arguments += shlex.split(build.get('settings', {}).get('COMPILER_FLAGS', ''))
                entries.append({'directory': str(source_root), 'file': str(path), 'arguments': arguments + ['-c', str(path)]})
    directory = root / '.cache/lsp/ios-sdk'
    write_json(directory / 'compile_commands.json', entries)
    write_json(directory / 'build-settings.json', targets)
    print(str(directory) + ': ' + str(len(entries)) + ' Xcode target commands')


def export_android(root, arch):
    cc, _, _ = toolchain(root, 'android', arch)
    ndk = Path(cc[0]).parents[5]
    directory = root / '.cache/lsp' / ('android-' + arch)
    directory.mkdir(parents=True, exist_ok=True)
    database = directory / 'compile_commands.json'
    command = [str(ndk / 'ndk-build'), str(database),
               'NDK_PROJECT_PATH=' + str(root / 'sdk-android/ApolloSDK'),
               'APP_BUILD_SCRIPT=' + str(root / 'sdk-android/ApolloSDK/jni/Android.mk'),
               'NDK_APPLICATION_MK=' + str(root / 'sdk-android/ApolloSDK/jni/Application.mk'),
               'APP_ABI=' + ('arm64-v8a' if arch == 'arm64' else arch), 'APP_PLATFORM=android-21',
               'NDK_TOOLCHAIN_VERSION=clang', 'NDK_DEBUG=1', 'NDK_OUT=' + str(directory / 'obj'),
               'NDK_LIBS_OUT=' + str(directory / 'libs'), 'COMPILE_COMMANDS_JSON=' + str(database)]
    output = run(command + config_options(root, 'android'), cwd=root)
    (directory / 'ndk-export.log').write_text(output, encoding='utf-8')
    entries = read_json(database)
    for entry in entries:
        entry['file'] = str((Path(entry['directory']) / entry['file']).resolve())
    write_json(database, entries)
    print('Android NDK database: ' + str(len(entries)) + ' commands')


def export_ohos(root, arch):
    cc, _, _ = toolchain(root, 'ohos', arch)
    native = Path(cc[0]).parents[2]
    directory = root / '.cache/lsp' / ('ohos-' + arch)
    options = config_options(root, 'ohos')
    command = ['cmake', '-S', str(root / 'sdk-ohos/u3player/src/main/cpp'), '-B', str(directory),
               '-DCMAKE_TOOLCHAIN_FILE=' + str(native / 'build/cmake/ohos.toolchain.cmake'),
               '-DOHOS_ARCH=' + ('arm64-v8a' if arch == 'arm64' else arch), '-DOHOS_PLATFORM=OHOS',
               '-DUSE_DEFAULT_MARCO=0', '-DBUILD_TYPE=debug', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON']
    output = run(command + ['-D' + option for option in options], cwd=root)
    (directory / 'cmake-export.log').write_text(output, encoding='utf-8')
    print('OHOS CMake database: ' + str(len(read_json(directory / 'compile_commands.json'))) + ' commands')


def export_tests(root):
    source = root / '.cache/lsp/tests-source'
    source.mkdir(parents=True, exist_ok=True)
    # Do not fabricate absent test stubs or production files to make an incomplete checkout build.
    exclusions = {
        'platform/common/gl/GLFilterHelper': 'unittest/native/stubs/VideoFilterManager_stub.cpp',
        'engine/ApolloSettings': 'unittest/native/stubs/VideoFilterManager_stub.cpp',
        'engine/asr/WebSocketASRService': 'native/engine/src/asr/WebSocketASRService.cpp',
    }
    excluded = {directory: missing for directory, missing in exclusions.items() if not (root / missing).is_file()}
    lines = ['cmake_minimum_required(VERSION 3.20)', 'project(apollo_lsp_tests LANGUAGES C CXX OBJCXX)',
             'function(add_subdirectory path)',
             '  get_filename_component(absolute "${path}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")']
    for directory in excluded:
        lines += ['  if(absolute STREQUAL "' + str(root / 'unittest/native' / directory) + '")',
                  '    message(STATUS "LSP export: skipping incomplete test directory ' + directory + '")',
                  '    return()', '  endif()']
    lines += ['  _add_subdirectory(${ARGV})', 'endfunction()',
              'add_subdirectory("' + str(root / 'unittest/native') + '" native)']
    (source / 'CMakeLists.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    directory = root / '.cache/lsp/tests'
    env = os.environ.copy()
    if sys.platform == 'darwin' and not env.get('HOMEBREW_CELLAR'):
        env['HOMEBREW_CELLAR'] = run(['brew', '--cellar']).strip()
    output = run(['cmake', '-S', str(source), '-B', str(directory), '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON'], env=env)
    (directory / 'configure.log').write_text(output, encoding='utf-8')
    write_json(directory / 'excluded-targets.json', excluded)
    print('Test database: ' + str(len(read_json(directory / 'compile_commands.json'))) + ' commands')
    for target, missing in excluded.items():
        print('Incomplete test target excluded: ' + target + ' (missing ' + missing + ')')


def activate(root, profile):
    if not profile_ready(root, profile):
        raise RuntimeError('Generate profile first: ' + profile)
    path = root / '.clangd'
    marker = '# Generated by apollo_lsp.py'
    if path.exists() and not path.read_text(encoding='utf-8').startswith(marker):
        raise RuntimeError('Existing .clangd is not managed by this exporter; merge it manually.')
    text = marker + '\nCompileFlags:\n  CompilationDatabase: .cache/lsp/' + profile + '\n'
    routes = {
        'sdk-cxx/cxx_demo_source/gui/.*': 'sdk-cxx/cxx_demo_source/gui/build',
        'unittest/.*': '.cache/lsp/tests',
        'sdk-ios/u3playersdk/.*': '.cache/lsp/ios-sdk',
        'sdk-android/.*': '.cache/lsp/android-arm64',
    }
    for platform in ('mac', 'ios', 'android', 'ohos'):
        directory = '.cache/lsp/' + platform + '-arm64'
        if profile_ready(root, platform + '-arm64'):
            routes['native/platform/' + platform + '/.*'] = directory
    for pattern, directory in routes.items():
        if (root / directory / 'compile_commands.json').is_file():
            text += '\n---\nIf:\n  PathMatch: ' + pattern + '\nCompileFlags:\n  CompilationDatabase: ' + directory + '\n'
    path.write_text(text, encoding='utf-8')
    print('Active shared-code profile: ' + profile)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('project', type=Path)
    parser.add_argument('--platform', choices=['mac', 'ios', 'android', 'ohos'], default='mac')
    parser.add_argument('--arch', choices=['arm64', 'x86_64'], default='arm64')
    parser.add_argument('--activate', action='store_true')
    parser.add_argument('--activate-only', action='store_true')
    parser.add_argument('--xcode', action='store_true', help='Also export the iOS SDK target settings and source list')
    parser.add_argument('--tests', action='store_true', help='Export existing unit-test targets in an isolated CMake directory')
    args = parser.parse_args()
    root = args.project.expanduser().resolve()
    if not (root / 'native/engine/inc').is_dir():
        parser.error('Not an Apollo checkout: ' + str(root))
    if not args.activate_only:
        status = root / '.cache/lsp' / (args.platform + '-' + args.arch) / 'status.json'
        write_json(status, {'ready': False})
        try:
            if args.platform == 'android':
                export_android(root, args.arch)
            elif args.platform == 'ohos':
                export_ohos(root, args.arch)
            else:
                export_make(root, args.platform, args.arch)
        except (RuntimeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
            write_json(status, {'ready': False, 'error': getattr(error, 'stderr', None) or str(error)})
            raise
        write_json(status, {'ready': True})
    if args.xcode:
        export_xcode(root)
    if args.tests:
        export_tests(root)
    if args.activate or args.activate_only:
        activate(root, args.platform + '-' + args.arch)


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        if isinstance(error, subprocess.CalledProcessError):
            print('Export failed: ' + str(error.cmd[0]), file=sys.stderr)
            print(error.stderr[-5000:], file=sys.stderr)
        else:
            print(str(error), file=sys.stderr)
        sys.exit(1)
