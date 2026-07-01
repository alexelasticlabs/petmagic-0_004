import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pet generation launch sheet uses explicit pet photo error keys', () {
    final source = File(
      'lib/features/templates/presentation/widgets/pet_generation_launch_sheet.dart',
    ).readAsStringSync();

    expect(source, contains('_normalizePetLaunchErrorKey(error.message)'));
    expect(source, contains("'pets.photo_not_found'"));
    expect(source, contains("'pets.photo_required'"));
    expect(source, contains("'pets.photo_type_not_allowed'"));
    expect(
      source,
      isNot(
        contains(
          "message.contains('unavailable') || message.contains('photo')",
        ),
      ),
    );
  });
}
