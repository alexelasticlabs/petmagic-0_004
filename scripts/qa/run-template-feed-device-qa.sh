#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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
LOCAL_MEDIA_HTTP_DEFINE=""
if [[ "$TARGET" == "integration_test/templates_feed_http_backend_smoke_test.dart" ]]; then
  LOCAL_MEDIA_HTTP_DEFINE="--dart-define=PETMAGIC_ALLOW_LOCAL_MEDIA_HTTP=true"
fi

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

  if [[ ! -f "$package_file" ]]; then
    return
  fi

  python3 - "$package_file" <<'PY'
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

  python3 - "$package_file" "$report_file" "$phase" <<'PY'
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
if command -v python3 >/dev/null 2>&1; then
  driver_request_result="$(
    python3 - "$RUN_DIR" <<'PY'
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
if command -v python3 >/dev/null 2>&1; then
  video_playback_log_marker_count="$(
    python3 - "$RUN_DIR/flutter-drive.log" \
      "$RUN_DIR/video-playback-log-summary.json" \
      "$RUN_DIR/video-playback-log-summary.md" <<'PY'
import json
import re
import sys
from pathlib import Path

log_path = Path(sys.argv[1])
json_path = Path(sys.argv[2])
markdown_path = Path(sys.argv[3])

patterns = (
    ("UnrecognizedInputFormatException", re.compile(r"UnrecognizedInputFormatException")),
    ("ExoPlaybackException", re.compile(r"ExoPlaybackException")),
    ("NoDeclaredBrand", re.compile(r"NoDeclaredBrand")),
    ("MediaCodecVideoRenderer error", re.compile(r"MediaCodecVideoRenderer error")),
    ("released video surface", re.compile(r"(?:The )?surface has been released", re.IGNORECASE)),
    ("Video player error", re.compile(r"Video player had error|VideoError", re.IGNORECASE)),
    ("Playback error", re.compile(r"\bPlayback error\b", re.IGNORECASE)),
    ("source error", re.compile(r"\bsource error\b", re.IGNORECASE)),
    ("AVPlayer error", re.compile(r"AVPlayer.*(?:error|failed)", re.IGNORECASE)),
)

matches = []
try:
    lines = log_path.read_text(errors="replace").splitlines()
except OSError:
    lines = []

for index, line in enumerate(lines, start=1):
    for name, pattern in patterns:
        if pattern.search(line):
            matches.append({
                "line": index,
                "marker": name,
                "text": line[:500],
            })
            break

summary = {
    "log_path": str(log_path),
    "marker_count": len(matches),
    "markers": matches[:50],
    "truncated": len(matches) > 50,
}
json_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

markdown_lines = ["# Video Playback Log Summary", ""]
markdown_lines.append(f"- marker_count: {summary['marker_count']}")
markdown_lines.append(f"- truncated: {str(summary['truncated']).lower()}")
if matches:
    markdown_lines.append("")
    markdown_lines.append("## Markers")
    markdown_lines.append("")
    for match in matches[:20]:
        text = match["text"].replace("\n", " ")
        markdown_lines.append(
            f"- line {match['line']}: {match['marker']}: {text}"
        )
markdown_path.write_text("\n".join(markdown_lines) + "\n")

print(len(matches))
PY
  )"
fi
if [[ "$video_playback_log_marker_count" != "0" ]]; then
  video_playback_log_failed=true
  completion_marker="${completion_marker}:video_playback_log_markers"
  if [[ "$drive_exit" -eq 0 ]]; then
    drive_exit=1
  fi
fi

{
  echo "{"
  echo "  \"completion_marker\": \"$completion_marker\","
  echo "  \"driver_request_result\": \"$driver_request_result\","
  echo "  \"exit_code\": $drive_exit,"
  echo "  \"build_failure_marker\": $build_failure_marker,"
  echo "  \"video_playback_log_failed\": $video_playback_log_failed,"
  echo "  \"video_playback_log_marker_count\": $video_playback_log_marker_count,"
  echo "  \"integration_response_data\": $(if [[ -f "$RUN_DIR/integration_response_data.json" ]]; then echo true; else echo false; fi)"
  echo "}"
} > "$RUN_DIR/completion-summary.json"

