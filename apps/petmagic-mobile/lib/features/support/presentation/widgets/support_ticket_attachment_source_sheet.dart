import 'package:flutter/material.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';

enum SupportTicketAttachmentSource { camera, gallery }

Future<SupportTicketAttachmentSource?> showSupportTicketAttachmentSourceSheet(
  BuildContext context,
) {
  return showPetMagicModalBottomSheet<SupportTicketAttachmentSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext, bottomInset) {
      final text = AppLocalizations.of(sheetContext);
      final colors = sheetContext.petMagicColors;
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
          child: Material(
            color: colors.surfaceStrong,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: colors.border.withValues(alpha: 0.9)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      text.supportChatAddPhotoTitle,
                      style: TextStyle(
                        color: colors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_camera_outlined,
                    color: colors.textStrong,
                  ),
                  title: Text(
                    text.supportChatTakePhotoAction,
                    style: TextStyle(color: colors.textStrong),
                  ),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(SupportTicketAttachmentSource.camera),
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_outlined,
                    color: colors.textStrong,
                  ),
                  title: Text(
                    text.supportChatChooseGalleryAction,
                    style: TextStyle(color: colors.textStrong),
                  ),
                  onTap: () => Navigator.of(
                    sheetContext,
                  ).pop(SupportTicketAttachmentSource.gallery),
                ),
                ListTile(
                  leading: Icon(Icons.close_rounded, color: colors.textMuted),
                  title: Text(
                    text.walletRedeemCancelAction,
                    style: TextStyle(color: colors.textSoft),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      );
    },
  );
}
