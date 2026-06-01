#!/usr/bin/env python3
from __future__ import annotations

import argparse
import plistlib
import shutil
import struct
import subprocess
import zlib
from pathlib import Path

APP_NAME = "CLI Approval Deck"
BUNDLE_ID = "io.github.langgugemaster.cli-approval-deck"
ICON_SIZES = (16, 32, 128, 256, 512)


def png_bytes(width: int, height: int, pixels: list[list[tuple[int, int, int, int]]]) -> bytes:
    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(
            ">I", zlib.crc32(kind + data) & 0xFFFFFFFF
        )

    raw = b"".join(b"\x00" + bytes(channel for pixel in row for channel in pixel) for row in pixels)
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def draw_icon(size: int) -> bytes:
    grid_size = 32
    scale = size // grid_size
    pixels = [[(7, 14, 22, 255) for _ in range(size)] for _ in range(size)]

    def block(x: int, y: int, width: int, height: int, color: tuple[int, int, int, int]) -> None:
        for row in range(y * scale, (y + height) * scale):
            for column in range(x * scale, (x + width) * scale):
                pixels[size - row - 1][column] = color

    outline = (20, 34, 38, 255)
    yellow = (255, 209, 46, 255)
    light = (255, 236, 98, 255)
    orange = (255, 122, 38, 255)
    green = (51, 242, 148, 255)

    block(7, 4, 18, 3, outline)
    block(5, 7, 21, 9, outline)
    block(8, 16, 13, 8, outline)
    block(6, 8, 19, 7, yellow)
    block(9, 15, 11, 8, light)
    block(24, 11, 6, 2, orange)
    block(13, 19, 2, 2, outline)
    block(9, 3, 3, 3, orange)
    block(18, 3, 3, 3, orange)
    block(2, 15, 3, 10, outline)
    block(1, 24, 11, 2, outline)
    block(1, 30, 11, 2, outline)
    block(0, 26, 2, 4, outline)
    block(11, 26, 2, 4, outline)
    block(2, 26, 9, 4, green)
    block(4, 28, 2, 1, outline)
    block(5, 27, 2, 1, outline)
    block(6, 28, 1, 1, outline)
    block(7, 29, 3, 1, outline)
    return png_bytes(size, size, pixels)


def info_plist() -> dict[str, object]:
    return {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleExecutable": "ApprovalDeck",
        "CFBundleIconFile": "DuckIcon",
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": APP_NAME,
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "1.0.1",
        "CFBundleVersion": "2",
        "LSMinimumSystemVersion": "13.0",
        "LSUIElement": False,
        "NSHighResolutionCapable": True,
    }


def wrapper_script() -> str:
    return """#!/bin/zsh
set -euo pipefail
RESOURCES=${0:A:h:h}
PYTHONPATH="$RESOURCES${PYTHONPATH:+:$PYTHONPATH}" exec python3 -m cli_approval_float.proxy "$@"
"""


def hook_script() -> str:
    return """#!/bin/zsh
set -euo pipefail
ZSHRC="$HOME/.zshrc"
MARKER="# CLI Approval Deck"
APP="/Applications/CLI Approval Deck.app"
touch "$ZSHRC"
if grep -qF "$MARKER" "$ZSHRC"; then
  print "CLI Approval Deck hooks already exist in $ZSHRC"
  exit 0
fi
cat >> "$ZSHRC" <<'EOF'

# CLI Approval Deck
codex() {
  "/Applications/CLI Approval Deck.app/Contents/Resources/bin/cli-approval-run" /opt/homebrew/bin/codex "$@"
}

claude() {
  "/Applications/CLI Approval Deck.app/Contents/Resources/bin/cli-approval-run" "$HOME/.local/bin/claude" "$@"
}
EOF
print "Installed CLI Approval Deck hooks. Run: source ~/.zshrc"
"""


def run(*command: str, cwd: Path | None = None) -> None:
    subprocess.run(command, cwd=cwd, check=True)


def build_icon(resources: Path, work: Path) -> None:
    iconset = work / "DuckIcon.iconset"
    iconset.mkdir(parents=True)
    source = work / "duck-1024.png"
    source.write_bytes(draw_icon(1024))
    for size in ICON_SIZES:
        run("sips", "-z", str(size), str(size), str(source), "--out", str(iconset / f"icon_{size}x{size}.png"))
        retina = size * 2
        run("sips", "-z", str(retina), str(retina), str(source), "--out", str(iconset / f"icon_{size}x{size}@2x.png"))
    run("iconutil", "-c", "icns", str(iconset), "-o", str(resources / "DuckIcon.icns"))


def package(root: Path, skip_build: bool = False, skip_dmg: bool = False) -> tuple[Path, Path]:
    dist = root / "dist"
    work = dist / ".package-work"
    app = dist / f"{APP_NAME}.app"
    dmg = dist / "CLI-Approval-Deck.dmg"
    shutil.rmtree(dist, ignore_errors=True)
    (app / "Contents" / "MacOS").mkdir(parents=True)
    resources = app / "Contents" / "Resources"
    (resources / "bin").mkdir(parents=True)
    work.mkdir(parents=True)

    if not skip_build:
        run("swift", "build", "-c", "release", cwd=root)
    executable = root / ".build" / "release" / "ApprovalFloat"
    if not executable.exists():
        raise FileNotFoundError(f"missing executable: {executable}")
    shutil.copy2(executable, app / "Contents" / "MacOS" / "ApprovalDeck")
    shutil.copytree(root / "cli_approval_float", resources / "cli_approval_float")
    (resources / "bin" / "cli-approval-run").write_text(wrapper_script(), encoding="utf-8")
    (resources / "install-shell-hooks").write_text(hook_script(), encoding="utf-8")
    (app / "Contents" / "Info.plist").write_bytes(plistlib.dumps(info_plist()))
    for executable_path in (
        app / "Contents" / "MacOS" / "ApprovalDeck",
        resources / "bin" / "cli-approval-run",
        resources / "install-shell-hooks",
    ):
        executable_path.chmod(0o755)
    build_icon(resources, work)
    run("codesign", "--force", "--deep", "--sign", "-", str(app))

    if not skip_dmg:
        stage = work / "dmg"
        stage.mkdir()
        shutil.copytree(app, stage / app.name)
        (stage / "Applications").symlink_to("/Applications")
        run(
            "hdiutil",
            "create",
            "-volname",
            APP_NAME,
            "-srcfolder",
            str(stage),
            "-ov",
            "-format",
            "UDZO",
            str(dmg),
        )
    shutil.rmtree(work)
    return app, dmg


def main() -> None:
    parser = argparse.ArgumentParser(description="Build CLI Approval Deck.app and DMG.")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--skip-dmg", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    app, dmg = package(root, args.skip_build, args.skip_dmg)
    print(f"Built {app}")
    if not args.skip_dmg:
        print(f"Built {dmg}")


if __name__ == "__main__":
    main()
