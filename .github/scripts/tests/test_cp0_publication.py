"""Fail-closed boundaries for the one-time real CP-0 publication experiment."""

import base64
from copy import deepcopy
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

import yaml

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / '.github/scripts'))
from cp0_publication import decode_claims, preflight, validate_claims

SHA = 'a' * 40
ENV = {
    'EXPECTED_SHA': SHA, 'EXPECTED_REPOSITORY_ID': '123', 'EXPECTED_OWNER_ID': '456',
    'GITHUB_RUN_ID': '789', 'GITHUB_RUN_ATTEMPT': '1',
}
CLAIMS = {
    'iss': 'https://token.actions.githubusercontent.com', 'aud': 'https://pub.dev',
    'event_name': 'workflow_dispatch', 'ref_type': 'tag', 'ref': 'refs/tags/v0.1.0',
    'repository': 'grupo-jocaagura/jocaagura_ia', 'repository_owner': 'grupo-jocaagura',
    'sha': SHA, 'repository_id': '123', 'repository_owner_id': '456',
    'sub': 'repo:grupo-jocaagura/jocaagura_ia:ref:refs/tags/v0.1.0',
    'run_id': '789', 'run_attempt': '1',
    'workflow_ref': 'grupo-jocaagura/jocaagura_ia/.github/workflows/cp0_publication.yaml@refs/tags/v0.1.0',
    'exp': 2000,
}


class CP0Tests(unittest.TestCase):
    def test_claims_allowlist_does_not_copy_extra_fields(self):
        result = validate_claims(dict(CLAIMS, private_value='do-not-record'), ENV, 1000)
        self.assertNotIn('private_value', result)
        self.assertEqual(result['event_name'], 'workflow_dispatch')

    def test_every_bound_identity_field_is_required_and_exact(self):
        for field in CLAIMS:
            for replacement in [None, 'wrong']:
                wrong = dict(CLAIMS, **{field: replacement})
                with self.subTest(field=field, replacement=replacement), self.assertRaises(ValueError):
                    validate_claims(wrong, ENV, 1000)
        for wrong in [dict(CLAIMS, exp=999), dict(CLAIMS, environment='pub.dev'),
                      dict(CLAIMS, ref='refs/heads/develop'), dict(CLAIMS, event_name='push')]:
            with self.assertRaises(ValueError):
                validate_claims(wrong, ENV, 1000)

    def test_decoder_errors_do_not_echo_token(self):
        payload = base64.urlsafe_b64encode(json.dumps(CLAIMS).encode()).decode().rstrip('=')
        self.assertEqual(decode_claims(f'header.{payload}.signature'), CLAIMS)
        for token in ['secret-token', 'header.secret-token.signature']:
            with self.assertRaises(ValueError) as error:
                decode_claims(token)
            self.assertNotIn('secret-token', str(error.exception))

    def test_actual_dispatch_guard_rejects_branch_publish_or_missing_consent(self):
        workflow = yaml.load((ROOT / '.github/workflows/cp0_publication.yaml').read_text(encoding='utf-8-sig'), Loader=yaml.BaseLoader)
        script = workflow['jobs']['validate']['steps'][0]['run']
        bash = Path('C:/Program Files/Git/bin/bash.exe') if os.name == 'nt' else Path('/bin/bash')
        if not bash.exists():
            self.skipTest('Bash required')
        common = dict(os.environ, EXPECTED_SHA=SHA, GITHUB_SHA=SHA,
                      GITHUB_REPOSITORY='grupo-jocaagura/jocaagura_ia', GITHUB_EVENT_NAME='workflow_dispatch',
                      OPERATION='publish', GITHUB_REF='refs/tags/v0.1.0', CONFIRMATION='publish jocaagura_ai 0.1.0')
        cases = [({}, 0), ({'OPERATION': 'prepare-tag', 'GITHUB_REF': 'refs/heads/develop', 'CONFIRMATION': ''}, 0),
                 ({'GITHUB_REF': 'refs/heads/develop'}, 1), ({'GITHUB_SHA': 'b' * 40}, 1),
                 ({'CONFIRMATION': ''}, 1), ({'GITHUB_EVENT_NAME': 'push'}, 1),
                 ({'GITHUB_REF': 'refs/tags/v0.2.0'}, 1), ({'OPERATION': 'unknown'}, 1),
                 ({'EXPECTED_SHA': 'master'}, 1), ({'GITHUB_REPOSITORY': 'fork/package'}, 1),
                 ({'OPERATION': 'prepare-tag'}, 1)]
        for override, expected in cases:
            result = subprocess.run([str(bash), '--noprofile', '--norc', '-e'], input=script,
                                    text=True, capture_output=True, env=dict(common, **override))
            with self.subTest(override=override):
                self.assertEqual(result.returncode == 0, expected == 0, result.stderr)

    def test_experiment_is_manual_and_upload_requires_successful_full_ci(self):
        workflow = yaml.load((ROOT / '.github/workflows/cp0_publication.yaml').read_text(encoding='utf-8'), Loader=yaml.BaseLoader)
        self.assertEqual(set(workflow['on']), {'workflow_dispatch'})
        self.assertEqual(workflow['concurrency'], {'group': 'pub-dev-release', 'cancel-in-progress': 'false'})
        self.assertEqual(workflow['jobs']['publish']['needs'], ['validate', 'ci'])
        self.assertEqual(workflow['jobs']['prepare_tag']['needs'], 'validate')
        publish_steps = workflow['jobs']['publish']['steps']
        upload = next(i for i, step in enumerate(publish_steps) if step.get('run') == 'dart pub publish --force')
        self.assertEqual(publish_steps[upload - 1]['run'], 'python3 .github/scripts/cp0_publication.py preflight')
        self.assertEqual(publish_steps[upload + 1]['run'], 'python3 .github/scripts/cp0_publication.py verify-publication')

    def test_preflight_rejects_already_published_and_absent_package(self):
        spec = 'name: jocaagura_ai\nversion: 0.1.0\nrepository: https://github.com/grupo-jocaagura/jocaagura_ia\n'
        notes = '## [0.1.0] - 2026-09-13\n\n- Changes.\n'
        for package, allowed in [
            ({'name': 'jocaagura_ai', 'versions': [{'version': '0.0.3'}]}, True),
            ({'name': 'jocaagura_ai', 'versions': [{'version': '0.1.0'}]}, False),
            (None, False),
        ]:
            with patch.dict(os.environ, ENV), patch('cp0_publication.subprocess.check_output', return_value=SHA), \
                    patch('cp0_publication.Path.read_text', side_effect=[spec, notes]), \
                    patch('cp0_publication.require_merged_commit') as provenance, \
                    patch('cp0_publication.read_json', return_value=deepcopy(package)):
                if allowed:
                    preflight()
                else:
                    with self.assertRaises(ValueError):
                        preflight()
                provenance.assert_called_once_with(SHA)


if __name__ == '__main__':
    unittest.main()
