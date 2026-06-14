#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MEDIA_ROOT="${1:-"$ROOT_DIR/src/Host/PetMagic.Host.Api/wwwroot/templates-media/manual-qa"}"

if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required to create local QA image fixtures on macOS." >&2
  exit 1
fi

mkdir -p "$MEDIA_ROOT"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

make_ppm() {
  local output="$1"
  local variant="$2"

  awk -v variant="$variant" '
    BEGIN {
      w = 720;
      h = 540;
      print "P3";
      print w, h;
      print 255;

      for (y = 0; y < h; y++) {
        for (x = 0; x < w; x++) {
          r = 238 - int(y * 0.06);
          g = 244 - int(x * 0.02);
          b = 236 + int(y * 0.02);

          dx = x - 360;
          dy = y - 265;
          face = (dx * dx) / (150 * 150) + (dy * dy) / (120 * 120);
          if (face <= 1) {
            r = 214;
            g = 174;
            b = 126;
          }

          leftEar = ((x - 250) * (x - 250)) / (65 * 65) + ((y - 165) * (y - 165)) / (95 * 95);
          rightEar = ((x - 470) * (x - 470)) / (65 * 65) + ((y - 165) * (y - 165)) / (95 * 95);
          if (leftEar <= 1 || rightEar <= 1) {
            r = 175;
            g = 124;
            b = 82;
          }

          leftEye = ((x - 312) * (x - 312)) + ((y - 250) * (y - 250));
          rightEye = ((x - 408) * (x - 408)) + ((y - 250) * (y - 250));
          if (leftEye <= 18 * 18 || rightEye <= 18 * 18) {
            r = 36;
            g = 34;
            b = 30;
          }

          nose = ((x - 360) * (x - 360)) / (30 * 30) + ((y - 292) * (y - 292)) / (20 * 20);
          if (nose <= 1) {
            r = 58;
            g = 42;
            b = 36;
          }

          if (variant == "watermarked" && x >= w - 222 && x <= w - 22 && y >= h - 68 && y <= h - 22) {
            r = int(r * 0.45 + 255 * 0.55);
            g = int(g * 0.45 + 255 * 0.55);
            b = int(b * 0.45 + 255 * 0.55);
          }

          if (variant == "watermarked" && y >= h - 56 && y <= h - 34) {
            if ((x >= w - 205 && x <= w - 194) || (x >= w - 185 && x <= w - 174) || (x >= w - 165 && x <= w - 154) || (x >= w - 145 && x <= w - 134) || (x >= w - 125 && x <= w - 114) || (x >= w - 105 && x <= w - 94) || (x >= w - 85 && x <= w - 74) || (x >= w - 65 && x <= w - 54)) {
              r = int(r * 0.35 + 72 * 0.65);
              g = int(g * 0.35 + 55 * 0.65);
              b = int(b * 0.35 + 42 * 0.65);
            }
          }

          print r, g, b;
        }
      }
    }
  ' > "$output"
}

convert_ppm() {
  local input="$1"
  local format="$2"
  local output="$3"
  sips -s format "$format" "$input" --out "$output" >/dev/null
}

CLEAN_PPM="$TMP_DIR/clean.ppm"
WATERMARKED_PPM="$TMP_DIR/watermarked.ppm"
make_ppm "$CLEAN_PPM" clean
make_ppm "$WATERMARKED_PPM" watermarked

for name in \
  free-image-clean.png \
  no-credit-clean.png \
  premium-image-clean.png \
  preparing-clean.png; do
  convert_ppm "$CLEAN_PPM" png "$MEDIA_ROOT/$name"
done

for name in \
  free-image-watermarked.png \
  no-credit-watermarked.png \
  premium-image-watermarked.png \
  watermark-preview-image.png \
  watermark-preview-video-frame.png; do
  convert_ppm "$WATERMARKED_PPM" png "$MEDIA_ROOT/$name"
done

for name in \
  free-image-source.jpg \
  free-video-source.jpg \
  no-credit-source.jpg \
  premium-image-source.jpg \
  preparing-source.jpg; do
  convert_ppm "$CLEAN_PPM" jpeg "$MEDIA_ROOT/$name"
done

video_clean="${WATERMARK_QA_VIDEO_CLEAN:-}"
video_watermarked="${WATERMARK_QA_VIDEO_WATERMARKED:-}"

if [[ -n "$video_clean" && -n "$video_watermarked" ]]; then
  cp "$video_clean" "$MEDIA_ROOT/free-video-clean.mp4"
  cp "$video_watermarked" "$MEDIA_ROOT/free-video-watermarked.mp4"
  echo "Copied video QA fixtures into $MEDIA_ROOT."
