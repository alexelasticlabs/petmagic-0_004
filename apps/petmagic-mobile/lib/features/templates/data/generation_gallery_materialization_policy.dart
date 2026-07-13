import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:petmagic_mobile/features/templates/data/generation_gallery_remote_file_materializer.dart';

class GenerationGalleryMaterializationPolicy {
  const GenerationGalleryMaterializationPolicy._();

  static bool isBackoffActive(DateTime? untilUtc, DateTime nowUtc) {
    return untilUtc != null && untilUtc.isAfter(nowUtc);
  }

  static void collectFailure(
    GenerationGalleryMaterializeFileResult result,
    Set<String> failureCodes,
  ) {
    final failureCode = result.failureCode;
    if (failureCode != null) {
      failureCodes.add(failureCode);
    }
  }

  static Duration retryBackoff(Duration baseBackoff, int failureCount) {
    final exponent = math.max(0, failureCount - 1);
    return baseBackoff * math.pow(2, exponent).toInt();
  }

  static String dioFailureCode(DioException error) {
    final statusCode = error.response?.statusCode ?? 0;
    return switch (statusCode) {
      401 || 403 => 'signed_url_unavailable',
      404 => 'storage_unavailable',
      408 || 429 || >= 500 => 'network_retryable',
      _ => 'network_error',
    };
  }
}
