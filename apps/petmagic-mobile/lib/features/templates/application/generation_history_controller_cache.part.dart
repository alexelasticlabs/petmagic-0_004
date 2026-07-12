part of 'generation_history_controller.dart';

mixin _GenerationHistoryControllerCache on _GenerationHistoryControllerBase {
  @override
  void _upsertGeneration(TemplateGenerationResult generation) {
    final updatedCache = _upsertGenerationInCaches(
      state.cachedItemsByFilter,
      generation,
    );

    final visibleItems = state.cachedItemsByFilter.containsKey(state.filter)
        ? (updatedCache[state.filter] ?? const <TemplateGenerationResult>[])
        : _upsertGenerationInList(state.items, generation, state.filter);

    state = state.copyWith(
      items: visibleItems,
      cachedItemsByFilter: updatedCache,
    );
  }

  Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  _upsertGenerationInCaches(
    Map<GenerationHistoryFilter, List<TemplateGenerationResult>> caches,
    TemplateGenerationResult generation,
  ) {
    final updated = <GenerationHistoryFilter, List<TemplateGenerationResult>>{};
    for (final entry in caches.entries) {
      updated[entry.key] = _upsertGenerationInList(
        entry.value,
        generation,
        entry.key,
      );
    }
    return updated;
  }

  List<TemplateGenerationResult> _upsertGenerationInList(
    List<TemplateGenerationResult> source,
    TemplateGenerationResult generation,
    GenerationHistoryFilter filter,
  ) {
    final localizedGeneration = _applyLocalReadState(generation);
    final next = [
      for (final item in source)
        if (item.generationId != generation.generationId) item,
    ];

    if (_matchesFilter(localizedGeneration, filter)) {
      next.insert(0, localizedGeneration);
    }

    next.sort((left, right) => right.updatedAtUtc.compareTo(left.updatedAtUtc));
    return next;
  }

  @override
  Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  _markReadInCaches(
    Map<GenerationHistoryFilter, List<TemplateGenerationResult>> caches,
    String generationId,
  ) {
    final updated = <GenerationHistoryFilter, List<TemplateGenerationResult>>{};
    for (final entry in caches.entries) {
      updated[entry.key] = _markReadInList(entry.value, generationId);
    }
    return updated;
  }

  @override
  List<TemplateGenerationResult> _markReadInList(
    List<TemplateGenerationResult> source,
    String generationId,
  ) {
    return [
      for (final item in source)
        if (item.generationId == generationId)
          item.copyWith(isUnread: false)
        else
          item,
    ];
  }

  @override
  Map<GenerationHistoryFilter, List<TemplateGenerationResult>>
  _removeGenerationFromCaches(
    Map<GenerationHistoryFilter, List<TemplateGenerationResult>> caches,
    String generationId,
  ) {
    final updated = <GenerationHistoryFilter, List<TemplateGenerationResult>>{};
    for (final entry in caches.entries) {
      updated[entry.key] = _removeGenerationFromList(entry.value, generationId);
    }
    return updated;
  }

  @override
  List<TemplateGenerationResult> _removeGenerationFromList(
    List<TemplateGenerationResult> source,
    String generationId,
  ) {
    return [
      for (final item in source)
        if (item.generationId != generationId) item,
    ];
  }

  Set<String> _deletedUnreadGenerationIds(
    List<TemplateGenerationResult> remoteItems,
    Set<String> deletedGenerationIds,
  ) {
    if (deletedGenerationIds.isEmpty) {
      return const {};
    }

    return remoteItems
        .where(
          (item) =>
              item.isUnread && deletedGenerationIds.contains(item.generationId),
        )
        .map((item) => item.generationId)
        .toSet();
  }

  @override
  Future<Set<String>> _loadDeletedUnreadGenerationIds({
    required Set<String> deletedGenerationIds,
    required List<TemplateGenerationResult> remoteItems,
  }) async {
    if (deletedGenerationIds.isEmpty) {
      return const {};
    }

    final deletedUnreadIds = <String>{};
    void collect(List<TemplateGenerationResult>? items) {
      if (items == null || items.isEmpty) {
        return;
      }

      deletedUnreadIds.addAll(
        _deletedUnreadGenerationIds(items, deletedGenerationIds),
      );
    }

    collect(remoteItems);
    collect(state.items);
    for (final items in state.cachedItemsByFilter.values) {
      collect(items);
    }

    if (deletedUnreadIds.length < deletedGenerationIds.length) {
      collect(await _repository.readCachedGenerations());
    }

    return deletedUnreadIds;
  }

  @override
  int _visibleUnreadCount(int unreadCount) {
    if (unreadCount <= 0) {
      return unreadCount;
    }

    final locallyHiddenUnreadIds = {
      ..._locallyDeletedUnreadGenerationIds,
      ..._locallyReadUnreadGenerationIds,
    };
    if (locallyHiddenUnreadIds.isEmpty) {
      return unreadCount;
    }

    final adjusted = unreadCount - locallyHiddenUnreadIds.length;
    return adjusted < 0 ? 0 : adjusted;
  }

  @override
  void _reconcileLocallyReadIds(List<TemplateGenerationResult> remoteItems) {
    if ((_locallyReadGenerationIds.isEmpty &&
            _locallyReadUnreadGenerationIds.isEmpty) ||
        remoteItems.isEmpty) {
      return;
    }

    final serverReadIds = remoteItems
        .where(
          (item) =>
              (_locallyReadGenerationIds.contains(item.generationId) ||
                  _locallyReadUnreadGenerationIds.contains(
                    item.generationId,
                  )) &&
              !item.isUnread,
        )
        .map((item) => item.generationId)
        .toSet();
    if (serverReadIds.isEmpty) {
      return;
    }

    _locallyReadGenerationIds = {
      for (final id in _locallyReadGenerationIds)
        if (!serverReadIds.contains(id)) id,
    };
    _locallyReadUnreadGenerationIds = {
      for (final id in _locallyReadUnreadGenerationIds)
        if (!serverReadIds.contains(id)) id,
    };
  }

  @override
  TemplateGenerationResult? _findGeneration(String generationId) {
    for (final item in state.items) {
      if (item.generationId == generationId) {
        return item;
      }
    }

    for (final items in state.cachedItemsByFilter.values) {
      for (final item in items) {
        if (item.generationId == generationId) {
          return item;
        }
      }
    }

    return null;
  }

  @override
  List<TemplateGenerationResult> _decorateWithLocalMedia(
    List<TemplateGenerationResult> source,
    Set<String> deletedGenerationIds,
    List<GenerationGalleryMediaRecordView> localReadyRecords,
  ) {
    if (source.isEmpty) {
      return const [];
    }

    if (localReadyRecords.isEmpty && deletedGenerationIds.isEmpty) {
      return source.map(_applyLocalReadState).toList(growable: false);
    }

    final localById = {
      for (final record in localReadyRecords) record.generationId: record,
    };

    return source
        .where((item) => !deletedGenerationIds.contains(item.generationId))
        .map((item) {
          final localRecord = localById[item.generationId];
          if (localRecord == null ||
              localRecord.isDeletedLocally ||
              !_localRecordMatchesGeneration(localRecord, item)) {
            if (item.localPreviewPath == null &&
                item.localOutputPath == null &&
                !item.isLocalMediaReady) {
              return _applyLocalReadState(item);
            }
            return _applyLocalReadState(
              item.copyWith(
                clearLocalPreviewPath: true,
                clearLocalOutputPath: true,
                isLocalMediaReady: false,
              ),
            );
          }

          if (item.localPreviewPath == localRecord.previewLocalPath &&
              item.localOutputPath == localRecord.outputLocalPath &&
              item.isLocalMediaReady == localRecord.isDownloadComplete) {
            return _applyLocalReadState(item);
          }
          return _applyLocalReadState(
            item.copyWith(
              localPreviewPath: localRecord.previewLocalPath,
              localOutputPath: localRecord.outputLocalPath,
              isLocalMediaReady: localRecord.isDownloadComplete,
            ),
          );
        })
        .toList(growable: false);
  }

  TemplateGenerationResult _applyLocalReadState(
    TemplateGenerationResult generation,
  ) {
    if (!_locallyReadGenerationIds.contains(generation.generationId)) {
      return generation;
    }

    return generation.copyWith(isUnread: false);
  }

  bool _matchesFilter(
    TemplateGenerationResult generation,
    GenerationHistoryFilter filter,
  ) {
    return switch (filter) {
      GenerationHistoryFilter.all => true,
      GenerationHistoryFilter.active => !generation.isTerminal,
      GenerationHistoryFilter.ready => generation.isCompleted,
      GenerationHistoryFilter.failed => generation.isFailed,
    };
  }

  @override
  TemplateGenerationResult _applyLocalRecordToGeneration(
    TemplateGenerationResult generation,
    GenerationGalleryMediaRecordView record,
  ) {
    if (!_localRecordMatchesGeneration(record, generation)) {
      return generation.copyWith(
        clearLocalPreviewPath: true,
        clearLocalOutputPath: true,
        isLocalMediaReady: false,
      );
    }

    return generation.copyWith(
      localPreviewPath: record.previewLocalPath,
      localOutputPath: record.outputLocalPath,
      isLocalMediaReady: record.isDownloadComplete,
    );
  }
}