summarize_metrics() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 not found; skipping metrics summary" \
      > "$RUN_DIR/metrics-summary.md"
    return
  fi

  python3 - "$RUN_DIR" <<'PY'
import json
import re
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])

def read_text(path):
    try:
        return path.read_text(errors="replace")
    except OSError:
        return ""

summary = {
    "flutter_performance": {},
    "flutter_report_data": {},
    "flutter_report_data_raw": {},
    "external_backend_smoke": None,
    "android": {
        "max_total_pss_kb": None,
        "max_total_rss_kb": None,
        "private_cache_before_kb": None,
        "private_cache_after_kb": None,
        "private_cache_delta_kb": None,
        "max_private_cache_kb": None,
        "external_cache_before_kb": None,
        "external_cache_after_kb": None,
        "external_cache_delta_kb": None,
        "max_external_cache_kb": None,
        "network": {
            "app_uid": None,
            "rx_bytes_delta": None,
            "tx_bytes_delta": None,
            "max_rx_bytes": None,
            "max_tx_bytes": None,
            "samples": {},
        },
        "gfxinfo": {},
    },
    "ios_simulator": {
        "cache_before_kb": None,
        "cache_after_kb": None,
        "cache_delta_kb": None,
        "max_cache_kb": None,
    },
}

performance_path = run_dir / "integration_response_data.json"
performance_metric_names = (
    "frame_count",
    "average_frame_build_time_millis",
    "90th_percentile_frame_build_time_millis",
    "99th_percentile_frame_build_time_millis",
    "worst_frame_build_time_millis",
    "missed_frame_build_budget_count",
    "average_frame_rasterizer_time_millis",
    "90th_percentile_frame_rasterizer_time_millis",
    "99th_percentile_frame_rasterizer_time_millis",
    "worst_frame_rasterizer_time_millis",
    "missed_frame_rasterizer_budget_count",
    "new_gen_gc_count",
    "old_gen_gc_count",
)
raw_performance_field_names = (
    "frame_build_times",
    "frame_rasterizer_times",
)
if performance_path.exists():
    try:
        performance_data = json.loads(read_text(performance_path))
    except json.JSONDecodeError:
        performance_data = {}
    if not isinstance(performance_data, dict):
        performance_data = {}
    for key, value in performance_data.items():
        if isinstance(value, dict):
            raw_report_fields = {
                report_key: report_value
                for report_key, report_value in value.items()
                if report_key not in raw_performance_field_names
            }
            if raw_report_fields:
                summary["flutter_report_data_raw"][key] = raw_report_fields
            if key == "templates_external_backend_smoke":
                probes = value.get("probes") if isinstance(value.get("probes"), list) else []
                random_probes = value.get("random_probes") if isinstance(value.get("random_probes"), list) else []
                summary["external_backend_smoke"] = {
                    "stage": value.get("stage"),
                    "base_url": value.get("base_url"),
                    "request_count": value.get("request_count"),
                    "selected_category": value.get("selected_category"),
                    "selected_search": value.get("selected_search"),
                    "first_page_has_more": value.get("first_page_has_more"),
                    "first_page_next_cursor_present": value.get("first_page_next_cursor_present"),
                    "second_page_requested": value.get("second_page_requested"),
                    "reason": value.get("reason"),
                    "probes": [
                        {
                            "name": probe.get("name"),
                            "status_code": probe.get("status_code"),
                            "item_count": probe.get("item_count"),
                            "has_more": probe.get("has_more"),
                            "next_cursor_present": probe.get("next_cursor_present"),
                            "duplicate_count": probe.get("duplicate_count"),
                            "raw_elapsed_ms": probe.get("raw_elapsed_ms"),
                            "parsed_elapsed_ms": probe.get("parsed_elapsed_ms"),
                            "item_types": probe.get("item_types"),
                            "preview_content_types": probe.get("preview_content_types"),
                        }
                        for probe in probes
                        if isinstance(probe, dict)
                    ],
                    "random_probes": [
                        {
                            "mode": probe.get("mode"),
                            "category": probe.get("category"),
                            "include_premium": probe.get("include_premium"),
                            "elapsed_ms": probe.get("elapsed_ms"),
                            "template_present": probe.get("template_present"),
                            "template_type": probe.get("template_type"),
                            "template_category": probe.get("template_category"),
                            "is_premium": probe.get("is_premium"),
                        }
                        for probe in random_probes
                        if isinstance(probe, dict)
                    ],
                }
            performance_metrics = {
                metric: value.get(metric)
                for metric in performance_metric_names
                if value.get(metric) is not None
            }
            if performance_metrics:
                summary["flutter_performance"][key] = performance_metrics
            report_fields = {}
            for report_key, report_value in value.items():
                if report_key in performance_metric_names or report_key in raw_performance_field_names:
                    continue
                if isinstance(report_value, (str, int, float, bool)) or report_value is None:
                    report_fields[report_key] = report_value
                elif isinstance(report_value, list):
                    report_fields[report_key] = ",".join(str(item) for item in report_value[:20])
                elif isinstance(report_value, dict):
                    report_fields[report_key] = json.dumps(report_value, sort_keys=True)
            if report_fields:
                summary["flutter_report_data"][key] = report_fields

