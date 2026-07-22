import 'package:dio/dio.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/network/request_identity.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/templates/application/template_error_key_mapper.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';

abstract final class TemplateGenerationPolicy {
  static bool canUsePrivateApi(AppLaunchState state) {
    return state.isLoading || state.isAuthenticated;
  }

  static String createCorrelationId() {
    return RequestIdentity.createCorrelationId().replaceFirst(
      'flow-',
      'generation-',
    );
  }

  static bool isCancelled(Object error) {
    return error is RequestCancelledException ||
        (error is DioException && error.type == DioExceptionType.cancel);
  }

  static String mapError(Object error) {
    if (error is GenerationWaitTooLongException) return error.message;
    if (error is AppException && error.statusCode == 401) {
      return 'auth.sign_in_required';
    }
    if (error is AppException && error.statusCode == 402) {
      return 'templates.insufficient_balance';
    }
    if (error is AppException) {
      final message = normalizeTemplateErrorKey(error.message);
      if (message != null) return message;
    }
    return 'templates.generation_failed';
  }

  static GenerationWaitTooLongException? queueRejection(Object error) {
    return error is GenerationWaitTooLongException ? error : null;
  }

  static Duration pollInterval(TemplateGenerationResult? generation) {
    return switch (generation?.status) {
      TemplateGenerationStatus.queued => const Duration(seconds: 8),
      TemplateGenerationStatus.submittingToProvider ||
      TemplateGenerationStatus.providerQueued => const Duration(seconds: 5),
      TemplateGenerationStatus.processing ||
      TemplateGenerationStatus.preprocessing ||
      TemplateGenerationStatus.generating ||
      TemplateGenerationStatus.providerProcessing ||
      TemplateGenerationStatus.importingMedia ||
      TemplateGenerationStatus.cancellationRequested ||
      TemplateGenerationStatus.finalizing => const Duration(seconds: 3),
      _ => const Duration(seconds: 5),
    };
  }
}
