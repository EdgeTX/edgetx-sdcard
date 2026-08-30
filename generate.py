"""Build per-variant SD card distribution zips from sdcard/ + sdcard.json."""

import json
import os
import shutil
import sys
import zipfile
from pathlib import Path

from rich.console import Console
from rich.progress import Progress
from rich.table import Table

IN_CI = bool(os.environ.get("GITHUB_ACTIONS"))
JUNK_NAMES = {".DS_Store", "Thumbs.db"}


def error_msg(message: str) -> None:
    if IN_CI:
        print(f"::error::{message}")
    else:
        Console(stderr=True).print(f"[bold red]Error:[/] {message}")


def extract_variants(sdcard_json_path: Path) -> list[str]:
    data = json.loads(sdcard_json_path.read_text())
    return sorted({target[2] for target in data["targets"]})


def find_missing_variants(variants: list[str], sdcard_dir: Path) -> list[str]:
    return sorted(variant for variant in variants if not (sdcard_dir / variant).is_dir())


def merge_ignore_existing(src_dir: Path, dst_dir: Path) -> None:
    for src_file in src_dir.rglob("*"):
        if not src_file.is_file():
            continue
        dst_file = dst_dir / src_file.relative_to(src_dir)
        if dst_file.exists():
            continue
        dst_file.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src_file, dst_file)


def merge_overwrite(src_dir: Path, dst_dir: Path) -> None:
    shutil.copytree(src_dir, dst_dir, dirs_exist_ok=True)


def build_zip(variant_dir: Path, zip_path: Path) -> None:
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(variant_dir.rglob("*")):
            if path.is_file() and path.name not in JUNK_NAMES:
                zf.write(path, arcname=path.relative_to(variant_dir))


def human_readable(size: float) -> str:
    for unit in ("B", "K", "M", "G"):
        if size < 1024 or unit == "G":
            return f"{size:.0f}{unit}" if unit == "B" else f"{size:.1f}{unit}"
        size /= 1024
    return f"{size:.1f}G"


def main() -> int:
    console = Console()
    root = Path.cwd()
    sdcard_dir = root / "sdcard"
    global_dir = sdcard_dir / "global"
    sdcard_json = root / "sdcard.json"
    dist_dir = root / "dist"
    build_dir = root / "sdcard-build"

    if not sdcard_dir.is_dir():
        error_msg("sdcard directory not found")
        return 1
    if not global_dir.is_dir():
        error_msg("sdcard/global directory not found")
        return 1
    if not sdcard_json.is_file():
        error_msg("sdcard.json not found")
        return 1

    console.print("Validating variants...")
    variants = extract_variants(sdcard_json)
    missing = find_missing_variants(variants, sdcard_dir)
    if missing:
        error_msg("Missing variant directories:")
        for variant in missing:
            if IN_CI:
                print(f"::error::  sdcard/{variant}")
            else:
                Console(stderr=True).print(f"  - sdcard/{variant}", style="red")
        return 1

    if dist_dir.exists():
        shutil.rmtree(dist_dir)
    if build_dir.exists():
        shutil.rmtree(build_dir)
    dist_dir.mkdir(parents=True)

    console.print("Building distribution (dereferencing symlinks)...")
    shutil.copytree(sdcard_dir, build_dir, symlinks=False)

    variant_dirs = sorted(p for p in build_dir.iterdir() if p.is_dir())
    build_global_dir = build_dir / "global"

    for variant_dir in variant_dirs:
        name = variant_dir.name
        if name.startswith("bw") and name != "bw":
            bw_dir = build_dir / "bw"
            if bw_dir.is_dir():
                merge_ignore_existing(bw_dir, variant_dir)
        elif name.startswith("c") and name != "color":
            color_dir = build_dir / "color"
            if color_dir.is_dir():
                merge_ignore_existing(color_dir, variant_dir)

    package_dirs = [d for d in variant_dirs if d.name not in ("bw", "color", "global")]

    for variant_dir in package_dirs:
        merge_overwrite(build_global_dir, variant_dir)

    console.print("Creating distribution packages...")
    generated: list[tuple[str, int]] = []
    with Progress(console=console) as progress:
        task = progress.add_task("Zipping variants", total=len(package_dirs))
        for variant_dir in package_dirs:
            zip_path = dist_dir / f"{variant_dir.name}.zip"
            build_zip(variant_dir, zip_path)
            generated.append((zip_path.name, zip_path.stat().st_size))
            progress.advance(task)

    if not IN_CI:
        shutil.rmtree(build_dir)

    table = Table(title="Generated Packages")
    table.add_column("File")
    table.add_column("Size", justify="right")
    for name, size in sorted(generated):
        table.add_row(name, human_readable(size))
    console.print(table)

    return 0


if __name__ == "__main__":
    sys.exit(main())
