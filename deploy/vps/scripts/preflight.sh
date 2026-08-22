#!/usr/bin/env bash
set -euo pipefail

readonly env_file="${1:-/opt/petmagic/shared/env/.env.vps}"
readonly deploy_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"

if [[ ! -f "$env_file" ]]; then
  echo "Missing VPS environment file: $env_file" >&2
  exit 1
fi

if [[ "$(stat -c '%a' "$env_file")" != "600" ]]; then
  echo "VPS environment file must have mode 0600." >&2
  exit 1
fi

duplicates="$(awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/ { count[$1]++ } END { for (key in count) if (count[key] > 1) print key }' "$env_file")"
if [[ -n "$duplicates" ]]; then
  echo "Duplicate keys in VPS environment file: $duplicates" >&2
  exit 1
fi

env_value() {
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

required=(
  SOURCE_REVISION POSTGRES_PASSWORD JWT_SIGNING_KEY FAL_AI_API_KEY
  R2_ACCOUNT_ID R2_ACCESS_KEY R2_SECRET_KEY R2_BUCKET_NAME R2_PUBLIC_URL
  PETMAGIC_BACKUP_R2_BUCKET
  STRIPE_LIVE_SECRET_KEY STRIPE_LIVE_PUBLISHABLE_KEY STRIPE_LIVE_WEBHOOK_SECRET
  GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL GOOGLE_PLAY_PRIVATE_KEY_PEM
  GOOGLE_PLAY_PUBSUB_AUDIENCE GOOGLE_PLAY_PUBSUB_EXPECTED_EMAIL
  GOOGLE_PLAY_PREMIUM_MONTHLY_PRODUCT_ID GOOGLE_PLAY_PREMIUM_YEARLY_PRODUCT_ID
  APP_STORE_SHARED_SECRET APP_STORE_PREMIUM_MONTHLY_PRODUCT_ID APP_STORE_PREMIUM_YEARLY_PRODUCT_ID
  FIREBASE_PROJECT_ID FIREBASE_SERVICE_ACCOUNT_JSON
  APPLE_CLIENT_ID APPLE_CLIENT_SECRET APPLE_AUDIENCES
  EMAIL_HOST EMAIL_PORT EMAIL_USERNAME EMAIL_PASSWORD EMAIL_FROM_ADDRESS
  ADMIN_MEDIA_ORIGINS
)

for key in "${required[@]}"; do
  value="$(env_value "$key")"
  if [[ -z "$value" || "$value" == *'__REQUIRED__'* || "$value" == *'replace_with_'* || "$value" == *'CHANGE_ME'* ]]; then
    echo "Missing or placeholder production value: $key" >&2
    exit 1
  fi
done

backup_r2_access_key="$(env_value PETMAGIC_BACKUP_R2_ACCESS_KEY)"
backup_r2_secret_key="$(env_value PETMAGIC_BACKUP_R2_SECRET_KEY)"
if [[ -n "$backup_r2_access_key" || -n "$backup_r2_secret_key" ]]; then
  if [[ -z "$backup_r2_access_key" || -z "$backup_r2_secret_key" \
    || "$backup_r2_access_key" == *'__REQUIRED__'* || "$backup_r2_secret_key" == *'__REQUIRED__'* ]]; then
    echo "Dedicated backup R2 credentials must be provided together, or both left empty for the application-key fallback." >&2
    exit 1
  fi
fi

google_client_id="$(env_value GOOGLE_CLIENT_ID)"
google_client_secret="$(env_value GOOGLE_CLIENT_SECRET)"
google_audiences="$(env_value GOOGLE_AUDIENCES)"
if [[ -n "$google_client_id" || -n "$google_client_secret" || -n "$google_audiences" ]]; then
  if [[ -z "$google_client_id" || -z "$google_client_secret" || -z "$google_audiences" \
    || "$google_client_id" == *'__REQUIRED__'* || "$google_client_secret" == *'__REQUIRED__'* \
    || "$google_audiences" == *'__REQUIRED__'* ]]; then
    echo "Google external auth must define GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, and GOOGLE_AUDIENCES together, or leave all three empty." >&2
    exit 1
  fi
fi

if [[ -n "$(git -c safe.directory="$deploy_root" -C "$deploy_root" status --porcelain 2>/dev/null)" ]]; then
  echo "The deployed release Git checkout must be clean." >&2
  exit 1
fi

source_revision="$(env_value SOURCE_REVISION)"
if [[ ! "$source_revision" =~ ^[0-9a-fA-F]{40}$ || "$source_revision" =~ ^0{40}$ ]]; then
  echo "SOURCE_REVISION must be the full 40-character Git commit SHA." >&2
  exit 1
fi

if ! git_revision="$(git -c safe.directory="$deploy_root" -C "$deploy_root" rev-parse HEAD 2>/dev/null)"; then
  echo "The deployed release must be a Git checkout." >&2
  exit 1
fi
if [[ "${git_revision,,}" != "${source_revision,,}" ]]; then
  echo "SOURCE_REVISION does not match the deployed Git checkout." >&2
  exit 1
fi

if [[ -n "$(env_value BOOTSTRAP_ADMIN_PASSWORD)" ]]; then
  echo "BOOTSTRAP_ADMIN_PASSWORD must remain empty in production." >&2
  exit 1
fi

for invariant in \
  'ASPNETCORE_ENVIRONMENT=Production' \
  'DOTNET_ENVIRONMENT=Production' \
  'DOCKER_BIND_ADDRESS=127.0.0.1' \
  'TEMPLATES_STORAGE_PROVIDER=R2' \
  'TEMPLATES_AI_PROVIDER=Fal' \
  'PETMAGIC_QA_FIXTURES_ENABLED=false' \
  'PETMAGIC_LOCAL_SMOKE_FAST_FAKE_COMPLETION=false' \
  'GENERATION_SCHEDULER_V2_ENABLED=false' \
  'TEMPLATES_FIREBASE_PUSH_ENABLED=true' \
  'ECONOMY_FIREBASE_PUSH_ENABLED=true'; do
  key="${invariant%%=*}"
  expected="${invariant#*=}"
  if [[ "$(env_value "$key")" != "$expected" ]]; then
    echo "Unsafe production value for $key; expected $expected." >&2
    exit 1
  fi
done

echo "VPS production environment preflight passed."
