#!/usr/bin/env python3
"""Compare the packaged Epic launcher with the public AppImage redirect.

The installer URL always redirects at the current build. The version is the
CDN path segment under Builds/EGLv2/. On a change, this rewrites
pkgs/epic-games-launcher.nix. GitHub Actions then opens a pull request.

Exit 0 when the check succeeds, including when no update is waiting.
Exit 1 when the redirect or the nix file cannot be read.
"""

import argparse
import base64
import hashlib
import os
import re
import subprocess
import sys
import urllib.parse
from pathlib import Path

INSTALLER_URL = (
    "https://launcher-public-service-prod06.ol.epicgames.com"
    "/launcher/api/installer/download/EpicGamesLauncher-x86_64.AppImage"
)
NIX_PATH = Path("pkgs/epic-games-launcher.nix")
UPDATE_BRANCH = "appimage-update"

VERSION_LINE = re.compile(r'^(  version = )"[^"]*";$', re.MULTILINE)
HASH_LINE = re.compile(r'^(    hash = )"sha256-[^"]*";$', re.MULTILINE)
CDN_VERSION = re.compile(
    r"/Builds/EGLv2/([^/]+)/Linux/EpicGamesLauncher-x86_64\.AppImage$"
)


def read_version(text):
    match = VERSION_LINE.search(text)
    if not match:
        raise SystemExit(f"no version assignment in {NIX_PATH}")
    return match.group(0).split('"', 2)[1]


def resolve_final_url():
    try:
        final = subprocess.check_output(
            [
                "curl",
                "-fsSI",
                "-o",
                "/dev/null",
                "-w",
                "%{url_effective}",
                "-L",
                "--max-redirs",
                "10",
                "--retry",
                "3",
                "--retry-delay",
                "2",
                INSTALLER_URL,
            ],
            text=True,
        ).strip()
    except subprocess.CalledProcessError as err:
        raise SystemExit(f"could not resolve {INSTALLER_URL}") from err
    path = urllib.parse.unquote(urllib.parse.urlparse(final).path)
    match = CDN_VERSION.search(path)
    if not match:
        raise SystemExit(f"could not parse a version from {final}")
    version = match.group(1)
    if version == "" or any(c in version for c in '"\\\n'):
        raise SystemExit(f"refusing unusual CDN version {version!r}")
    return final, version


def version_on_ref(ref):
    result = subprocess.run(
        ["git", "show", f"{ref}:{NIX_PATH.as_posix()}"],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    return read_version(result.stdout)


def open_update_pr_exists():
    listed = subprocess.run(
        [
            "gh",
            "pr",
            "list",
            "--head",
            UPDATE_BRANCH,
            "--state",
            "open",
            "--json",
            "number",
            "--jq",
            "length",
        ],
        capture_output=True,
        text=True,
    )
    if listed.returncode != 0:
        print(listed.stderr.strip(), file=sys.stderr)
        return False
    try:
        return int(listed.stdout.strip()) > 0
    except ValueError:
        return False


def update_branch_already_has(version):
    # A merged or reverted branch still contains the version. Skip the
    # download only while a pull request for that proposal is open.
    if not open_update_pr_exists():
        print(f"no open pull request for {UPDATE_BRANCH}")
        return False
    fetched = subprocess.run(
        ["git", "fetch", "--depth=1", "origin", UPDATE_BRANCH],
        capture_output=True,
        text=True,
    )
    if fetched.returncode != 0:
        print(f"no existing {UPDATE_BRANCH} branch to compare", file=sys.stderr)
        return False
    existing = version_on_ref(f"origin/{UPDATE_BRANCH}")
    if existing == version:
        print(f"{UPDATE_BRANCH} already proposes {version}")
        return True
    return False


def download_hash():
    proc = subprocess.Popen(
        [
            "curl",
            "-fL",
            "--retry",
            "3",
            "--retry-delay",
            "2",
            "-o",
            "-",
            INSTALLER_URL,
        ],
        stdout=subprocess.PIPE,
    )
    digest = hashlib.sha256()
    assert proc.stdout is not None
    while True:
        chunk = proc.stdout.read(1024 * 1024)
        if not chunk:
            break
        digest.update(chunk)
    if proc.wait() != 0:
        raise SystemExit("download of the AppImage failed")
    return "sha256-" + base64.b64encode(digest.digest()).decode("ascii")


def rewrite_nix(text, version, sri):
    text, version_count = VERSION_LINE.subn(rf'\1"{version}";', text, count=1)
    text, hash_count = HASH_LINE.subn(rf'\1"{sri}";', text, count=1)
    if version_count != 1 or hash_count != 1:
        raise SystemExit(
            f"expected to replace one version and one hash, got {version_count} and {hash_count}"
        )
    return text


def write_output(key, value):
    path = os.environ.get("GITHUB_OUTPUT")
    if not path:
        return
    if "\n" in str(value):
        raise SystemExit(f"refusing multiline output for {key}")
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(f"{key}={value}\n")


def write_summary(lines):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="print the packaged and upstream versions without downloading",
    )
    args = parser.parse_args()

    text = NIX_PATH.read_text(encoding="utf-8")
    packaged = read_version(text)
    final_url, upstream = resolve_final_url()
    print(f"packaged: {packaged}")
    print(f"upstream: {upstream}")
    print(f"redirect: {final_url}")

    if packaged == upstream:
        print("already current")
        write_output("changed", "false")
        write_output("version", upstream)
        write_summary(
            [
                "### AppImage check",
                "",
                f"Already current at `{upstream}`.",
            ]
        )
        return

    if args.check:
        print(f"update available: {packaged} -> {upstream}")
        return

    if update_branch_already_has(upstream):
        write_output("changed", "false")
        write_output("version", upstream)
        write_summary(
            [
                "### AppImage check",
                "",
                f"`{UPDATE_BRANCH}` already proposes `{upstream}`.",
            ]
        )
        return

    print(f"downloading {upstream}")
    sri = download_hash()
    print(f"hash: {sri}")
    NIX_PATH.write_text(rewrite_nix(text, upstream, sri), encoding="utf-8")
    write_output("changed", "true")
    write_output("version", upstream)
    write_output("hash", sri)
    write_summary(
        [
            "### AppImage check",
            "",
            f"Update available: `{packaged}` -> `{upstream}`.",
            "",
            f"Hash: `{sri}`",
        ]
    )


if __name__ == "__main__":
    main()
