#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
for script in "$repo_root"/scripts/*.sh; do
  bash -n "$script"
done

python3 - "$repo_root" <<'PY'
from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile

repo = Path(sys.argv[1])
required = (
    ".gitignore", "LICENSE", "README.md", "scripts/sync-links.sh", "scripts/check.sh",
    "skills/workflows/polish-loop/SKILL.md",
    "skills/workflows/polish-loop/references/lenses.md",
    "skills/workflows/polish-loop/references/rubrics.md",
    "skills/workflows/polish-loop/agents/openai.yaml",
    "skills/orchestration/orca-agent-tab/SKILL.md", "assets/.gitkeep",
)
for name in required:
    if not (repo / name).is_file():
        raise SystemExit(f"Missing file: {name}")

entries = sorted((repo / "skills").glob("*/*/SKILL.md"))
names = set()
for entry in entries:
    content = entry.read_text(encoding="utf-8")
    frontmatter = re.match(r"\A---\r?\n(.*?)\r?\n---(?:\r?\n|\Z)", content, re.S)
    if not frontmatter:
        raise SystemExit(f"Missing frontmatter: {entry.relative_to(repo)}")
    name = re.search(r"^name:\s*([a-z0-9-]+)\s*$", frontmatter[1], re.M)
    if not name or name[1] != entry.parent.name or name[1] in names:
        raise SystemExit(f"Invalid or duplicate skill name: {entry.relative_to(repo)}")
    if not re.search(r"^description:\s*\S", frontmatter[1], re.M):
        raise SystemExit(f"Missing description: {entry.relative_to(repo)}")
    names.add(name[1])

# Look for personal home paths, without embedding one in this repository.
private_path = re.compile(r"/(?:Users|home)/[^\s/]+|[A-Za-z]:[\\/]Users[\\/][^\s\\/]+")
for path in sorted(repo.rglob("*")):
    if ".git" in path.relative_to(repo).parts or not path.is_file():
        continue
    if path.is_symlink():
        raise SystemExit(f"Repository files must be real files: {path.relative_to(repo)}")
    try:
        content = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if private_path.search(content):
        raise SystemExit(f"Private home path in: {path.relative_to(repo)}")
print(f"PASS: layout, {len(entries)} skill entries, privacy, and shell syntax")

def sync(*args, success=True):
    result = subprocess.run(["bash", str(repo / "scripts/sync-links.sh"), *map(str, args)], capture_output=True, text=True)
    if (result.returncode == 0) != success:
        raise SystemExit(result.stdout + result.stderr)
    return result

with tempfile.TemporaryDirectory(prefix="agent-workflows-check-") as temporary:
    root = Path(temporary)
    first, second = root / "host one/skills", root / "host two/skills"
    targets = ("--target", first, "--target", second)
    sync("--dry-run", *targets)
    assert not first.exists() and not second.exists(), "Dry run wrote directories"
    sync(*targets)
    for target in (first, second):
        for entry in entries:
            link = target / entry.parent.name
            assert link.is_symlink() and not os.path.isabs(os.readlink(link))
            assert link.resolve() == entry.parent, f"Wrong link: {link}"
    before = {p: p.lstat().st_mtime_ns for target in (first, second) for p in target.iterdir()}
    sync(*targets)
    assert before == {p: p.lstat().st_mtime_ns for p in before}, "Repeat run rewrote links"
    broken = first / "polish-loop"
    broken.unlink()
    broken.symlink_to("missing-skill")
    sync(*targets)
    assert broken.resolve() == repo / "skills/workflows/polish-loop"
    conflict = root / "conflict/skills"
    conflict.mkdir(parents=True)
    real_directory = conflict / "polish-loop"
    real_directory.mkdir()
    marker = real_directory / "keep.txt"
    marker.write_text("keep", encoding="utf-8")
    untouched = root / "must stay absent/skills"
    sync("--target", untouched, "--target", conflict, success=False)
    assert marker.read_text(encoding="utf-8") == "keep" and not untouched.exists()
    blocked_parent = root / "file-parent"
    blocked_parent.write_text("keep", encoding="utf-8")
    sync("--target", blocked_parent / "skills", success=False)
    assert blocked_parent.read_text(encoding="utf-8") == "keep"
print("PASS: dry run, relative links, spaces, idempotency, broken links, and conflict protection")
PY
