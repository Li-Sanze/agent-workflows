#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

python3 - "$repo_root" "$@" <<'PY'
import argparse
import os
from pathlib import Path
import sys
import uuid

parser = argparse.ArgumentParser(description="Install flat, relative skill symlinks.")
parser.add_argument("--dry-run", action="store_true", help="Preview without writing anything")
parser.add_argument("--target", action="append", required=True, metavar="DIR", help="Host skill directory; repeat for multiple targets")
args = parser.parse_args(sys.argv[2:])
repo = Path(sys.argv[1])
sources = sorted(p.parent for p in (repo / "skills").glob("*/*/SKILL.md"))
if not sources:
    parser.error("No skills found at skills/<category>/<name>/SKILL.md")
names = [p.name for p in sources]
if len(names) != len(set(names)):
    parser.error("Skill names must be unique across categories")

targets = list(dict.fromkeys(Path(p).expanduser().absolute() for p in args.target))

# Check every destination before the first write; never replace real content.
plan = []
conflicts = []
for target in targets:
    for ancestor in (target, *target.parents):
        if os.path.lexists(ancestor) and not ancestor.is_dir():
            conflicts.append(f"Not a directory: {ancestor}")
            break
    for source in sources:
        destination = target / source.name
        relative = os.path.relpath(source, start=target.resolve())
        if os.path.lexists(destination) and not destination.is_symlink():
            conflicts.append(f"Refusing to replace real content: {destination}")
        plan.append((destination, relative))
if conflicts:
    parser.exit(1, "\n".join(dict.fromkeys(conflicts)) + "\n")

for destination, relative in plan:
    if destination.is_symlink() and os.readlink(destination) == relative:
        print(f"unchanged: {destination}")
        continue
    if args.dry_run:
        print(f"would link: {destination} -> {relative}")
        continue
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f".{destination.name}.link-{uuid.uuid4().hex}")
    try:
        os.symlink(relative, temporary)
        os.replace(temporary, destination)
    finally:
        if temporary.is_symlink():
            temporary.unlink()
    print(f"linked: {destination} -> {relative}")
print(f"{'Previewed' if args.dry_run else 'Checked'} {len(plan)} links across {len(targets)} targets.")
PY
