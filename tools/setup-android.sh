#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tool_root=${CORRIDOR12_TOOL_ROOT:-"$repo_root/.tools"}
sdk_root="$tool_root/android-sdk"
java_binary=$(readlink -f "$(command -v java)")
java_root=$(dirname -- "$(dirname -- "$java_binary")")
mkdir -p "$tool_root/downloads" "$sdk_root" "$tool_root/config/godot"

# Official checksums from Google's repository2-1.xml package metadata.
fetch_sdk() {
    local name=$1 checksum=$2 archive="$tool_root/downloads/$1"
    if [[ ! -f "$archive" ]]; then
        curl --fail --silent --show-error --location --retry 2 \
            "https://dl.google.com/android/repository/$name" --output "$archive.part"
        printf '%s  %s\n' "$checksum" "$archive.part" | sha1sum --check --status
        mv -- "$archive.part" "$archive"
    fi
    printf '%s  %s\n' "$checksum" "$archive" | sha1sum --check --status
}
fetch_sdk build-tools_r35.0.1_linux.zip e009a9b188cfeb1d2b4c318ab5cb4f1ddc368861
fetch_sdk platform-tools_r37.0.1-linux.zip 477254aa5f903c15cf51001717bdf347fb6b53e0

python3 - "$tool_root" "$java_root" <<'PY'
from pathlib import Path
from zipfile import ZipFile
import json, re, sys
root, java = Path(sys.argv[1]).resolve(), sys.argv[2]
sdk = root / 'android-sdk'
for name, prefix, destination in [
    ('build-tools_r35.0.1_linux.zip', 'android-15/', sdk / 'build-tools' / '35.0.1'),
    ('platform-tools_r37.0.1-linux.zip', 'platform-tools/', sdk / 'platform-tools'),
]:
    with ZipFile(root / 'downloads' / name) as archive:
        for entry in archive.infolist():
            if entry.is_dir() or not entry.filename.startswith(prefix):
                continue
            path = destination / entry.filename[len(prefix):]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(archive.read(entry))
            mode = (entry.external_attr >> 16) & 0o777
            if mode:
                path.chmod(mode)
settings = root / 'config' / 'godot' / 'editor_settings-4.6.tres'
text = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
bindings = {
    'export/android/java_sdk_path': java,
    'export/android/android_sdk_path': str(sdk),
    'export/android/debug_keystore': str(root / 'android-debug.keystore'),
    'export/android/debug_keystore_user': 'androiddebugkey',
    'export/android/debug_keystore_pass': 'android',
}
for key, value in bindings.items():
    text = re.sub(r'^' + re.escape(key) + r' = .*\n?', '', text, flags=re.M)
    text += f'{key} = {json.dumps(value)}\n'
settings.write_text(text)
PY

# This development key is local and ignored by Git; never use it for a store release.
if [[ ! -f "$tool_root/android-debug.keystore" ]]; then
    "$java_root/bin/keytool" -genkeypair -noprompt -keystore "$tool_root/android-debug.keystore" \
        -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 \
        -validity 10000 -dname "CN=Corridor 12 Development,O=Corridor 12,C=PS"
fi
"$sdk_root/build-tools/35.0.1/apksigner" version
