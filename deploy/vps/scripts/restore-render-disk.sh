#!/usr/bin/env bash
# Historical one-time import artifact. Normal VPS deployment and operations do not invoke this script.
set -euo pipefail
umask 077

readonly import_root="/opt/petmagic/shared/backups/import"
readonly destination="/opt/petmagic/shared/api-data"
readonly archive_path="${1:-}"
readonly expected_sha="${2:-}"
staging_dir=""

if [[ -z "$archive_path" || ! -f "$archive_path" || ! "$expected_sha" =~ ^[0-9a-fA-F]{64}$ ]]; then
  echo "Usage: $0 /opt/petmagic/shared/backups/import/<api-data>.tar.gz <expected-sha256>" >&2
  exit 1
fi

resolved_archive="$(realpath "$archive_path")"
case "$resolved_archive" in
  "$import_root"/*) ;;
  *)
    echo "Refusing to restore an archive outside $import_root." >&2
    exit 1
    ;;
esac

actual_sha="$(sha256sum "$resolved_archive" | awk '{print $1}')"
if [[ "${actual_sha,,}" != "${expected_sha,,}" ]]; then
  echo "Initial API-data archive SHA-256 does not match the source manifest." >&2
  exit 1
fi

if find "$destination" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
  echo "Refusing to overwrite non-empty API data directory: $destination" >&2
  exit 1
fi

mapfile -t archive_entries < <(tar -tzf "$resolved_archive")
if [[ "${#archive_entries[@]}" -eq 0 ]]; then
  echo "Archive is empty." >&2
  exit 1
fi
while IFS= read -r metadata; do
  case "${metadata:0:1}" in
    -|d) ;;
    *)
      echo "Archive contains a non-regular entry." >&2
      exit 1
      ;;
  esac
done < <(tar -tvzf "$resolved_archive")

for entry in "${archive_entries[@]}"; do
  normalized="${entry#./}"
  if [[ "$entry" == /* || "/$normalized/" == */../* ]]; then
    echo "Archive contains an unsafe path." >&2
    exit 1
  fi
  case "$normalized" in
    ""|DataProtection-Keys|DataProtection-Keys/*|wwwroot|wwwroot/*) ;;
    *)
      echo "Archive has an unexpected top-level path: $entry" >&2
      exit 1
      ;;
  esac
done

staging_dir="$(mktemp -d /opt/petmagic/shared/.api-data-restore.XXXXXX)"
cleanup() {
  if [[ -n "$staging_dir" && -d "$staging_dir" ]]; then
    rm -rf -- "$staging_dir"
  fi
}
trap cleanup EXIT

tar -xzf "$resolved_archive" -C "$staging_dir"
if [[ ! -d "$staging_dir/DataProtection-Keys" || ! -d "$staging_dir/wwwroot" ]]; then
  echo "Archive is missing the expected DataProtection-Keys or wwwroot directory." >&2
  exit 1
fi
key_count="$(find "$staging_dir/DataProtection-Keys" -type f | wc -l)"
file_count="$(find "$staging_dir" -type f | wc -l)"
if [[ ! "$key_count" =~ ^[1-9][0-9]*$ || ! "$file_count" =~ ^[1-9][0-9]*$ ]]; then
  echo "Archive does not contain a Data Protection key." >&2
  exit 1
fi

chown -R root:root "$staging_dir"
find "$staging_dir" -type d -exec chmod 0700 {} +
find "$staging_dir" -type d -exec chmod g-s {} +
find "$staging_dir" -type f -exec chmod 0600 {} +
rmdir "$destination" 2>/dev/null || true
mv "$staging_dir" "$destination"
staging_dir=""
trap - EXIT
chown root:root "$destination"
chmod 0700 "$destination"
chmod g-s "$destination"

printf 'restoredAtUtc=%s\nsourceFile=%s\nsha256=%s\nfileCount=%s\ndataProtectionKeyCount=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(basename "$resolved_archive")" "$actual_sha" "$file_count" "$key_count" \
  > /opt/petmagic/shared/backups/render-disk-restore.marker

echo "Initial API-data import restore verified; files: $file_count"
