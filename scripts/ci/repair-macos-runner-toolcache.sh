#!/usr/bin/env bash
# Prepares the non-relocatable Ruby tool-cache location required by
# ruby/setup-ruby on a self-hosted macOS runner. It changes no application,
# signing, provider or secret configuration.

set -euo pipefail

if [[ "${1:-}" != "--prepare-ruby-toolcache" ]]; then
  echo 'Usage: repair-macos-runner-toolcache.sh --prepare-ruby-toolcache' >&2
  exit 2
fi

if [[ "$(uname -s)" != 'Darwin' ]]; then
  echo 'This repair may only run on the macOS self-hosted runner.' >&2
  exit 2
fi

if ! sudo -n true 2>/dev/null; then
  echo 'Passwordless sudo is required to create the Ruby tool-cache path. Run this script from a Mac administrator session instead.' >&2
  exit 1
fi

runner_user="$(id -un)"
runner_group="$(id -gn)"
runner_home='/Users/runner'
toolcache="$runner_home/hostedtoolcache"

if sudo -n test -e "$runner_home"; then
  existing_owner="$(sudo -n stat -f '%Su' "$runner_home")"
  if [[ "$existing_owner" != "$runner_user" ]]; then
    echo "$runner_home already exists but is owned by $existing_owner, not $runner_user. Refusing to change an unrelated macOS home directory." >&2
    exit 1
  fi
fi

sudo -n /usr/bin/install -d -o "$runner_user" -g "$runner_group" -m 0755 "$runner_home"
sudo -n /usr/bin/install -d -o "$runner_user" -g "$runner_group" -m 0755 "$toolcache"
test -w "$toolcache"

echo "Ruby tool-cache is writable by $runner_user: $toolcache"
