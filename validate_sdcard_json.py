"""Validate sdcard.json: syntax, schema, alphabetical order, and variant directories."""

import json
import os
import sys
from pathlib import Path

from sdcard_json_utils import RESOLUTION_RE, natural_sort_key

IN_CI = bool(os.environ.get("GITHUB_ACTIONS"))


def error_msg(message: str) -> None:
    print(f"::error::{message}" if IN_CI else f"ERROR: {message}")


def validate_schema(data: object) -> list[str]:
    if not isinstance(data, dict) or set(data.keys()) != {"targets"}:
        return ['sdcard.json must be an object with a single "targets" key']

    targets = data["targets"]
    if not isinstance(targets, list):
        return ['"targets" must be an array']

    errors = []
    for i, target in enumerate(targets, start=1):
        if not (isinstance(target, list) and len(target) == 3):
            errors.append(f"target {i} must be a [name, prefix, resolution] array")
            continue
        name, prefix, resolution = target
        if not isinstance(name, str) or not name.strip():
            errors.append(f"target {i} name must be a non-empty string")
            name = f"#{i}"
        if not isinstance(prefix, str) or not prefix.strip() or not prefix.endswith("-"):
            errors.append(f"target {i} ({name!r}) prefix must be a non-empty string ending in '-'")
        if not isinstance(resolution, str) or not RESOLUTION_RE.match(resolution):
            errors.append(f"target {i} ({name!r}) resolution {resolution!r} must match bw<W>x<H> or c<W>x<H>")
    return errors


def validate_order(targets: list[list[str]]) -> list[str]:
    names = [t[0] for t in targets]
    sorted_names = sorted(names, key=natural_sort_key)
    for i, (actual, expected) in enumerate(zip(names, sorted_names)):
        if actual != expected:
            message = (
                f"targets are not in natural alphabetical order: {actual!r} at position {i + 1} "
                f"should come after {expected!r}"
            )
            return [message]
    return []


def validate_variant_dirs(targets: list[list[str]], sdcard_dir: Path) -> list[str]:
    resolutions = sorted({t[2] for t in targets})
    return [
        f'target resolution "{resolution}" has no matching sdcard/{resolution}/ directory'
        for resolution in resolutions
        if not (sdcard_dir / resolution).is_dir()
    ]


def main() -> int:
    root = Path.cwd()
    sdcard_json_path = root / "sdcard.json"
    sdcard_dir = root / "sdcard"

    try:
        data = json.loads(sdcard_json_path.read_text())
    except FileNotFoundError:
        error_msg("sdcard.json not found")
        return 1
    except json.JSONDecodeError as e:
        error_msg(f"sdcard.json is not valid JSON: {e}")
        return 1

    errors = validate_schema(data)
    if errors:
        for e in errors:
            error_msg(e)
        return 1

    targets = data["targets"]
    errors = validate_order(targets) + validate_variant_dirs(targets, sdcard_dir)
    if errors:
        for e in errors:
            error_msg(e)
        return 1

    print(f"sdcard.json OK: {len(targets)} targets validated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
