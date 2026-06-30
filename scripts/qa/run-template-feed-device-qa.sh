#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QA_DIR="$ROOT_DIR/scripts/qa"
MOBILE_DIR="$ROOT_DIR/apps/petmagic-mobile"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$ROOT_DIR/artifacts/mobile-template-feed}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
RUN_DIR="$ARTIFACT_ROOT/$RUN_ID"

DEVICE_ID="${DEVICE_ID:-}"
MODE="${MODE:-profile}"
TARGET="${TARGET:-integration_test/templates_feed_stress_test.dart}"
DRIVER="${DRIVER:-test_driver/integration_test.dart}"
APP_ID="${APP_ID:-com.petmagic.app}"
NETWORK_SPEED="${NETWORK_SPEED:-}"
ADB_BIN="${ADB_BIN:-}"
ANDROID_SAMPLE_INTERVAL_SECONDS="${ANDROID_SAMPLE_INTERVAL_SECONDS:-5}"
FLUTTER_DRIVE_EXTRA_ARGS="${FLUTTER_DRIVE_EXTRA_ARGS:-}"
QA_MAX_ANDROID_PRIVATE_CACHE_DELTA_KB="${QA_MAX_ANDROID_PRIVATE_CACHE_DELTA_KB:-65536}"
QA_MAX_ANDROID_EXTERNAL_CACHE_DELTA_KB="${QA_MAX_ANDROID_EXTERNAL_CACHE_DELTA_KB:-65536}"
QA_MAX_IOS_SIMULATOR_CACHE_DELTA_KB="${QA_MAX_IOS_SIMULATOR_CACHE_DELTA_KB:-65536}"
VIDEO_LOG_SUMMARY_PY="$QA_DIR/template-feed-video-log-summary.py"
METRICS_SUMMARY_PY="$QA_DIR/template-feed-metrics-summary.py"
CACHE_BUDGET_SUMMARY_PY="$QA_DIR/template-feed-cache-budget-summary.py"
LOCAL_MEDIA_HTTP_DEFINE=""
PYTHON_BIN=""
if [[ "$TARGET" == "integration_test/templates_feed_http_backend_smoke_test.dart" ]]; then
  LOCAL_MEDIA_HTTP_DEFINE="--dart-define=PETMAGIC_ALLOW_LOCAL_MEDIA_HTTP=true"
fi

for candidate in python3 python; do
  resolved_python="$(command -v "$candidate" 2>/dev/null || true)"
  if [[ -n "$resolved_python" && -x "$resolved_python" ]]; then
    PYTHON_BIN="$resolved_python"
    break
  fi
done

if [[ -z "$ADB_BIN" ]]; then
  adb_from_path="$(command -v adb 2>/dev/null || true)"
  for candidate in \
    "$adb_from_path" \
    "${ANDROID_HOME:-}/platform-tools/adb" \
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
    "$HOME/Library/Android/sdk/platform-tools/adb"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      ADB_BIN="$candidate"
      break
    fi
  done
fi

if [[ -z "$DEVICE_ID" ]]; then
  echo "Set DEVICE_ID to an attached Flutter device id." >&2
  echo "Available devices:" >&2
  (cd "$MOBILE_DIR" && flutter devices) >&2
  exit 2
fi

mkdir -p "$RUN_DIR"

