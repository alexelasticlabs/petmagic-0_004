import 'dart:io';

const _templateFlowSheetsLibraryPaths = [
  'lib/features/templates/presentation/widgets/template_flow_sheets.dart',
  'lib/features/templates/presentation/widgets/template_flow_sheets_actions.part.dart',
  'lib/features/templates/presentation/widgets/template_flow_sheets_blocked.part.dart',
  'lib/features/templates/presentation/widgets/template_flow_sheets_chrome.part.dart',
  'lib/features/templates/presentation/widgets/template_flow_sheets_placeholders.part.dart',
  'lib/features/templates/presentation/widgets/template_flow_sheets_helpers.part.dart',
  'lib/features/templates/presentation/widgets/template_flow_sheets_content.part.dart',
  'lib/features/templates/presentation/widgets/template_flow_sheets_generation.part.dart',
  'lib/features/templates/presentation/widgets/template_flow_media_preview.part.dart',
];

String readTemplateFlowSheetsLibrarySource() {
  return _templateFlowSheetsLibraryPaths
      .map((path) => File(path).readAsStringSync())
      .join('\n');
}
