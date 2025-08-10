#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Comet – CPLX Installer
# -----------------------------------------------------------------------------
# By default, Comet does not allow extensions to tweak its "perplexity.ai"
# new tab page (likely to prevent ad blockers etc.; it also prevents the
# "Complexity" extension from working!).
#
# We've found a simple, safe workaround:
# This installer creates a wrapper shortcut app named:
#   ~/Applications/Comet - CPLX.app
#
# When you launch *that* shortcut app, it:
#   1) offers to quit Comet if it's already running,
#   2) flips "Allow-external-extensions-scripting-on-NTP" to true in:
#        ~/Library/Application Support/Comet/Local State
#   3) launches the real Comet.
#
# Result: Complexity will work! (as extensions can modify the new tab page)
#
# Notes:
# - No admin required. Built-in libraries only (bash, sed, awk, osascript).
# - A per-launch log is written to: ~/Library/Logs/Comet-CPLX.log
# - This does NOT modify Comet.app itself; it just creates a wrapper app.
# -----------------------------------------------------------------------------

set -euo pipefail

# ----------------------------- Config & Paths --------------------------------
APP_NAME="Comet - CPLX"
BUNDLE_ID="app.cplx.cometpatched"

TARGET_DIR="${HOME}/Applications"                   # Wrapper app location
APP_DIR="${TARGET_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RES_DIR="${CONTENTS_DIR}/Resources"

ICON_NAME="app.icns"
INSTALL_LOG_PREFIX="[Installer]"

# ----------------------------- Pretty Printers --------------------------------
# important: send installer logs to STDERR so command substitutions don't capture them
msg()  { printf "%s %s\n" "$INSTALL_LOG_PREFIX" "$*" >&2; }
ok()   { printf "✔ %s\n" "$*" >&2; }
warn() { printf "⚠ %s\n" "$*" >&2; }
err()  { printf "✖ %s\n" "$*" >&2; }

# ------------------------------ Intro Banner ----------------------------------
print_intro() {
  printf "\n" >&2
  printf "============================================================\n" >&2
  printf "   Comet Complexity Fixer for macOS (by github.com/theJayTea)\n" >&2
  printf "============================================================\n\n" >&2
  printf "Comet blocks extensions on the perplexity.ai pages, so Complexity can't work by default (maybe they do this to prevent ad-blockers stopping Perplexity tracking/ads?).\n" >&2
  printf "\n" >&2
  printf "This script creates a new shortcut/wrapper app called 'Comet - CPLX.app'. Simply launch Comet by opening *this* new shortcut!\n"
  printf "\n" >&2
  printf "This shortcut app flips an internal Comet setting right before it launches Comet for you, to fix the issue :)\n" >&2
  printf "\n" >&2
  printf "============================================================\n\n" >&2
  printf "⚙️  Script Log:" >&2
  printf "\n\n" >&2
}

# -------------------------- Find Comet.app (friendly) -------------------------
find_comet_app() {
  msg "Looking for Comet.app in the usual places…"
  for candidate in "/Applications/Comet.app" "${HOME}/Applications/Comet.app"; do
    if [[ -d "$candidate" ]]; then
      ok "Found Comet installed at: $candidate"
      # Only the path goes to STDOUT:
      echo "$candidate"
      return 0
    fi
  done
  warn "Comet.app wasn’t found in /Applications or ~/Applications."
  msg  "Please pick it in the dialog… (Select the real Comet.app)"

  # Let the user choose interactively (logs go to STDERR via msg/ok/warn)
  local chosen
  set +e
  chosen="$(osascript <<'AS'
    try
      set theApp to choose application with prompt "Select Comet.app"
      POSIX path of (theApp as alias)
    on error
      return ""
    end try
AS
)"
  local rc=$?
  set -e
  if [[ $rc -ne 0 || -z "$chosen" || ! -d "${chosen%/}" ]]; then
    err "No valid app selected. Exiting."
    exit 1
  fi
  ok "Using Comet at: ${chosen%/}"
  # Only the path to STDOUT:
  echo "${chosen%/}"
}

# --------------------------------- Run! ---------------------------------------
print_intro

# Capture only the path (no log noise now)
COMET_APP_PATH="$(find_comet_app)"
# Safety: strip trailing slash if any
COMET_APP_PATH="${COMET_APP_PATH%/}"
ICON_SRC="${COMET_APP_PATH}/Contents/Resources/app.icns"

# --------------------------- Build .app bundle --------------------------------
msg "Creating wrapper shortcut app at: ${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"

# Minimal Info.plist for a runnable Application bundle
cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key><string>1.2.2</string>
  <key>CFBundleShortVersionString</key><string>1.2.2</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>${APP_NAME}</string>
  <key>CFBundleIconFile</key><string>${ICON_NAME%.*}</string>
</dict></plist>
PLIST

# "Borrow" Comet's icon if present so our CPLX shortcut app looks nice :p
if [[ -f "${ICON_SRC}" ]]; then
  cp -f "${ICON_SRC}" "${RES_DIR}/${ICON_NAME}" || true
  ok "'Borrowed' Comet’s icon so the shortcut looks nice heh"
