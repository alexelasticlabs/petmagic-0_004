import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_random_selector.dart';

void main() {
  test('filters candidates by mode and media availability', () {
    final templates = [
      _template(
        'image-1',
        TemplateType.image,
        thumbnailUrl: 'https://cdn/i.jpg',
      ),
      _template('video-1', TemplateType.video, previewUrl: 'https://cdn/v.mp4'),
      _template('missing-media', TemplateType.image),
      _template('', TemplateType.video, previewUrl: 'https://cdn/empty.mp4'),
    ];

    expect(
      filterRandomTemplateCandidates(
        templates,
        mode: TemplateRandomMode.any,
        hasPremiumAccess: false,
      ).map((template) => template.templateId),
      ['image-1', 'video-1'],
    );
    expect(
      filterRandomTemplateCandidates(
        templates,
        mode: TemplateRandomMode.image,
        hasPremiumAccess: false,
      ).map((template) => template.templateId),
      ['image-1'],
    );
    expect(
      filterRandomTemplateCandidates(
        templates,
        mode: TemplateRandomMode.video,
        hasPremiumAccess: false,
      ).map((template) => template.templateId),
      ['video-1'],
    );
  });

  test('excludes premium templates when premium access is missing', () {
    final templates = [
      _template(
        'free',
        TemplateType.image,
        thumbnailUrl: 'https://cdn/free.jpg',
      ),
      _template(
        'premium',
        TemplateType.image,
        isPremium: true,
        thumbnailUrl: 'https://cdn/premium.jpg',
      ),
    ];

    expect(
      filterRandomTemplateCandidates(
        templates,
        mode: TemplateRandomMode.any,
        hasPremiumAccess: false,
      ).map((template) => template.templateId),
      ['free'],
    );
    expect(
      filterRandomTemplateCandidates(
        templates,
        mode: TemplateRandomMode.any,
        hasPremiumAccess: true,
      ).map((template) => template.templateId),
      ['free', 'premium'],
    );
  });

  test('selects using the full filtered candidate range', () {
    final templates = [
      _template('a', TemplateType.image, thumbnailUrl: 'https://cdn/a.jpg'),
      _template('b', TemplateType.image, thumbnailUrl: 'https://cdn/b.jpg'),
      _template('c', TemplateType.image, thumbnailUrl: 'https://cdn/c.jpg'),
    ];

    final selected = selectRandomTemplate(
      templates,
      mode: TemplateRandomMode.image,
      hasPremiumAccess: false,
      random: _FixedRandom(2),
    );

    expect(selected?.templateId, 'c');
  });

  test('returns null when no candidate is available', () {
    final selected = selectRandomTemplate(
      [_template('video', TemplateType.video, previewUrl: 'https://cdn/v.mp4')],
      mode: TemplateRandomMode.image,
      hasPremiumAccess: false,
      random: _FixedRandom(0),
    );

    expect(selected, isNull);
  });
}

TemplateItem _template(
  String id,
  TemplateType type, {
  bool isPremium = false,
  String? thumbnailUrl,
  String? previewUrl,
}) {
  return TemplateItem(
    templateId: id,
    templateType: type,
    title: id,
    shortDescription: id,
    petPhotoRequirements: const ['Clear photo'],
    category: 'Magic',
    tags: const ['pet'],
    isPremium: isPremium,
    tokenCost: 1,
    thumbnailUrl: thumbnailUrl,
    previewAsset: previewUrl == null
        ? null
        : TemplateAsset(
            url: previewUrl,
            fileName: previewUrl.split('/').last,
            contentType: type == TemplateType.video
                ? 'video/mp4'
                : 'image/jpeg',
          ),
  );
}

class _FixedRandom implements Random {
  const _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => value.toDouble();

  @override
  int nextInt(int max) {
    expect(value, lessThan(max));
    return value;
  }
}
