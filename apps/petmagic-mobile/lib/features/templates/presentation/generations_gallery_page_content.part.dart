part of 'generations_gallery_page.dart';

extension on _GenerationsGalleryPageState {
  List<Widget> _buildContentSlivers(
    BuildContext context,
    AppLocalizations text,
    _GalleryPageViewState state, {
    required bool isAuthenticated,
  }) {
    if (!isAuthenticated) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ProtectedAuthGate(
            subtitle: text.generationStatusEmptyMessage,
            onSignIn: () {
              unawaited(
                showAuthRequiredSheet(
                  context,
                  redirectPath: GenerationsGalleryPage.routePath,
                ),
              );
            },
          ),
        ),
      ];
    }

    final filteredItems = _itemsForSelectedFilter(state.items, state.filter);

    if (state.isLoading && filteredItems.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    }
    if (state.errorMessage != null && filteredItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(message: state.errorMessage!),
        ),
      ];
    }
    if (filteredItems.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(filter: state.filter),
        ),
      ];
    }

    final bottomInset = petMagicBottomNavInset(context) + 22;

    if (state.filter == GenerationHistoryFilter.all) {
      final activeItems = state.items
          .where((item) => !item.isTerminal)
          .toList(growable: false);
      final readyItems = state.items
          .where((item) => item.isCompleted)
          .toList(growable: false);
      final failedItems = state.items
          .where((item) => item.isFailed)
          .toList(growable: false);

      final slivers = <Widget>[];
      if (activeItems.isNotEmpty) {
        slivers.add(
          _sectionHeaderSliver(
            text.generationStatusSectionActive,
            activeItems.length,
          ),
        );
        slivers.add(_activeListSliver(activeItems));
      }
      if (readyItems.isNotEmpty) {
        slivers.add(
          _sectionHeaderSliver(
            text.generationStatusSectionReady,
            readyItems.length,
          ),
        );
        slivers.add(_readyGridSliver(readyItems));
      }
      if (failedItems.isNotEmpty) {
        slivers.add(
          _sectionHeaderSliver(
            text.generationStatusSectionFailed,
            failedItems.length,
          ),
        );
        slivers.add(_failedListSliver(failedItems));
      }
      slivers.add(_paginationFooterSliver(state, bottomInset));
      return slivers;
    }

    if (state.filter == GenerationHistoryFilter.ready) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          sliver: SliverGrid.builder(
            itemCount: filteredItems.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) => _ReadyGridCard(
              key: ValueKey(filteredItems[index].generationId),
              generation: filteredItems[index],
              galleryState: this,
            ),
          ),
        ),
        _paginationFooterSliver(state, bottomInset),
      ];
    }

    if (state.filter == GenerationHistoryFilter.active) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          sliver: const SliverToBoxAdapter(child: _ActiveInfoCard()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          sliver: SliverList.separated(
            itemCount: filteredItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _ActiveCard(
              key: ValueKey(filteredItems[index].generationId),
              generation: filteredItems[index],
            ),
          ),
        ),
        _paginationFooterSliver(state, bottomInset),
      ];
    }

    if (state.filter == GenerationHistoryFilter.failed) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
          sliver: SliverList.separated(
            itemCount: filteredItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _FailedCard(
              key: ValueKey(filteredItems[index].generationId),
              generation: filteredItems[index],
            ),
          ),
        ),
        _paginationFooterSliver(state, bottomInset),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        sliver: SliverList.separated(
          itemCount: filteredItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final generation = filteredItems[index];
            if (generation.isFailed) {
              return _FailedCard(
                key: ValueKey(generation.generationId),
                generation: generation,
              );
            }
            return _ActiveCard(
              key: ValueKey(generation.generationId),
              generation: generation,
            );
          },
        ),
      ),
      _paginationFooterSliver(state, bottomInset),
    ];
  }

  List<TemplateGenerationResult> _itemsForSelectedFilter(
    List<TemplateGenerationResult> items,
    GenerationHistoryFilter filter,
  ) {
    return switch (filter) {
      GenerationHistoryFilter.all => items,
      GenerationHistoryFilter.active =>
        items.where((item) => !item.isTerminal).toList(growable: false),
      GenerationHistoryFilter.ready =>
        items.where((item) => item.isCompleted).toList(growable: false),
      GenerationHistoryFilter.failed =>
        items.where((item) => item.isFailed).toList(growable: false),
    };
  }
}
