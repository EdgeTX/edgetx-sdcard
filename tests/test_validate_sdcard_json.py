from pathlib import Path

from validate_sdcard_json import validate_order, validate_schema, validate_variant_dirs


def test_validate_schema_accepts_well_formed_targets() -> None:
    data = {"targets": [["Device A", "a-", "c480x272"], ["Device B", "b-", "bw128x64"]]}

    assert validate_schema(data) == []


def test_validate_schema_rejects_extra_top_level_keys() -> None:
    data = {"targets": [], "changelog": "hi"}

    assert validate_schema(data) != []


def test_validate_schema_rejects_bad_prefix_and_resolution() -> None:
    data = {"targets": [["Device A", "a", "480x272"]]}

    errors = validate_schema(data)

    assert any("prefix" in e for e in errors)
    assert any("resolution" in e for e in errors)


def test_validate_order_passes_for_sorted_names() -> None:
    targets = [["Device A", "a-", "c480x272"], ["Device B2", "b2-", "c480x272"], ["Device B10", "b10-", "c480x272"]]

    assert validate_order(targets) == []


def test_validate_order_flags_out_of_order_names() -> None:
    targets = [["Device B", "b-", "c480x272"], ["Device A", "a-", "c480x272"]]

    errors = validate_order(targets)

    assert len(errors) == 1
    assert "Device B" in errors[0]


def test_validate_variant_dirs_flags_missing_directory(tmp_path: Path) -> None:
    sdcard_dir = tmp_path / "sdcard"
    (sdcard_dir / "c480x272").mkdir(parents=True)
    targets = [["Device A", "a-", "c480x272"], ["Device B", "b-", "bw128x64"]]

    errors = validate_variant_dirs(targets, sdcard_dir)

    assert len(errors) == 1
    assert "bw128x64" in errors[0]
