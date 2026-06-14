#!/usr/bin/env bash
set -euo pipefail

container="${WATERMARK_QA_POSTGRES_CONTAINER:-petmagic-0_004-postgres-1}"
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

if [[ -n "$file" ]]; then
  docker exec -i "$container" psql -U "$db_user" -d "$db_name" "${forwarded[@]}" < "$file"
else
  docker exec -i "$container" psql -U "$db_user" -d "$db_name" "${forwarded[@]}"
fi
