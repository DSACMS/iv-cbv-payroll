#!/usr/bin/env python3
"""
Bidirectional Dockerfile OS package patcher.

Usage: python3 patch-dockerfile.py <trivy-results.json> <Dockerfile>

Reads Trivy JSON output and reconciles the auto-managed RUN block in the
Dockerfile's BASE stage:
  - Adds packages Trivy flags as fixable that aren't already patched
  - Removes packages from the auto-fix block that are no longer flagged
    (meaning the base image update resolved them)
  - Removes the entire auto-fix block if it becomes empty

Only manages blocks marked with the AUTOFIX_MARKER comment.
Never touches the manually-maintained "Upgrade packages in base image" block.
"""

import json
import re
import sys
from pathlib import Path

AUTOFIX_MARKER = "# Auto-fix: OS package vulnerabilities detected by Trivy"
MANUAL_BLOCK_MARKER = "# Upgrade packages in base image to address security issues"
INSERTION_ANCHOR = "# Rails app lives here"


def parse_trivy_results(trivy_path: str) -> dict[str, str]:
    """
    Returns {pkg_name: fixed_version} for all HIGH/CRITICAL OS packages
    that have a fix available.
    """
    with open(trivy_path) as f:
        data = json.load(f)

    needed: dict[str, str] = {}
    for result in data.get("Results", []):
        if result.get("Class") != "os-pkgs":
            continue
        for vuln in result.get("Vulnerabilities") or []:
            fixed = vuln.get("FixedVersion", "")
            if not fixed:
                continue
            pkg = vuln["PkgName"]
            # Keep the highest version if the same package appears in multiple CVEs.
            # For Debian-style versions, a simple string comparison is usually sufficient
            # since Trivy already resolves to the single fixed version per package.
            if pkg not in needed or fixed > needed[pkg]:
                needed[pkg] = fixed
    return needed


def parse_autofix_block(lines: list[str]) -> tuple[int, int, set[str]]:
    """
    Finds the auto-managed block in the Dockerfile lines.

    Returns (start_line_index, end_line_index, set_of_package_names).
    start/end are inclusive line indices, or (-1, -1) if the block doesn't exist.
    Package names are extracted from lines matching '      pkgname' or '      pkgname=version'.
    """
    start = -1
    end = -1
    packages: set[str] = set()

    for i, line in enumerate(lines):
        if AUTOFIX_MARKER in line:
            start = i
        if start != -1 and end == -1:
            # Package lines look like: '      pkgname \' or '      pkgname=version \'
            pkg_match = re.match(r"^\s{6}([a-z0-9][a-z0-9.+\-]*)(?:=[^\s\\]+)?\s*\\?\s*$", line)
            if pkg_match:
                packages.add(pkg_match.group(1))
            # The block ends at the apt cleanup line
            if "rm -rf /var/lib/apt/lists" in line and start != -1:
                end = i
                break

    return start, end, packages


def build_autofix_block(packages: dict[str, str], cve_ids: list[str] | None = None) -> list[str]:
    """
    Builds the lines for a new auto-fix RUN block.
    packages: {pkg_name: fixed_version}
    """
    pkg_lines = []
    for pkg, version in sorted(packages.items()):
        pkg_lines.append(f"      {pkg}={version} \\\n")

    cve_comment = " ".join(cve_ids) if cve_ids else "see Trivy scan results"
    block = [
        f"{AUTOFIX_MARKER} (managed automatically)\n",
        "# hadolint ignore=DL3008\n",
        "RUN apt-get update -qq && \\\n",
        "    apt-get install -y --no-install-recommends \\\n",
    ]
    block.extend(pkg_lines)
    block.append("    && \\\n")
    block.append("    rm -rf /var/lib/apt/lists /var/cache/apt/archives\n")
    return block


def find_insertion_index(lines: list[str]) -> int:
    """
    Finds the line index after the manually-maintained security block,
    immediately before '# Rails app lives here'.
    """
    for i, line in enumerate(lines):
        if INSERTION_ANCHOR in line:
            return i
    return -1


def main(trivy_path: str, dockerfile_path: str) -> None:
    needed = parse_trivy_results(trivy_path)
    print(f"Trivy flagged {len(needed)} package(s) with fixes available: {sorted(needed)}")

    dockerfile = Path(dockerfile_path)
    lines = dockerfile.read_text().splitlines(keepends=True)

    block_start, block_end, currently_patched = parse_autofix_block(lines)
    print(f"Currently in auto-fix block: {sorted(currently_patched)}")

    to_add = {pkg: ver for pkg, ver in needed.items() if pkg not in currently_patched}
    to_remove = currently_patched - set(needed.keys())

    if not to_add and not to_remove:
        print("No changes needed.")
        return

    if to_add:
        print(f"Adding: {sorted(to_add)}")
    if to_remove:
        print(f"Removing (resolved by base image update): {sorted(to_remove)}")

    # --- Rebuild the auto-fix block with the new package set ---
    new_packages: dict[str, str] = {}

    # Carry over packages that are still needed from the existing block
    # (we need their versions — re-read them from the existing block lines)
    if block_start != -1:
        for line in lines[block_start : block_end + 1]:
            match = re.match(r"^\s{6}([a-z0-9][a-z0-9.+\-]*)=([^\s\\]+)", line)
            if match:
                pkg, ver = match.group(1), match.group(2)
                if pkg not in to_remove:
                    new_packages[pkg] = ver

    # Add newly needed packages with their Trivy-provided fixed versions
    new_packages.update(to_add)

    # --- Apply changes ---
    if block_start != -1:
        # Replace the existing block
        if new_packages:
            new_block_lines = build_autofix_block(new_packages)
            lines[block_start : block_end + 1] = new_block_lines
        else:
            # All packages resolved — remove the block entirely.
            # Also remove a trailing blank line after the block if present.
            del_end = block_end + 1
            if del_end < len(lines) and lines[del_end].strip() == "":
                del_end += 1
            del lines[block_start:del_end]
            print("Auto-fix block removed (all packages resolved by base image update).")
    else:
        # Insert a new block before the anchor line
        insert_at = find_insertion_index(lines)
        if insert_at == -1:
            print(
                f"ERROR: Could not find insertion anchor '{INSERTION_ANCHOR}' in Dockerfile.",
                file=sys.stderr,
            )
            sys.exit(1)
        new_block_lines = build_autofix_block(new_packages)
        # Insert block + blank separator before the anchor
        lines[insert_at:insert_at] = new_block_lines + ["\n"]

    dockerfile.write_text("".join(lines))
    print(f"Dockerfile updated: {dockerfile_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <trivy-results.json> <Dockerfile>", file=sys.stderr)
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
