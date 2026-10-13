#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tool_root=${CORRIDOR12_TOOL_ROOT:-"$repo_root/.tools"}
godot_bin=${GODOT_BIN:-"$tool_root/bin/godot"}
export XDG_DATA_HOME="$tool_root/data"
export XDG_CONFIG_HOME="$tool_root/config"
export XDG_CACHE_HOME="$tool_root/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
cd -- "$repo_root"

run_checked() {
    local log status=0
    log=$(mktemp)
    "$@" > "$log" 2>&1 || status=$?
    cat "$log"
    if (( status != 0 )) || rg -q '^(SCRIPT ERROR:|ERROR:)' "$log"; then
        rm -- "$log"
        return 1
    fi
    rm -- "$log"
}

version=$("$godot_bin" --headless --version)
if [[ "$version" != 4.6.3.stable.* ]]; then
    printf 'Expected Godot 4.6.3.stable; found %s\n' "$version" >&2
    exit 1
fi

mkdir -p build/windows build/linux build/web build/packages
touch build/.gdignore
run_checked "$godot_bin" --headless --path . --editor --quit
run_checked "$godot_bin" --headless --path . --script res://tests/smoke.gd
run_checked "$godot_bin" --headless --path . --quit-after 10
run_checked "$godot_bin" --headless --path . --export-release "Windows Desktop" build/windows/Corridor12.exe
run_checked "$godot_bin" --headless --path . --export-release "Web" build/web/index.html
run_checked "$godot_bin" --headless --path . --export-release "Linux" build/linux/Corridor12.x86_64
chmod +x build/linux/Corridor12.x86_64
run_checked build/linux/Corridor12.x86_64 --headless --quit-after 10

python3 - <<'PY'
from hashlib import sha256
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

build = Path('build')
instructions = {
    'windows': 'Extract this ZIP, then double-click Corridor12.exe. Godot is not required.\n',
    'linux': 'Extract this ZIP, run chmod +x Corridor12.x86_64, then ./Corridor12.x86_64.\n',
    'web': 'Serve this folder over HTTP, for example: python3 -m http.server 8000\nThen open http://localhost:8000 in a WebGL2-capable browser.\nOpening index.html directly as a file will not work.\n',
}
names = {'windows': 'Windows-x64', 'linux': 'Linux-x64', 'web': 'Web'}
checksums = []
for target, name in names.items():
    folder = build / target
    (folder / 'HOW-TO-PLAY.txt').write_text(instructions[target] +
        '\nSelect a district, choose cargo and a route, queue up to two convoys, then simulate the day.\n', encoding='utf-8')
    (folder / 'GODOT-LICENSE.txt').write_bytes(Path('docs/GODOT-LICENSE.txt').read_bytes())
    output = build / 'packages' / f'Corridor12-{name}.zip'
    with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
        for path in sorted(folder.rglob('*')):
            if path.is_file():
                archive.write(path, path.relative_to(folder))
    with ZipFile(output) as archive:
        if archive.testzip() is not None:
            raise RuntimeError(f'Corrupt package: {output}')
    checksums.append(f'{sha256(output.read_bytes()).hexdigest()}  {output.name}')
    print(f'Built {output} ({output.stat().st_size:,} bytes)')
(build / 'packages' / 'SHA256SUMS.txt').write_text('\n'.join(checksums) + '\n')
PY
