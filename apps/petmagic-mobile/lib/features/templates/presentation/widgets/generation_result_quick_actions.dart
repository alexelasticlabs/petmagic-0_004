import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/features/templates/application/template_generation_contract.dart';
import 'package:petmagic_mobile/features/templates/presentation/mappers/generation_status_mappers.dart';

class GenerationResultQuickActions extends StatelessWidget {
  const GenerationResultQuickActions({
    required this.generation,
    required this.busy,
    required this.onSave,
    required this.onShare,
    super.key,
  });

  final TemplateGenerationResult generation;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final saveLabel = generation.isWatermarkRemoved
        ? text.generationStatusDownloadWithoutWatermark
        : generation.hasWatermark
        ? text.generationStatusSaveWithWatermark
        : text.generationStatusSaveAction;
    final shareLabel = generation.hasWatermark
        ? text.generationStatusShareWithWatermark
        : text.supportChatShareAction;
    final resultReady =
        generation.isCompleted &&
        generation.galleryMedia.state == GalleryMediaState.resultReady;
    final save = OutlinedButton.icon(
      key: const ValueKey('result-quick-save'),
      onPressed: busy || !resultReady || !generation.galleryMedia.canDownload
          ? null
          : onSave,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon: const Icon(Icons.download_rounded, size: 19),
      label: Text(saveLabel, textAlign: TextAlign.center),
    );
    final share = FilledButton.tonalIcon(
      key: const ValueKey('result-quick-share'),
      onPressed: busy || !resultReady || !generation.galleryMedia.canShare
          ? null
          : onShare,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon: const Icon(Icons.ios_share_rounded, size: 18),
      label: Text(shareLabel, textAlign: TextAlign.center),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 350 ||
                MediaQuery.textScalerOf(context).scale(14) > 18 ||
                generation.hasWatermark ||
                generation.isWatermarkRemoved;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [save, const SizedBox(height: 8), share],
              );
            }
            return Row(
              children: [
                Expanded(child: save),
                const SizedBox(width: 10),
                Expanded(child: share),
              ],
            );
          },
        ),
        if (generation.galleryMedia.needsExplanation) ...[
          const SizedBox(height: 8),
          Text(
            galleryMediaStateMessage(text, generation),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
