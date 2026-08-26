#!/usr/bin/env bash
# Preflight for the dedicated PetMagic macOS GitHub Actions runner.
#
# This script never downloads a runner, registers it with GitHub, installs
# packages, or reads project secrets. It prepares only local cache/log folders
# and reports the exact missing prerequisites. Runner registration remains a
# deliberate, interactive GitHub action because its token is short-lived.

set -euo pipefail

readonly EXPECTED_FLUTTER_VERSION="3.44.5"
readonly CACHE_ROOT="$HOME/.cache/petmagic-ci"

failures=0

info() {
  printf '[info] %s\n' "$*"
}

ok() {
  printf '[ ok ] %s\n' "$*"
}

warn() {
  printf '[warn] %s\n' "$*" >&2
}

missing() {
  printf '[missing] %s\n' "$*" >&2
  failures=1
}

require_command() {
  local command_name="$1"
  local hint="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$(command -v "$command_name")"
  else
    missing "$command_name — $hint"
  fi
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  printf 'This preflight must run on macOS. Detected: %s\n' "$(uname -s)" >&2
  exit 2
fi

info "PetMagic macOS runner preflight"
info "Host: $(scutil --get ComputerName 2>/dev/null || hostname)"
info "Architecture: $(uname -m)"
info "macOS: $(sw_vers -productVersion)"

require_command git "install Xcode Command Line Tools or Git"
require_command xcodebuild "install Xcode from the App Store and run it once"
require_command xcrun "install Xcode Command Line Tools"
require_command ruby "install the Ruby runtime required by apps/petmagic-mobile/Gemfile"
require_command bundle "run: gem install bundler"
require_command python3 "install Python 3 required by Flutter/iOS test tooling"
require_command java "install a supported JDK for the Android toolchain"
require_command flutter "install Flutter $EXPECTED_FLUTTER_VERSION"
require_command curl "install curl required by the GitHub runner bootstrap"

if command -v xcodebuild >/dev/null 2>&1; then
  xcode_version="$(xcodebuild -version 2>/dev/null | tr '\n' ' ' || true)"
  if [[ -n "$xcode_version" ]]; then
    ok "$xcode_version"
  else
    missing "Xcode license/toolchain is not ready — run: sudo xcodebuild -license accept"
  fi
fi

if command -v flutter >/dev/null 2>&1; then
  flutter_version="$(flutter --version --machine 2>/dev/null | python3 -c 'import json, sys; print(json.load(sys.stdin).get("frameworkVersion", ""))' 2>/dev/null || true)"
  if [[ "$flutter_version" == "$EXPECTED_FLUTTER_VERSION" ]]; then
    ok "Flutter $flutter_version"
  else
    missing "Flutter $EXPECTED_FLUTTER_VERSION is required; found ${flutter_version:-unknown}"
  fi
fi

if command -v java >/dev/null 2>&1; then
  ok "$(java -version 2>&1 | head -n 1)"
fi

mkdir -p \
  "$CACHE_ROOT/pub" \
  "$CACHE_ROOT/gradle" \
  "$CACHE_ROOT/bundle" \
  "$CACHE_ROOT/logs" \
  "$CACHE_ROOT/artifacts"
chmod 700 "$CACHE_ROOT"
ok "Prepared private cache root: $CACHE_ROOT"

cat <<'NEXT_STEPS'

Next steps after this preflight passes:
  1. In GitHub: repository Settings → Actions → Runners → New self-hosted runner → macOS.
  2. Follow GitHub's generated download/configure commands on this Mac.
  3. Register a repository-scoped runner with the extra label: petmagic-mobile.
  4. Install it as a service with the generated runner's ./svc.sh install and ./svc.sh start.
  5. Keep the runner's work directory separate from any developer checkout.

Do not paste GitHub registration tokens, SSH keys, .p8 files, keystores, or
environment-file contents into chat or commit them to the repository.
NEXT_STEPS

if [[ "$failures" -ne 0 ]]; then
  warn "Preflight found missing prerequisites. No system changes were made."
  exit 1
fi

info "Preflight passed. No runner was registered and no credentials were changed."
