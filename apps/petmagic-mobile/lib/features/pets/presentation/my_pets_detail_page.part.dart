part of 'my_pets_page.dart';

class PetDetailsPage extends ConsumerStatefulWidget {
  const PetDetailsPage({required this.petId, super.key});

  static const routePath = '/profile/pets/:petId';

  static String location(String petId) =>
      '/profile/pets/${Uri.encodeComponent(petId)}';

  final String petId;

  @override
  ConsumerState<PetDetailsPage> createState() => _PetDetailsPageState();
}

class _PetDetailsPageState extends ConsumerState<PetDetailsPage> {
  bool _isAddingPhoto = false;
  CancelToken? _addPhotoCancelToken;

  @override
  void didUpdateWidget(covariant PetDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId == widget.petId) {
      return;
    }

    final cancelToken = _addPhotoCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('pet_photo_upload_pet_changed');
    }
    _addPhotoCancelToken = null;
    if (_isAddingPhoto) {
      setState(() => _isAddingPhoto = false);
    }
  }

  void _addPhoto(String petId, {String? currentAvatarUrl}) {
    if (_isAddingPhoto) {
      return;
    }

    final cancelToken = CancelToken();
    _addPhotoCancelToken = cancelToken;
    setState(() => _isAddingPhoto = true);
    unawaited(() async {
      try {
        await _pickAndUploadPhoto(
          context,
          ref,
          petId,
          currentAvatarUrl: currentAvatarUrl,
          cancelToken: cancelToken,
        );
      } on Object catch (error) {
        if (_isPetPhotoRequestCancelled(error, cancelToken)) {
          return;
        }
        if (mounted) {
          final text = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_petPhotoUploadErrorMessage(text, error))),
          );
        }
      } finally {
        final isActiveUpload = identical(_addPhotoCancelToken, cancelToken);
        if (isActiveUpload) {
          _addPhotoCancelToken = null;
        }
        if (mounted && isActiveUpload) {
          setState(() => _isAddingPhoto = false);
        }
      }
    }());
  }

  @override
  void dispose() {
    final cancelToken = _addPhotoCancelToken;
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('pet_photo_upload_disposed');
    }
    _addPhotoCancelToken = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final launchState = ref.watch(appLaunchControllerProvider);
    final text = AppLocalizations.of(context);
    final bottomInset = petMagicScrollableBottomInset(context);

    if (launchState.isLoading || !launchState.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: Text(text.petsDetailsTitle)),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.backgroundTop, colors.backgroundBottom],
            ),
          ),
          child: launchState.isLoading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: _PetAuthGate(
                    redirectPath: PetDetailsPage.location(widget.petId),
                  ),
                ),
        ),
      );
    }

    final pets = ref.watch(petsProvider);
    final petsLoadRequiresSignIn = _isUnauthorizedError(pets.asError?.error);

    if (petsLoadRequiresSignIn) {
      return Scaffold(
        appBar: AppBar(title: Text(text.petsDetailsTitle)),
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.backgroundTop, colors.backgroundBottom],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: _PetAuthGate(
              redirectPath: PetDetailsPage.location(widget.petId),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(text.petsDetailsTitle),
        actions: [
          IconButton(
            tooltip: text.petsDeleteTooltip,
            onPressed: () => _deletePet(context, ref, widget.petId),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundTop, colors.backgroundBottom],
          ),
        ),
        child: pets.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (_, _) => _StateView(
            title: text.petsLoadPetErrorTitle,
            actionLabel: text.petsRetryAction,
            onAction: () => ref.invalidate(petsProvider),
          ),
          data: (items) {
            final pet = _findPet(items, widget.petId);
            if (pet == null) {
              return _StateView(title: text.petsNotFoundTitle);
            }

            final photos = ref.watch(petPhotosProvider(widget.petId));
            final generations = ref.watch(petGenerationsProvider(widget.petId));

            return RefreshIndicator.adaptive(
              onRefresh: () => _refreshPetDetails(ref, widget.petId),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _PetHeader(
                        pet: pet,
                        text: text,
                        onEdit: () => _showPetForm(context, ref, pet: pet),
                        onGenerate: () =>
                            context.go(_templatesWithPetLocation(pet.id)),
                        onAddPhoto: () =>
                            _addPhoto(pet.id, currentAvatarUrl: pet.avatarUrl),
                        isAddingPhoto: _isAddingPhoto,
                      ),
                    ),
                  ),
                  _SectionTitleSliver(
                    title: text.petsPhotosTitle,
                    topPadding: 16,
                  ),
                  ...photos.when(
                    loading: () => const <Widget>[_PhotoGridSkeletonSliver()],
                    error: (_, _) => <Widget>[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        sliver: SliverToBoxAdapter(
                          child: _InlineError(
                            label: text.petsLoadPhotosErrorTitle,
                            retryLabel: text.petsRetryAction,
                            onRetry: () =>
                                ref.invalidate(petPhotosProvider(widget.petId)),
                          ),
                        ),
                      ),
                    ],
                    data: (items) => <Widget>[
                      _PhotoGrid(
                        petId: pet.id,
                        currentAvatarUrl: pet.avatarUrl,
                        photos: items,
                        text: text,
                      ),
                    ],
                  ),
                  _SectionTitleSliver(
                    title: text.petsHistoryTitle,
                    topPadding: 18,
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
                    sliver: SliverToBoxAdapter(
                      child: generations.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => _InlineError(
                          label: text.petsLoadHistoryErrorTitle,
                          retryLabel: text.petsRetryAction,
                          onRetry: () => ref.invalidate(
                            petGenerationsProvider(widget.petId),
                          ),
                        ),
                        data: (items) =>
                            _GenerationList(generations: items, text: text),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
