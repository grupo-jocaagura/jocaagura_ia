"""Plan an explicit minor/major promotion from development patch changelogs."""

import argparse
import base64
from collections import defaultdict
import json
import os
from pathlib import Path
import re

from release_notes import release_notes

VERSION = r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
SECTIONS = ("Added", "Changed", "Deprecated", "Removed", "Fixed", "Security")


def parse_version(value):
    if not re.fullmatch(VERSION, value):
        raise ValueError("Version must use stable X.Y.Z")
    return tuple(map(int, value.split(".")))


def promotion_plan(pubspec, changelog, source, bump):
    base = parse_version(source)
    if bump not in ("minor", "major"):
        raise ValueError("Promotion must explicitly select minor or major")
    target_tuple = (base[0], base[1] + 1, 0) if bump == "minor" else (base[0] + 1, 0, 0)
    target = ".".join(map(str, target_tuple))
    versions = re.findall(r"^version:[ \t]*([^\s#]+)", pubspec, re.MULTILINE)
    if len(versions) != 1:
        raise ValueError("Expected exactly one package version")
    current = versions[0]
    parse_version(current)
    if current not in (source, target):
        raise ValueError("develop version changed: review and supply its exact source version")
    headings = list(re.finditer(r"^##[ \t]+(.+?)[ \t]*$", changelog, re.MULTILINE))
    entries = {}
    for i, heading in enumerate(headings):
        label = heading[1]
        if label == "Unreleased":
            key = "Unreleased"
        else:
            match = re.fullmatch(rf"\[({VERSION})\] - \d{{4}}-\d{{2}}-\d{{2}}", label)
            if not match:
                raise ValueError(f"Invalid changelog heading: {label}")
            key = match[1]
        if key in entries:
            raise ValueError(f"Duplicate changelog entry: {key}")
        end = headings[i + 1].start() if i + 1 < len(headings) else len(changelog)
        entries[key] = changelog[heading.end():end].strip()
    if "Unreleased" not in entries:
        raise ValueError("Expected exactly one Unreleased entry")
    if source != "0.0.0" and source not in entries:
        raise ValueError("Source version has no changelog entry")
    if current == target:
        if entries["Unreleased"]:
            raise ValueError("Promotion already prepared but new Unreleased notes need review")
        notes = release_notes(pubspec, changelog, f"v{target}")
        return {"version": target, "notes": notes, "state": "already_prepared", "patches": []}
    if target in entries:
        raise ValueError("Target changelog entry already exists before version preparation")
    released = {key: parse_version(key) for key in entries if key != "Unreleased"}
    if any(version > base for version in released.values()):
        raise ValueError("Changelog contains a release newer than the selected source")
    milestones = [version for version in released.values() if version[2] == 0]
    boundary = max(milestones, default=(0, 0, 0))
    patches = sorted((key for key, version in released.items() if boundary < version <= base and version[2] > 0), key=parse_version, reverse=True)
    contributions = [("Unreleased", entries["Unreleased"])]
    for patch in patches:
        contributions.append((patch, release_notes(f"version: {patch}\n", changelog, f"v{patch}").strip()))
    grouped = defaultdict(list)
    for label, body in contributions:
        if not body:
            continue
        sections = list(re.finditer(r"^###[ \t]+([^\n]+?)[ \t]*$", body, re.MULTILINE))
        if not sections or body[:sections[0].start()].strip():
            raise ValueError(f"{label} notes must use Keep a Changelog sections")
        for i, heading in enumerate(sections):
            section = heading[1]
            if section not in SECTIONS:
                raise ValueError(f"Unknown changelog section: {section}")
            end = sections[i + 1].start() if i + 1 < len(sections) else len(body)
            content = body[heading.end():end].strip()
            if content:
                grouped[section].append(f"#### {label}\n\n{content}")
    notes = "\n\n".join(f"### {section}\n\n" + "\n\n".join(grouped[section]) for section in SECTIONS if grouped[section])
    if not notes:
        raise ValueError("No unpromoted patch changes or Unreleased notes to promote")
    return {"version": target, "notes": notes + "\n", "state": "new_promotion", "patches": patches}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--from-version", required=True)
    parser.add_argument("--bump", choices=("minor", "major"), required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    try:
        plan = promotion_plan(Path("pubspec.yaml").read_text(encoding="utf-8"), Path("CHANGELOG.md").read_text(encoding="utf-8"), args.from_version, args.bump)
        args.output_dir.mkdir(parents=True, exist_ok=True)
        (args.output_dir / "notes.md").write_text(plan["notes"], encoding="utf-8")
        (args.output_dir / "plan.json").write_text(json.dumps(plan, indent=2), encoding="utf-8")
        if os.environ.get("GITHUB_OUTPUT"):
            encoded = base64.b64encode(plan["notes"].encode()).decode()
            with Path(os.environ["GITHUB_OUTPUT"]).open("a", encoding="utf-8") as output:
                output.write(f"version={plan['version']}\nchangelog_base64={encoded}\n")
        print(f"{plan['state']}: {args.from_version} -> {plan['version']}; patches: {', '.join(plan['patches']) or 'none'}")
    except (ValueError, OSError) as error:
        parser.exit(1, f"Promotion validation failed: {error}\n")


if __name__ == "__main__":
    main()