class _GenerationHistoryLoadRequest {
  const _GenerationHistoryLoadRequest({
    required this.filter,
    required this.refresh,
  });

  final GenerationHistoryFilter filter;
  final bool refresh;
}

String _historyLoadErrorMessage(Object error) {
  if (error is AppException) {
    final message = normalizeTemplateErrorKey(error.message);
    final safeMessage = switch (message) {
      'templates.connection_timeout' => message,
      'templates.server_timeout' => message,
      'templates.request_failed' => message,
      _ => null,
    };
    if (safeMessage != null) {
      return safeMessage;
    }

    final statusCode = error.statusCode;
    if (statusCode == 401) {
      return 'auth.session_expired';
    }
    if (statusCode == 408) {
      return 'templates.connection_timeout';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'templates.server_timeout';
    }

    return 'templates.request_failed';
  }

  return 'templates.request_failed';
}

bool _isCancelledRequest(Object error) {
  return error is RequestCancelledException;
}

bool _localRecordMatchesGeneration(
  GenerationGalleryMediaRecordView record,
  TemplateGenerationResult generation,
) {
  final previewUrl = _historyPreviewUrl(generation);
  final outputUrl = _safeGenerationMediaUrl(generation.outputUrl);
  if (previewUrl == null && outputUrl == null) {
    return false;
  }

  return _safeNullableMediaUrlEquals(record.previewRemoteUrl, previewUrl) &&
      _safeNullableMediaUrlEquals(record.outputRemoteUrl, outputUrl);
}

