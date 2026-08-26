#!/usr/bin/env python3
import hashlib
import pathlib
import shutil
import subprocess
import sys
import tarfile

root = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / "scripts"))
from version import load as load_version  # noqa: E402

dist = root / "dist"
release = root / "release"
release_version = load_version()
if release.exists():
    shutil.rmtree(release)
release.mkdir()

linux_arches = {
    "x86_64",
    "arm64",
}
windows_arches = ["x86_64", "arm64"]

def required(path):
    if not path.is_file():
        raise SystemExit(f"Missing release input: {path}")
    return path

def add_tar_file(archive, source, name, mode):
    info = archive.gettarinfo(str(source), name)
    info.mode = mode
    with source.open("rb") as stream:
        archive.addfile(info, stream)

for godot_arch in sorted(linux_arches):
    binary = required(dist / f"linux-{godot_arch}" / "deadworld")
    pck = required(dist / f"linux-{godot_arch}" / "deadworld.pck")
    with tarfile.open(release / release_version.artifact("linux", godot_arch, "tar.gz"), "w:gz", compresslevel=9) as archive:
        add_tar_file(archive, binary, "deadworld/deadworld", 0o755)
        add_tar_file(archive, pck, "deadworld/deadworld.pck", 0o644)

for architecture in windows_arches:
    binary = required(dist / f"windows-{architecture}" / "deadworld.exe")
    shutil.copy2(binary, release / release_version.artifact("windows", architecture, "exe"))

apk = dist / "deadworld-android-universal.apk"
if apk.is_file(): shutil.copy2(apk, release / release_version.artifact("android", "universal", "apk"))

outputs = sorted(release.glob("deadworld-*"))
with (release / f"SHA256SUMS-{release_version.tag}.txt").open("w", encoding="ascii") as checksums:
    for path in outputs:
        checksums.write(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n")
print(f"Packaged {len(outputs)} artifacts for {release_version.tag}")
