"""Promotion arithmetic, changelog boundaries and retry behavior."""

from pathlib import Path
import os
import subprocess
import tempfile
import yaml
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / ".github/scripts"))
from prepare_promotion import promotion_plan
from release_policy import publication_state


def entry(version, note):
    return f"\n## [{version}] - 2026-09-12\n\n### Added\n\n- {note}\n"


def spec(version):
    return f"version: {version}\n"


class PromotionTests(unittest.TestCase):
    def setUp(self):
        self.history = "# Changelog\n\n## Unreleased\n\n### Fixed\n\n- Pending fix.\n" + entry("0.0.3", "Three.") + entry("0.0.2", "Two.") + entry("0.0.1", "One.")

    def test_minor_consolidates_patches_and_unreleased_without_editing_history(self):
        original = self.history
        plan = promotion_plan(spec("0.0.3"), self.history, "0.0.3", "minor")
        self.assertEqual(plan["version"], "0.1.0")
        self.assertEqual(plan["patches"], ["0.0.3", "0.0.2", "0.0.1"])
        for note in ["Pending fix.", "Three.", "Two.", "One."]:
            self.assertIn(note, plan["notes"])
        self.assertEqual(self.history, original)

    def test_major_and_numeric_minor_increment(self):
        self.assertEqual(promotion_plan(spec("0.0.3"), self.history, "0.0.3", "major")["version"], "1.0.0")
        history = "# Changelog\n\n## Unreleased\n" + entry("2.9.12", "New.") + entry("2.9.0", "Old release.")
        self.assertEqual(promotion_plan(spec("2.9.12"), history, "2.9.12", "minor")["version"], "2.10.0")
        self.assertEqual(promotion_plan(spec("2.9.12"), history, "2.9.12", "major")["version"], "3.0.0")

    def test_already_promoted_history_is_not_reaggregated(self):
        history = "# Changelog\n\n## Unreleased\n" + entry("0.1.2", "New patch.") + entry("0.1.0", "Old promotion.") + entry("0.0.3", "Already shipped.")
        plan = promotion_plan(spec("0.1.2"), history, "0.1.2", "major")
        self.assertEqual(plan["patches"], ["0.1.2"])
        self.assertIn("New patch.", plan["notes"])
        self.assertNotIn("Old promotion.", plan["notes"])
        self.assertNotIn("Already shipped.", plan["notes"])

    def test_retry_keeps_the_same_target_instead_of_bumping_again(self):
        plan = promotion_plan(spec("0.0.3"), self.history, "0.0.3", "minor")
        prepared = "# Changelog\n\n## Unreleased\n\n## [0.1.0] - 2026-09-12\n\n" + plan["notes"] + entry("0.0.3", "Three.") + entry("0.0.2", "Two.") + entry("0.0.1", "One.")
        retry = promotion_plan(spec("0.1.0"), prepared, "0.0.3", "minor")
        self.assertEqual(retry["state"], "already_prepared")
        self.assertEqual(retry["version"], "0.1.0")
        self.assertEqual(retry["notes"], plan["notes"])
        with self.assertRaises(ValueError):
            promotion_plan(spec("0.1.0"), prepared.replace("## Unreleased\n", "## Unreleased\n\n### Fixed\n- Later work.\n"), "0.0.3", "minor")

    def test_empty_unreleased_can_promote_recorded_patches(self):
        plan = promotion_plan(spec("0.0.3"), "# Changelog\n\n## Unreleased\n" + entry("0.0.3", "Ready patch."), "0.0.3", "minor")
        self.assertIn("Ready patch.", plan["notes"])

    def test_bad_inputs_and_inconsistent_history_fail_closed(self):
        cases = [
            (spec("0.0.4"), self.history, "0.0.3", "minor"),
            (spec("0.0.3"), self.history, "0.0.3", "patch"),
            (spec("0.0.3"), self.history, "00.0.3", "major"),
            (spec("0.0.3"), self.history + entry("0.0.3", "Duplicate."), "0.0.3", "minor"),
            (spec("0.0.3"), self.history + entry("0.1.0", "Conflicting target."), "0.0.3", "minor"),
            (spec("0.0.3"), self.history.replace("### Fixed", "### Unknown"), "0.0.3", "minor"),
            (spec("0.0.3"), self.history.replace("## Unreleased", "## Unsupported"), "0.0.3", "minor"),
            (spec("0.0.3"), "# Changelog\n\n## Unreleased\n", "0.0.3", "minor"),
            (spec("0.1.0"), "# Changelog\n\n## Unreleased\n" + entry("0.1.0", "Previously released."), "0.1.0", "minor"),
        ]
        for inputs in cases:
            with self.subTest(inputs=inputs), self.assertRaises(ValueError):
                promotion_plan(*inputs)

    def test_workflow_rejects_develop_movement_before_preparation(self):
        bash = Path("C:/Program Files/Git/bin/bash.exe") if os.name == "nt" else Path("/bin/bash")
        if not bash.exists():
            self.skipTest("Bash required")
        current = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        scratch = ROOT / ".dart_tool"
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="promotion-head-test-", dir=scratch) as name:
            directory = Path(name).resolve()
            self.assertTrue(directory.is_relative_to(scratch.resolve()))
            for filename, job, env_key in [("prepare_promotion.yaml", "plan", "DISPATCH_SHA"), ("prepare_version.yaml", "prepare_version", "EXPECTED_HEAD")]:
                workflow = yaml.load((ROOT / ".github/workflows" / filename).read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
                script = next(step["run"] for step in workflow["jobs"][job]["steps"] if step.get("id") == "head")
                for sha, expected in [(current, 0), ("0" * 40, 1)]:
                    env = dict(os.environ, GITHUB_OUTPUT=(directory / "outputs").as_posix(), **{env_key: sha})
                    result = subprocess.run([str(bash), "--noprofile", "--norc", "-e"], input=script, text=True, capture_output=True, cwd=ROOT, env=env)
                    with self.subTest(workflow=filename, sha=sha):
                        self.assertEqual(result.returncode, expected, result.stderr)

    def test_automated_publisher_refuses_patches_even_if_already_published(self):
        for package in [None, {"name": "jocaagura_ai", "versions": [{"version": "0.0.3"}]}]:
            with self.assertRaisesRegex(ValueError, "minor or major"):
                publication_state("0.0.3", package)


if __name__ == "__main__":
    unittest.main()