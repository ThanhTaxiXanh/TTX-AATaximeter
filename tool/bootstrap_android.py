#!/usr/bin/env python3
"""Idempotently configure Flutter-generated Android build for TTX.

Copy a native Flutter MethodChannel and experimental CarAppService scaffold.
The car service is intentionally NOT registered in AndroidManifest because
taximeter-only behavior does not meet a verified Android Auto app category.
"""
from pathlib import Path
from shutil import copy2
from xml.etree import ElementTree as ET

path = Path("android/app/src/main/AndroidManifest.xml")
if not path.is_file():
    raise SystemExit("Generate android/ using flutter create first")
uri = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", uri)
tree = ET.parse(path)
root = tree.getroot()
for permission in (
    "android.permission.INTERNET",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.ACCESS_FINE_LOCATION",
):
    if not any(
        node.tag == "uses-permission"
        and node.attrib.get("{" + uri + "}name") == permission
        for node in root
    ):
        root.insert(0, ET.Element("uses-permission", {"{" + uri + "}name": permission}))
app = root.find("application")
if app is not None:
    app.set("{" + uri + "}label", "TTX AATaximeter")
tree.write(path, encoding="utf-8", xml_declaration=True)

gradle = Path("android/app/build.gradle.kts")
if not gradle.is_file():
    raise SystemExit("Flutter-generated Kotlin Gradle file is required")
content = gradle.read_text()
if "androidx.car.app:app:1.7.0" not in content:
    content += """
// Android for Cars read-only scaffold. NOT registered as a CarAppService.
dependencies {
    implementation("androidx.car.app:app:1.7.0")
    implementation("androidx.car.app:app-projected:1.7.0")
}
"""
    gradle.write_text(content)

source = Path("tool/android_templates")
target = Path(
    "android/app/src/main/kotlin/vn/thanhtaxixanh/ttx_aataximeter"
)
target.mkdir(parents=True, exist_ok=True)
for name in ("MainActivity.kt", "CarStateStore.kt",
             "TtxCarAppService.kt", "TtxCarScreen.kt"):
    copy2(source / name, target / name)

print("Android GPS permissions, Flutter bridge and native scaffold installed.")
print("CarAppService not registered: no verified eligible Android Auto category.")
