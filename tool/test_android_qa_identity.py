#!/usr/bin/env python3
"""Test independent QA install identity without Android SDK or Flutter."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from xml.etree import ElementTree as ET

from android_qa_identity import (
    PRODUCTION_ID, QA_ID, QA_LABEL, ANDROID_URI,
    configure_qa_identity, assert_qa_identity,
)


class QaIdentityTests(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.gradle = root / "build.gradle.kts"
        self.manifest = root / "AndroidManifest.xml"
        self.gradle.write_text(
            'android {\n'
            f'    namespace = "{PRODUCTION_ID}"\n'
            '    defaultConfig {\n'
            f'        applicationId = "{PRODUCTION_ID}"\n'
            '    }\n'
            '}\n', encoding="utf-8",
        )
        self.manifest.write_text(
            '<?xml version="1.0" encoding="utf-8"?>'
            f'<manifest xmlns:android="{ANDROID_URI}">'
            '<application android:label="TTX AATaximeter" />'
            '</manifest>', encoding="utf-8",
        )

    def test_isolated_id_data_sandbox_and_label(self):
        configure_qa_identity(self.gradle, self.manifest)
        assert_qa_identity(self.gradle, self.manifest)
        text = self.gradle.read_text(encoding="utf-8")
        self.assertIn(f'namespace = "{PRODUCTION_ID}"', text)
        self.assertIn(f'applicationId = "{QA_ID}"', text)
        self.assertNotIn(f'applicationId = "{PRODUCTION_ID}"', text)
        tree = ET.parse(self.manifest)
        self.assertEqual(
            tree.getroot().find("application").get(f"{{{ANDROID_URI}}}label"),
            QA_LABEL,
        )

    def test_idempotent_on_repeated_bootstrap(self):
        configure_qa_identity(self.gradle, self.manifest)
        before = self.gradle.read_text(encoding="utf-8")
        configure_qa_identity(self.gradle, self.manifest)
        self.assertEqual(before, self.gradle.read_text(encoding="utf-8"))
        assert_qa_identity(self.gradle, self.manifest)

    def test_refuses_unknown_or_malicious_package_ids(self):
        original = self.gradle.read_text(encoding="utf-8")
        unexpected = original.replace(
            f'applicationId = "{PRODUCTION_ID}"',
            'applicationId = "com.other.app"',
        )
        self.gradle.write_text(unexpected, encoding="utf-8")
        with self.assertRaisesRegex(RuntimeError, "unexpected applicationId"):
            configure_qa_identity(self.gradle, self.manifest)
        self.assertEqual(unexpected, self.gradle.read_text(encoding="utf-8"))

    def test_rejects_multiple_app_ids_in_future_template(self):
        source = self.gradle.read_text(encoding="utf-8")
        self.gradle.write_text(
            source + f'applicationId = "{PRODUCTION_ID}"\n',
            encoding="utf-8",
        )
        with self.assertRaisesRegex(RuntimeError, "exactly one"):
            configure_qa_identity(self.gradle, self.manifest)

    def test_fails_closed_if_namespace_is_not_expected(self):
        original = self.gradle.read_text(encoding="utf-8")
        self.gradle.write_text(
            original.replace(
                f'namespace = "{PRODUCTION_ID}"',
                'namespace = "com.other.unexpected"',
            ), encoding="utf-8",
        )
        with self.assertRaisesRegex(RuntimeError, "namespace changed"):
            configure_qa_identity(self.gradle, self.manifest)


if __name__ == "__main__":
    unittest.main()
