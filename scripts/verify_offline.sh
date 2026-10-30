#!/usr/bin/env bash
set -euo pipefail

manifest="app/src/main/AndroidManifest.xml"
app_gradle="app/build.gradle"
native_net="emulator-core/src/main/cpp/xenia/src/xenia/kernel/xam/xam_net.cc"
native_cmake="emulator-core/src/main/cpp/CMakeLists.txt"

fail() {
  echo "OFFLINE POLICY FAILED: $*" >&2
  exit 1
}

if grep -Eq 'android.permission.(INTERNET|ACCESS_NETWORK_STATE)' "$manifest"; then
  fail "Android network permission found"
fi

python3 - "$manifest" <<'PY' || fail "emulator host is externally exported"
import sys
import xml.etree.ElementTree as ET

android = "{http://schemas.android.com/apk/res/android}"
root = ET.parse(sys.argv[1]).getroot()
for activity in root.findall("./application/activity"):
    if activity.get(android + "name") == "xendroid.compose.EmulatorHostActivity":
        if activity.get(android + "exported") != "false":
            raise SystemExit(1)
        break
else:
    raise SystemExit(1)
PY

if grep -Eqi '(retrofit|okhttp|logging-interceptor)' "$app_gradle"; then
  fail "HTTP client dependency found"
fi

if find app/src/main -type f -print0 | xargs -0 grep -Eqi '(checkForUpdates|GithubApi|api.github.com/repos/.*/releases)'; then
  fail "online updater code found"
fi

if grep -Eq 'DEFINE_bool\(network_enabled,[[:space:]]*true' "$native_net"; then
  fail "guest networking defaults to enabled"
fi

if ! grep -Fq 'kNetworkDisabledByBuild = true' "$native_net"; then
  fail "compile-time guest socket block is missing"
fi

if grep -Eq '^[[:space:]]*discord-rpc[[:space:]]*$' "$native_cmake"; then
  fail "Discord RPC is linked into the Android library"
fi

echo "Offline security policy: PASS"