metadata_file="$RUN_DIR/template-feed-device-qa.env"
{
  echo "RUN_ID=$RUN_ID"
  echo "DEVICE_ID=$DEVICE_ID"
  echo "MODE=$MODE"
  echo "TARGET=$TARGET"
  echo "DRIVER=$DRIVER"
  echo "APP_ID=$APP_ID"
  echo "NETWORK_SPEED=$NETWORK_SPEED"
  echo "ADB_BIN=$ADB_BIN"
  echo "ANDROID_SAMPLE_INTERVAL_SECONDS=$ANDROID_SAMPLE_INTERVAL_SECONDS"
  echo "FLUTTER_DRIVE_EXTRA_ARGS=$FLUTTER_DRIVE_EXTRA_ARGS"
  echo "QA_MAX_ANDROID_PRIVATE_CACHE_DELTA_KB=$QA_MAX_ANDROID_PRIVATE_CACHE_DELTA_KB"
  echo "QA_MAX_ANDROID_EXTERNAL_CACHE_DELTA_KB=$QA_MAX_ANDROID_EXTERNAL_CACHE_DELTA_KB"
  echo "QA_MAX_IOS_SIMULATOR_CACHE_DELTA_KB=$QA_MAX_IOS_SIMULATOR_CACHE_DELTA_KB"
  echo "LOCAL_MEDIA_HTTP_DEFINE=$LOCAL_MEDIA_HTTP_DEFINE"
  echo "GIT_COMMIT=$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  echo "UTC_STARTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$metadata_file"

(cd "$MOBILE_DIR" && flutter devices) > "$RUN_DIR/flutter-devices.txt" 2>&1 || true
(cd "$MOBILE_DIR" && flutter doctor -v) > "$RUN_DIR/flutter-doctor.txt" 2>&1 || true

is_android_device=false
if [[ -n "$ADB_BIN" ]] && "$ADB_BIN" -s "$DEVICE_ID" get-state >/dev/null 2>&1; then
  is_android_device=true
fi

is_ios_simulator=false
if command -v xcrun >/dev/null 2>&1 &&
  xcrun simctl list devices 2>/dev/null | grep -q "$DEVICE_ID"; then
  is_ios_simulator=true
fi

if [[ "$is_ios_simulator" == true && "$MODE" != "debug" ]]; then
  cat > "$RUN_DIR/blocked.txt" <<EOF
iOS Simulator cannot run Flutter profile/release integration builds.
Use MODE=debug for a functional simulator smoke, or use a physical iOS device for profile/FPS evidence.
EOF
  cat "$RUN_DIR/blocked.txt" >&2
  exit 2
fi

capture_android_snapshot() {
  local phase="$1"

  if [[ "$is_android_device" != true ]]; then
    return
  fi

  "$ADB_BIN" -s "$DEVICE_ID" shell dumpsys meminfo "$APP_ID" \
    > "$RUN_DIR/android-meminfo-$phase.txt" 2>&1 || true
  "$ADB_BIN" -s "$DEVICE_ID" shell dumpsys gfxinfo "$APP_ID" framestats \
    > "$RUN_DIR/android-gfxinfo-$phase.txt" 2>&1 || true
  "$ADB_BIN" -s "$DEVICE_ID" shell \
    "run-as $APP_ID sh -c 'du -ak cache 2>/dev/null | sort -nr | head -80'" \
    > "$RUN_DIR/android-private-cache-$phase.txt" 2>&1 || true
  "$ADB_BIN" -s "$DEVICE_ID" shell du -ak "/sdcard/Android/data/$APP_ID/cache" \
    > "$RUN_DIR/android-external-cache-$phase.txt" 2>&1 || true
  capture_android_uid_network_stats "$phase"
}

capture_android_uid_network_stats() {
  local phase="$1"
  local app_uid

  if [[ "$is_android_device" != true ]]; then
    return
  fi

  app_uid="$(
    "$ADB_BIN" -s "$DEVICE_ID" shell cmd package list packages -U "$APP_ID" 2>/dev/null |
      tr -d '\r' |
      sed -n 's/.*uid:\([0-9][0-9]*\).*/\1/p' |
      head -n 1 || true
  )"
  if [[ -z "$app_uid" ]]; then
    app_uid="$(
      "$ADB_BIN" -s "$DEVICE_ID" shell dumpsys package "$APP_ID" 2>/dev/null |
        tr -d '\r' |
        sed -n 's/.*userId=\([0-9][0-9]*\).*/\1/p' |
        head -n 1 || true
    )"
  fi

  {
    echo "APP_UID=$app_uid"
    if [[ -z "$app_uid" ]]; then
      echo "status=missing_uid"
      return 0
    fi

    echo "status=uid_resolved"
    echo "XT_QTAGUID_SUMMARY_BEGIN"
    "$ADB_BIN" -s "$DEVICE_ID" shell cat /proc/net/xt_qtaguid/stats 2>/dev/null |
      awk -v uid="$app_uid" '
        BEGIN { rows = 0; rx = 0; tx = 0 }
        NR > 1 && $4 == uid { rows += 1; rx += $6; tx += $8 }
        END {
          print "xt_qtaguid_rows=" rows
          print "rx_bytes=" rx
          print "tx_bytes=" tx
        }
      '
    echo "XT_QTAGUID_SUMMARY_END"
    echo "NETSTATS_DETAIL_BEGIN"
    "$ADB_BIN" -s "$DEVICE_ID" shell dumpsys netstats detail --uid "$app_uid" 2>/dev/null |
      head -200 || true
    echo "NETSTATS_DETAIL_END"
  } > "$RUN_DIR/android-network-uid-$phase.txt" 2>&1 || true
}

