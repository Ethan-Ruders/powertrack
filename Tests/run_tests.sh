#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_BIN="/tmp/PowerTrackCoreTestsBin"

rm -f "$OUT_BIN"

# shellcheck disable=SC2086
xcrun --sdk macosx swiftc \
  -swift-version 5 \
  -default-isolation MainActor \
  -enable-upcoming-feature MemberImportVisibility \
  -DPOWERTRACK_TESTS \
  ${EXTRA_SWIFT_FLAGS:-} \
  "$REPO_ROOT/PowerTrack/models.swift" \
  "$REPO_ROOT/PowerTrack/ProgramGenerator.swift" \
  "$REPO_ROOT/PowerTrack/ProgramJSONImporter.swift" \
  "$REPO_ROOT/PowerTrack/EtapeEchauffement.swift" \
  "$REPO_ROOT/PowerTrack/SeanceExportDTO.swift" \
  "$REPO_ROOT/PowerTrack/BackupManager.swift" \
  "$REPO_ROOT/PowerTrack/RankSystem.swift" \
  "$REPO_ROOT/Tests/PowerTrackCoreTests.swift" \
  -o "$OUT_BIN"

"$OUT_BIN"
rm -f "$OUT_BIN"
