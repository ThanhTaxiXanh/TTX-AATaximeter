#!/usr/bin/env python3
"""Configure an isolated, installable Android QA variant after flutter create.

ONLY run this when TTX_QA_BUILD=1. The published/production application ID is
never rewritten in committed Flutter app source; Flutter's generated Gradle
project is ephemeral in GitHub Actions.
"""
from pathlib import Path
import re
from xml.etree import ElementTree as ET

PRODUCTION_ID = "vn.thanhtaxixanh.ttx_aataximeter"
QA_ID = PRODUCTION_ID + ".qa"
QA_LABEL = "TTX Driver Pro QA"
ANDROID_URI = "http://schemas.android.com/apk/res/android"

_APPLICATION_ID = re.compile(
    r'(?m)^(?P<indent>\s*applicationId\s*=\s*")'
    r'(?P<id>[^"]+)(?P<close>")\s*$'
)


def configure_qa_identity(gradle: Path, manifest: Path) -> None:
    """Fail closed on unexpected Flutter templates or a foreign package ID.

    The namespace, native Kotlin MethodChannel package and service names must
    remain untouched. Only the installable Android applicationId changes.
    """
    if not gradle.is_file() or not manifest.is_file():
        raise RuntimeError("Expected Flutter-generated Gradle and manifest files")
    content = gradle.read_text(encoding="utf-8")
    matches = list(_APPLICATION_ID.finditer(content))
    if len(matches) != 1:
        raise RuntimeError("Expected exactly one Gradle applicationId assignment")
    actual = matches[0].group("id")
    if actual not in (PRODUCTION_ID, QA_ID):
        raise RuntimeError(f"Refusing to rewrite unexpected applicationId {actual!r}")
    if actual == PRODUCTION_ID:
        changed = _APPLICATION_ID.sub(
            lambda m: m.group("indent") + QA_ID + m.group("close"),
            content, count=1,
        )
        gradle.write_text(changed, encoding="utf-8")
    else:
        changed = content

    # Keep namespace unchanged: only Android's install identity is isolated.
    if f'namespace = "{PRODUCTION_ID}"' not in changed:
        raise RuntimeError("Flutter Kotlin namespace changed unexpectedly")

    tree = ET.parse(manifest)
    application = tree.getroot().find("application")
    if application is None:
        raise RuntimeError("No Android application entry in manifest")
    ET.register_namespace("android", ANDROID_URI)
    application.set(f"{{{ANDROID_URI}}}label", QA_LABEL)
    tree.write(manifest, encoding="utf-8", xml_declaration=True)


def assert_qa_identity(gradle: Path, manifest: Path) -> None:
    """Deterministic pre-build verification; also checked in actual APK."""
    content = gradle.read_text(encoding="utf-8")
    actual = list(_APPLICATION_ID.finditer(content))
    if len(actual) != 1 or actual[0].group("id") != QA_ID:
        raise RuntimeError("QA build must use an isolated applicationId")
    tree = ET.parse(manifest)
    app = tree.getroot().find("application")
    if app is None or app.get(f"{{{ANDROID_URI}}}label") != QA_LABEL:
        raise RuntimeError("QA build must carry its own visible launcher label")
