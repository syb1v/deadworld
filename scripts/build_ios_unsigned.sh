#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
	echo "iOS export requires macOS + Xcode." >&2
	echo "Use GitHub Actions -> iOS Build, or run make ios on macOS." >&2
	exit 1
fi

for command in godot xcodebuild xcrun plutil lipo zip unzip file python3 codesign shasum; do
	command -v "${command}" >/dev/null || { echo "Missing required command: ${command}" >&2; exit 1; }
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${ROOT}/build/ios-xcode"
DERIVED_DATA="${ROOT}/build/ios-derived"
DIST="${ROOT}/dist"
RELEASE_TAG="$(python3 "${ROOT}/scripts/version.py" print --field tag)"
BUILD_NUMBER="$(python3 "${ROOT}/scripts/version.py" print --field build)"
IPA_NAME="deadworld-${RELEASE_TAG}-ios-arm64-unsigned.ipa"
IPA="${DIST}/${IPA_NAME}"
PROJECT_ZIP="${DIST}/deadworld-${RELEASE_TAG}-ios-xcode-project.zip"
CHECKSUM="${IPA}.sha256"

python3 "${ROOT}/scripts/version.py" check

rm -rf "${BUILD_ROOT}" "${DERIVED_DATA}" "${IPA}" "${PROJECT_ZIP}" "${CHECKSUM}"
mkdir -p "${BUILD_ROOT}" "${DIST}"

godot --version
xcodebuild -version
xcode-select -p
xcrun --sdk iphoneos --show-sdk-path

godot --headless --path "${ROOT}/client" --export-release "iOS Unsigned" "${BUILD_ROOT}/Deadworld"

PROJECT="$(python3 - "${BUILD_ROOT}" <<'PY'
import pathlib, sys
print(next(iter(pathlib.Path(sys.argv[1]).glob("**/*.xcodeproj")), ""))
PY
)"
[[ -n "${PROJECT}" ]] || { echo "Godot did not generate an Xcode project" >&2; exit 1; }
python3 - "${BUILD_ROOT}" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
if not any(root.glob("**/*Info.plist")):
    raise SystemExit("Generated Info.plist is missing")
if not any(next(root.glob(pattern), None) for pattern in ("**/*.pck", "**/*.xcframework", "**/*.a")):
    raise SystemExit("Generated Godot game data/framework is missing")
PY

xcodebuild -list -project "${PROJECT}"
SCHEME="$(xcodebuild -list -json -project "${PROJECT}" | python3 -c 'import json,sys; data=json.load(sys.stdin); schemes=data.get("project",{}).get("schemes",[]); print(schemes[0] if schemes else "")')"
[[ -n "${SCHEME}" ]] || { echo "No shared Xcode scheme found" >&2; exit 1; }

xcodebuild \
	-project "${PROJECT}" \
	-scheme "${SCHEME}" \
	-configuration Release \
	-sdk iphoneos \
	-arch arm64 \
	-derivedDataPath "${DERIVED_DATA}" \
	CODE_SIGNING_ALLOWED=NO \
	CODE_SIGNING_REQUIRED=NO \
	CODE_SIGN_IDENTITY="" \
	DEVELOPMENT_TEAM="" \
	build

APP="$(python3 - "${DERIVED_DATA}/Build/Products" <<'PY'
import pathlib, sys
print(next(iter(pathlib.Path(sys.argv[1]).glob("**/Release-iphoneos/*.app")), ""))
PY
)"
[[ -n "${APP}" ]] || { echo "Unsigned iphoneos .app was not produced" >&2; exit 1; }
PLIST="${APP}/Info.plist"
[[ -f "${PLIST}" ]] || { echo "Built app Info.plist is missing" >&2; exit 1; }
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "${PLIST}")"
EXECUTABLE="${APP}/${EXECUTABLE_NAME}"
[[ -f "${EXECUTABLE}" ]] || { echo "Built app executable is missing" >&2; exit 1; }

file "${EXECUTABLE}"
lipo -info "${EXECUTABLE}"
lipo -archs "${EXECUTABLE}" | tr ' ' '\n' | grep -qx arm64 || { echo "Built app is not arm64" >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${PLIST}")" == "org.staydev.deadworld" ]] || { echo "Unexpected bundle identifier" >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${PLIST}")" == "${BUILD_NUMBER}" ]] || { echo "Built app CFBundleVersion does not match ${RELEASE_TAG}" >&2; exit 1; }
/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "${PLIST}"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${PLIST}"
python3 - "${PLIST}" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as stream:
    families = plistlib.load(stream).get("UIDeviceFamily", [])
if 1 not in families:
    raise SystemExit(f"Built app does not target iPhone: UIDeviceFamily={families}")
PY
if codesign -dv "${APP}" >/dev/null 2>&1; then
	echo "App unexpectedly contains a code signature" >&2
	exit 1
fi

PACKAGE_ROOT="$(mktemp -d)"
trap 'rm -rf "${PACKAGE_ROOT}"' EXIT
mkdir -p "${PACKAGE_ROOT}/Payload"
cp -R "${APP}" "${PACKAGE_ROOT}/Payload/Deadworld.app"
(
	cd "${PACKAGE_ROOT}"
	zip -qry "${IPA}" Payload
)
(
	cd "${BUILD_ROOT}"
	zip -qry "${PROJECT_ZIP}" .
)
shasum -a 256 "${IPA}" | awk -v name="${IPA_NAME}" '{print $1 "  " name}' > "${CHECKSUM}"

python3 - "${IPA}" "${EXECUTABLE_NAME}" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    names = set(archive.namelist())
for required in ("Payload/Deadworld.app/Info.plist", f"Payload/Deadworld.app/{sys.argv[2]}"):
    if required not in names:
        raise SystemExit(f"IPA entry is missing: {required}")
PY
python3 - "${IPA}" "${RELEASE_TAG}" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as archive:
    pck = archive.read("Payload/Deadworld.app/Deadworld.pck")
for marker in (sys.argv[2].encode(), b"ContainerPanel", b"InteractionTarget"):
    if marker not in pck:
        raise SystemExit(f"IPA game data is missing release marker: {marker.decode()}")
PY
echo "Unsigned IPA: ${IPA}"
cat "${CHECKSUM}"
