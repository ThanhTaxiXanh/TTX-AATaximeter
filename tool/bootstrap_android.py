#!/usr/bin/env python3
"""Idempotently add foreground GPS permissions to a flutter-created Android manifest."""
from pathlib import Path
from xml.etree import ElementTree as ET

path = Path("android/app/src/main/AndroidManifest.xml")
if not path.is_file():
    raise SystemExit("Generate android/ using flutter create first")
uri = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", uri)
tree = ET.parse(path)
root = tree.getroot()
for permission in [
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
]:
    if not any(item.tag == "uses-permission"
               and item.attrib.get("{" + uri + "}name") == permission
               for item in root):
        root.insert(0, ET.Element("uses-permission", {"{" + uri + "}name": permission}))
tree.write(path, encoding="utf-8", xml_declaration=True)
print("Android GPS permissions configured:", path)
