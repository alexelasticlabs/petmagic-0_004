import 'package:petmagic_mobile/features/templates/domain/template_discovery_models.dart';

final class TemplateDiscoveryState {
  const TemplateDiscoveryState({
    this.sections = const [],
    this.page,
    this.revision,
    this.isLoading = false,
    this.isRefreshing = false,
    this.loadedFromCache = false,
    this.hasLoaded = false,
    this.errorMessage,
  });

  final List<TemplateDiscoverySection> sections;
  final TemplateDiscoveryPageSettings? page;
  final int? revision;

  List<TemplateDiscoverySection> get carouselSections =>
      page?.carouselEnabled == false
      ? const []
      : sections.where((section) => section.showInCarousel).toList();

  List<TemplateDiscoverySection> get railSections =>
      sections.where((section) => section.showAsRail).toList();
  final bool isLoading;
  final bool isRefreshing;
  final bool loadedFromCache;
  final bool hasLoaded;
  final String? errorMessage;

  bool get isInitialLoading => isLoading && sections.isEmpty;
  bool get isEmpty =>
      hasLoaded &&
      carouselSections.isEmpty &&
      railSections.isEmpty &&
      errorMessage == null;

  TemplateDiscoveryState copyWith({
    List<TemplateDiscoverySection>? sections,
    TemplateDiscovery? discovery,
    bool? isLoading,
    bool? isRefreshing,
    bool? loadedFromCache,
    bool? hasLoaded,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TemplateDiscoveryState(
      sections: discovery?.sections ?? sections ?? this.sections,
      page: discovery != null ? discovery.page : page,
      revision: discovery != null ? discovery.revision : revision,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      loadedFromCache: loadedFromCache ?? this.loadedFromCache,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