String? _historyPreviewUrl(TemplateGenerationResult generation) {
  final resultPreview = _safeGenerationMediaUrl(generation.resultPreviewUrl);
  final output = _safeGenerationMediaUrl(generation.outputUrl);
  final source = _safeGenerationMediaUrl(generation.sourceImageAsset?.url);
  final normalized = _safeGenerationMediaUrl(generation.normalizedImageUrl);
  final generationIsVideo = isVideoGenerationResult(generation);

  if (resultPreview != null && !isLikelyGenerationVideoUrl(resultPreview)) {
    return resultPreview;
  }

  if (generationIsVideo) {
    if (source != null) {
      return source;
    }
    if (normalized != null) {
      return normalized;
    }
    return output != null && isLikelyGenerationImageUrl(output) ? output : null;
  }

  if (output != null && !isLikelyGenerationVideoUrl(output)) {
    return output;
  }
  if (source != null) {
    return source;
  }
  if (normalized != null) {
    return normalized;
  }
  return null;
}

String? _safeGenerationMediaUrl(String? raw) {
  return parseSafeGenerationMediaUri(raw)?.toString();
}

bool _safeNullableMediaUrlEquals(String? left, String? right) {
  if (left == null && right == null) {
    return true;
  }
  if (left == null || right == null) {
    return false;
  }
  final leftUri = parseSafeGenerationMediaUri(left);
  final rightUri = parseSafeGenerationMediaUri(right);
  return leftUri != null &&
      rightUri != null &&
      leftUri.toString() == rightUri.toString();
}

// Generation history application cache orchestration.