for path in run_dir.glob("android-meminfo-*.txt"):
    text = read_text(path)
    pss_match = re.search(r"TOTAL PSS:\s*(\d+)", text)
    rss_match = re.search(r"TOTAL RSS:\s*(\d+)", text)
    if pss_match:
        value = int(pss_match.group(1))
        current = summary["android"]["max_total_pss_kb"]
        summary["android"]["max_total_pss_kb"] = value if current is None else max(current, value)
    if rss_match:
        value = int(rss_match.group(1))
        current = summary["android"]["max_total_rss_kb"]
        summary["android"]["max_total_rss_kb"] = value if current is None else max(current, value)

def first_du_total(path):
    for line in read_text(path).splitlines():
        parts = line.split()
        if parts and parts[0].isdigit():
            return int(parts[0])
    return None

def phase_from_path(path, prefix):
    stem = path.stem
    if stem.startswith(prefix):
        return stem[len(prefix):]
    return stem

def du_samples(pattern, prefix):
    samples = []
    for path in sorted(run_dir.glob(pattern)):
        value = first_du_total(path)
        if value is not None:
            samples.append({
                "phase": phase_from_path(path, prefix),
                "value": value,
            })
    return samples

def max_du_total(pattern):
    values = []
    for path in run_dir.glob(pattern):
        value = first_du_total(path)
        if value is not None:
            values.append(value)
    return max(values) if values else None

def cache_delta(before, after):
    if before is None or after is None:
        return None
    return max(0, after - before)

private_cache_samples = du_samples(
    "android-private-cache-*.txt",
    "android-private-cache-",
)
private_cache_before = first_du_total(run_dir / "android-private-cache-before.txt")
private_cache_after = first_du_total(run_dir / "android-private-cache-after.txt")
if private_cache_before is None and private_cache_samples:
    private_cache_before = private_cache_samples[0]["value"]
if private_cache_after is None and private_cache_samples:
    private_cache_after = private_cache_samples[-1]["value"]
summary["android"]["private_cache_before_kb"] = private_cache_before
summary["android"]["private_cache_after_kb"] = private_cache_after
summary["android"]["private_cache_delta_kb"] = cache_delta(
    summary["android"]["private_cache_before_kb"],
    summary["android"]["private_cache_after_kb"],
)
summary["android"]["max_private_cache_kb"] = max_du_total("android-private-cache-*.txt")
external_cache_samples = du_samples(
    "android-external-cache-*.txt",
    "android-external-cache-",
)
external_cache_before = first_du_total(run_dir / "android-external-cache-before.txt")
external_cache_after = first_du_total(run_dir / "android-external-cache-after.txt")
if external_cache_before is None and external_cache_samples:
    external_cache_before = external_cache_samples[0]["value"]