capture_ios_simulator_snapshot() {
  local phase="$1"
  local data_container

  if [[ "$is_ios_simulator" != true ]]; then
    return
  fi

  data_container="$(xcrun simctl get_app_container "$DEVICE_ID" "$APP_ID" data 2>/dev/null || true)"
  if [[ -z "$data_container" || ! -d "$data_container" ]]; then
    echo "No data container found for $APP_ID on $DEVICE_ID" \
      > "$RUN_DIR/ios-simulator-cache-$phase.txt"
    return
  fi

  {
    echo "DATA_CONTAINER=$data_container"
    du -ak \
      "$data_container/Library/Caches" \
      "$data_container/Library/Application Support" \
      "$data_container/Documents" \
      "$data_container/tmp" 2>/dev/null | sort -nr | head -120
  } > "$RUN_DIR/ios-simulator-cache-$phase.txt" 2>&1 || true
}

prepare_ios_simulator_spm_package() {
  local package_file="$MOBILE_DIR/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
  local report_file="$RUN_DIR/ios-spm-deployment-target.txt"

  if [[ "$is_ios_simulator" != true ]]; then
    return
  fi

  (
    cd "$MOBILE_DIR"
    flutter pub get
  ) > "$RUN_DIR/flutter-pub-get-ios.txt" 2>&1

  if [[ ! -f "$package_file" ]]; then
    {
      echo "FlutterGeneratedPluginSwiftPackage/Package.swift not found after flutter pub get."
      echo "Expected path: $package_file"
    } > "$report_file"
    return
  fi

  patch_ios_simulator_spm_package_once "$package_file"
  write_ios_spm_package_report "$package_file" "$report_file" "after-pub-get"
}

resolve_ios_simulator_spm_dependencies() {
  if [[ "$is_ios_simulator" != true ]]; then
    return
  fi

  (
    cd "$MOBILE_DIR/ios"
    xcodebuild \
      -resolvePackageDependencies \
      -workspace Runner.xcworkspace \
      -scheme Runner \
      -configuration Debug \
      -sdk iphonesimulator \
      -destination "id=$DEVICE_ID"
  ) > "$RUN_DIR/ios-spm-resolve-package-dependencies.txt" 2>&1 || true
}

patch_ios_simulator_spm_package_once() {
  local package_file="$1"

  if [[ ! -f "$package_file" || -z "$PYTHON_BIN" ]]; then
    return
  fi

  "$PYTHON_BIN" - "$package_file" <<'PY'
import re
import sys
from pathlib import Path

package_file = Path(sys.argv[1])
text = package_file.read_text()
updated = re.sub(r'\.iOS\("13\.0"\)', '.iOS("15.0")', text)
if updated != text:
    package_file.write_text(updated)
PY
}

