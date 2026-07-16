#!/bin/zsh

set -euo pipefail

REPOSITORY="${CODEX_METER_REPOSITORY:-roblej/codex-meter}"
REF="${CODEX_METER_REF:-main}"
INSTALL_DIRECTORY="${CODEX_METER_INSTALL_DIRECTORY:-$HOME/Applications}"
SKIP_LAUNCH="${CODEX_METER_SKIP_LAUNCH:-0}"
TEMP_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/codex-meter-install.XXXXXX")"

cleanup() {
    rm -rf "$TEMP_DIRECTORY"
}
trap cleanup EXIT INT TERM

for command in curl tar swift xcrun ditto; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "필요한 명령을 찾지 못했습니다: $command" >&2
        exit 1
    fi
done

if ! xcrun --find actool >/dev/null 2>&1; then
    echo "Xcode 15 이상이 필요합니다. Xcode 설치와 xcode-select 설정을 확인해 주세요." >&2
    exit 1
fi

SOURCE_DIRECTORY="$TEMP_DIRECTORY/source"
ARCHIVE_PATH="$TEMP_DIRECTORY/source.tar.gz"
ARCHIVE_URL="https://github.com/$REPOSITORY/archive/refs/heads/$REF.tar.gz"

echo "Codex Meter 소스를 내려받는 중…"
curl --fail --silent --show-error --location "$ARCHIVE_URL" --output "$ARCHIVE_PATH"
mkdir -p "$SOURCE_DIRECTORY"
tar -xzf "$ARCHIVE_PATH" --strip-components=1 -C "$SOURCE_DIRECTORY"

echo "Codex Meter를 빌드하는 중…"
"$SOURCE_DIRECTORY/scripts/build-app.sh"

SOURCE_APP="$SOURCE_DIRECTORY/dist/CodexMeter.app"
DESTINATION_APP="$INSTALL_DIRECTORY/CodexMeter.app"

if [[ -d "$DESTINATION_APP" ]] && pgrep -x CodexMeter >/dev/null 2>&1; then
    osascript -e 'tell application "Codex Meter" to quit' >/dev/null 2>&1 || true
    sleep 1
fi

mkdir -p "$INSTALL_DIRECTORY"
rm -rf "$DESTINATION_APP"
ditto "$SOURCE_APP" "$DESTINATION_APP"

echo "설치 완료: $DESTINATION_APP"
if [[ "$SKIP_LAUNCH" != "1" ]]; then
    open "$DESTINATION_APP"
fi
