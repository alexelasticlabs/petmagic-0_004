part of 'generations_gallery_page.dart';

Future<void> _showReadyCardActions(
  BuildContext context,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
  _GenerationsGalleryPageState galleryState,
) async {
  final colors = context.petMagicColors;
  final isMediaActionInFlight = galleryState._isMediaActionInFlight;
  final mediaMessage = galleryMediaStateMessage(text, generation);
  final canDownload =
      generation.galleryMedia.canDownload && !isMediaActionInFlight;
  final canShare = generation.galleryMedia.canShare && !isMediaActionInFlight;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = petMagicScrollableBottomInset(sheetContext);
      final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
          child: Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: colors.border.withValues(alpha: 0.85)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (generation.galleryMedia.needsExplanation &&
                        mediaMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: _GalleryMediaStateBanner(
                          generation: generation,
                          message: mediaMessage,
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.open_in_new_rounded),
                      title: Text(text.generationStatusOpenStatusAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        if (generation.isUnread) {
                          ref
                              .read(
                                generationHistoryControllerProvider.notifier,
                              )
                              .markRead(generation.generationId);
                        }
                        context.appNavigator.push(
                          GenerationDestination(generation.generationId),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.download_rounded),
                      title: Text(text.generationStatusSaveAction),
                      subtitle:
                          !generation.galleryMedia.canDownload &&
                              mediaMessage.isNotEmpty
                          ? Text(mediaMessage)
                          : null,
                      enabled: canDownload,
                      onTap: !canDownload
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              unawaited(
                                _saveGenerationToGallery(
                                  galleryState,
                                  text,
                                  ref,
                                  generation,
                                ),
                              );
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.share_rounded),
                      title: Text(text.supportChatShareAction),
                      subtitle:
                          !generation.galleryMedia.canShare &&
                              mediaMessage.isNotEmpty
                          ? Text(mediaMessage)
                          : null,
                      enabled: canShare,
                      onTap: !canShare
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              unawaited(
                                _shareGenerationFile(
                                  galleryState,
                                  text,
                                  ref,
                                  generation,
                                ),
                              );
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.link_rounded),
                      title: Text(text.generationStatusCopyLinkAction),
                      subtitle:
                          !generation.galleryMedia.canShare &&
                              mediaMessage.isNotEmpty
                          ? Text(mediaMessage)
                          : null,
                      enabled: canShare,
                      onTap: !canShare
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              unawaited(
                                _copyGenerationLink(
                                  galleryState,
                                  text,
                                  ref,
                                  generation,
                                ),
                              );
                            },
                    ),
                    ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: Text(text.generationStatusDeleteAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(
                          _deleteGeneration(context, text, ref, generation),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(text.generationStatusReportProblemAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.appNavigator.push(
                          SupportChatDestination(
                            initialMessage:
                                _buildGenerationProblemReportMessage(
                                  text,
                                  generation,
                                ),
                            relatedGenerationId: generation.generationId,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _showFailedCardActions(
  BuildContext context,
  AppLocalizations text,
  WidgetRef ref,
  TemplateGenerationResult generation,
) async {
  final colors = context.petMagicColors;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final bottomInset = petMagicScrollableBottomInset(sheetContext);
      final maxSheetHeight = MediaQuery.sizeOf(sheetContext).height * 0.8;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset),
          child: Material(
            color: colors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: colors.border.withValues(alpha: 0.85)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.open_in_new_rounded),
                      title: Text(text.generationStatusOpenStatusAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        if (generation.isUnread) {
                          ref
                              .read(
                                generationHistoryControllerProvider.notifier,
                              )
                              .markRead(generation.generationId);
                        }
                        context.appNavigator.push(
                          GenerationDestination(generation.generationId),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.image_search_rounded),
                      title: Text(text.generationStatusPickAnotherPhotoAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.appNavigator.go(
                          _templatesDestinationForGeneration(generation),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.support_agent_rounded),
                      title: Text(text.generationStatusContactSupportAction),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.appNavigator.push(
                          SupportChatDestination(
                            initialMessage:
                                _buildGenerationProblemReportMessage(
                                  text,
                                  generation,
                                ),
                            relatedGenerationId: generation.generationId,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
