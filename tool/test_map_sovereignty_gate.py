"""Regression guard for Vietnam map policy and external publication gate."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import check_map_sovereignty as policy  # noqa: E402


class MapSovereigntyCI(unittest.TestCase):
    def test_source_gate_is_wired_for_all_map_changes(self):
        self.assertEqual(policy.check_source(), [])

    def test_external_publication_fails_closed_without_evidence(self):
        errors = policy.check_publication()
        self.assertTrue(errors)
        self.assertTrue(any("NOT CERTIFIED" in x for x in errors))
        self.assertTrue(any("raster_tiles" in x for x in errors))
        self.assertTrue(any("vector_style_and_tiles" in x for x in errors))
        self.assertTrue(any("search_results" in x for x in errors))
        self.assertTrue(any("screenshots_and_exports" in x for x in errors))

    def test_policy_has_all_three_vietnamese_names_and_reviewed_urls(self):
        self.assertEqual(set(policy.EXPECTED_LABELS),
                         {"hoangSa", "truongSa", "bienDong"})
        self.assertEqual(len(policy.EXPECTED_SOURCES), 3)
        for label in policy.EXPECTED_LABELS.values():
            self.assertIn(label, policy.POLICY.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
