#!/usr/bin/env bash
# Repairs the persistent tool-cache location of the dedicated PetMagic runner.
# It changes no application, signing, provider or secret configuration.

set -euo pipefail

if [[ "${1:-}" != "--restart-runner" ]]; then
  echo 'Usage: repair-macos-runner-toolcache.sh --restart-runner' >&2
  exit 2
fi

if [[ "$(uname -s)" != 'Darwin' ]]; then
  echo 'This repair may only run on the macOS self-hosted runner.' >&2
  exit 2
fi

if [[ -z "${RUNNER_WORKSPACE:-}" ]]; then
  echo 'RUNNER_WORKSPACE is required to locate the self-hosted runner.' >&2
  exit 2
fi

runner_root="$(cd "${RUNNER_WORKSPACE%/_work}" && pwd)"
runner_env="$runner_root/.env"
toolcache="$HOME/.cache/petmagic-ci/toolcache"

if [[ ! -x "$runner_root/svc.sh" ]]; then
  echo "Runner service script is missing: $runner_root/svc.sh" >&2
  exit 1
fi

mkdir -p "$toolcache"
chmod 700 "$HOME/.cache/petmagic-ci" "$toolcache"

temporary_env="$(mktemp "$runner_root/.env.petmagic.XXXXXX")"
trap 'rm -f "$temporary_env"' EXIT

if [[ -f "$runner_env" ]]; then
  awk '!/^(AGENT_TOOLSDIRECTORY|RUNNER_TOOL_CACHE)=/' "$runner_env" > "$temporary_env"
fi
printf 'AGENT_TOOLSDIRECTORY=%s\nRUNNER_TOOL_CACHE=%s\n' "$toolcache" "$toolcache" >> "$temporary_env"
chmod 600 "$temporary_env"
mv "$temporary_env" "$runner_env"
trap - EXIT

launch_agent_dir="$HOME/Library/LaunchAgents"
shopt -s nullglob
service_plists=("$launch_agent_dir"/actions.runner*.plist)
if [[ "${#service_plists[@]}" -ne 1 ]]; then
  echo "Expected exactly one Actions runner LaunchAgent, found ${#service_plists[@]}." >&2
  exit 1
fi

service_label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "${service_plists[0]}")"
if [[ -z "$service_label" ]]; then
  echo 'Unable to read the runner LaunchAgent label.' >&2
  exit 1
fi

echo "Runner .env updated with writable toolcache: $toolcache"
echo "Restarting LaunchAgent $service_label; this maintenance job is expected to stop immediately."
launchctl kickstart -k "gui/$(id -u)/$service_label"
