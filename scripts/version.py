#!/usr/bin/env python3
"""Single source of truth for the released client version.

`VERSION` holds the public tag, for example `v0.1.0-prealpha.6`. Every platform
identifier is derived from it so a release can never ship mismatched labels:

    tag              v0.1.0-prealpha.6
    semantic         0.1.0
    prerelease       prealpha.6
    build number     6            (Android versionCode, iOS CFBundleVersion)
    package version  0.1.0~prealpha6   (DEB)
    rpm release      0.prealpha6

`stamp` rewrites the generated fields in the client and packaging inputs.
`check` fails when any of those files drifted from `VERSION`, which CI uses to
block releases built from stale metadata.
"""
import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / "VERSION"
TAG_PATTERN = re.compile(r"^v(?P<semantic>\d+\.\d+\.\d+)(?:-(?P<prerelease>[0-9A-Za-z.]+))?$")


class Version:
    def __init__(self, tag: str) -> None:
        match = TAG_PATTERN.match(tag)
        if not match:
            raise SystemExit(f"Invalid version tag: {tag!r}; expected vMAJOR.MINOR.PATCH[-prerelease]")
        self.tag = tag
        self.semantic = match.group("semantic")
        self.prerelease = match.group("prerelease") or ""
        self.build = self._build_number()

    def _build_number(self) -> int:
        # Monotonic build number for stores/devices: a release build uses the
        # patch level, a prerelease uses its trailing counter.
        if not self.prerelease:
            return int(self.semantic.split(".")[-1]) or 1
        counters = re.findall(r"\d+", self.prerelease)
        if not counters:
            raise SystemExit(f"Prerelease {self.prerelease!r} has no numeric build counter")
        return int(counters[-1])

    @property
    def display(self) -> str:
        return self.tag.lstrip("v")

    @property
    def deb_version(self) -> str:
        return f"{self.semantic}~{self.prerelease.replace('.', '')}" if self.prerelease else self.semantic

    @property
    def rpm_release(self) -> str:
        return f"0.{self.prerelease.replace('.', '')}" if self.prerelease else "1"

    def artifact(self, platform: str, architecture: str, extension: str) -> str:
        return f"deadworld-{self.tag}-{platform}-{architecture}.{extension}"


def load(tag: str | None = None) -> Version:
    return Version(tag or VERSION_FILE.read_text(encoding="ascii").strip())


def _substitute(path: pathlib.Path, rules: list[tuple[str, str]]) -> tuple[pathlib.Path, str, str]:
    original = path.read_text(encoding="utf-8")
    updated = original
    for pattern, replacement in rules:
        updated, count = re.subn(pattern, replacement, updated, flags=re.MULTILINE)
        if count == 0:
            raise SystemExit(f"Version pattern not found in {path}: {pattern}")
    return path, original, updated


def plan(version: Version) -> list[tuple[pathlib.Path, str, str]]:
    return [
        _substitute(ROOT / "client/export_presets.cfg", [
            (r'^version/code=\d+$', f"version/code={version.build}"),
            (r'^version/name=".*"$', f'version/name="{version.display}"'),
            (r'^application/short_version=".*"$', f'application/short_version="{version.semantic}"'),
            (r'^application/version=".*"$', f'application/version="{version.build}"'),
        ]),
        _substitute(ROOT / "client/scenes/Boot.tscn", [
            (r'^text = "v[0-9A-Za-z.\-]+ \| PRE-ALPHA"$', f'text = "{version.tag} | PRE-ALPHA"'),
            (r'^text = "v[0-9A-Za-z.\-]+"$', f'text = "{version.tag}"'),
        ]),
        _substitute(ROOT / "client/scripts/world/World.gd", [
            (r'^const BUILD_LABEL := ".*"$', f'const BUILD_LABEL := "{version.tag}"'),
        ]),
        _substitute(ROOT / "admin/server.mjs", [
            (r'process\.env\.RELEASE_TAG \|\| "v[0-9A-Za-z.\-]+"', f'process.env.RELEASE_TAG || "{version.tag}"'),
        ]),
        _substitute(ROOT / "infra/docker-compose.prod.yml", [
            (r'RELEASE_TAG:\s*\$\{RELEASE_TAG:-v[0-9A-Za-z.\-]+\}', f"RELEASE_TAG: ${{RELEASE_TAG:-{version.tag}}}"),
        ]),
        _substitute(ROOT / ".env.example", [
            (r'^RELEASE_TAG=v[0-9A-Za-z.\-]+$', f"RELEASE_TAG={version.tag}"),
        ]),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["stamp", "check", "print"])
    parser.add_argument("--tag", help="override the tag instead of reading VERSION")
    parser.add_argument("--field", default="tag", help="field printed by the print command")
    arguments = parser.parse_args()
    version = load(arguments.tag)

    if arguments.command == "print":
        fields = {
            "tag": version.tag,
            "display": version.display,
            "semantic": version.semantic,
            "build": str(version.build),
            "deb": version.deb_version,
            "rpm": version.rpm_release,
        }
        if arguments.field not in fields:
            raise SystemExit(f"Unknown field {arguments.field!r}; expected one of {sorted(fields)}")
        print(fields[arguments.field])
        return 0

    changes = plan(version)
    if arguments.command == "check":
        drifted = [str(path.relative_to(ROOT)) for path, original, updated in changes if original != updated]
        if drifted:
            print(f"Version drift for {version.tag}: {', '.join(drifted)}", file=sys.stderr)
            return 1
        print(f"Version metadata matches {version.tag}")
        return 0

    for path, original, updated in changes:
        if original != updated:
            path.write_text(updated, encoding="utf-8")
            print(f"Stamped {path.relative_to(ROOT)}")
    print(f"Version metadata stamped to {version.tag}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
