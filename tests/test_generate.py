import json
import zipfile
from pathlib import Path

from generate import build_zip, extract_variants, find_missing_variants, merge_ignore_existing, merge_overwrite


def test_extract_variants_dedupes_and_sorts(tmp_path: Path) -> None:
    sdcard_json = tmp_path / "sdcard.json"
    sdcard_json.write_text(
        json.dumps(
            {
                "targets": [
                    ["Device A", "a-", "c480x272"],
                    ["Device B", "b-", "bw128x64"],
                    ["Device C", "c-", "c480x272"],
                ]
            }
        )
    )

    assert extract_variants(sdcard_json) == ["bw128x64", "c480x272"]


def test_find_missing_variants(tmp_path: Path) -> None:
    sdcard_dir = tmp_path / "sdcard"
    (sdcard_dir / "c480x272").mkdir(parents=True)

    assert find_missing_variants(["c480x272", "bw128x64"], sdcard_dir) == ["bw128x64"]
    assert find_missing_variants(["c480x272"], sdcard_dir) == []


def test_merge_ignore_existing_keeps_destination_file(tmp_path: Path) -> None:
    src_dir = tmp_path / "src"
    dst_dir = tmp_path / "dst"
    src_dir.mkdir()
    dst_dir.mkdir()

    (src_dir / "shared.txt").write_text("from source")
    (dst_dir / "shared.txt").write_text("from destination")
    (src_dir / "only_in_src.txt").write_text("copied over")

    merge_ignore_existing(src_dir, dst_dir)

    assert (dst_dir / "shared.txt").read_text() == "from destination"
    assert (dst_dir / "only_in_src.txt").read_text() == "copied over"


def test_merge_overwrite_replaces_destination_file(tmp_path: Path) -> None:
    src_dir = tmp_path / "src"
    dst_dir = tmp_path / "dst"
    src_dir.mkdir()
    dst_dir.mkdir()

    (src_dir / "shared.txt").write_text("from source")
    (dst_dir / "shared.txt").write_text("from destination")

    merge_overwrite(src_dir, dst_dir)

    assert (dst_dir / "shared.txt").read_text() == "from source"


def test_build_zip_uses_relative_arcnames(tmp_path: Path) -> None:
    variant_dir = tmp_path / "c480x272"
    (variant_dir / "SCRIPTS").mkdir(parents=True)
    (variant_dir / "SCRIPTS" / "foo.lua").write_text("-- lua")
    (variant_dir / "top.txt").write_text("hello")

    zip_path = tmp_path / "c480x272.zip"
    build_zip(variant_dir, zip_path)

    with zipfile.ZipFile(zip_path) as zf:
        names = set(zf.namelist())
        assert names == {"SCRIPTS/foo.lua", "top.txt"}
        assert zf.read("top.txt") == b"hello"


def test_build_zip_excludes_junk_files(tmp_path: Path) -> None:
    variant_dir = tmp_path / "c480x272"
    (variant_dir / "TEMPLATES").mkdir(parents=True)
    (variant_dir / ".DS_Store").write_text("junk")
    (variant_dir / "TEMPLATES" / ".DS_Store").write_text("junk")
    (variant_dir / "TEMPLATES" / "Thumbs.db").write_text("junk")
    (variant_dir / "keep.txt").write_text("keep me")

    zip_path = tmp_path / "c480x272.zip"
    build_zip(variant_dir, zip_path)

    with zipfile.ZipFile(zip_path) as zf:
        assert zf.namelist() == ["keep.txt"]
