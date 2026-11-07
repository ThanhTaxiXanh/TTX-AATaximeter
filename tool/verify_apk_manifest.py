#!/usr/bin/env python3
"""Verify Android merged binary manifest in the built APK, not source guesses.

Android 14+ requires foreground location type and matching permissions.
The CarAppService skeleton must remain unregistered until classification is
verified. This check does not prove GPS works on a physical device.
"""
from pathlib import Path
import os
import re
import subprocess
import sys

apk = Path("build/app/outputs/flutter-apk/app-debug.apk")
sdk = Path(os.getenv("ANDROID_HOME") or os.getenv("ANDROID_SDK_ROOT") or
           "/usr/local/lib/android/sdk")
tools = list((sdk / "build-tools").glob("*/aapt"))
if not apk.is_file():
    raise SystemExit(f"Missing built APK: {apk}")
if not tools:
    raise SystemExit(f"No aapt found in SDK: {sdk}")

# Numeric newest release, not lexicographic 9 > 35.
def release(path: Path) -> tuple[int, ...]:
    return tuple(int(x) for x in re.findall(r"\d+", path.parent.name))

aapt = sorted(tools, key=release)[-1]
manifest = subprocess.check_output(
    [str(aapt), "dump", "xmltree", str(apk), "AndroidManifest.xml"],
    text=True, stderr=subprocess.STDOUT,
)
permissions = subprocess.check_output(
    [str(aapt), "dump", "permissions", str(apk)],
    text=True, stderr=subprocess.STDOUT,
)
required = (
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_BACKGROUND_LOCATION",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_LOCATION",
    "android.permission.WAKE_LOCK",
)
missing = [name for name in required if name not in permissions]
if missing:
    raise SystemExit("Missing permissions in APK: " + ", ".join(missing))

# GeolocatorLocationService must be declared in the merged APK by the plugin.
service = "com.baseflow.geolocator.GeolocatorLocationService"
offset = manifest.find(service)
if offset < 0:
    raise SystemExit(f"No Geolocator location service in APK: {service}")
# Each service attribute appears on subsequent lines (its subtree).
scope = manifest[offset:offset + 1300]
if not re.search(r"foregroundServiceType.*(?:0x0*8\b|\blocation\b)",
                 scope, re.IGNORECASE):
    raise SystemExit(
        "GeolocatorLocationService exists but type location(0x8) not found "
        "in following manifest attributes"
    )

if "TtxCarAppService" in manifest:
    raise SystemExit(
        "Experimental taxi-only CarAppService must not be registered "
        "as an unsupported Android Auto category"
    )
print("APK_MERGED_MANIFEST_OK")
print("Confirmed permissions:", ", ".join(required))
print("Confirmed geolocator service foreground type=location")
print("Android Auto taximeter scaffold is NOT registered.")
