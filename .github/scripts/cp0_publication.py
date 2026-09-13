"""One-time CP-0 checks. This script never creates a tag or uploads a package."""

import argparse
import base64
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import time

from release_policy import PACKAGE, REPOSITORY, metadata, publication_state, read_json, require_merged_commit
from release_notes import release_notes

VERSION = "0.1.0"
TAG = f"v{VERSION}"


class ClaimValidationError(ValueError):
    """A fixed field name that is safe to report, never a token or received value."""


def validate_claims(claims, env, now):
    """Check claim semantics only; pub.dev, not this decoder, verifies the JWT signature."""
    owner, repository = REPOSITORY.split("/", 1)
    # This repository's OIDC settings confirm use_immutable_subject=true.
    # Bind both immutable IDs as well as the separately checked names and ref.
    subject = (
        f"repo:{owner}@{env['EXPECTED_OWNER_ID']}/"
        f"{repository}@{env['EXPECTED_REPOSITORY_ID']}:ref:refs/tags/{TAG}"
    )
    expected = {
        "iss": "https://token.actions.githubusercontent.com",
        "aud": "https://pub.dev",
        "event_name": "workflow_dispatch",
        "ref_type": "tag",
        "ref": f"refs/tags/{TAG}",
        "repository": REPOSITORY,
        "repository_owner": "grupo-jocaagura",
        "sha": env["EXPECTED_SHA"],
        "repository_id": env["EXPECTED_REPOSITORY_ID"],
        "repository_owner_id": env["EXPECTED_OWNER_ID"],
        "sub": subject,
        "run_id": env["GITHUB_RUN_ID"],
        "run_attempt": env["GITHUB_RUN_ATTEMPT"],
        "workflow_ref": f"{REPOSITORY}/.github/workflows/cp0_publication.yaml@refs/tags/{TAG}",
    }
    if not isinstance(claims, dict):
        raise ClaimValidationError("payload")
    for key, value in expected.items():
        if not value or claims.get(key) != value:
            raise ClaimValidationError(key)
    if claims.get("environment") is not None:
        raise ClaimValidationError("environment")
    if not isinstance(claims.get("exp"), int) or claims["exp"] <= now:
        raise ClaimValidationError("exp")
    return dict(expected, environment=None, exp=claims["exp"])


def decode_claims(token):
    try:
        parts = token.split(".")
        if len(parts) != 3:
            raise ValueError()
        payload = parts[1]
        return json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
    except (ValueError, UnicodeError):
        # Do not include token fragments, decoder errors or response bodies in logs.
        raise ValueError("Cannot decode OIDC payload") from None


def summary(title, data):
    report = f"## {title}\n\n```json\n{json.dumps(data, indent=2)}\n```\n"
    print(report)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a", encoding="utf-8") as output:
            output.write(report)


def preflight():
    sha = os.environ["EXPECTED_SHA"]
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
    if head != sha:
        raise ValueError("Checkout differs from the explicitly selected release commit")
    spec = Path("pubspec.yaml").read_text(encoding="utf-8-sig")
    if metadata(spec) != VERSION:
        raise ValueError("This one-time CP-0 experiment only permits 0.1.0")
    release_notes(spec, Path("CHANGELOG.md").read_text(encoding="utf-8"), TAG)
    require_merged_commit(sha)
    package = read_json(f"https://pub.dev/api/packages/{PACKAGE}", missing_ok=True)
    if publication_state(VERSION, package) != "ready_for_human_tag":
        raise ValueError("CP-0 requires an unpublished candidate; an existing version cannot prove authorization")
    print("Validated unpublished 0.1.0 and exact merged release provenance. CP-0 remains pending.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["preflight", "claims", "verify-publication"])
    args = parser.parse_args()
    try:
        if args.operation == "preflight":
            preflight()
        elif args.operation == "claims":
            claims = validate_claims(decode_claims(os.environ["PUB_TOKEN"]), os.environ, time.time())
            summary("CP-0 identity evidence (package authorization still pending)", claims)
        else:
            result = read_json(f"https://pub.dev/api/packages/{PACKAGE}/versions/{VERSION}")
            if (not isinstance(result, dict) or result.get("version") != VERSION
                    or not isinstance(result.get("pubspec"), dict)
                    or result["pubspec"].get("name") != PACKAGE
                    or not result.get("archive_sha256")):
                raise ValueError("Published package confirmation is incomplete")
            summary("CP-0 service evidence after successful OIDC upload", {
                "package": PACKAGE, "version": VERSION,
                "archive_sha256": result["archive_sha256"], "published": result.get("published"),
                "release_commit": os.environ["EXPECTED_SHA"],
                "run_url": f"https://github.com/{REPOSITORY}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
                "checked_at": datetime.now(timezone.utc).isoformat(),
                "next": "Record pub.dev audit-log attribution before closing CP-0; post-merge automation remains disabled.",
            })
    except ClaimValidationError as error:
        parser.exit(1, f"CP-0 OIDC claim mismatch: {error}. Upload remains blocked.\n")
    except (ValueError, OSError, KeyError, subprocess.CalledProcessError):
        # Never emit environment contents, bearer tokens or untrusted service bodies.
        parser.exit(1, "CP-0 verification failed. No authorization conclusion may be inferred; inspect the failed step.\n")


if __name__ == "__main__":
    main()
