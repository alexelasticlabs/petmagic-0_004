import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/data/template_discovery_dto.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';

void main() {
  test('discovery DTO parses sections and converts feed cards to domain', () {
    final dto = TemplateDiscoveryDto.fromJson({
      'sections': [
        {
          'category': ' Pet Mischief ',
          'items': [
            {
              'id': 'template-video-1',
              'type': 'Video',
              'title': 'Night Road Flee',
              'shortDescription': 'Pets on a night drive',
              'category': {'title': 'Pet Mischief'},
              'tags': ['pets', 'night'],
              'isPremium': true,
              'tokenCost': 9,
              'media': {
                'thumbnailUrl': 'https://cdn.petmagic.test/thumb.jpg',
                'feedLoopMediumUrl': 'https://cdn.petmagic.test/preview.mp4',
                'mediaKind': 'video',
                'durationMs': 3200,
                'mediaVersion': 5,
              },
              'version': 6,
            },
          ],
        },
        {'category': '   ', 'items': const []},
        'ignored',
      ],
      'generatedAtUtc': '2026-09-04T06:00:00+02:00',
    });

    expect(dto.sections, hasLength(1));
    expect(dto.sections.single.category, 'Pet Mischief');
    expect(dto.generatedAtUtc, DateTime.utc(2026, 9, 4, 4));

    final discovery = dto.toDomain();
    final section = discovery.sections.single;
    final item = section.representative!;
    expect(section.category, 'Pet Mischief');
    expect(item.templateId, 'template-video-1');
    expect(item.templateType, TemplateType.video);
    expect(item.category, 'Pet Mischief');
    expect(item.tokenCost, 9);
    expect(item.previewAsset?.url, 'https://cdn.petmagic.test/preview.mp4');
    expect(item.previewAsset?.durationSeconds, 3.2);
    expect(item.mediaVersion, 5);
  });

  test('discovery DTO keeps an empty section and normalizes invalid date', () {
    final dto = TemplateDiscoveryDto.fromJson({
      'sections': [
        {
          'category': 'Pawsome Frames',
          'items': [42, null],
        },
      ],
      'generatedAtUtc': 'not-a-date',
    });

    expect(
      dto.generatedAtUtc,
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    expect(dto.toDomain().sections.single.representative, isNull);

    final roundTrip = TemplateDiscoveryDto.fromJson(dto.toJson());
    expect(roundTrip.sections.single.category, 'Pawsome Frames');
    expect(roundTrip.sections.single.items, isEmpty);
  });
}
