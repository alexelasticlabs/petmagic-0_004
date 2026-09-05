part of 'templates_discovery_page.dart';

final templateDiscoveryPlaybackManagerProvider =
    Provider.autoDispose<TemplateFeedPlaybackManager>((ref) {
      final manager = TemplateFeedPlaybackManager(
        mediaPreloadQueue: TemplateFeedMediaPreloadQueue(),
      );
      ref.onDispose(manager.dispose);
      return manager;
    });

class _TemplateDiscoveryRails extends ConsumerStatefulWidget {
  const _TemplateDiscoveryRails({
    required this.sections,
    required this.moreLabel,
    required this.previewControllerFactory,
    required this.onMorePressed,
    required this.onTemplatePressed,
  });

  final List<TemplateDiscoverySection> sections;
  final String moreLabel;
  final TemplatePreviewControllerFactory? previewControllerFactory;
  final ValueChanged<String> onMorePressed;
  final void Function(
    TemplateItem template,
    String category,
    List<TemplateItem> previewItems,
  )
  onTemplatePressed;

  @override
  ConsumerState<_TemplateDiscoveryRails> createState() =>
      _TemplateDiscoveryRailsState();
}

class _TemplateDiscoveryRailsState
    extends ConsumerState<_TemplateDiscoveryRails> {
  TemplateFeedPlaybackManager? _configuredManager;
  TemplateFeedPlaybackEnvironment? _configuredEnvironment;
  TemplateFeedPlaybackManager? _pendingManager;
  TemplateFeedPlaybackEnvironment? _pendingEnvironment;
  bool _configurationScheduled = false;

  void _schedulePlaybackConfiguration({
    required TemplateFeedPlaybackManager manager,
    required TemplateFeedPlaybackEnvironment environment,
  }) {
    if (identical(_configuredManager, manager) &&
        _configuredEnvironment == environment) {
      return;
    }

    _pendingManager = manager;
    _pendingEnvironment = environment;
    if (_configurationScheduled) {
      return;
    }

    _configurationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configurationScheduled = false;
      if (!mounted) {
        return;
      }

      final nextManager = _pendingManager;
      final nextEnvironment = _pendingEnvironment;
      if (nextManager == null || nextEnvironment == null) {
        return;
      }

      _configuredManager = nextManager;
      _configuredEnvironment = nextEnvironment;
      nextManager.configure(
        feedKind: TemplateFeedKind.mixed,
        environment: nextEnvironment,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final playbackManager = ref.watch(templateDiscoveryPlaybackManagerProvider);
    final playbackEnvironment = ref.watch(
      templateFeedPlaybackEnvironmentProvider,
    );
    _schedulePlaybackConfiguration(
      manager: playbackManager,
      environment: playbackEnvironment,
    );

    return SliverList.separated(
      itemCount: widget.sections.length,
      separatorBuilder: (_, _) => const SizedBox(height: PetMagicSpacing.lg),
      itemBuilder: (context, index) {
        final section = widget.sections[index];
        return TemplateDiscoveryRail(
          section: section,
          sectionIndex: index,
          moreLabel: widget.moreLabel,
          playbackManager: playbackManager,
          previewControllerFactory: widget.previewControllerFactory,
          onMorePressed: () => widget.onMorePressed(section.category),
          onTemplatePressed: (template) => widget.onTemplatePressed(
            template,
            section.category,
            section.items,
          ),
        );
      },
    );
  }
}
