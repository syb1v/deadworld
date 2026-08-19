#!/usr/bin/env python3
import hashlib
import os
import pathlib
import shutil
import subprocess
import tarfile
import zipfile

root = pathlib.Path(__file__).resolve().parent.parent
dist = root / "dist"
release = root / "release"
version = os.environ.get("RELEASE_VERSION", "0.1.0~prealpha3")
if release.exists():
    shutil.rmtree(release)
release.mkdir()

linux_arches = {
    "x86_64": ("amd64", "x86_64"),
    "x86_32": ("i386", "i686"),
    "arm64": ("arm64", "aarch64"),
    "arm32": ("armhf", "armv7hl"),
}
windows_arches = ["x86_64", "x86_32", "arm64"]

def required(path):
    if not path.is_file():
        raise SystemExit(f"Missing release input: {path}")
    return path

def add_tar_file(archive, source, name, mode):
    info = archive.gettarinfo(str(source), name)
    info.mode = mode
    with source.open("rb") as stream:
        archive.addfile(info, stream)

def write_deb(architecture, binary, pck):
    package_root = release / f"deb-{architecture}"
    app = package_root / "opt" / "deadworld"
    desktop = package_root / "usr" / "share" / "applications"
    control = package_root / "DEBIAN"
    app.mkdir(parents=True); desktop.mkdir(parents=True); control.mkdir()
    shutil.copy2(binary, app / "deadworld"); (app / "deadworld").chmod(0o755)
    shutil.copy2(pck, app / "deadworld.pck")
    (desktop / "deadworld.desktop").write_text("[Desktop Entry]\nType=Application\nName=Project Deadworld\nExec=/opt/deadworld/deadworld\nTerminal=false\nCategories=Game;\n", encoding="ascii")
    (control / "control").write_text(f"Package: deadworld\nVersion: {version}\nArchitecture: {architecture}\nMaintainer: Project Deadworld\nSection: games\nPriority: optional\nDescription: Pre-alpha multiplayer survival tech test\n", encoding="ascii")
    subprocess.run(["dpkg-deb", "--root-owner-group", "--build", str(package_root), str(release / f"deadworld-linux-{architecture}.deb")], check=True)
    shutil.rmtree(package_root)

def write_rpm(architecture, binary, pck):
    top = release / f"rpm-{architecture}"
    for name in ["BUILD", "BUILDROOT", "RPMS", "SOURCES", "SPECS", "SRPMS"]: (top / name).mkdir(parents=True)
    shutil.copy2(binary, top / "SOURCES" / "deadworld")
    shutil.copy2(pck, top / "SOURCES" / "deadworld.pck")
    spec = f'''Name: deadworld
Version: 0.1.0
Release: 0.prealpha3
Summary: Pre-alpha multiplayer survival tech test
License: Proprietary
%description
Project Deadworld pre-alpha multiplayer survival tech test.

%install
mkdir -p %{{buildroot}}/opt/deadworld
install -m 0755 %{{_sourcedir}}/deadworld %{{buildroot}}/opt/deadworld/deadworld
install -m 0644 %{{_sourcedir}}/deadworld.pck %{{buildroot}}/opt/deadworld/deadworld.pck

%files
/opt/deadworld/deadworld
/opt/deadworld/deadworld.pck
'''
    (top / "SPECS" / "deadworld.spec").write_text(spec, encoding="ascii")
    subprocess.run(["rpmbuild", "--target", architecture, "--define", f"_topdir {top}", "-bb", str(top / "SPECS" / "deadworld.spec")], check=True)
    built = next((top / "RPMS").rglob("*.rpm"))
    shutil.move(built, release / f"deadworld-linux-{architecture}.rpm")
    shutil.rmtree(top)

for godot_arch, (deb_arch, rpm_arch) in linux_arches.items():
    binary = required(dist / f"linux-{godot_arch}" / "deadworld")
    pck = required(dist / f"linux-{godot_arch}" / "deadworld.pck")
    with tarfile.open(release / f"deadworld-linux-{godot_arch}.tar.gz", "w:gz", compresslevel=9) as archive:
        add_tar_file(archive, binary, "deadworld/deadworld", 0o755)
        add_tar_file(archive, pck, "deadworld/deadworld.pck", 0o644)
    write_deb(deb_arch, binary, pck)
    write_rpm(rpm_arch, binary, pck)

for architecture in windows_arches:
    binary = required(dist / f"windows-{architecture}" / "deadworld.exe")
    shutil.copy2(binary, release / f"deadworld-windows-{architecture}.exe")
    with zipfile.ZipFile(release / f"deadworld-windows-{architecture}.zip", "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        archive.write(binary, "deadworld.exe")

apk = dist / "deadworld-android-universal.apk"
if apk.is_file(): shutil.copy2(apk, release / apk.name)
aab = dist / "deadworld-android-universal.aab"
if aab.is_file(): shutil.copy2(aab, release / aab.name)

outputs = sorted(release.glob("deadworld-*"))
with (release / "SHA256SUMS.txt").open("w", encoding="ascii") as checksums:
    for path in outputs:
        checksums.write(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.name}\n")
