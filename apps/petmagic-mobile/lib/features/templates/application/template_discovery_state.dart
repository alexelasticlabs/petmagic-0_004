import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';

final class TemplateDiscoveryState {
  const TemplateDiscoveryState({
    this.sections = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.loadedFromCache = false,
    this.hasLoaded = false,
    this.errorMessage,
  });

  final List<TemplateDiscoverySection> sections;
  final bool isLoading;
  final bool isRefreshing;
  final bool loadedFromCache;
  final bool hasLoaded;
  final String? errorMessage;

  bool get isInitialLoading => isLoading && sections.isEmpty;
  bool get isEmpty => hasLoaded && sections.isEmpty && errorMessage == null;

  TemplateDiscoveryState copyWith({
    List<TemplateDiscoverySection>? sections,
    bool? isLoading,
    bool? isRefreshing,
    bool? loadedFromCache,
    bool? hasLoaded,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TemplateDiscoveryState(
      sections: sections ?? this.sections,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadedFromCache: loadedFromCache ?? this.loadedFromCache,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
