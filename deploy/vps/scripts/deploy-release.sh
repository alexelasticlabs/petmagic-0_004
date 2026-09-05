#!/usr/bin/env bash
set -euo pipefail

readonly deploy_root="/opt/petmagic/current"
readonly env_file="/opt/petmagic/shared/env/.env.vps"
readonly ssh_config="/opt/petmagic/shared/git-deploy/ssh_config"
readonly release_lock="/run/petmagic/release.lock"
readonly expected_origin="git@github.com:alexelasticlabs/petmagic-0_004.git"
readonly restart_timeout_seconds=480
readonly minimum_release_free_bytes=$((12 * 1024 * 1024 * 1024))

fail() {
  echo "Release failed: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: sudo bash deploy/vps/scripts/deploy-release.sh [--revision <full-sha>]

Fetches origin/master, deploys its tip by default, and accepts an older commit
only when it is an ancestor of origin/master. The script rolls back the Git
checkout and SOURCE_REVISION if image build, service restart, or runtime
preflight fails.
EOF
}

read_env_value() {
  local key="$1"
  local value
  value="$(sed -n "s/^${key}=//p" "$env_file" | tail -n 1)"
  if (( ${#value} >= 2 )); then
    if [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]] \
      || [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi
  printf '%s' "$value"
}

write_source_revision() {
  local revision="$1"
  local temporary_path
  temporary_path="$(mktemp "${env_file}.tmp.XXXXXX")" || return 1
  chmod 600 "$temporary_path" || { rm -f "$temporary_path"; return 1; }

  # Explicit checks are required: rollback invokes this function in a conditional,
  # where Bash disables errexit even when the script uses set -e.
  if ! awk -v revision="$revision" '
    /^SOURCE_REVISION=/ {
      print "SOURCE_REVISION=" revision
      replaced = 1
      next
    }
    { print }
    END {
      if (!replaced) print "SOURCE_REVISION=" revision
    }
  ' "$env_file" > "$temporary_path"; then
    rm -f "$temporary_path"
    return 1
  fi

  [[ -s "$temporary_path" ]] || { rm -f "$temporary_path"; return 1; }
  mv -f "$temporary_path" "$env_file" || { rm -f "$temporary_path"; return 1; }
}

wait_for_service() {
  local elapsed=0
  while ! systemctl is-active --quiet petmagic-compose.service; do
    if (( elapsed >= restart_timeout_seconds )); then
      return 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
}

requested_revision=""
while (( $# > 0 )); do
  case "$1" in
    --revision)
      (( $# >= 2 )) || fail "--revision requires a full commit SHA."
      requested_revision="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ $EUID -eq 0 ]] || fail "Run this script with sudo."
[[ -f "$env_file" ]] || fail "Missing VPS environment file."
[[ -f "$ssh_config" ]] || fail "Missing root-only GitHub deploy-key SSH config."
[[ "$(stat -c '%a' "$env_file")" == "600" ]] || fail "VPS environment file must have mode 0600."

cd "$deploy_root"
git_cmd=(git -c "safe.directory=$deploy_root" -C "$deploy_root")
[[ "$("${git_cmd[@]}" remote get-url origin)" == "$expected_origin" ]] \
  || fail "origin must be the dedicated PetMagic GitHub SSH remote."
[[ -z "$("${git_cmd[@]}" status --porcelain)" ]] \
  || fail "The deployed checkout must be clean before a release."
systemctl is-active --quiet petmagic-postgres-backup.service \
  && fail "Off-site backup is running; wait for it to finish before a release."

exec 9>"$release_lock"
flock -n 9 || fail "Another release is already in progress."

previous_revision="$("${git_cmd[@]}" rev-parse HEAD)"
previous_source_revision="$(read_env_value SOURCE_REVISION)"
[[ "$previous_revision" == "$previous_source_revision" ]] \
  || fail "SOURCE_REVISION does not match the current deployed checkout."

rollback_needed=false
rollback_reserve=""
service_restart_attempted=false
rollback() {
  local status=$?
  trap - EXIT INT TERM ERR
  # Release reserved blocks before checkout/env restoration, including on ENOSPC.
  [[ -z "$rollback_reserve" ]] || rm -f "$rollback_reserve"
  if [[ "$rollback_needed" == true ]]; then
    echo "Release did not complete; restoring $previous_revision." >&2
    if ! "${git_cmd[@]}" checkout --detach "$previous_revision" >&2 \
      || ! write_source_revision "$previous_source_revision"; then
      echo "Rollback could not restore checkout/configuration; refusing to restart running services." >&2
      exit 1
    fi
    if [[ "$service_restart_attempted" == true ]]; then
      systemctl restart petmagic-compose.service >&2 || true
      wait_for_service || true
    fi
  fi
  exit "$status"
}

GIT_SSH_COMMAND="ssh -F $ssh_config" "${git_cmd[@]}" fetch --prune origin \
  '+refs/heads/master:refs/remotes/origin/master'

if [[ -n "$requested_revision" ]]; then
  [[ "$requested_revision" =~ ^[0-9a-fA-F]{40}$ ]] \
    || fail "--revision must be a full 40-character commit SHA."
  target_revision="$("${git_cmd[@]}" rev-parse --verify "${requested_revision}^{commit}")"
else
  target_revision="$("${git_cmd[@]}" rev-parse --verify 'origin/master^{commit}')"
fi

"${git_cmd[@]}" merge-base --is-ancestor "$target_revision" origin/master \
  || fail "Requested revision is not contained in origin/master."

if [[ "$target_revision" == "$previous_revision" ]]; then
  echo "PetMagic is already deployed at $target_revision."
  exit 0
fi

available_bytes="$(df --output=avail -B1 "$deploy_root" | tail -n 1 | tr -d ' ')"
[[ "$available_bytes" =~ ^[0-9]+$ ]] || fail "Could not determine available disk space."
(( available_bytes >= minimum_release_free_bytes )) \
  || fail "At least 12 GiB free disk space is required before building release images."
rollback_reserve="$(mktemp "${env_file}.reserve.XXXXXX")"
if ! fallocate -l 67108864 "$rollback_reserve"; then
  rm -f "$rollback_reserve"
  fail "Could not reserve disk space for rollback."
fi

rollback_needed=true
trap rollback EXIT INT TERM
"${git_cmd[@]}" checkout --detach "$target_revision"
write_source_revision "$target_revision"
bash deploy/vps/scripts/preflight.sh "$env_file"

compose=(docker compose --env-file "$env_file" -f docker-compose.yml -f deploy/vps/compose.vps.yaml)
"${compose[@]}" build --pull backend generation-worker admin-web
service_restart_attempted=true
systemctl restart petmagic-compose.service
wait_for_service || fail "petmagic-compose.service did not become active."
bash deploy/vps/scripts/runtime-preflight.sh

rollback_needed=false
rm -f "$rollback_reserve"
trap - EXIT INT TERM
echo "PetMagic release completed: $target_revision"
