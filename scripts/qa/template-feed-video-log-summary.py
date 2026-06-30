#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path


def main() -> int:
    log_path = Path(sys.argv[1])
    json_path = Path(sys.argv[2])
    markdown_path = Path(sys.argv[3])

    patterns = (
        ("UnrecognizedInputFormatException", re.compile(r"UnrecognizedInputFormatException")),
        ("ExoPlaybackException", re.compile(r"ExoPlaybackException")),
        ("NoDeclaredBrand", re.compile(r"NoDeclaredBrand")),
        ("MediaCodecVideoRenderer error", re.compile(r"MediaCodecVideoRenderer error")),
        (
            "released video surface",
            re.compile(r"(?:The )?surface has been released", re.IGNORECASE),
        ),
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
                matches.append(
                    {
                        "line": index,
                        "marker": name,
                        "text": line[:500],
                    }
                )
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
            markdown_lines.append(f"- line {match['line']}: {match['marker']}: {text}")
    markdown_path.write_text("\n".join(markdown_lines) + "\n")

    print(len(matches))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