if external_cache_after is None and external_cache_samples:
    external_cache_after = external_cache_samples[-1]["value"]
summary["android"]["external_cache_before_kb"] = external_cache_before
summary["android"]["external_cache_after_kb"] = external_cache_after
summary["android"]["external_cache_delta_kb"] = cache_delta(
    summary["android"]["external_cache_before_kb"],
    summary["android"]["external_cache_after_kb"],
)
summary["android"]["max_external_cache_kb"] = max_du_total("android-external-cache-*.txt")

for path in run_dir.glob("android-gfxinfo-*.txt"):
    text = read_text(path)
    frames = re.search(r"Total frames rendered:\s*(\d+)", text)
    janky = re.search(r"Janky frames:\s*(\d+)\s*\(([^)]+)\)", text)
    if frames and int(frames.group(1)) > 0:
        summary["android"]["gfxinfo"][path.stem.replace("android-gfxinfo-", "")] = {
            "total_frames": int(frames.group(1)),
            "janky_frames": int(janky.group(1)) if janky else None,
            "janky_percent": janky.group(2) if janky else None,
        }

network_samples = []
for path in sorted(run_dir.glob("android-network-uid-*.txt")):
    text = read_text(path)
    phase = path.stem.replace("android-network-uid-", "")
    uid_match = re.search(r"^APP_UID=(\d+)", text, re.MULTILINE)
    rows_match = re.search(r"^xt_qtaguid_rows=(\d+)", text, re.MULTILINE)
    rx_match = re.search(r"^rx_bytes=(\d+)", text, re.MULTILINE)
    tx_match = re.search(r"^tx_bytes=(\d+)", text, re.MULTILINE)
    sample = {
        "phase": phase,
        "app_uid": int(uid_match.group(1)) if uid_match else None,
        "xt_qtaguid_rows": int(rows_match.group(1)) if rows_match else None,
        "rx_bytes": int(rx_match.group(1)) if rx_match else None,
        "tx_bytes": int(tx_match.group(1)) if tx_match else None,
    }
    if sample["app_uid"] is not None:
        summary["android"]["network"]["app_uid"] = sample["app_uid"]
    if sample["rx_bytes"] is not None and sample["tx_bytes"] is not None:
        network_samples.append(sample)
        summary["android"]["network"]["samples"][phase] = {
            "rx_bytes": sample["rx_bytes"],
            "tx_bytes": sample["tx_bytes"],
            "xt_qtaguid_rows": sample["xt_qtaguid_rows"],
        }

if network_samples:
    summary["android"]["network"]["max_rx_bytes"] = max(
        sample["rx_bytes"] for sample in network_samples
    )
    summary["android"]["network"]["max_tx_bytes"] = max(
        sample["tx_bytes"] for sample in network_samples
    )
    before_sample = next(
        (sample for sample in network_samples if sample["phase"] == "before"),
        network_samples[0],
    )
    after_sample = next(
        (sample for sample in reversed(network_samples) if sample["phase"] == "after"),
        network_samples[-1],
    )
    summary["android"]["network"]["rx_bytes_delta"] = max(
        0,
        after_sample["rx_bytes"] - before_sample["rx_bytes"],
    )
    summary["android"]["network"]["tx_bytes_delta"] = max(
        0,
        after_sample["tx_bytes"] - before_sample["tx_bytes"],
    )

ios_cache_samples = du_samples(
    "ios-simulator-cache-*.txt",
    "ios-simulator-cache-",
)
ios_values = [sample["value"] for sample in ios_cache_samples]
ios_cache_before = first_du_total(run_dir / "ios-simulator-cache-before.txt")
ios_cache_after = first_du_total(run_dir / "ios-simulator-cache-after.txt")
if ios_cache_before is None and ios_cache_samples:
    ios_cache_before = ios_cache_samples[0]["value"]
