"""Exercise the workflow's actual version preparation code without GitHub writes."""

import base64
import contextlib
import io
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / ".github/scripts"))
from release_notes import release_notes
from prepare_promotion import promotion_plan

WORKFLOW = yaml.load(
    (ROOT / ".github/workflows/prepare_version.yaml").read_text(encoding="utf-8"),
    Loader=yaml.BaseLoader,
)
PREPARE = next(
    step["run"] for step in WORKFLOW["jobs"]["prepare_version"]["steps"]
    if step.get("id") == "prepare"
).split("python3 <<'PY'\n", 1)[1].rsplit("\nPY", 1)[0]
NOTES = "### Fixed\n\n- Correct CI configuration."
CHANGELOG = "# Changelog\n\n## Unreleased\n\n" + NOTES + "\n"


class PrepareVersionTests(unittest.TestCase):
    def setUp(self):
        scratch = ROOT / ".dart_tool"
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="ci-version-test-", dir=scratch)
        self.directory = Path(self.temp.name).resolve()
        # TemporaryDirectory recursively cleans only this verified workspace path.
        self.assertTrue(self.directory.is_relative_to(scratch.resolve()))
        self.addCleanup(self.temp.cleanup)
        self.pubspec = self.directory / "pubspec.yaml"
        self.changelog = self.directory / "CHANGELOG.md"
        self.pubspec.write_text("name: fixture\nversion: 0.0.0\n", encoding="utf-8")
        self.changelog.write_text(CHANGELOG, encoding="utf-8")

    def run_prepare(self, version="0.0.1", notes=NOTES, encoded=None):
        output = self.directory / "outputs"
        output.write_text("", encoding="utf-8")
        env = {
            "TARGET_VERSION": version,
            "CHANGELOG_INPUT_BASE64": encoded if encoded is not None else base64.b64encode(notes.encode()).decode(),
            "GITHUB_OUTPUT": str(output),
        }
        original = Path.cwd()
        code = 0
        try:
            os.chdir(self.directory)
            with patch.dict(os.environ, env), contextlib.redirect_stdout(io.StringIO()):
                try:
                    exec(compile(PREPARE, "prepare_version.yaml", "exec"), {})
                except SystemExit as error:
                    code = error.code
        finally:
            os.chdir(original)
        outputs = dict(line.split("=", 1) for line in output.read_text(encoding="utf-8").splitlines())
        return code, outputs

    def test_bootstrap_can_prepare_first_release(self):
        code, outputs = self.run_prepare()
        self.assertEqual(code, 0)
        self.assertEqual(outputs["state"], "NEW_PREPARATION")
        self.assertIn("version: 0.0.1\n", self.pubspec.read_text())
        self.assertEqual(release_notes(self.pubspec.read_text(), self.changelog.read_text(), "v0.0.1"), NOTES + "\n")
        self.assertIn("## Unreleased\n", self.changelog.read_text())

    def test_identical_retry_is_idempotent(self):
        self.run_prepare()
        before = self.changelog.read_bytes()
        code, outputs = self.run_prepare()
        self.assertEqual(code, 0)
        self.assertEqual(outputs["state"], "VERSION_ALREADY_PREPARED")
        self.assertEqual(self.changelog.read_bytes(), before)

    def test_version_edit_preserves_following_comments_and_configuration(self):
        suffix = "\n# Repository metadata\nenvironment:\n  sdk: ^3.13.2\n"
        self.pubspec.write_text("name: fixture\nversion: 0.0.0\n" + suffix)
        code, _ = self.run_prepare()
        self.assertEqual(code, 0)
        self.assertEqual(self.pubspec.read_text(), "name: fixture\nversion: 0.0.1\n" + suffix)

    def test_retry_with_different_notes_is_rejected(self):
        self.run_prepare()
        code, outputs = self.run_prepare(notes="### Fixed\n- Different notes.")
        self.assertEqual((code, outputs["state"]), (1, "VERSION_STATE_INCONSISTENT"))

    def test_invalid_versions_leave_files_unchanged(self):
        for version in ["1.0.0+1", "1.0.0-beta.1", "01.0.0", "garbage"]:
            with self.subTest(version=version):
                before = self.pubspec.read_bytes(), self.changelog.read_bytes()
                code, outputs = self.run_prepare(version)
                self.assertEqual((code, outputs["state"]), (1, "VERSION_INPUT_INVALID"))
                self.assertEqual((self.pubspec.read_bytes(), self.changelog.read_bytes()), before)

    def test_version_regression_is_rejected(self):
        self.pubspec.write_text("version: 0.2.0\n")
        code, outputs = self.run_prepare("0.1.9")
        self.assertEqual((code, outputs["state"]), (1, "VERSION_REGRESSION"))

    def test_numeric_version_order_and_previous_releases(self):
        self.pubspec.write_text("version: 0.9.0\n")
        old = "\n## [0.9.0] - 2026-09-01\n\n### Added\n- Old feature.\n"
        self.changelog.write_text(CHANGELOG + old)
        code, _ = self.run_prepare("0.10.0")
        self.assertEqual(code, 0)
        self.assertTrue(self.changelog.read_text().endswith(old))

    def test_empty_unreleased_is_rejected(self):
        self.changelog.write_text("# Changelog\n\n## Unreleased\n")
        code, outputs = self.run_prepare()
        self.assertEqual((code, outputs["state"]), (1, "UNRELEASED_EMPTY"))

    def test_promotion_uses_patch_history_when_unreleased_is_empty(self):
        self.pubspec.write_text("name: fixture\nversion: 0.0.3\n", encoding="utf-8")
        history = "\n## [0.0.3] - 2026-09-12\n\n### Added\n\n- Recorded patch.\n"
        self.changelog.write_text("# Changelog\n\n## Unreleased\n" + history, encoding="utf-8")
        plan = promotion_plan(self.pubspec.read_text(), self.changelog.read_text(), "0.0.3", "minor")
        with patch.dict(os.environ, {"PROMOTION": "true"}):
            code, outputs = self.run_prepare(plan["version"], notes=plan["notes"])
        self.assertEqual((code, outputs["state"]), (0, "NEW_PREPARATION"))
        self.assertTrue(self.changelog.read_text().endswith(history))
        retry = promotion_plan(self.pubspec.read_text(), self.changelog.read_text(), "0.0.3", "minor")
        with patch.dict(os.environ, {"PROMOTION": "true"}):
            code, outputs = self.run_prepare(retry["version"], notes=retry["notes"])
        self.assertEqual((code, outputs["state"]), (0, "VERSION_ALREADY_PREPARED"))

    def test_duplicate_unreleased_is_rejected(self):
        self.changelog.write_text(CHANGELOG + "\n## Unreleased\n")
        code, outputs = self.run_prepare()
        self.assertEqual((code, outputs["state"]), (1, "VERSION_STATE_INCONSISTENT"))

    def test_invalid_base64_is_rejected(self):
        code, outputs = self.run_prepare(encoded="not base64!")
        self.assertEqual((code, outputs["state"]), (1, "CHANGELOG_INPUT_INVALID"))

    def test_release_notes_cannot_inject_version_headings(self):
        code, outputs = self.run_prepare(notes=NOTES + "\n## [9.0.0] - 2026-09-01")
        self.assertEqual((code, outputs["state"]), (1, "CHANGELOG_INPUT_INVALID"))


class ReleaseTagTests(unittest.TestCase):
    def test_tag_mismatch_and_bootstrap_are_rejected(self):
        for version, tag in [("0.0.0", "v0.0.0"), ("0.1.0", "v0.2.0")]:
            with self.subTest(version=version), self.assertRaises(ValueError):
                release_notes(f"version: {version}", CHANGELOG, tag)

    def test_missing_duplicate_and_empty_release_entries_are_rejected(self):
        heading = "\n## [0.1.0] - 2026-09-12\n"
        for changelog in [CHANGELOG, heading + NOTES + heading + NOTES, heading + "### Fixed\n"]:
            with self.subTest(changelog=changelog), self.assertRaises(ValueError):
                release_notes("version: 0.1.0", changelog, "v0.1.0")


if __name__ == "__main__":
    unittest.main()
