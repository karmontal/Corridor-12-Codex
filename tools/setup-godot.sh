#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tool_root=${CORRIDOR12_TOOL_ROOT:-"$repo_root/.tools"}
version=4.6.3
release_url="https://github.com/godotengine/godot-builds/releases/download/$version-stable"
export XDG_DATA_HOME="$tool_root/data"
export XDG_CONFIG_HOME="$tool_root/config"
export XDG_CACHE_HOME="$tool_root/cache"
mkdir -p "$tool_root/downloads" "$tool_root/bin" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"

fetch_verified() {
    local name=$1 checksum=$2 archive="$tool_root/downloads/$1"
    if [[ ! -f "$archive" ]]; then
        curl --fail --silent --show-error --location --retry 2 "$release_url/$name" --output "$archive.part"
        printf '%s  %s\n' "$checksum" "$archive.part" | sha512sum --check --status
        mv -- "$archive.part" "$archive"
    fi
    printf '%s  %s\n' "$checksum" "$archive" | sha512sum --check --status
}

# Checksums from the official 4.6.3-stable SHA512-SUMS.txt release asset.
fetch_verified "Godot_v${version}-stable_linux.x86_64.zip" \
    a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c
fetch_verified "Godot_v${version}-stable_export_templates.tpz" \
    da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68

python3 - "$tool_root" "$version" <<'PY'
from pathlib import Path
from zipfile import ZipFile
import sys

root, version = Path(sys.argv[1]), sys.argv[2]
with ZipFile(root / 'downloads' / f'Godot_v{version}-stable_linux.x86_64.zip') as archive:
    binary = root / 'bin' / 'godot'
    binary.write_bytes(archive.read(f'Godot_v{version}-stable_linux.x86_64'))
    binary.chmod(0o755)
destination = root / 'data' / 'godot' / 'export_templates' / f'{version}.stable'
destination.mkdir(parents=True, exist_ok=True)
templates = ['version.txt', 'linux_release.x86_64', 'windows_release_x86_64.exe',
             'windows_release_x86_64_console.exe', 'web_nothreads_release.zip']
with ZipFile(root / 'downloads' / f'Godot_v{version}-stable_export_templates.tpz') as archive:
    for name in templates:
        (destination / name).write_bytes(archive.read(f'templates/{name}'))
print(f'Installed Godot {version} and Windows, Linux, single-threaded Web release templates.')
PY
"$tool_root/bin/godot" --headless --version
