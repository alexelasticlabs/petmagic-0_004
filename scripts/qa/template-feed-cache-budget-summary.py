#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def read_positive_int(raw: str) -> int | None:
    try:
        value = int(str(raw).strip())
    except ValueError:
        return None
    return value if value > 0 else None


def main() -> int:
    run_dir = Path(sys.argv[1])
    thresholds = {
        "android_private_cache_delta_kb": sys.argv[2],
        "android_external_cache_delta_kb": sys.argv[3],
        "ios_simulator_cache_delta_kb": sys.argv[4],
    }
    metrics_path = run_dir / "metrics-summary.json"

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
            violations.append({"name": name, "actual_kb": actual_int, "limit_kb": limit})

    summary = {
        "thresholds": {key: read_positive_int(value) for key, value in thresholds.items()},
        "violations": violations,
        "violation_count": len(violations),
    }
    (run_dir / "cache-budget-summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
