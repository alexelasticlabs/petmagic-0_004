#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
release_script="${1:-$root/deploy/vps/scripts/deploy-release.sh}"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
env_file="$test_dir/test.env"
printf 'SOURCE_REVISION=old\nTEST_VALUE=preserved\n' > "$env_file"
chmod 600 "$env_file"
cp "$env_file" "$test_dir/original"

# Load only the writer, never the root-only deployment body.
source <(sed -n '/^write_source_revision() {/,/^}/p' "$release_script")

# Reproduce rollback's conditional call: set -e is disabled inside the function.
awk() { printf 'partial output\n'; return 1; }
if write_source_revision new; then
  echo 'Failed writer incorrectly reported success.' >&2
  exit 1
fi
cmp "$env_file" "$test_dir/original"
unset -f awk

awk() { return 0; }
if write_source_revision new; then
  echo 'Empty output incorrectly replaced the environment.' >&2
  exit 1
fi
cmp "$env_file" "$test_dir/original"
unset -f awk

mv() { return 1; }
if write_source_revision new; then
  echo 'Failed rename incorrectly reported success.' >&2
  exit 1
fi
cmp "$env_file" "$test_dir/original"
unset -f mv

write_source_revision new
printf 'SOURCE_REVISION=new\nTEST_VALUE=preserved\n' > "$test_dir/expected"
cmp "$env_file" "$test_dir/expected"
[[ "$(stat -c '%a' "$env_file")" == 600 ]]
[[ -z "$(find "$test_dir" -name 'test.env.tmp.*' -print -quit)" ]]
echo 'Release env writer safety: 4 checks passed.'
