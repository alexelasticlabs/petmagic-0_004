#!/usr/bin/env python3
import csv
import json
import re
import sys
from pathlib import Path


MEMINFO_RE = re.compile(
    r"\*\* MEMINFO in pid (?P<pid>\d+) \[com\.petmagic\.app\] \*\*.*?"
    r"TOTAL PSS:\s*(?P<pss>\d+)\s+TOTAL RSS:\s*(?P<rss>\d+)",
    re.DOTALL,
)


def phase_sort_key(path: Path) -> tuple[int, int]:
    name = path.stem
    if name.endswith("before"):
        return (0, 0)
    if name.endswith("after"):
        return (9, 0)
    match = re.search(r"during-(\d+)$", name)
    if match:
        return (1, int(match.group(1)))
    return (5, 0)


def phase_name(path: Path) -> str:
    prefix = "android-meminfo-"
    stem = path.stem
    return stem[len(prefix) :] if stem.startswith(prefix) else stem


def parse_meminfo(path: Path) -> dict[str, int | str] | None:
    try:
        raw = path.read_bytes()
    except OSError:
        return None
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        text = raw.decode("utf-16", errors="replace")
    else:
        text = raw.decode("utf-8", errors="replace")

    match = MEMINFO_RE.search(text)
    if not match:
        return None

    return {
        "phase": phase_name(path),
        "pid": int(match.group("pid")),
        "total_pss_kb": int(match.group("pss")),
        "total_rss_kb": int(match.group("rss")),
    }


def longest_pid_samples(samples: list[dict[str, int | str]]) -> list[dict[str, int | str]]:
    by_pid: dict[int, list[dict[str, int | str]]] = {}
    for sample in samples:
        by_pid.setdefault(int(sample["pid"]), []).append(sample)
    if not by_pid:
        return []
    return max(by_pid.values(), key=len)


def trend_summary(samples: list[dict[str, int | str]]) -> dict[str, int | float | bool | None]:
    if not samples:
        return {
            "sample_count": 0,
            "first_pss_kb": None,
            "last_pss_kb": None,
            "min_pss_kb": None,
            "max_pss_kb": None,
            "delta_pss_kb": None,
            "tail_delta_pss_kb": None,
            "monotonic_increase_steps": 0,
            "plateau_likely": False,
        }

    pss_values = [int(sample["total_pss_kb"]) for sample in samples]
    tail = pss_values[-min(5, len(pss_values)) :]
    monotonic_increase_steps = sum(
        1 for previous, current in zip(pss_values, pss_values[1:]) if current > previous
    )
    tail_delta = max(tail) - min(tail) if tail else 0
    total_delta = pss_values[-1] - pss_values[0]
    plateau_likely = len(pss_values) >= 5 and tail_delta <= max(2048, int(max(tail) * 0.02))

    return {
        "sample_count": len(samples),
        "first_pss_kb": pss_values[0],
        "last_pss_kb": pss_values[-1],
        "min_pss_kb": min(pss_values),
        "max_pss_kb": max(pss_values),
        "delta_pss_kb": total_delta,
        "tail_delta_pss_kb": tail_delta,
        "monotonic_increase_steps": monotonic_increase_steps,
        "plateau_likely": plateau_likely,
    }


def main() -> int:
    run_dir = Path(sys.argv[1])
    samples = [
        sample
        for sample in (
            parse_meminfo(path)
            for path in sorted(run_dir.glob("android-meminfo-*.txt"), key=phase_sort_key)
        )
        if sample is not None
    ]
    main_samples = longest_pid_samples(samples)
    summary = {
        "run_dir": str(run_dir),
        "all_sample_count": len(samples),
        "selected_pid": main_samples[0]["pid"] if main_samples else None,
        "selected_samples": main_samples,
        "trend": trend_summary(main_samples),
    }

    (run_dir / "memory-plateau-summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n"
    )
    with (run_dir / "memory-plateau-samples.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["phase", "pid", "total_pss_kb", "total_rss_kb"])
        writer.writeheader()
        writer.writerows(main_samples)

    trend = summary["trend"]
    lines = [
        "# Memory Plateau Summary",
        "",
        f"- all_sample_count: {summary['all_sample_count']}",
        f"- selected_pid: {summary['selected_pid']}",
        f"- selected_sample_count: {trend['sample_count']}",
        f"- first_pss_kb: {trend['first_pss_kb']}",
        f"- last_pss_kb: {trend['last_pss_kb']}",
        f"- min_pss_kb: {trend['min_pss_kb']}",
        f"- max_pss_kb: {trend['max_pss_kb']}",
        f"- delta_pss_kb: {trend['delta_pss_kb']}",
        f"- tail_delta_pss_kb: {trend['tail_delta_pss_kb']}",
        f"- monotonic_increase_steps: {trend['monotonic_increase_steps']}",
        f"- plateau_likely: {str(trend['plateau_likely']).lower()}",
    ]
    (run_dir / "memory-plateau-summary.md").write_text("\n".join(lines) + "\n")
    print(json.dumps(trend, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