elif command -v swift >/dev/null 2>&1; then
  swift - "$MEDIA_ROOT/free-video-clean.mp4" clean "$MEDIA_ROOT/free-video-watermarked.mp4" watermarked <<'SWIFT'
import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation

func drawSyntheticPet(context: CGContext, width: Int, height: Int, frame: Int, frameCount: Int) {
    let t = CGFloat(frame) / CGFloat(max(1, frameCount - 1))
    context.setFillColor(CGColor(red: 0.92 - t * 0.06, green: 0.96 - t * 0.04, blue: 0.94, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let sway = sin(t * .pi * 2) * 20
    let centerX = CGFloat(width) * 0.50 + sway
    let centerY = CGFloat(height) * 0.50

    context.setFillColor(CGColor(red: 0.69, green: 0.48, blue: 0.31, alpha: 1))
    context.fillEllipse(in: CGRect(x: centerX - 170, y: centerY - 170, width: 120, height: 175))
    context.fillEllipse(in: CGRect(x: centerX + 50, y: centerY - 170, width: 120, height: 175))

    context.setFillColor(CGColor(red: 0.82, green: 0.62, blue: 0.42, alpha: 1))
    context.fillEllipse(in: CGRect(x: centerX - 160, y: centerY - 120, width: 320, height: 250))

    context.setFillColor(CGColor(red: 0.12, green: 0.10, blue: 0.09, alpha: 1))
    context.fillEllipse(in: CGRect(x: centerX - 75, y: centerY - 20, width: 34, height: 34))
    context.fillEllipse(in: CGRect(x: centerX + 41, y: centerY - 20, width: 34, height: 34))
    context.fillEllipse(in: CGRect(x: centerX - 28, y: centerY + 40, width: 56, height: 36))
}

func drawWatermark(context: CGContext, width: Int, height: Int) {
    let badgeWidth = CGFloat(width) * 0.078
    let badgeHeight = max(CGFloat(height) * 0.035, 18)
    let margin = CGFloat(width) * 0.025
    let rect = CGRect(
        x: CGFloat(width) - badgeWidth - margin,
        y: CGFloat(height) - badgeHeight - margin,
        width: badgeWidth,
        height: badgeHeight)

    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.58))
    context.fill(rect)
    context.setFillColor(CGColor(red: 0.21, green: 0.16, blue: 0.12, alpha: 0.62))

    let barCount = 7
    let gap = badgeWidth / CGFloat(barCount * 2 + 1)
    let barWidth = gap
    for index in 0..<barCount {
        let barHeight = badgeHeight * (index % 2 == 0 ? 0.52 : 0.34)
        let x = rect.minX + gap + CGFloat(index * 2) * gap
        let y = rect.midY - barHeight / 2
        context.fill(CGRect(x: x, y: y, width: barWidth, height: barHeight))
    }
}

func renderVideo(path: String, variant: String) throws {
    let outputURL = URL(fileURLWithPath: path)
    try? FileManager.default.removeItem(at: outputURL)

    let width = 720
    let height = 540
    let fps: Int32 = 12
    let frameCount = 36

    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height
    ])
    input.expectsMediaDataInRealTime = false

    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: input,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ])

    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)

    for frame in 0..<frameCount {
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.01)
        }

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBuffer)
        guard let buffer = pixelBuffer else {
            throw NSError(domain: "PetMagicWatermarkQA", code: 1)
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!

        drawSyntheticPet(context: context, width: width, height: height, frame: frame, frameCount: frameCount)
        if variant == "watermarked" {
            drawWatermark(context: context, width: width, height: height)
        }

        adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: fps))
        CVPixelBufferUnlockBaseAddress(buffer, [])
    }

    input.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting {
        semaphore.signal()
    }
    semaphore.wait()

    if writer.status != .completed {
        throw writer.error ?? NSError(domain: "PetMagicWatermarkQA", code: 2)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count % 2 == 0 else {
    throw NSError(domain: "PetMagicWatermarkQA", code: 3)
}

var index = 0
while index < arguments.count {
    try renderVideo(path: arguments[index], variant: arguments[index + 1])
    index += 2
}
SWIFT
  echo "Generated synthetic MP4 video QA fixtures into $MEDIA_ROOT."
else
  rm -f "$MEDIA_ROOT/free-video-clean.mp4" "$MEDIA_ROOT/free-video-watermarked.mp4"
  echo "Image QA fixtures are ready in $MEDIA_ROOT."
  echo "Video fixtures were not created. Install Swift/AVFoundation or set WATERMARK_QA_VIDEO_CLEAN and WATERMARK_QA_VIDEO_WATERMARKED to real playable MP4 files, then rerun this script."
fi

echo "Watermark manual QA media preparation complete."
