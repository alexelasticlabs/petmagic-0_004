# Templates Preview Content Profile

This document defines required preview media parameters for template catalog cards.

## Goal

Preview assets must load fast, autoplay smoothly in viewport, and avoid excessive network/cache pressure.

## Required Rules

1. Container and codecs

- Preferred container: `mp4`
- Preferred video codec: `H.264`
- Preferred audio: no audio track

2. Duration

- Minimum duration: `0.5s`
- Maximum duration: `18.0s`
- Recommended target: `4s - 10s`

3. Playback behavior constraints

- Preview must look acceptable in silent loop mode.
- First frame must be meaningful (used as immediate visual context before playback starts).

4. Resolution and bitrate guidance

- Recommended max side: `1080px`
- Keep bitrate moderate for mobile autoplay scenarios.

## Backend Validation Notes

The admin media upload endpoint enforces preview duration bounds and requires duration metadata for preview videos.

## Operational Checklist

Before publishing a template preview:

- Verify duration is within bounds.
- Verify visual quality in muted looping playback.
- Verify first frame is representative of template output style.
- Avoid long intros and black frames.
