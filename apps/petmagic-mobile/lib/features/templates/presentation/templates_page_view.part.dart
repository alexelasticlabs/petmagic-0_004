part of 'templates_page.dart';

extension _TemplatesPageView on _TemplatesPageState {
  Widget _buildTemplatesPage(BuildContext context) {
    ref.listen<NetworkStatusState>(networkStatusControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.hasInternet != false || !next.hasInternet || !mounted) {
        return;
      }

      if (_shouldRefreshAccessOnReconnect) {
        _refreshAccessForAuthenticatedUser(forceRefresh: true);
      }

      final state = ref.read(templatesControllerProvider);
      if (state.items.isNotEmpty || state.isInitialLoading) {
        return;
      }
      if (classifyAppUnavailable(
            raw: state.errorMessage,
            hasInternet: next.hasInternet,
          ) ==
          null) {
        return;
      }

      unawaited(_refreshFeed(forceRefresh: true));
    });
    ref.listen<String?>(
      templatesControllerProvider.select((state) => state.query.search),
      (previous, next) => _syncSearchFieldWithQuery(next),
    );
    final headerState = ref.watch(
      templatesControllerProvider.select(
        (state) => (
          query: state.query,
          categories: state.categories,
          templateOfTheDay: state.templateOfTheDay,
          isTemplateOfTheDayLoading: state.isTemplateOfTheDayLoading,
          templateOfTheDayError: state.templateOfTheDayError,
          isInitialLoading: state.isInitialLoading,
        ),
      ),
    );
    final controller = ref.read(templatesControllerProvider.notifier);
    final text = AppLocalizations.of(context);
    final colors = context.petMagicColors;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final subtitleStyle = Theme.of(context).textTheme.bodySmall;
    final bottomInset = petMagicScrollableBottomInset(context);
    final templateOfTheDay = headerState.templateOfTheDay;
    final selectedPetId = widget.initialPetId;
    final selectedPetPhotoId = widget.initialPetPhotoId;
    _trackTemplateOfTheDayViewed(templateOfTheDay);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.backgroundTop, colors.backgroundBottom],
        ),
      ),
      child: Stack(
        children: [
          RefreshIndicator.adaptive(
            onRefresh: () async {
              await PetMagicHaptics.medium();
              await controller.refresh();
            },
            color: colors.accent,
            child: CustomScrollView(
              scrollCacheExtent: ScrollCacheExtent.pixels(
                _TemplatesPageState._gridCacheExtent,
              ),
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TemplatesTopBarSlot(
                            onAuthPressed: () => context.appNavigator.go(
                              AuthDestination(
                                redirectPath: _templatesPageLocation(
                                  currentPetId: widget.initialPetId,
                                  currentPetPhotoId: widget.initialPetPhotoId,
                                ),
                              ),
                            ),
                            onRewardsPressed: () => context.appNavigator.go(
                              const RewardsDestination(),
                            ),
                            onTopUpPressed: () => context.appNavigator.push(
                              const WalletDestination(),
                            ),
                            onWalletPressed: () => context.appNavigator.push(
                              const WalletDestination(),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            text.createMagicTitle,
                            style: titleStyle?.copyWith(
                              color: colors.textStrong,
                              fontSize: 17,
                              height: 1.08,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            text.pickTemplateSubtitle,
                            style: subtitleStyle?.copyWith(
                              color: colors.textSoft,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CreateWithPetBlockSlot(
                            selectedPetId: selectedPetId,
                            selectedPetPhotoId: selectedPetPhotoId,
                          ),
                          const SizedBox(height: 5),
                          TemplatesSearchField(
                            controller: _searchController,
                            onChanged: _handleSearchChanged,
                          ),
                          const SizedBox(height: 6),
                          TemplateTypeFilters(
                            selectedType: headerState.query.type,
                            categories: headerState.categories,
                            selectedCategory: headerState.query.category,
                            onTypeSelected: controller.setType,
                            onCategorySelected: controller.setCategory,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _TemplateFeedSlivers(
                  bottomInset: bottomInset,
                  templateOfTheDay: templateOfTheDay,
                  selectedType: headerState.query.type,
                  selectedCategory: headerState.query.category,
                  searchQuery: headerState.query.search,
                  onTemplateSelected: (template) =>
                      unawaited(_handleTemplateSelected(template)),
                  onTemplateOfTheDaySelected: (featured) =>
                      unawaited(_handleTemplateOfTheDaySelected(featured)),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: petMagicBottomNavInset(context, extraSpacing: 24),
            child: FloatingRandomTemplateButton(
              isLoading: _isRandomTemplateLoading,
              isEnabled: !headerState.isInitialLoading,
              onPressed: _handleRandomTemplatePressed,
            ),
          ),
        ],
      ),
    );
  }
}
