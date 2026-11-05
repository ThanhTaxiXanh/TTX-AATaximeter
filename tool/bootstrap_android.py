#!/usr/bin/env python3
"""Idempotently configure Flutter-generated Android build for TTX.

Copy a native Flutter MethodChannel and experimental CarAppService scaffold.
The car service is intentionally NOT registered in AndroidManifest because
taximeter-only behavior does not meet a verified Android Auto app category.
"""
from pathlib import Path
from shutil import copy2
import os
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
    "android.permission.ACCESS_BACKGROUND_LOCATION",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_LOCATION",
    "android.permission.WAKE_LOCK",
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


# Match Android's launch surface to the Flutter dark UI: never flash a
# default white background while Android initializes its native plugins.
# The app still renders the interactive Flutter view after normal startup.
dark_launch = """<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
  <item android:drawable="@android:color/black" />
</layer-list>
"""
for folder in ("drawable", "drawable-v21"):
    file = Path("android/app/src/main/res") / folder / "launch_background.xml"
    if file.is_file():
        file.write_text(dark_launch, encoding="utf-8")

for folder in ("values", "values-night"):
    style_path = Path("android/app/src/main/res") / folder / "styles.xml"
    if not style_path.is_file():
        continue
    style_tree = ET.parse(style_path)
    for style in style_tree.getroot().findall("style"):
        if style.attrib.get("name") in ("LaunchTheme", "NormalTheme"):
            item = next((node for node in style.findall("item")
                         if node.attrib.get("name") == "android:windowBackground"),
                        None)
            if item is None:
                item = ET.SubElement(style, "item",
                                     {"name": "android:windowBackground"})
            item.text = "@drawable/launch_background"
    style_tree.write(style_path, encoding="utf-8", xml_declaration=True)

# Android 12+ uses a system-rendered splash before Flutter's first frame.
v31 = Path("android/app/src/main/res/values-v31/styles.xml")
v31.parent.mkdir(parents=True, exist_ok=True)
v31.write_text("""<?xml version="1.0" encoding="utf-8"?>
<resources>
  <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
    <item name="android:windowSplashScreenBackground">#09090A</item>
    <item name="android:windowBackground">@drawable/launch_background</item>
  </style>
</resources>
""", encoding="utf-8")

gradle = Path("android/app/build.gradle.kts")
if not gradle.is_file():
    raise SystemExit("Flutter-generated Kotlin Gradle file is required")
content = gradle.read_text()

# These CarAppService classes are NOT registered in AndroidManifest and have
# no working Android Auto UI. Excluding them from ordinary phone APKs removes
# unused AndroidX Car dependencies without changing the Flutter taximeter,
# the native MethodChannel, GPS/FGS or local trip data.
# To develop the future Android Auto scaffold, explicitly opt in during
# bootstrap: TTX_INCLUDE_CAR_SCAFFOLD=1 python3 tool/bootstrap_android.py
include_car_scaffold = os.getenv("TTX_INCLUDE_CAR_SCAFFOLD") == "1"

source = Path("tool/android_templates")
target = Path(
    "android/app/src/main/kotlin/vn/thanhtaxixanh/ttx_aataximeter"
)
target.mkdir(parents=True, exist_ok=True)

# The MethodChannel and display state mirror are still used on the phone.
for name in ("MainActivity.kt", "CarStateStore.kt"):
    copy2(source / name, target / name)

optional_car_sources = ("TtxCarAppService.kt", "TtxCarScreen.kt")
if include_car_scaffold:
    for name in optional_car_sources:
        copy2(source / name, target / name)
    if "androidx.car.app:app:1.7.0" not in content:
        content += """
// Experimental (unregistered) Android Auto display scaffold. Explicit opt-in.
dependencies {
    implementation("androidx.car.app:app:1.7.0")
    implementation("androidx.car.app:app-projected:1.7.0")
}
"""
else:
    # Idempotency: running bootstrap a second time must not retain optional
    # Android for Cars classes from a previous opt-in invocation.
    for name in optional_car_sources:
        (target / name).unlink(missing_ok=True)
    if "androidx.car.app:app:1.7.0" in content:
        content = content.replace("""
// Experimental (unregistered) Android Auto display scaffold. Explicit opt-in.
dependencies {
    implementation("androidx.car.app:app:1.7.0")
    implementation("androidx.car.app:app-projected:1.7.0")
}
""", "")
        content = content.replace("""
// Android for Cars read-only scaffold. NOT registered as a CarAppService.
dependencies {
    implementation("androidx.car.app:app:1.7.0")
    implementation("androidx.car.app:app-projected:1.7.0")
}
""", "")
gradle.write_text(content)

print("Android GPS permissions and native Flutter display bridge installed.")
print("Experimental CarAppService compiled:", include_car_scaffold)
print("CarAppService is still unregistered; no eligible Android Auto host yet.")
