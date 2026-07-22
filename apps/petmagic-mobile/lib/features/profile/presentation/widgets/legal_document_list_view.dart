import 'package:flutter/material.dart';
import 'package:petmagic_mobile/features/profile/domain/profile_models.dart';

class LegalDocumentListView extends StatelessWidget {
  const LegalDocumentListView({
    super.key,
    required this.documents,
    this.includeDocumentTitles = true,
    this.padding,
    this.documentSpacing = 16,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<MobileLegalDocument> documents;
  final bool includeDocumentTitles;
  final EdgeInsetsGeometry? padding;
  final double documentSpacing;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: _itemCount,
      itemBuilder: _buildItem,
    );
  }

  int get _itemCount {
    var count = 0;

    for (
      var documentIndex = 0;
      documentIndex < documents.length;
      documentIndex++
    ) {
      final document = documents[documentIndex];
      if (includeDocumentTitles && document.title.isNotEmpty) {
        count += 2;
      }
      if (document.summary.isNotEmpty) {
        count += 2;
      }

      for (final section in document.sections) {
        if (section.heading.isNotEmpty) {
          count += 2;
        }
        count += section.paragraphs.length * 2;
      }

      if (documentIndex != documents.length - 1) {
        count += 1;
      }
    }

    return count;
  }

  Widget _buildItem(BuildContext context, int index) {
    final theme = Theme.of(context);
    var cursor = index;

    for (
      var documentIndex = 0;
      documentIndex < documents.length;
      documentIndex++
    ) {
      final document = documents[documentIndex];

      if (includeDocumentTitles && document.title.isNotEmpty) {
        if (cursor == 0) {
          return Text(
            document.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          );
        }
        cursor -= 1;
        if (cursor == 0) {
          return const SizedBox(height: 8);
        }
        cursor -= 1;
      }

      if (document.summary.isNotEmpty) {
        if (cursor == 0) {
          return Text(document.summary, style: theme.textTheme.bodyMedium);
        }
        cursor -= 1;
        if (cursor == 0) {
          return const SizedBox(height: 12);
        }
        cursor -= 1;
      }

      for (final section in document.sections) {
        if (section.heading.isNotEmpty) {
          if (cursor == 0) {
            return Text(
              section.heading,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            );
          }
          cursor -= 1;
          if (cursor == 0) {
            return const SizedBox(height: 6);
          }
          cursor -= 1;
        }

        for (final paragraph in section.paragraphs) {
          if (cursor == 0) {
            return Text(paragraph, style: theme.textTheme.bodyMedium);
          }
          cursor -= 1;
          if (cursor == 0) {
            return const SizedBox(height: 8);
          }
          cursor -= 1;
        }
      }

      if (documentIndex != documents.length - 1) {
        if (cursor == 0) {
          return SizedBox(height: documentSpacing);
        }
        cursor -= 1;
      }
    }

    return const SizedBox.shrink();
  }
}
