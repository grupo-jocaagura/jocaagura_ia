"""Run coverage boundary cases and syntax checks against the actual workflows."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[3]
BASH = shutil.which("bash")
if BASH is None and os.name == "nt":
    candidate = Path("C:/Program Files/Git/bin/bash.exe")
    if candidate.is_file():
        BASH = str(candidate)
WORKFLOWS = {
    path.name: yaml.load(path.read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
    for path in (ROOT / ".github/workflows").iterdir()
    if path.suffix in (".yaml", ".yml")
}


@unittest.skipUnless(BASH, "Bash is required to execute workflow scripts")
class WorkflowTests(unittest.TestCase):
    def test_embedded_bash_and_python_syntax(self):
        for filename, workflow in WORKFLOWS.items():
            for job in workflow["jobs"].values():
                for step in job.get("steps", []):
                    if "run" not in step:
                        continue
                    script = re.sub(r"\$\{\{.*?\}\}", "fixture", step["run"])
                    with self.subTest(file=filename, step=step.get("name")):
                        result = subprocess.run([BASH, "--noprofile", "--norc", "-n"], input=script, encoding="utf-8", capture_output=True)
                        self.assertEqual(result.returncode, 0, result.stderr)
                        for embedded in re.findall(r"python3 <<'PY'\n(.*?)\nPY", script, re.DOTALL):
                            compile(embedded, filename, "exec")

    def test_coverage_threshold_uses_unrounded_values_and_rejects_empty_reports(self):
        steps = WORKFLOWS["validate_pr.yaml"]["jobs"]["test_and_coverage"]["steps"]
        script = next(step["run"] for step in steps if step.get("id") == "coverage")
        scratch = ROOT / ".dart_tool"
        scratch.mkdir(exist_ok=True)
        for covered, total, required, expected in [(95, 100, "95", "pass"), (94999, 100000, "95", "fail"), (0, 0, "95", "fail"), (99, 100, "100", "fail"), (1, 1, "100", "pass")]:
            with self.subTest(covered=covered, total=total, required=required):
                temporary = tempfile.TemporaryDirectory(prefix="ci-coverage-test-", dir=scratch)
                directory = Path(temporary.name).resolve()
                self.assertTrue(directory.is_relative_to(scratch.resolve()))
                with temporary:
                    report = directory / "lcov.info"
                    report.write_text(f"SF:lib/example.dart\nLF:{total}\nLH:{covered}\nend_of_record\n", newline="\n")
                    (directory / "coverage_files.txt").write_text(report.as_posix() + "\n", newline="\n")
                    output = directory / "output"
                    env = dict(os.environ, RUNNER_TEMP=directory.as_posix(), GITHUB_OUTPUT=output.as_posix(), COVERAGE_MIN=required)
                    result = subprocess.run([BASH, "--noprofile", "--norc"], input=script, encoding="utf-8", capture_output=True, env=env)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertIn(f"gate={expected}\n", output.read_text())

    def test_repository_variable_cannot_lower_coverage_below_95(self):
        steps = WORKFLOWS["validate_pr.yaml"]["jobs"]["test_and_coverage"]["steps"]
        script = steps[0]["run"]
        for threshold, expected in [("95", 0), ("100", 0), ("94.9", 1), ("101", 1), ("NaN", 1), ("", 1)]:
            with self.subTest(threshold=threshold):
                result = subprocess.run([BASH, "--noprofile", "--norc"], input=script, encoding="utf-8", capture_output=True, env=dict(os.environ, COVERAGE_MIN=threshold))
                self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

    def test_core_coverage_cannot_hide_an_uncovered_server(self):
        steps = WORKFLOWS["validate_pr.yaml"]["jobs"]["test_and_coverage"]["steps"]
        script = next(step["run"] for step in steps if step.get("id") == "coverage")
        scratch = ROOT / ".dart_tool"
        scratch.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="ci-packages-", dir=scratch) as name:
            directory = Path(name).resolve()
            reports = []
            for package, covered, total in [("core", 1000, 1000), ("server", 0, 10)]:
                report = directory / f"{package}.info"
                report.write_text(f"SF:lib/example.dart\nLF:{total}\nLH:{covered}\nend_of_record\n", newline="\n")
                reports.append(report.as_posix())
            (directory / "coverage_files.txt").write_text("\n".join(reports) + "\n", newline="\n")
            output = directory / "output"
            result = subprocess.run([BASH, "--noprofile", "--norc"], input=script, encoding="utf-8", capture_output=True,
                                    env=dict(os.environ, RUNNER_TEMP=directory.as_posix(), GITHUB_OUTPUT=output.as_posix(), COVERAGE_MIN="95"))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("gate=fail\n", output.read_text())

    def test_commit_comparisons_paginate_and_fail_on_partial_api_errors(self):
        steps = WORKFLOWS["validate_commits_and_lints.yaml"]["jobs"]["validate"]["steps"]
        source = next(step["run"] for step in steps if step.get("id") == "commits")
        functions = source[source.index("get_commit_shas_push() {"):source.index('case "$GITHUB_EVENT_NAME"')]
        for function in ["get_commit_shas_push", "get_commit_shas_pull_request"]:
            for failure in [False, True]:
                with self.subTest(function=function, failure=failure):
                    mock = '''
set -euo pipefail
OWNER=fixture REPO=fixture GITHUB_EVENT_PATH=fixture
jq() { printf '%s' abc123; }
gh() {
  [[ "$*" == *--paginate* && "$*" == *per_page=100* ]] || return 99
  seq 1 251
'''
                    mock += "return 1\n}\n" if failure else "}\n"
                    script = mock + functions + f'\nSHAS="$({function})"\nprintf "%s\\n" "$SHAS"\n'
                    result = subprocess.run([BASH, "--noprofile", "--norc"], input=script, encoding="utf-8", capture_output=True)
                    self.assertEqual(result.returncode, 1 if failure else 0, result.stderr)
                    if not failure:
                        self.assertEqual(len(result.stdout.splitlines()), 251)
