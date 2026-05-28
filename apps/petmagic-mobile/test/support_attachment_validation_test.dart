import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/support/presentation/support_attachment_validation.dart';

void main() {
  group('SupportAttachmentValidation', () {
    test('allows supported image within size limit', () {
      final result = SupportAttachmentValidation.validate(
        contentType: 'image/jpeg',
        fileSizeBytes: 1024,
        imageMaxBytes: 10 * 1024 * 1024,
        videoMaxBytes: 50 * 1024 * 1024,
        videoMaxDuration: const Duration(seconds: 60),
      );

      expect(result.isAllowed, isTrue);
      expect(result.isVideo, isFalse);
      expect(result.error, isNull);
    });

    test('rejects unsupported format', () {
      final result = SupportAttachmentValidation.validate(
        contentType: 'video/webm',
        fileSizeBytes: 1024,
        imageMaxBytes: 10 * 1024 * 1024,
        videoMaxBytes: 50 * 1024 * 1024,
        videoMaxDuration: const Duration(seconds: 60),
      );

      expect(result.isAllowed, isFalse);
      expect(result.error, SupportAttachmentValidationError.unsupportedFormat);
    });

    test('rejects oversized video', () {
      final result = SupportAttachmentValidation.validate(
        contentType: 'video/mp4',
        fileSizeBytes: 51 * 1024 * 1024,
        imageMaxBytes: 10 * 1024 * 1024,
        videoMaxBytes: 50 * 1024 * 1024,
        videoMaxDuration: const Duration(seconds: 60),
      );

      expect(result.isAllowed, isFalse);
      expect(result.error, SupportAttachmentValidationError.fileTooLarge);
    });

    test('rejects too long video duration', () {
      final result = SupportAttachmentValidation.validate(
        contentType: 'video/mp4',
        fileSizeBytes: 10 * 1024 * 1024,
        imageMaxBytes: 10 * 1024 * 1024,
        videoMaxBytes: 50 * 1024 * 1024,
        videoMaxDuration: const Duration(seconds: 60),
        videoDuration: const Duration(seconds: 61),
      );

      expect(result.isAllowed, isFalse);
      expect(result.error, SupportAttachmentValidationError.videoTooLong);
    });
  });
}
