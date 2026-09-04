import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/platform/app_runtime_info.dart';
import 'package:petmagic_mobile/features/templates/application/template_discovery_repository.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_cache_data_source.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_dto.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_remote_data_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';

final defaultTemplateDiscoveryRepositoryProvider =
    Provider<TemplateDiscoveryRepository>((ref) {
      return DefaultTemplateDiscoveryRepository(
        remoteDataSource: ref.watch(templateDiscoveryRemoteDataSourceProvider),
        cacheDataSource: ref.watch(templateDiscoveryCacheDataSourceProvider),
        runtimeInfo: ref.watch(appRuntimeInfoProvider),
      );
    });

final class DefaultTemplateDiscoveryRepository
    implements TemplateDiscoveryRepository {
  const DefaultTemplateDiscoveryRepository({
    required TemplateDiscoveryRemoteDataSource remoteDataSource,
    required TemplateDiscoveryCacheDataSource cacheDataSource,
    required AppRuntimeInfo runtimeInfo,
  }) : _remoteDataSource = remoteDataSource,
       _cacheDataSource = cacheDataSource,
       _runtimeInfo = runtimeInfo;

  final TemplateDiscoveryRemoteDataSource _remoteDataSource;
  final TemplateDiscoveryCacheDataSource _cacheDataSource;
  final AppRuntimeInfo _runtimeInfo;

  @override
  Future<TemplateDiscovery?> readCached() async {
    final localeTag = _runtimeInfo.locale.languageTag;
    final cached = await _cacheDataSource.read(localeTag: localeTag);
    return cached?.toDomain();
  }

  @override
  Future<TemplateDiscovery> fetch() async {
    final localeTag = _runtimeInfo.locale.languageTag;
    final dto = await _remoteDataSource.fetch();
    unawaited(_persistBestEffort(dto, localeTag: localeTag));
    return dto.toDomain();
  }

  Future<void> _persistBestEffort(
    TemplateDiscoveryDto dto, {
    required String localeTag,
  }) async {
    try {
      await _cacheDataSource.write(dto, localeTag: localeTag);
    } catch (error, stackTrace) {
      AppLogger.warn(
        feature: 'Templates.Discovery',
        operation: 'persist_cache',
        message: 'Template discovery cache could not be persisted.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void cancelPendingRequest() => _remoteDataSource.cancelPendingRequest();
}
