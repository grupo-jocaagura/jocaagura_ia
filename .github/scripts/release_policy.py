"""Read-only release eligibility and provenance checks. Never creates a tag or uploads."""

import argparse
import json
import os
from pathlib import Path
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import yaml

from release_notes import release_notes

REPOSITORY = "grupo-jocaagura/jocaagura_ia"
PACKAGE = "jocaagura_ai"
REPOSITORY_URL = f"https://github.com/{REPOSITORY}"
STABLE = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)")


def semver(value):
    if not isinstance(value, str) or not STABLE.fullmatch(value):
        raise ValueError("Expected stable X.Y.Z version")
    return tuple(map(int, value.split(".")))


def metadata(text):
    data = yaml.safe_load(text)
    if not isinstance(data, dict) or data.get("name") != PACKAGE:
        raise ValueError(f"Root package must be named {PACKAGE}")
    if data.get("repository") != REPOSITORY_URL:
        raise ValueError("Root repository URL must match the official repository")
    if "publish_to" in data:
        raise ValueError("Root pubspec must not declare publish_to")
    if data.get("dependencies") or data.get("dependency_overrides"):
        raise ValueError("Published core must keep SDK-only runtime dependencies")
    version = data.get("version")
    if semver(version) == (0, 0, 0):
        raise ValueError("0.0.0 is bootstrap only")
    return version


def require_release_pr(pr, merged_sha=None):
    try:
        valid = (
            pr["base"]["ref"] == "master"
            and pr["head"]["ref"] == "develop"
            and pr["base"]["repo"]["full_name"] == REPOSITORY
            and pr["head"]["repo"]["full_name"] == REPOSITORY
        )
    except (KeyError, TypeError):
        valid = False
    if not valid:
        raise ValueError("Releases require an official develop -> master PR (no forks)")
    if merged_sha is not None and (
        not pr.get("merged_at")
        or pr.get("state") != "closed"
        or pr.get("merge_commit_sha") != merged_sha
    ):
        raise ValueError("Release commit must be the exact merged develop -> master PR commit")


def read_json(url, *, missing_ok=False, token=None):
    headers = {"Accept": "application/json", "User-Agent": "jocaagura-release-validation"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        with urlopen(Request(url, headers=headers), timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        if missing_ok and error.code == 404:
            return None
        raise ValueError(f"Service returned HTTP {error.code}; release eligibility is unknown") from None


def publication_state(version, package):
    target = semver(version)
    if package is None:
        return "manual_first_publication"
    if not isinstance(package, dict) or package.get("name") != PACKAGE:
        raise ValueError("pub.dev returned an unexpected package identity")
    versions = package.get("versions")
    if not isinstance(versions, list) or not versions:
        raise ValueError("pub.dev returned an invalid version listing")
    stable = []
    for item in versions:
        if not isinstance(item, dict) or not isinstance(item.get("version"), str):
            raise ValueError("pub.dev returned malformed version data")
        value = item["version"]
        if STABLE.fullmatch(value):
            stable.append(semver(value))
        elif not re.fullmatch(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?", value):
            raise ValueError("pub.dev returned an invalid semantic version")
    if stable and target < max(stable):
        raise ValueError("Release version regresses behind a published stable version")
    if target in stable:
        return "already_published"
    return "ready_for_human_tag"


def require_merged_commit(sha, *, reader=read_json):
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Expected an exact 40-character commit SHA")
    token = os.environ.get("GH_TOKEN")
    for page in range(1, 101):
        prs = reader(
            f"https://api.github.com/repos/{REPOSITORY}/commits/{sha}/pulls?per_page=100&page={page}",
            token=token,
        )
        if not isinstance(prs, list):
            raise ValueError("GitHub returned an invalid PR listing")
        for pr in prs:
            try:
                require_release_pr(pr, merged_sha=sha)
            except ValueError:
                continue
            return
        if len(prs) < 100:
            break
    raise ValueError("No official merged develop -> master PR authorizes this exact commit")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pr-event", type=Path)
    parser.add_argument("--tag")
    parser.add_argument("--commit")
    parser.add_argument("--metadata-only", action="store_true")
    args = parser.parse_args()
    try:
        if args.pr_event:
            event = json.loads(args.pr_event.read_text(encoding="utf-8"))
            require_release_pr(event.get("pull_request"))
        spec = Path("pubspec.yaml").read_text(encoding="utf-8")
        version = metadata(spec)
        if args.metadata_only:
            print(f"Verified package identity: {PACKAGE} {version}")
            return
        release_notes(spec, Path("CHANGELOG.md").read_text(encoding="utf-8"), args.tag or f"v{version}")
        if args.commit:
            require_merged_commit(args.commit)
        package = read_json(f"https://pub.dev/api/packages/{PACKAGE}", missing_ok=True)
        state = publication_state(version, package)
        messages = {
            "manual_first_publication": "First publication requires a maintainer; automatic upload is blocked.",
            "already_published": "This version already exists; skip upload. Never overwrite a published version.",
            "ready_for_human_tag": "Eligible after CI and merge. CP-0 is pending: a maintainer must push the release tag.",
        }
        print(f"{state}: {PACKAGE} {version}. {messages[state]}")
        if os.environ.get("GITHUB_OUTPUT"):
            with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as output:
                output.write(f"state={state}\nversion={version}\n")
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a", encoding="utf-8") as output:
                output.write(f"## Release eligibility\n\n`{PACKAGE} {version}`: **{state}**\n\n{messages[state]}\n")
        if args.tag and state == "manual_first_publication":
            raise ValueError("Automatic first publication is not supported")
    except (ValueError, OSError, yaml.YAMLError) as error:
        parser.exit(1, f"Release validation failed: {error}\n")


if __name__ == "__main__":
    main()