from sync_fw_json import format_sdcard_json, reconcile


def resolver(resolutions: dict[str, str | None]):
    return lambda prefix: resolutions.get(prefix)


def test_reconcile_reports_no_changes_when_already_in_sync() -> None:
    sdcard_targets = [["Device A", "a-", "c480x272"]]
    fw_targets = [["Device A", "a-"]]

    new_targets, changes, warnings = reconcile(sdcard_targets, fw_targets, resolver({"a-": "c480x272"}))

    assert new_targets == sdcard_targets
    assert changes == []
    assert warnings == []


def test_reconcile_adds_new_target_with_derived_resolution() -> None:
    new_targets, changes, warnings = reconcile([], [["Device A", "a-"]], resolver({"a-": "c480x272"}))

    assert new_targets == [["Device A", "a-", "c480x272"]]
    assert "Added" in changes[0]
    assert "c480x272" in changes[0]
    assert warnings == []


def test_reconcile_warns_and_skips_new_target_when_resolution_unknown() -> None:
    new_targets, changes, warnings = reconcile([], [["Device A", "a-"]], resolver({}))

    assert new_targets == []
    assert changes == []
    assert "skipped" in warnings[0]


def test_reconcile_removes_target_missing_from_fw_json() -> None:
    sdcard_targets = [["Device A", "a-", "c480x272"]]

    new_targets, changes, warnings = reconcile(sdcard_targets, [], resolver({}))

    assert new_targets == []
    assert "Removed" in changes[0]
    assert "Device A" in changes[0]
    assert warnings == []


def test_reconcile_fixes_drifted_resolution_on_existing_target() -> None:
    sdcard_targets = [["HelloRadioSky V12", "v12-", "bw128x64"]]
    fw_targets = [["HelloRadioSky V12", "v12-"]]

    new_targets, changes, warnings = reconcile(sdcard_targets, fw_targets, resolver({"v12-": "c320x240"}))

    assert new_targets == [["HelloRadioSky V12", "v12-", "c320x240"]]
    assert any("bw128x64 -> c320x240" in c for c in changes)
    assert warnings == []


def test_reconcile_renames_target_keeping_its_resolution() -> None:
    sdcard_targets = [["Old Name", "a-", "c480x272"]]
    fw_targets = [["New Name", "a-"]]

    new_targets, changes, warnings = reconcile(sdcard_targets, fw_targets, resolver({"a-": "c480x272"}))

    assert new_targets == [["New Name", "a-", "c480x272"]]
    assert any("Old Name" in c and "New Name" in c for c in changes)
    assert warnings == []


def test_reconcile_keeps_existing_resolution_and_warns_when_lookup_fails() -> None:
    sdcard_targets = [["Device A", "a-", "c480x272"]]
    fw_targets = [["Device A", "a-"]]

    new_targets, changes, warnings = reconcile(sdcard_targets, fw_targets, resolver({}))

    assert new_targets == [["Device A", "a-", "c480x272"]]
    assert changes == []
    assert "could not verify" in warnings[0]


def test_reconcile_sorts_result_naturally_by_name() -> None:
    fw_targets = [["Device B2", "b2-"], ["Device A", "a-"], ["Device B10", "b10-"]]
    resolutions = {"a-": "c480x272", "b2-": "c480x272", "b10-": "c480x272"}

    new_targets, _changes, _warnings = reconcile([], fw_targets, resolver(resolutions))

    assert [t[0] for t in new_targets] == ["Device A", "Device B2", "Device B10"]


def test_format_sdcard_json_matches_repo_style() -> None:
    targets = [["Device A", "a-", "c480x272"], ["Device B", "b-", "bw128x64"]]

    output = format_sdcard_json(targets)

    assert output == (
        '{\n  "targets": [\n    ["Device A", "a-", "c480x272"],\n    ["Device B", "b-", "bw128x64"]\n  ]\n}\n'
    )
