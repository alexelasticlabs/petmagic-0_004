#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
service="${WATERMARK_QA_POSTGRES_SERVICE:-postgres}"
container="${WATERMARK_QA_POSTGRES_CONTAINER:-}"
db_user="${WATERMARK_QA_POSTGRES_USER:-petmagic_user}"
db_name="${WATERMARK_QA_POSTGRES_DB:-petmagic_db}"

args=("$@")
if [[ ${#args[@]} -gt 0 && "${args[0]}" =~ ^postgres(ql)?:// ]]; then
  args=("${args[@]:1}")
fi

file=""
forwarded=()
index=0
while [[ $index -lt ${#args[@]} ]]; do
  arg="${args[$index]}"
  if [[ "$arg" == "-f" && $((index + 1)) -lt ${#args[@]} ]]; then
    file="${args[$((index + 1))]}"
    index=$((index + 2))
    continue
  fi

  forwarded+=("$arg")
  index=$((index + 1))
done

if [[ -n "$container" ]]; then
  if [[ -n "$file" ]]; then
    docker exec -i "$container" psql -U "$db_user" -d "$db_name" "${forwarded[@]}" < "$file"
  else
    docker exec -i "$container" psql -U "$db_user" -d "$db_name" "${forwarded[@]}"
  fi
  exit 0
fi

if [[ -n "$file" ]]; then
  docker compose -f "$repo_root/docker-compose.yml" exec -T "$service" \
    psql -U "$db_user" -d "$db_name" "${forwarded[@]}" < "$file"
else
  docker compose -f "$repo_root/docker-compose.yml" exec -T "$service" \
    psql -U "$db_user" -d "$db_name" "${forwarded[@]}"
fi
