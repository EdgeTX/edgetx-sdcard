"""Reconcile sdcard.json against EdgeTX/edgetx's fw.json.

fw.json only carries [name, prefix] pairs, no screen resolution, so for
every target this also fetches radio/src/boards/hw_defs/<flavour>.json
and derives "bw<W>x<H>" / "c<W>x<H>" from lcd_w/lcd_h/lcd_depth - the
same hardware description the firmware build itself uses. That covers
new targets, renames, removed targets, and resolution drift on existing
entries (this is what would have caught the HelloRadioSky V12 mistake
automatically: it was hand-entered as bw128x64, but its PCB is actually
colorlcd 320x240).

Rewrites sdcard.json in place if anything changed and prints a summary
of what changed to stdout for the calling workflow to use as a PR body.
Exits non-zero only on a hard failure to fetch fw.json itself - a
per-target hw_defs lookup failure just leaves that entry untouched and
is reported instead of guessed at.
"""

import functools
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

from sdcard_json_utils import natural_sort_key

IN_CI = bool(os.environ.get("GITHUB_ACTIONS"))

EDGETX_RAW = "https://raw.githubusercontent.com/EdgeTX/edgetx/main"
FW_JSON_URL = f"{EDGETX_RAW}/fw.json"
HW_DEF_URL = f"{EDGETX_RAW}/radio/src/boards/hw_defs/{{flavour}}.json"

# fw.json prefixes that don't map 1:1 onto their hw_defs/<flavour>.json
# filename. See tools/boards.py and the PCBREV branches in
# targets/taranis/CMakeLists.txt (EdgeTX/edgetx) for how PCBREV picks
# FLAVOUR - HW_DESC_JSON is "${FLAVOUR}.json", not the fw.json prefix.
PREFIX_TO_FLAVOUR_OVERRIDES = {
    "x9dp2019": "x9d+2019",
}


@functools.cache
def fetch_json(url: str) -> dict | list | None:
    try:
        with urllib.request.urlopen(url, timeout=15) as resp:
            return json.loads(resp.read())
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError, ValueError) as e:
        print(f"warning: failed to fetch {url}: {e}", file=sys.stderr)
        return None


def resolution_for_prefix(prefix: str) -> str | None:
    flavour_key = prefix.rstrip("-")
    flavour = PREFIX_TO_FLAVOUR_OVERRIDES.get(flavour_key, flavour_key)
    hw_def = fetch_json(HW_DEF_URL.format(flavour=flavour))
    if hw_def is None:
        return None
    try:
        display = hw_def["display"]
        width, height, depth = display["lcd_w"], display["lcd_h"], display["lcd_depth"]
    except (KeyError, TypeError):
        return None
    kind = "bw" if depth <= 4 else "c"
    return f"{kind}{width}x{height}"


def reconcile(
    sdcard_targets: list[list[str]],
    fw_targets: list[list[str]],
    resolve_resolution=resolution_for_prefix,
) -> tuple[list[list[str]], list[str], list[str]]:
    """Return (new sdcard.json targets, content changes for the PR body, warnings to surface regardless)."""
    by_prefix = {prefix: (name, prefix, resolution) for name, prefix, resolution in sdcard_targets}
    fw_prefixes = {prefix for _name, prefix in fw_targets}

    changes: list[str] = []
    warnings: list[str] = []
    result: list[list[str]] = []

    for fw_name, fw_prefix in fw_targets:
        existing = by_prefix.get(fw_prefix)
        resolution = resolve_resolution(fw_prefix)

        if existing is None:
            if resolution is None:
                warnings.append(
                    f'new target "{fw_name}" ({fw_prefix}) skipped - could not determine '
                    "screen resolution from hw_defs, needs manual review"
                )
                continue
            result.append([fw_name, fw_prefix, resolution])
            changes.append(f'- Added "{fw_name}" ({fw_prefix}) as {resolution}')
            continue

        existing_name, _existing_prefix, existing_resolution = existing
        new_resolution = resolution if resolution is not None else existing_resolution

        if resolution is None:
            warnings.append(f'could not verify resolution for "{fw_name}" ({fw_prefix}), keeping {existing_resolution}')
        if fw_name != existing_name:
            changes.append(f'- Renamed "{existing_name}" -> "{fw_name}" ({fw_prefix})')
        if new_resolution != existing_resolution:
            changes.append(f'- Fixed "{fw_name}" ({fw_prefix}) resolution: {existing_resolution} -> {new_resolution}')

        result.append([fw_name, fw_prefix, new_resolution])

    for existing_name, existing_prefix, _existing_resolution in sdcard_targets:
        if existing_prefix not in fw_prefixes:
            changes.append(f'- Removed "{existing_name}" ({existing_prefix}) - no longer in fw.json')

    result.sort(key=lambda t: natural_sort_key(t[0]))
    return result, changes, warnings


def format_sdcard_json(targets: list[list[str]]) -> str:
    lines = ["{", '  "targets": [']
    for i, target in enumerate(targets):
        comma = "," if i < len(targets) - 1 else ""
        lines.append(f"    {json.dumps(target)}{comma}")
    lines.append("  ]")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> int:
    sdcard_json_path = Path.cwd() / "sdcard.json"
    sdcard_targets = json.loads(sdcard_json_path.read_text())["targets"]

    fw_data = fetch_json(FW_JSON_URL)
    if fw_data is None:
        print("::error::could not fetch fw.json from EdgeTX/edgetx", file=sys.stderr)
        return 1

    new_targets, changes, warnings = reconcile(sdcard_targets, fw_data["targets"])

    for warning in warnings:
        print(f"::warning::{warning}" if IN_CI else f"WARNING: {warning}", file=sys.stderr)

    if not changes:
        print("sdcard.json is already in sync with fw.json")
        return 0

    sdcard_json_path.write_text(format_sdcard_json(new_targets))

    print("sdcard.json updated:\n")
    print("\n".join(changes))
    return 0


if __name__ == "__main__":
    sys.exit(main())
