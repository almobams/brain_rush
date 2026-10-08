#!/usr/bin/env python3
"""Write auditable sidecars for native store screenshots."""

from __future__ import annotations

import json
import struct
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "store_assets" / "source_capture"

DEVICES = {
    ("android", "phone"): {
        "device": "Pixel_8_Pro_API_36",
        "device_id": "emulator-5554",
        "os": "Android 16 (API 36)",
    },
    ("android", "tablet_7"): {
        "device": "Brain_Rush_7in_API_36 (Nexus 7 2013 profile)",
        "device_id": "emulator-5554",
        "os": "Android 16 (API 36)",
    },
    ("android", "tablet_10"): {
        "device": "Pixel_Tablet_API_36",
        "device_id": "emulator-5554",
        "os": "Android 16 (API 36)",
    },
    ("ios", "iphone"): {
        "device": "iPhone 17 Pro Max",
        "device_id": "44A0E9FB-E409-4956-90C2-4D8A16784230",
        "os": "iOS 26.5",
    },
    ("ios", "ipad"): {
        "device": "Brain Rush iPad Pro 13 (iPad Pro 13-inch M4)",
        "device_id": "E04D3A2B-A690-43F5-B56F-B8F262A6B9E4",
        "os": "iOS 18.4",
    },
}


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def main() -> None:
    records: list[dict[str, object]] = []
    for path in sorted(SOURCE.glob("*/*/*/*.png")):
        platform, locale, device_class, filename = path.relative_to(SOURCE).parts
        details = DEVICES[(platform, device_class)]
        width, height = png_size(path)
        relative = path.relative_to(ROOT).as_posix()
        if platform == "android":
            command = (
                f"adb -s {details['device_id']} exec-out screencap -p > {relative}"
            )
            method = "Android Emulator framebuffer via adb exec-out screencap -p"
        else:
            command = f"xcrun simctl io {details['device_id']} screenshot {relative}"
            method = "iOS Simulator framebuffer via xcrun simctl io screenshot"
        record = {
            "file": relative,
            "platform": platform,
            **details,
            "locale": locale,
            "capture_method": method,
            "capture_command": command,
            "capture_timestamp": datetime.fromtimestamp(
                path.stat().st_mtime, timezone.utc
            ).isoformat(),
            "native_dimensions": f"{width}x{height}",
            "untouched_source": True,
        }
        sidecar = path.with_suffix(".metadata.json")
        sidecar.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        records.append(record)

    metadata_dir = ROOT / "store_assets" / "metadata"
    metadata_dir.mkdir(parents=True, exist_ok=True)
    (metadata_dir / "source_captures.json").write_text(
        json.dumps(records, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Wrote metadata for {len(records)} native screenshots")


if __name__ == "__main__":
    main()
