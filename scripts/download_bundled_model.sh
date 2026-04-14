#!/usr/bin/env bash
# download_bundled_model.sh
#
# Downloads the KB Whisper Large (CoreML) model from HuggingFace and places it
# at Transcribe/Resources/BundledModel/ so it is bundled inside the app.
#
# After running this script, add the BundledModel folder to Xcode as a
# "folder reference" (blue folder icon, not yellow group icon):
#
#   1. In Xcode, right-click the "Resources" group → "Add Files to Transcribe…"
#   2. Navigate to Transcribe/Resources/BundledModel
#   3. Select the folder, choose "Create folder references" (NOT groups)
#   4. Make sure the "Transcribe" target is checked → Add
#
# The bundled DMG will be ~3.1 GB larger but works fully offline on
# firewalled / air-gapped computers with no first-launch download needed.
#
# Requirements: Python 3 with huggingface_hub installed.
#   pip install huggingface_hub
#
# Usage: bash scripts/download_bundled_model.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEST="$PROJECT_ROOT/Transcribe/Resources/BundledModel"

REPO="mickekringai/kb-whisper-coreml"
VARIANT="large"

echo "==> Downloading KB Whisper Large (CoreML) from HuggingFace..."
echo "    Repo   : $REPO"
echo "    Variant: $VARIANT"
echo "    Target : $DEST"
echo ""

if [ -d "$DEST" ] && [ "$(ls -A "$DEST" 2>/dev/null)" ]; then
    echo "BundledModel folder already exists and is non-empty — skipping download."
    echo "Delete $DEST to force a re-download."
    exit 0
fi

mkdir -p "$DEST"

python3 - <<PYEOF
import sys
try:
    from huggingface_hub import snapshot_download
except ImportError:
    print("ERROR: huggingface_hub is not installed. Run: pip install huggingface_hub", file=sys.stderr)
    sys.exit(1)

dest = "$DEST"
repo = "$REPO"
variant = "$VARIANT"

print(f"Downloading {repo} (variant: {variant})...")
path = snapshot_download(
    repo_id=repo,
    allow_patterns=[f"{variant}/*"],
    local_dir=dest,
)
print(f"Downloaded to: {path}")
PYEOF

echo ""
echo "==> Done. Model downloaded to: $DEST"
echo ""
echo "Next steps:"
echo "  1. Open Transcribe.xcodeproj in Xcode"
echo "  2. Right-click 'Resources' group → 'Add Files to Transcribe…'"
echo "  3. Select the BundledModel folder"
echo "  4. Choose 'Create folder references' (blue icon)"
echo "  5. Ensure 'Transcribe' target is checked → Add"
echo "  6. Build: xcodebuild build -scheme Transcribe CLANG_COVERAGE_MAPPING=NO"
