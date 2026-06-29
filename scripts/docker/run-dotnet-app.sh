#!/bin/sh
set -eu

APP_USER="${APP_USER:-appuser}"
APP_DLL="${APP_DLL:?APP_DLL is required}"

ensure_owned_dir() {
  target="$1"
  mkdir -p "$target"
  chown -R "$APP_USER:$APP_USER" "$target"
}

if [ "$(id -u)" = "0" ]; then
  if [ -n "${APP_VOLUME_DIRS:-}" ]; then
    for target in $APP_VOLUME_DIRS; do
      ensure_owned_dir "$target"
    done
  fi

  exec su -s /bin/sh "$APP_USER" -c "dotnet $APP_DLL"
fi

exec dotnet "$APP_DLL"