write_ios_spm_package_report() {
  local package_file="$1"
  local report_file="$2"
  local phase="$3"

  if [[ ! -f "$package_file" ]]; then
    {
      echo "phase=$phase"
      echo "status=missing"
      echo "path=$package_file"
    } > "$report_file"
    return
  fi

  if [[ -z "$PYTHON_BIN" ]]; then
    {
      echo "phase=$phase"
      echo "status=missing_python"
      echo "path=$package_file"
    } > "$report_file"
    return
  fi

  "$PYTHON_BIN" - "$package_file" "$report_file" "$phase" <<'PY'
import sys
from pathlib import Path

package_file = Path(sys.argv[1])
report_file = Path(sys.argv[2])
phase = sys.argv[3]
text = package_file.read_text()
contains_ios_13 = '.iOS("13.0")' in text
contains_ios_15 = '.iOS("15.0")' in text
status = "compatible" if contains_ios_15 and not contains_ios_13 else "needs-patch"
report_file.write_text(
    f"phase={phase}\n"
    f"status={status}\n"
    f"path={package_file}\n"
    f"contains_iOS_13={contains_ios_13}\n"
    f"contains_iOS_15={contains_ios_15}\n"
)
PY
}

write_completion_summary() {
  {
    echo "{"
    echo "  \"completion_marker\": \"$completion_marker\","
    echo "  \"driver_request_result\": \"$driver_request_result\","
    echo "  \"exit_code\": $drive_exit,"
    echo "  \"build_failure_marker\": $build_failure_marker,"
    echo "  \"video_playback_log_failed\": $video_playback_log_failed,"
    echo "  \"video_playback_log_marker_count\": $video_playback_log_marker_count,"
    echo "  \"cache_budget_failed\": $cache_budget_failed,"
    echo "  \"cache_budget_violation_count\": $cache_budget_violation_count,"
    echo "  \"integration_response_data\": $(if [[ -f "$RUN_DIR/integration_response_data.json" ]]; then echo true; else echo false; fi)"
    echo "}"
  } > "$RUN_DIR/completion-summary.json"
}

ios_spm_patch_watchdog_pid=""
ios_spm_patch_watchdog_stop=""
start_ios_spm_patch_watchdog() {
  local package_file="$MOBILE_DIR/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"

  if [[ "$is_ios_simulator" != true ]]; then
    return
  fi

  ios_spm_patch_watchdog_stop="$RUN_DIR/ios-spm-patch-watchdog.stop"
  rm -f "$ios_spm_patch_watchdog_stop"
  (
    while [[ ! -f "$ios_spm_patch_watchdog_stop" ]]; do
      patch_ios_simulator_spm_package_once "$package_file"
      sleep 0.25
    done
    patch_ios_simulator_spm_package_once "$package_file"
  ) > "$RUN_DIR/ios-spm-patch-watchdog.log" 2>&1 &
  ios_spm_patch_watchdog_pid=$!
}

stop_ios_spm_patch_watchdog() {
  if [[ -z "$ios_spm_patch_watchdog_pid" ]]; then
    return
  fi

  touch "$ios_spm_patch_watchdog_stop"
  wait "$ios_spm_patch_watchdog_pid" 2>/dev/null || true
  ios_spm_patch_watchdog_pid=""
}

capture_android_network_status() {
  local phase="$1"

  if [[ "$is_android_device" != true ]]; then
    return
  fi

  "$ADB_BIN" -s "$DEVICE_ID" emu network status \
    > "$RUN_DIR/android-network-status-$phase.txt" 2>&1 || true
}

reset_android_network() {
  if [[ "$is_android_device" == true && -n "$NETWORK_SPEED" ]]; then
    "$ADB_BIN" -s "$DEVICE_ID" emu network speed full >/dev/null 2>&1 || true
    capture_android_network_status after-reset
  fi
}

capture_android_network_status before
if [[ "$is_android_device" == true && -n "$NETWORK_SPEED" ]]; then
  "$ADB_BIN" -s "$DEVICE_ID" emu network speed "$NETWORK_SPEED" \
    > "$RUN_DIR/android-network-speed.txt" 2>&1 || true
  capture_android_network_status after-set
  trap reset_android_network EXIT
fi

capture_android_snapshot before
capture_ios_simulator_snapshot before
prepare_ios_simulator_spm_package
resolve_ios_simulator_spm_dependencies
if [[ "$is_ios_simulator" == true ]]; then
  xcrun simctl terminate "$DEVICE_ID" "$APP_ID" \
    > "$RUN_DIR/ios-simulator-terminate-before.txt" 2>&1 || true
fi