if ios_cache_after is None and ios_cache_samples:
    ios_cache_after = ios_cache_samples[-1]["value"]
summary["ios_simulator"]["cache_before_kb"] = ios_cache_before
summary["ios_simulator"]["cache_after_kb"] = ios_cache_after
summary["ios_simulator"]["cache_delta_kb"] = cache_delta(
    summary["ios_simulator"]["cache_before_kb"],
    summary["ios_simulator"]["cache_after_kb"],
)
summary["ios_simulator"]["max_cache_kb"] = max(ios_values) if ios_values else None

(run_dir / "metrics-summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n"
)

lines = ["# Metrics Summary", ""]
if summary["flutter_performance"]:
    lines.append("## Flutter Performance")
    lines.append("")
    for key, metrics in summary["flutter_performance"].items():
        lines.append(f"- {key}:")
        for metric, value in metrics.items():
            lines.append(f"  - {metric}: {value}")
    lines.append("")

if summary["flutter_report_data"]:
    lines.append("## Flutter Report Data")
    lines.append("")
    for key, fields in summary["flutter_report_data"].items():
        lines.append(f"- {key}:")
        for field, value in fields.items():
            lines.append(f"  - {field}: {value}")
    lines.append("")

external = summary.get("external_backend_smoke")
if external:
    lines.append("## External Backend Smoke")
    lines.append("")
    for field in (
        "stage",
        "reason",
        "base_url",
        "request_count",
        "selected_category",
        "selected_search",
        "first_page_has_more",
        "first_page_next_cursor_present",
        "second_page_requested",
    ):
        if external.get(field) is not None:
            lines.append(f"- {field}: {external.get(field)}")
    if external.get("probes"):
        lines.append("- probes:")
        for probe in external["probes"]:
            lines.append(
                "  - "
                f"{probe.get('name')}: "
                f"status={probe.get('status_code')}, "
                f"items={probe.get('item_count')}, "
                f"has_more={probe.get('has_more')}, "
                f"next_cursor={probe.get('next_cursor_present')}, "
                f"duplicates={probe.get('duplicate_count')}, "
                f"raw_ms={probe.get('raw_elapsed_ms')}, "
                f"parse_ms={probe.get('parsed_elapsed_ms')}, "
                f"types={probe.get('item_types')}, "
                f"media={probe.get('preview_content_types')}"
            )
    if external.get("random_probes"):
        lines.append("- random_probes:")
        for probe in external["random_probes"]:
            lines.append(
                "  - "
                f"{probe.get('mode')}: "
                f"category={probe.get('category')}, "
                f"include_premium={probe.get('include_premium')}, "
                f"present={probe.get('template_present')}, "
                f"type={probe.get('template_type')}, "
                f"template_category={probe.get('template_category')}, "
                f"elapsed_ms={probe.get('elapsed_ms')}"
            )
    lines.append("")

android = summary["android"]
lines.append("## Android")
lines.append("")
for key in ("max_total_pss_kb", "max_total_rss_kb", "max_private_cache_kb", "max_external_cache_kb"):
    lines.append(f"- {key}: {android.get(key)}")
for key in (
    "private_cache_before_kb",
    "private_cache_after_kb",
    "private_cache_delta_kb",
    "external_cache_before_kb",
    "external_cache_after_kb",
    "external_cache_delta_kb",
):
    lines.append(f"- {key}: {android.get(key)}")
network = android["network"]
if network["samples"]:
    lines.append(f"- network_app_uid: {network.get('app_uid')}")
    lines.append(f"- network_rx_bytes_delta: {network.get('rx_bytes_delta')}")
    lines.append(f"- network_tx_bytes_delta: {network.get('tx_bytes_delta')}")
    lines.append(f"- network_max_rx_bytes: {network.get('max_rx_bytes')}")
    lines.append(f"- network_max_tx_bytes: {network.get('max_tx_bytes')}")
