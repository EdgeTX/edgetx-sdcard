# Contributing

## Building the distribution zips

The per-variant SD card zips (`dist/*.zip`) are built by `generate.py` from the `sdcard/` tree and `sdcard.json`. It's a small [uv](https://docs.astral.sh/uv/)-managed Python project — no separate install step, `uv` resolves and runs everything from `pyproject.toml`.

Install `uv` (see [the uv install docs](https://docs.astral.sh/uv/getting-started/installation/)), then from the repo root:

```sh
# Build the zips into dist/
uv run generate.py

# Run the test suite
uv run pytest

# Lint and format-check
uv run ruff check .
uv run ruff format --check .

# Auto-fix formatting
uv run ruff format .
```

`generate.py`'s logic lives in plain, independently testable functions (variant extraction, directory merging, zip building) — see `tests/test_generate.py` for examples. When changing its behavior, add or update a test alongside the change.

## Keeping sdcard.json in sync with EdgeTX/edgetx

`sdcard.json` mirrors the target list in [`fw.json`](https://github.com/EdgeTX/edgetx/blob/main/fw.json) from `EdgeTX/edgetx`, plus a screen resolution per target that `fw.json` doesn't carry.

- `validate_sdcard_json.py` checks `sdcard.json`'s syntax, schema, alphabetical order, and that every referenced resolution has a matching `sdcard/<resolution>/` directory. It runs in CI on every change to `sdcard.json`.
- `sync_fw_json.py` fetches `fw.json` and the relevant `radio/src/boards/hw_defs/<flavour>.json` files from `EdgeTX/edgetx` and reconciles `sdcard.json` against them — additions, removals, renames, and resolution corrections. It runs weekly and opens a PR when it finds drift; run it locally with `uv run sync_fw_json.py` to check on demand. A target it can't resolve a screen size for is left alone and reported as a warning rather than guessed at — that still needs a human.

## Working with symlinks

See the [README](README.md#for-developers) for details on the symlink layout used to avoid duplicating shared template files across screen sizes, and the Windows sync-script fallback for environments without symlink support.
