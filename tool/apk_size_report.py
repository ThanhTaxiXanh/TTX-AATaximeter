#!/usr/bin/env python3
"""Read-only APK size breakdown by ZIP contents (no Android SDK needed).

Use GitHub Actions output to compare universal Debug vs ARM64 Release.
Do not confuse archive/APK size with the installed app size.
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
from zipfile import ZipFile


def report(path: Path) -> str:
    if not path.is_file():
        raise FileNotFoundError(path)
    categories: dict[str, int] = defaultdict(int)
    native_libs: dict[str, int] = defaultdict(int)
    with ZipFile(path) as archive:
        for entry in archive.infolist():
            if entry.is_dir():
                continue
            name = entry.filename
            # Group by APK uncompressed payload categories; numbers are
            # advisory because APK compression/alignment also takes space.
            if name.startswith("lib/"):
                category = "Native libraries"
                parts = name.split("/")
                if len(parts) > 2:
                    native_libs[parts[1]] += entry.file_size
            elif name.startswith("assets/") or "flutter_assets" in name:
                category = "Flutter assets"
            elif name.endswith(".dex"):
                category = "DEX bytecode"
            elif name.startswith("res/") or name == "resources.arsc":
                category = "Android resources"
            else:
                category = "Other files"
            categories[category] += entry.file_size
    to_mb = lambda n: f"{n / 1_000_000:.2f} MB"
    lines = [
        f"APK file: {path.name}",
        f"APK size: {to_mb(path.stat().st_size)} ({path.stat().st_size} bytes)",
        "",
        "Uncompressed content by category (not additively comparable to APK size):",
        *[f"  {key}: {to_mb(size)}"
          for key, size in sorted(categories.items(), key=lambda x: -x[1])],
        "",
        "Native libraries by ABI:",
        *([f"  {abi}: {to_mb(size)}"
            for abi, size in sorted(native_libs.items())] or ["  none"]),
    ]
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("apk", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    content = report(args.apk)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(content, encoding="utf-8")
    else:
        print(content, end="")


if __name__ == "__main__":
    main()