if android["gfxinfo"]:
    lines.append("- gfxinfo:")
    for phase, metrics in android["gfxinfo"].items():
        lines.append(
            f"  - {phase}: total_frames={metrics['total_frames']}, "
            f"janky_frames={metrics['janky_frames']}, "
            f"janky_percent={metrics['janky_percent']}"
        )
lines.append("")

lines.append("## iOS Simulator")
lines.append("")
for key in ("cache_before_kb", "cache_after_kb", "cache_delta_kb", "max_cache_kb"):
    lines.append(f"- {key}: {summary['ios_simulator'].get(key)}")
lines.append("")

(run_dir / "metrics-summary.md").write_text("\n".join(lines))
PY
}

summarize_metrics

cache_budget_violation_count=0
cache_budget_failed=false
if command -v python3 >/dev/null 2>&1; then
  cache_budget_violation_count="$(
    python3 - "$RUN_DIR" \
      "$QA_MAX_ANDROID_PRIVATE_CACHE_DELTA_KB" \
      "$QA_MAX_ANDROID_EXTERNAL_CACHE_DELTA_KB" \
      "$QA_MAX_IOS_SIMULATOR_CACHE_DELTA_KB" <<'PY'
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
thresholds = {
    "android_private_cache_delta_kb": sys.argv[2],
    "android_external_cache_delta_kb": sys.argv[3],
    "ios_simulator_cache_delta_kb": sys.argv[4],
}
metrics_path = run_dir / "metrics-summary.json"

def read_positive_int(raw):
    try:
        value = int(str(raw).strip())
    except ValueError:
        return None
    return value if value > 0 else None

try:
    metrics = json.loads(metrics_path.read_text())
except (OSError, json.JSONDecodeError):
    metrics = {}

android = metrics.get("android") if isinstance(metrics.get("android"), dict) else {}
ios = metrics.get("ios_simulator") if isinstance(metrics.get("ios_simulator"), dict) else {}
checks = [
    (
        "android_private_cache_delta_kb",
        android.get("private_cache_delta_kb"),
        read_positive_int(thresholds["android_private_cache_delta_kb"]),
    ),
    (
        "android_external_cache_delta_kb",
        android.get("external_cache_delta_kb"),
        read_positive_int(thresholds["android_external_cache_delta_kb"]),
    ),
    (
        "ios_simulator_cache_delta_kb",
        ios.get("cache_delta_kb"),
        read_positive_int(thresholds["ios_simulator_cache_delta_kb"]),
    ),
]

violations = []
for name, actual, limit in checks:
    if actual is None or limit is None:
        continue
    try:
        actual_int = int(actual)
    except (TypeError, ValueError):
        continue
    if actual_int > limit:
        violations.append({
            "name": name,
            "actual_kb": actual_int,
            "limit_kb": limit,
        })

summary = {
    "thresholds": {
        key: read_positive_int(value)
        for key, value in thresholds.items()
    },
    "violations": violations,
    "violation_count": len(violations),
}
(run_dir / "cache-budget-summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n"
)

lines = ["# Cache Budget Summary", ""]
for key, value in summary["thresholds"].items():
    lines.append(f"- {key}: {value}")
lines.append(f"- violation_count: {summary['violation_count']}")
if violations:
    lines.append("")
    lines.append("## Violations")
    lines.append("")
    for violation in violations:
        lines.append(
            f"- {violation['name']}: actual={violation['actual_kb']}KB, "
            f"limit={violation['limit_kb']}KB"
        )
(run_dir / "cache-budget-summary.md").write_text("\n".join(lines) + "\n")

print(len(violations))
PY
  )"
fi
if [[ "$cache_budget_violation_count" != "0" ]]; then
  cache_budget_failed=true
  completion_marker="${completion_marker}:cache_budget_violations"
  if [[ "$drive_exit" -eq 0 ]]; then
    drive_exit=1
  fi
fi

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