rm -f "$MOBILE_DIR/build/integration_response_data.json"
rm -f "$MOBILE_DIR"/build/flutter_driver_commands_*.log
rm -f "$RUN_DIR/integration_response_data.json"
rm -f "$RUN_DIR"/flutter_driver_commands_*.log

drive_args=(flutter drive "--driver=$DRIVER" "--target=$TARGET" -d "$DEVICE_ID" --no-dds)
if [[ "$MODE" == "profile" ]]; then
  drive_args+=(--profile)
elif [[ "$MODE" == "release" ]]; then
  drive_args+=(--release)
elif [[ "$MODE" != "debug" ]]; then
  echo "MODE must be debug, profile, or release." >&2
  exit 2
fi
if [[ -n "$FLUTTER_DRIVE_EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  extra_drive_args=($FLUTTER_DRIVE_EXTRA_ARGS)
  drive_args+=("${extra_drive_args[@]}")
fi
if [[ -n "$LOCAL_MEDIA_HTTP_DEFINE" ]]; then
  drive_args+=("$LOCAL_MEDIA_HTTP_DEFINE")
fi
if [[ "$is_ios_simulator" == true ]]; then
  drive_args+=(--no-pub)
fi

set +e
start_ios_spm_patch_watchdog
(
  cd "$MOBILE_DIR"
  export FLUTTER_TEST_OUTPUTS_DIR="$RUN_DIR"
  "${drive_args[@]}"
) > "$RUN_DIR/flutter-drive.log" 2>&1 &
drive_pid=$!

sample_index=0
while kill -0 "$drive_pid" >/dev/null 2>&1; do
  sample_index=$((sample_index + 1))
  capture_android_snapshot "during-$(printf '%02d' "$sample_index")"
  capture_ios_simulator_snapshot "during-$(printf '%02d' "$sample_index")"
  sleep "$ANDROID_SAMPLE_INTERVAL_SECONDS"
done

wait "$drive_pid"
drive_exit=$?
stop_ios_spm_patch_watchdog
set -e
if [[ "$is_ios_simulator" == true ]]; then
  write_ios_spm_package_report \
    "$MOBILE_DIR/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift" \
    "$RUN_DIR/ios-spm-deployment-target-after-drive.txt" \
    "after-drive"
fi

capture_android_snapshot after
capture_ios_simulator_snapshot after
reset_android_network

if [[ -f "$MOBILE_DIR/build/integration_response_data.json" ]]; then
  if [[ ! -f "$RUN_DIR/integration_response_data.json" ]]; then
    cp "$MOBILE_DIR/build/integration_response_data.json" \
      "$RUN_DIR/integration_response_data.json"
  fi
fi
for driver_log in "$MOBILE_DIR"/build/flutter_driver_commands_*.log; do
  if [[ -f "$driver_log" ]]; then
    cp "$driver_log" "$RUN_DIR/$(basename "$driver_log")"
  fi
done

completion_marker="not_found"
if grep -q "All tests passed" "$RUN_DIR/flutter-drive.log"; then
  completion_marker="all_tests_passed_log"
fi
build_failure_marker=false
if grep -Eq "Failed to build iOS app|Could not build the application|BUILD FAILED|Execution failed for task" "$RUN_DIR/flutter-drive.log"; then
  build_failure_marker=true
  completion_marker="${completion_marker}:build_failed"
  if [[ "$drive_exit" -eq 0 ]]; then
    drive_exit=1
  fi
  rm -f "$RUN_DIR/integration_response_data.json"
  rm -f "$RUN_DIR"/flutter_driver_commands_*.log
fi
driver_request_result="not_found"
if [[ -n "$PYTHON_BIN" ]]; then
  driver_request_result="$(
    "$PYTHON_BIN" - "$RUN_DIR" <<'PY'
import re
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
matches = []
for path in sorted(run_dir.glob("flutter_driver_commands_*.log")):
    try:
        text = path.read_text(errors="replace")
    except OSError:
        continue
    matches.extend(re.findall(r'"result":"(true|false)"', text))
if matches:
    print(matches[-1])
else:
    print("not_found")
PY
  )"
fi
if [[ "$completion_marker" == "not_found" && "$driver_request_result" == "true" ]]; then
  completion_marker="driver_request_data_true"
elif [[ "$driver_request_result" == "false" ]]; then
  completion_marker="driver_request_data_false"
fi
if grep -q "Service connection disposed" "$RUN_DIR/flutter-drive.log"; then
  completion_marker="${completion_marker}:service_connection_disposed"
fi

video_playback_log_marker_count=0
video_playback_log_failed=false
cache_budget_violation_count=0
cache_budget_failed=false
if [[ -n "$PYTHON_BIN" && -f "$VIDEO_LOG_SUMMARY_PY" ]]; then
  video_playback_log_marker_count="$(
    "$PYTHON_BIN" \
      "$VIDEO_LOG_SUMMARY_PY" \
      "$RUN_DIR/flutter-drive.log" \
      "$RUN_DIR/video-playback-log-summary.json" \
      "$RUN_DIR/video-playback-log-summary.md"
  )"
