#!/bin/bash
set -euo pipefail

#───────────────────────────────────────────────────────────────────────────────
# PingyDingy — Build & Submit to TestFlight
#
# Usage:
#   ./scripts/build-testflight.sh
#   ./scripts/build-testflight.sh --skip-upload    # Archive only
#   ./scripts/build-testflight.sh --bump major     # Bump marketing version
#
# Credentials auto-detected from ../EmailWatch/AppleCredentials/
#───────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT="$PROJECT_DIR/PingyDingy.xcodeproj"
SCHEME="PingyDingy"
BUILD_DIR="$PROJECT_DIR/scripts/.build-testflight"
ARCHIVE_PATH="$BUILD_DIR/PingyDingy.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"
LOG_DIR="$BUILD_DIR/logs"

SKIP_UPLOAD=false
BUMP_TYPE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-upload) SKIP_UPLOAD=true; shift ;;
        --bump) BUMP_TYPE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

#───────────────────────────────────────────────────────────────────────────────
# Helpers
#───────────────────────────────────────────────────────────────────────────────

info()  { echo "▸ $*"; }
error() { echo "✘ $*" >&2; exit 1; }
ok()    { echo "✔ $*"; }

#───────────────────────────────────────────────────────────────────────────────
# Step 1: Verify environment + auto-detect credentials
#───────────────────────────────────────────────────────────────────────────────

info "Checking environment..."

command -v xcodebuild >/dev/null || error "xcodebuild not found"

EMAILWATCH_CREDS="$PROJECT_DIR/../EmailWatch/AppleCredentials"

if [[ -z "${ASC_KEY_ID:-}" && -d "$EMAILWATCH_CREDS" ]]; then
    ASC_KEY_PATH=$(find "$EMAILWATCH_CREDS" -name "AuthKey_*.p8" | head -1)
    if [[ -n "$ASC_KEY_PATH" ]]; then
        ASC_KEY_ID=$(basename "$ASC_KEY_PATH" .p8 | sed 's/AuthKey_//')
        ISSUER_FILE="${ASC_KEY_PATH%.p8}.issuer"
        [[ -f "$ISSUER_FILE" ]] && ASC_ISSUER_ID=$(cat "$ISSUER_FILE")
        info "Credentials from EmailWatch: Key=$ASC_KEY_ID"
    fi
fi

if [[ "$SKIP_UPLOAD" == false ]]; then
    [[ -n "${ASC_KEY_ID:-}" ]]   || error "ASC_KEY_ID not found"
    [[ -n "${ASC_ISSUER_ID:-}" ]] || error "ASC_ISSUER_ID not found"
    [[ -n "${ASC_KEY_PATH:-}" ]] || error "ASC_KEY_PATH not found"
    [[ -f "$ASC_KEY_PATH" ]]     || error "API key not found at $ASC_KEY_PATH"
fi

ok "Environment ready"

#───────────────────────────────────────────────────────────────────────────────
# Step 2: Bump version numbers
#───────────────────────────────────────────────────────────────────────────────

cd "$PROJECT_DIR"

CURRENT_MARKETING=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | grep "MARKETING_VERSION" | head -1 | awk '{print $3}')
CURRENT_BUILD=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
    | grep "CURRENT_PROJECT_VERSION" | head -1 | awk '{print $3}')

NEW_BUILD=$((CURRENT_BUILD + 1))

if [[ -n "$BUMP_TYPE" ]]; then
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_MARKETING"
    case "$BUMP_TYPE" in
        major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
        minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
        patch) PATCH=$((PATCH + 1)) ;;
        *) error "Invalid bump type: $BUMP_TYPE (use major/minor/patch)" ;;
    esac
    NEW_MARKETING="$MAJOR.$MINOR.$PATCH"
else
    NEW_MARKETING="$CURRENT_MARKETING"
fi

info "Version: $NEW_MARKETING ($NEW_BUILD)  [was $CURRENT_MARKETING ($CURRENT_BUILD)]"

sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$NEW_MARKETING\"/" project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"$NEW_BUILD\"/" project.yml
sed -i '' "s/CFBundleShortVersionString: \".*\"/CFBundleShortVersionString: \"$NEW_MARKETING\"/" project.yml
sed -i '' "s/CFBundleVersion: \".*\"/CFBundleVersion: \"$NEW_BUILD\"/" project.yml

info "Regenerating Xcode project..."
xcodegen generate --quiet 2>/dev/null || xcodegen generate

ok "Version bumped to $NEW_MARKETING ($NEW_BUILD)"

#───────────────────────────────────────────────────────────────────────────────
# Step 3: Archive
#───────────────────────────────────────────────────────────────────────────────

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$LOG_DIR"

ARCHIVE_LOG="$LOG_DIR/archive-$(date +%Y%m%d-%H%M%S).log"

info "Archiving..."

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    MARKETING_VERSION="$NEW_MARKETING" \
    CURRENT_PROJECT_VERSION="$NEW_BUILD" \
    2>&1 | tee "$ARCHIVE_LOG" | tail -5

[[ -d "$ARCHIVE_PATH" ]] || error "Archive failed — check $ARCHIVE_LOG"
ok "Archive created"

#───────────────────────────────────────────────────────────────────────────────
# Step 4: Export + Upload (matching EmailWatch pattern)
#───────────────────────────────────────────────────────────────────────────────

EXPORT_LOG="$LOG_DIR/export-$(date +%Y%m%d-%H%M%S).log"

if [[ "$SKIP_UPLOAD" == true ]]; then
    DESTINATION="export"
else
    DESTINATION="upload"
fi

cat > "$EXPORT_OPTIONS" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>${DESTINATION}</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
PLIST

# Build export command — matches EmailWatch deploy-ios.sh pattern
EXPORT_CMD=(
    xcodebuild
    -exportArchive
    -archivePath "$ARCHIVE_PATH"
    -exportPath "$EXPORT_PATH"
    -exportOptionsPlist "$EXPORT_OPTIONS"
)

# Add API key auth (for cloud signing + upload)
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
    EXPORT_CMD+=(
        -authenticationKeyPath "$ASC_KEY_PATH"
        -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    )
fi

if [[ "$SKIP_UPLOAD" == true ]]; then
    info "Exporting IPA..."
else
    info "Exporting and uploading to App Store Connect..."
fi

"${EXPORT_CMD[@]}" 2>&1 | tee "$EXPORT_LOG" | tail -10

# Check result
if grep -q "EXPORT SUCCEEDED\|Upload succeeded" "$EXPORT_LOG"; then
    ok "Export/upload succeeded"
else
    echo ""
    error "Export failed — check $EXPORT_LOG"
fi

#───────────────────────────────────────────────────────────────────────────────
# Step 5: Commit version bump
#───────────────────────────────────────────────────────────────────────────────

cd "$PROJECT_DIR"
if ! git diff --quiet project.yml PingyDingy/Info.plist 2>/dev/null; then
    git add project.yml PingyDingy/Info.plist PingyDingy.xcodeproj/
    git commit -m "build: bump version to $NEW_MARKETING ($NEW_BUILD) for TestFlight"
    ok "Version bump committed"
fi

#───────────────────────────────────────────────────────────────────────────────
# Done
#───────────────────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════"
echo "  PingyDingy $NEW_MARKETING ($NEW_BUILD)"
if [[ "$SKIP_UPLOAD" == true ]]; then
echo "  Archived + exported (not uploaded)"
else
echo "  Submitted to TestFlight"
echo "  Allow ~15 min for processing"
fi
echo "═══════════════════════════════════════════════"
