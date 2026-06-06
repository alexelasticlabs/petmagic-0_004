#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SUITE_ID="${SUITE_ID:-minimal-$(date -u +%Y%m%dT%H%M%SZ)}"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-$ROOT_DIR/artifacts/load}"
SUITE_DIR="$ARTIFACT_ROOT/$SUITE_ID"

mkdir -p "$SUITE_DIR"

run_profile() {
  local name="$1"
  local profile="$2"
  local vus="$3"
  local iterations="$4"
  local duration="${5:-}"
  local rate="${6:-}"
  local mode="${7:-${MODE:-user}}"

  echo "Running $name: PROFILE=$profile MODE=$mode VUS=$vus ITERATIONS=$iterations DURATION=${duration:-default} RATE=${rate:-default}"

  RUN_ID="$SUITE_ID/$name" \
    MODE="$mode" \
    PROFILE="$profile" \
    VUS="$vus" \
    ITERATIONS="$iterations" \
    DURATION="${duration:-${DURATION:-2m}}" \
    RATE="${rate:-${RATE:-100}}" \
    bash "$ROOT_DIR/scripts/load/run-template-generation-baseline.sh"
}

cat > "$SUITE_DIR/suite-metadata.env" <<EOF
SUITE_ID=$SUITE_ID
BASE_URL=${BASE_URL:-http://host.docker.internal:5001}
TEMPLATE_ID=${TEMPLATE_ID:-}
MODE=${MODE:-user}
WORKER_COUNT=${WORKER_COUNT:-3}
EOF

# Minimal production-readiness suite:
# 100 create requests, 100 create+poll flows, 100 polling VUs,
# 10 duplicate-idempotency checks, and 10 overload VUs.
run_profile "01-generation-100" "generation" "100" "100"
run_profile "02-create-and-poll-100" "create-and-poll" "100" "100"
run_profile "03-polling-100" "polling" "100" "100" "${POLLING_DURATION:-2m}"
run_profile "04-duplicates-10" "duplicates" "10" "10" "" "" "${DUPLICATES_MODE:-user}"
run_profile "05-overload-10" "overload" "10" "10" "${OVERLOAD_DURATION:-2m}" "${OVERLOAD_RATE:-10}"

{
  echo "# PetMagic Minimal Load Suite"
  echo
  echo "- Suite: $SUITE_ID"
  echo "- Target: ${BASE_URL:-http://host.docker.internal:5001}"
  echo "- Template: ${TEMPLATE_ID:-unset}"
  echo "- Mode: ${MODE:-user}"
  echo "- Workers: ${WORKER_COUNT:-3}"
  echo
  echo "## Runs"
  echo
  find "$SUITE_DIR" -mindepth 2 -maxdepth 2 -name baseline-report.md -print | sort | sed "s#^$SUITE_DIR/#- #"
} > "$SUITE_DIR/minimal-suite-report.md"

echo "Minimal load suite artifacts written to $SUITE_DIR"
