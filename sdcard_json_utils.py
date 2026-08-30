"""Helpers shared by validate_sdcard_json.py and sync_fw_json.py."""

import re

RESOLUTION_RE = re.compile(r"^(bw|c)\d+x\d+$")


def natural_sort_key(name: str) -> list[int | str]:
    """Split a string into text/number chunks so digit runs compare numerically."""
    return [int(chunk) if chunk.isdigit() else chunk.lower() for chunk in re.split(r"(\d+)", name)]
