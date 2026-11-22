#!/usr/bin/env python3
"""Generate SideStore/AltStore source metadata and landing page for PowerTrack."""

import argparse
import datetime
import html
import json
import os
import plistlib
import shutil
import subprocess
from pathlib import Path


def resolve_pages_base_url(repository: str) -> str:
    """Compute the GitHub Pages base URL for a given owner/repo slug."""
    owner, repo_name = repository.split("/", 1)
    owner_lower = owner.lower()
    if repo_name.lower() == f"{owner_lower}.github.io":
        return f"https://{owner_lower}.github.io"
    return f"https://{owner_lower}.github.io/{repo_name}"


def read_last_commit_subject() -> str:
    """Return the latest git commit subject line, or a safe fallback."""
    try:
        output = subprocess.check_output(
            ["git", "log", "-1", "--pretty=%s"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        return output.strip() or "Automated CI build"
    except (subprocess.SubprocessError, FileNotFoundError):
        return "Automated CI build"


def build_source_payload(
    plist_path: Path,
    ipa_path: Path,
    repository: str,
    run_number: str,
    release_tag: str,
) -> dict:
    """Build an AltStore/SideStore-compatible source.json dictionary."""
    with plist_path.open("rb") as f:
        plist = plistlib.load(f)

    version = str(plist.get("CFBundleShortVersionString", "1.0"))
    build_version = str(plist.get("CFBundleVersion", run_number))
    min_os = str(plist.get("MinimumOSVersion", "26.5"))
    bundle_id = str(plist.get("CFBundleIdentifier", "com.ethanruders.PowerTrack"))
    ipa_size = ipa_path.stat().st_size
    build_date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    pages_base = resolve_pages_base_url(repository)
    commit_subject = read_last_commit_subject()

    return {
        "name": "PowerTrack",
        "identifier": f"{bundle_id}.source",
        "subtitle": "Suivi de force athlétique (PowerTrack)",
        "description": "Builds iOS automatiques de PowerTrack générés via GitHub Actions.",
        "iconURL": f"{pages_base}/icon.png",
        "apps": [
            {
                "name": "PowerTrack",
                "bundleIdentifier": bundle_id,
                "developerName": "Ethan Ruders",
                "subtitle": "Suivi de force athlétique",
                "localizedDescription": (
                    "Application native SwiftUI/SwiftData de suivi de force athlétique "
                    "(Powerlifting) avec chronomètre intelligent et Live Activity."
                ),
                "iconURL": f"{pages_base}/icon.png",
                "tintColor": "#DE7A42",
                "versions": [
                    {
                        "version": version,
                        "buildVersion": build_version,
                        "date": build_date,
                        "localizedDescription": f"Build #{run_number} — {commit_subject}",
                        "downloadURL": f"https://github.com/{repository}/releases/download/{release_tag}/PowerTrack.ipa",
                        "size": ipa_size,
                        "minOSVersion": min_os,
                    }
                ],
                "permissions": [],
            }
        ],
        "news": [],
    }


def render_index_html(pages_base: str, version: str, build_version: str, download_url: str) -> str:
    """Render a minimal landing page with a one-tap SideStore source link."""
    source_url = f"{pages_base}/source.json"
    sidestore_url = f"sidestore://source?url={source_url}"
    escaped_source = html.escape(source_url, quote=True)
    escaped_sidestore = html.escape(sidestore_url, quote=True)
    escaped_download = html.escape(download_url, quote=True)
    escaped_version = html.escape(f"{version} (build {build_version})")

    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PowerTrack — Source SideStore</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #09090B; color: #F5F5F7; max-width: 560px; margin: 48px auto; padding: 0 20px; line-height: 1.5; }}
    .card {{ background: #111114; border-radius: 16px; padding: 24px; border: 1px solid rgba(255, 255, 255, 0.12); }}
    .header {{ display: flex; align-items: center; gap: 16px; margin-bottom: 16px; }}
    .header img {{ width: 64px; height: 64px; border-radius: 14px; }}
    .btn {{ display: inline-block; background: #F5F5F7; color: #09090B; font-weight: 700; text-decoration: none; padding: 12px 20px; border-radius: 999px; margin-top: 8px; }}
    code {{ display: block; background: #09090B; border: 1px solid rgba(255, 255, 255, 0.09); padding: 10px 12px; border-radius: 8px; overflow-x: auto; font-size: 13px; margin: 12px 0; }}
    a.muted {{ color: #DE7A42; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <img src="icon.png" alt="PowerTrack">
      <div>
        <h1 style="margin:0;font-size:22px;">PowerTrack</h1>
        <p style="margin:4px 0 0;color:#aaa;">Dernière version : {escaped_version}</p>
      </div>
    </div>
    <p>Ajoute cette source dans SideStore sur ton iPhone pour recevoir les mises à jour sans fil :</p>
    <a class="btn" href="{escaped_sidestore}">Ajouter à SideStore</a>
    <code>{escaped_source}</code>
    <p><a class="muted" href="{escaped_download}">Télécharger PowerTrack.ipa directement</a></p>
  </div>
</body>
</html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate SideStore source.json and landing page.")
    parser.add_argument("--plist", required=True, type=Path)
    parser.add_argument("--ipa", required=True, type=Path)
    parser.add_argument("--icon", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--run-number", default=os.environ.get("GITHUB_RUN_NUMBER"))
    parser.add_argument("--release-tag", default=os.environ.get("RELEASE_TAG"))
    args = parser.parse_args()

    repository = args.repository or ""
    run_number = args.run_number or ""
    release_tag = args.release_tag or ""
    if not (repository and run_number and release_tag):
        parser.error("--repository, --run-number, and --release-tag (or corresponding env vars) are required.")

    source = build_source_payload(
        plist_path=args.plist,
        ipa_path=args.ipa,
        repository=repository,
        run_number=run_number,
        release_tag=release_tag,
    )

    args.out_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.icon, args.out_dir / "icon.png")

    (args.out_dir / "source.json").write_text(
        json.dumps(source, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    latest = source["apps"][0]["versions"][0]
    pages_base = resolve_pages_base_url(repository)
    (args.out_dir / "index.html").write_text(
        render_index_html(
            pages_base=pages_base,
            version=latest["version"],
            build_version=latest["buildVersion"],
            download_url=latest["downloadURL"],
        ),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