fi
if [[ "$video_playback_log_marker_count" != "0" ]]; then
  video_playback_log_failed=true
  completion_marker="${completion_marker}:video_playback_log_markers"
  if [[ "$drive_exit" -eq 0 ]]; then
    drive_exit=1
  fi
fi

summarize_metrics() {
  if [[ -z "$PYTHON_BIN" || ! -f "$METRICS_SUMMARY_PY" ]]; then
    echo "python interpreter not found; skipping metrics summary" \
      > "$RUN_DIR/metrics-summary.md"
    return
  fi

  "$PYTHON_BIN" "$METRICS_SUMMARY_PY" "$RUN_DIR"
}

summarize_metrics

if [[ -n "$PYTHON_BIN" && -f "$CACHE_BUDGET_SUMMARY_PY" ]]; then
  cache_budget_violation_count="$(
    "$PYTHON_BIN" "$CACHE_BUDGET_SUMMARY_PY" \
      "$RUN_DIR" \
      "$QA_MAX_ANDROID_PRIVATE_CACHE_DELTA_KB" \
      "$QA_MAX_ANDROID_EXTERNAL_CACHE_DELTA_KB" \
      "$QA_MAX_IOS_SIMULATOR_CACHE_DELTA_KB"
  )"
fi
if [[ "$cache_budget_violation_count" != "0" ]]; then
  cache_budget_failed=true
  completion_marker="${completion_marker}:cache_budget_violations"
  if [[ "$drive_exit" -eq 0 ]]; then
    drive_exit=1
  fi
fi

write_completion_summary

{
  echo "# Template Feed Device QA"
  echo
  echo "- Run: $RUN_ID"
  echo "- Device: $DEVICE_ID"
  echo "- Mode: $MODE"
  echo "- Target: $TARGET"
  echo "- App id: $APP_ID"
  echo "- Network speed: ${NETWORK_SPEED:-default}"
  echo "- Exit code: $drive_exit"
  echo "- Completion marker: $completion_marker"
  echo "- Driver request result: $driver_request_result"
  echo "- Integration response data: $(if [[ -f "$RUN_DIR/integration_response_data.json" ]]; then echo present; else echo missing; fi)"
  echo "- Video playback log markers: $video_playback_log_marker_count"
  echo "- Cache budget violations: $cache_budget_violation_count"
  echo
  if [[ -f "$RUN_DIR/metrics-summary.md" ]]; then
    cat "$RUN_DIR/metrics-summary.md"
    echo
  fi
  if [[ -f "$RUN_DIR/cache-budget-summary.md" ]]; then
    cat "$RUN_DIR/cache-budget-summary.md"
    echo
  fi
  if [[ -f "$RUN_DIR/video-playback-log-summary.md" ]]; then
    cat "$RUN_DIR/video-playback-log-summary.md"
    echo
  fi
  echo
  echo "## Artifacts"
  echo
  find "$RUN_DIR" -maxdepth 1 -type f -print | sort | sed "s#^$RUN_DIR/#- #"
} > "$RUN_DIR/template-feed-device-qa-report.md"

echo "Template feed QA artifacts written to $RUN_DIR"
exit "$drive_exit"
