part of 'my_pets_page.dart';

class _GenerationList extends StatelessWidget {
  const _GenerationList({required this.generations, required this.text});

  final List<PetGenerationSummary> generations;
  final AppLocalizations text;

  @override
  Widget build(BuildContext context) {
    if (generations.isEmpty) {
      return _PetSectionEmpty(label: text.petsNoGenerationsTitle);
    }

    return Column(
      children: [
        for (final generation in generations.take(12))
          _PetGenerationHistoryTile(generation: generation, text: text),
      ],
    );
  }
}

class _PetGenerationHistoryTile extends StatelessWidget {
  const _PetGenerationHistoryTile({
    required this.generation,
    required this.text,
  });

  final PetGenerationSummary generation;
  final AppLocalizations text;

  @override
  Widget build(BuildContext context) {
    final safeOutputUrl = parseSafeGenerationMediaUri(
      generation.outputUrl,
    )?.toString();
    final shareSafeUrl = safeOutputUrl == null
        ? null
        : persistentSafeGenerationMediaUrl(safeOutputUrl);

    return Card(
      child: ListTile(
        title: Text(generation.templateTitle ?? generation.templateId),
        subtitle: Text(
          '${generation.templateType ?? text.petsTemplateFallback} · ${_petGenerationStatusTitle(text, generation)} · ${_formatDate(context, generation.createdAtUtc)}',
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: text.petsOpenGenerationTooltip,
              onPressed: () => context.appNavigator.push(
                GenerationDestination(generation.generationId),
              ),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
            IconButton(
              tooltip: text.petsShareGenerationTooltip,
              onPressed: shareSafeUrl == null || shareSafeUrl.isEmpty
                  ? null
                  : () => SharePlus.instance.share(
                      ShareParams(text: shareSafeUrl),
                    ),
              icon: const Icon(Icons.ios_share_rounded),
            ),
            IconButton(
              tooltip: text.petsUseGenerationAsInputTooltip,
              onPressed: () => context.appNavigator.go(
                TemplatesDestination(
                  petId: generation.petId,
                  petPhotoId: generation.petPhotoId,
                ),
              ),
              icon: const Icon(Icons.auto_fix_high_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

String _petGenerationStatusTitle(
  AppLocalizations text,
  PetGenerationSummary generation,
) {
  if (generation.isCompleted) return text.generationStatusStatusCompleted;
  if (generation.isFailed) return text.generationStatusStatusFailed;
  if (generation.isCancelled) return text.generationStatusStatusCancelled;

  return switch (generation.stage) {
    'queued' => text.generationStatusStageQueued,
    'preprocessing' => text.templateFlowStepProcessPhoto,
    'generating' => text.templateFlowStepCreateMagic,
    'finalizing' => text.templateFlowStepFinalTouches,
    _ => text.generationStatusStatusCreatingMagic,
  };
}
