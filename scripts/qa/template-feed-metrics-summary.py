#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


def read_text(path: Path) -> str:
    try:
        return path.read_text(errors="replace")
    except OSError:
        return ""


def first_du_total(path: Path) -> int | None:
    for line in read_text(path).splitlines():
        parts = line.split()
        if parts and parts[0].isdigit():
            return int(parts[0])
    return None


def phase_from_path(path: Path, prefix: str) -> str:
    stem = path.stem
    if stem.startswith(prefix):
        return stem[len(prefix) :]
    return stem


def du_samples(run_dir: Path, pattern: str, prefix: str) -> list[dict[str, int | str]]:
    samples = []
    for path in sorted(run_dir.glob(pattern)):
        value = first_du_total(path)
        if value is not None:
            samples.append({"phase": phase_from_path(path, prefix), "value": value})
    return samples


def max_du_total(run_dir: Path, pattern: str) -> int | None:
    values = []
    for path in run_dir.glob(pattern):
        value = first_du_total(path)
        if value is not None:
            values.append(value)
    return max(values) if values else None


def cache_delta(before: int | None, after: int | None) -> int | None:
    if before is None or after is None:
        return None
    return max(0, after - before)


def main() -> int:
    run_dir = Path(sys.argv[1])
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
    raw_performance_field_names = ("frame_build_times", "frame_rasterizer_times")
    if performance_path.exists():
        try:
            performance_data = json.loads(read_text(performance_path))
        except json.JSONDecodeError:
            performance_data = {}
        if not isinstance(performance_data, dict):
            performance_data = {}
        for key, value in performance_data.items():
            if not isinstance(value, dict):
                continue

            raw_report_fields = {
                report_key: report_value
                for report_key, report_value in value.items()
                if report_key not in raw_performance_field_names
            }
            if raw_report_fields:
                summary["flutter_report_data_raw"][key] = raw_report_fields

            if key == "templates_external_backend_smoke":
                probes = value.get("probes") if isinstance(value.get("probes"), list) else []
                random_probes = (
                    value.get("random_probes") if isinstance(value.get("random_probes"), list) else []
                )
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

    private_cache_samples = du_samples(run_dir, "android-private-cache-*.txt", "android-private-cache-")
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
    summary["android"]["max_private_cache_kb"] = max_du_total(run_dir, "android-private-cache-*.txt")

    external_cache_samples = du_samples(run_dir, "android-external-cache-*.txt", "android-external-cache-")
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
    summary["android"]["max_external_cache_kb"] = max_du_total(run_dir, "android-external-cache-*.txt")

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
        summary["android"]["network"]["max_rx_bytes"] = max(sample["rx_bytes"] for sample in network_samples)
        summary["android"]["network"]["max_tx_bytes"] = max(sample["tx_bytes"] for sample in network_samples)
        before_sample = next(
            (sample for sample in network_samples if sample["phase"] == "before"),
            network_samples[0],
        )
        after_sample = next(
            (sample for sample in reversed(network_samples) if sample["phase"] == "after"),
            network_samples[-1],
        )
        summary["android"]["network"]["rx_bytes_delta"] = max(
            0, after_sample["rx_bytes"] - before_sample["rx_bytes"]
        )
        summary["android"]["network"]["tx_bytes_delta"] = max(
            0, after_sample["tx_bytes"] - before_sample["tx_bytes"]
        )

    ios_cache_samples = du_samples(run_dir, "ios-simulator-cache-*.txt", "ios-simulator-cache-")
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

    (run_dir / "metrics-summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

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
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