else
  warn "Tried to borrow Comet’s icon, but couldn’t find it at: ${ICON_SRC}"
  warn "Proceeding without a custom icon."
fi

# ----------------------- Launcher script inside the app -----------------------
# This is what runs when you double-click "Comet - CPLX".
cat > "${MACOS_DIR}/${APP_NAME}" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail

# (Installer will substitute this path)
COMET_APP_PATH="@@COMET_APP_PATH@@"

USER_DATA_DIR="${HOME}/Library/Application Support/Comet"
LOCAL_STATE="${USER_DATA_DIR}/Local State"
BACKUP="${LOCAL_STATE}.cplx.bak"
LOG="${HOME}/Library/Logs/Comet-CPLX.log"

# ----------------------------- Helpers ---------------------------------------
log()  { printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
is_running() { osascript -e 'application "Comet" is running' 2>/dev/null | grep -qi true; }

ensure_dirs() {
  mkdir -p "${USER_DATA_DIR}"
  mkdir -p "$(dirname "$LOG")"
  : > "$LOG" || true
}

backup_local_state() {
  if [[ -f "$LOCAL_STATE" ]]; then
    cp -f "$LOCAL_STATE" "$BACKUP" || true
  else
    # Create a minimal JSON file so sed/grep have something sane.
    printf '{}' > "$LOCAL_STATE"
  fi
}

verify_true() {
  grep -Eq '"Allow-external-extensions-scripting-on-NTP"[[:space:]]*:[[:space:]]*true' "$LOCAL_STATE"
}

sed_patch() {
  # Flip ANY occurrences of false -> true for that key (global replace).
  local before after
  before="$(grep -Eo '"Allow-external-extensions-scripting-on-NTP"[[:space:]]*:[[:space:]]*(true|false)' "$LOCAL_STATE" || true)"
  /usr/bin/sed -E -i '' \
    's/"Allow-external-extensions-scripting-on-NTP"[[:space:]]*:[[:space:]]*false/"Allow-external-extensions-scripting-on-NTP": true/g' \
    "$LOCAL_STATE"
  after="$(grep -Eo '"Allow-external-extensions-scripting-on-NTP"[[:space:]]*:[[:space:]]*(true|false)' "$LOCAL_STATE" || true)"
  log "Before: ${before:-<none>}  ->  After: ${after:-<none>}"
}

ask_quit_if_running() {
  if is_running; then
    osascript <<'AS' || true
      try
        display dialog "Comet is currently running.

Quit and relaunch with the patch applied?" buttons {"Cancel", "Quit & Relaunch"} default button "Quit & Relaunch" with icon caution
        tell application "Comet" to quit
      on error
      end try
AS
    # Wait up to ~10s for Comet to quit
    i=0
    while is_running && [ $i -lt 100 ]; do
      sleep 0.1
      i=$((i+1))
    done
  fi
}

launch_comet() {
  if [[ -d "$COMET_APP_PATH" ]]; then
    log "Launching Comet via path."
    open "$COMET_APP_PATH"
  else
    log "Launching Comet via app name."
    open -a "Comet"
  fi
}

main() {
  log "=== Comet - CPLX launch begin ==="
  ensure_dirs
  ask_quit_if_running
  backup_local_state
  sed_patch

  if verify_true; then
    log "Verification: key is TRUE before launch."
    launch_comet
  else
    log "Verification failed; not launching Comet to avoid confusion."
    log "Check your Local State file and try again."
    exit 1
  fi
  log "=== Comet - CPLX launch end ==="
}
main "$@"
LAUNCHER

# ---------------------- Substitute the Comet path safely ----------------------
# Escape slashes and ampersands for sed; COMET_APP_PATH has no newlines now.
escaped_path="$(printf '%s' "${COMET_APP_PATH}" | sed -e 's/[\/&]/\\&/g')"
# macOS sed inline edit syntax: -i '' (no backup)
sed -E -i '' "s/@@COMET_APP_PATH@@/${escaped_path}/g" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# ----------------------------- Friendly outro --------------------------------
printf "\n" >&2
  printf "============================================================\n\n" >&2
ok "✅ Done! Created: ${APP_NAME}.app :3"
printf "\n" >&2
printf "✅ What’s next:\n" >&2
printf "  • Open Spotlight and launch Comet through this patched shortcut: %s\n" "${APP_NAME}" >&2
printf "  • The patched shortcut is saved at: %s\n" "${TARGET_DIR}" >&2
printf "  • You can replace your original Comet dock icon with this!\n" >&2
printf "\n" >&2
printf "If you're curious, each launch through the patched shortcut will:\n" >&2
printf "  1) Ensure Comet isn’t running (offers to quit),\n" >&2
printf "  2) Re-flip Local State's "Allow-external-extensions-scripting-on-NTP" key to TRUE (the harmless patch),\n" >&2
printf "  3) Then launch Comet!\n" >&2