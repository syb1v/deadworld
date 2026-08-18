#!/usr/bin/env python3
import hashlib
import pathlib
import shutil
import zipfile

root = pathlib.Path(__file__).resolve().parent.parent
dist = root / "dist"
release = root / "release"
if release.exists():
    shutil.rmtree(release)
release.mkdir()

artifacts = {
    "deadworld-linux-x86_64.zip": [dist / "deadworld-linux.x86_64", dist / "deadworld-linux.pck"],
    "deadworld-windows-x86_64.zip": [dist / "deadworld-windows.exe", dist / "deadworld-windows.pck"],
}
for archive_name, files in artifacts.items():
    with zipfile.ZipFile(release / archive_name, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            if not path.is_file():
                raise SystemExit(f"Missing release input: {path}")
            archive.write(path, path.name)

android = release / "deadworld-android-arm64.apk"
shutil.copy2(dist / "deadworld-android.apk", android)

outputs = sorted(release.glob("deadworld-*"))
with (release / "SHA256SUMS.txt").open("w", encoding="ascii") as checksums:
    for path in outputs:
        checksums.write(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n")
