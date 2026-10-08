#!/usr/bin/env python3
"""Validate every native screenshot metadata sidecar."""

from __future__ import annotations

import json
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "store_assets" / "source_capture"
REQUIRED = {
    "file",
    "platform",
    "device",
    "device_id",
    "os",
    "locale",
    "capture_method",
    "capture_command",
    "capture_timestamp",
    "native_dimensions",
    "untouched_source",
}


def png_size(path: Path) -> str:
    with path.open("rb") as stream:
        header = stream.read(24)
    width, height = struct.unpack(">II", header[16:24])
    return f"{width}x{height}"


def main() -> None:
    screenshots = sorted(SOURCE.glob("*/*/*/0[1-6]_*.png"))
    if len(screenshots) != 60:
        raise SystemExit(f"Expected 60 native screenshots, found {len(screenshots)}")

    for screenshot in screenshots:
        sidecar = screenshot.with_suffix(".metadata.json")
        if not sidecar.is_file():
            raise SystemExit(f"Missing metadata: {sidecar}")
        data = json.loads(sidecar.read_text(encoding="utf-8"))
        missing = REQUIRED.difference(data)
        if missing:
            raise SystemExit(f"{sidecar} missing fields: {sorted(missing)}")
        expected_file = screenshot.relative_to(ROOT).as_posix()
        if data["file"] != expected_file:
            raise SystemExit(f"{sidecar} references {data['file']}, expected {expected_file}")
        if data["native_dimensions"] != png_size(screenshot):
            raise SystemExit(f"{sidecar} dimension does not match its PNG")
        if data["untouched_source"] is not True:
            raise SystemExit(f"{sidecar} is not marked as an untouched source")
        method = str(data["capture_method"])
        if data["platform"] == "android" and "adb exec-out screencap" not in method:
            raise SystemExit(f"{sidecar} does not identify Android framebuffer capture")
        if data["platform"] == "ios" and "simctl io screenshot" not in method:
            raise SystemExit(f"{sidecar} does not identify Simulator framebuffer capture")

    manifest = json.loads(
        (ROOT / "store_assets" / "metadata" / "source_captures.json").read_text(
            encoding="utf-8"
        )
    )
    if len(manifest) != 60:
        raise SystemExit(f"Expected 60 manifest records, found {len(manifest)}")
    print("Validated metadata for 60 native screenshots.")


if __name__ == "__main__":
    main()
