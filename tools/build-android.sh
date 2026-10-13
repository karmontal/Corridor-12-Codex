#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tool_root=${CORRIDOR12_TOOL_ROOT:-"$repo_root/.tools"}
godot_bin=${GODOT_BIN:-"$tool_root/bin/godot"}
export XDG_DATA_HOME="$tool_root/data"
export XDG_CONFIG_HOME="$tool_root/config"
export XDG_CACHE_HOME="$tool_root/cache"
cd -- "$repo_root"
mkdir -p build/android build/packages
touch build/.gdignore
log=$(mktemp)
trap 'rm -f -- "$log"' EXIT
for operation in import test export; do
    case "$operation" in
        import) args=(--editor --quit) ;;
        test) args=(--script res://tests/smoke.gd) ;;
        export) args=(--export-debug Android build/android/Corridor12-Android.apk) ;;
    esac
    "$godot_bin" --headless --path . "${args[@]}" > "$log" 2>&1 || { cat "$log"; exit 1; }
    cat "$log"
    if rg -q '^(SCRIPT ERROR:|ERROR:)' "$log"; then exit 1; fi
done
build_tools="$tool_root/android-sdk/build-tools/35.0.1"
"$build_tools/apksigner" verify --verbose build/android/Corridor12-Android.apk
"$build_tools/zipalign" -c -P 16 4 build/android/Corridor12-Android.apk
"$build_tools/aapt" dump badging build/android/Corridor12-Android.apk > build/android/manifest-info.txt
rg "package: name='org.karmontal.corridor12'" build/android/manifest-info.txt
rg "native-code:.*arm64-v8a" build/android/manifest-info.txt
cp build/android/Corridor12-Android.apk build/packages/
python3 - <<'PY'
from hashlib import sha256
from pathlib import Path
package = Path('build/packages/Corridor12-Android.apk')
checksums = package.parent / 'SHA256SUMS.txt'
lines = checksums.read_text().splitlines() if checksums.exists() else []
lines = [line for line in lines if not line.endswith(package.name)]
lines.append(f'{sha256(package.read_bytes()).hexdigest()}  {package.name}')
checksums.write_text('\n'.join(lines) + '\n')
print(f'Built and signature-verified {package} ({package.stat().st_size:,} bytes)')
PY
