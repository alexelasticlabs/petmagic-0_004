part of 'template_category_carousel.dart';

class _CarouselProgress extends StatelessWidget {
  const _CarouselProgress({
    required this.currentIndex,
    required this.categories,
    required this.label,
    required this.reduceMotion,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentIndex;
  final List<String> categories;
  final String label;
  final bool reduceMotion;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = context.petMagicColors;
    final itemCount = categories.length;
    if (itemCount <= 1) return const SizedBox.shrink();
    String description(int index) =>
        '${categories[index]}, ${index + 1} / $itemCount';
    return Semantics(
      key: const ValueKey('discovery-carousel-position'),
      label: label,
      value: description(currentIndex),
      increasedValue: description((currentIndex + 1) % itemCount),
      decreasedValue: description((currentIndex - 1) % itemCount),
      onIncrease: onNext,
      onDecrease: onPrevious,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(itemCount, (index) {
          final selected = index == currentIndex;
          return AnimatedContainer(
            duration: reduceMotion ? Duration.zero : PetMagicMotion.fast,
            curve: PetMagicMotion.emphasized,
            width: selected ? 18 : 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected
                  ? colors.accentInk
                  : colors.textMuted.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(PetMagicRadii.pill),
            ),
          );
        }),
      ),
    );
  }
}

int _logicalIndex(int rawIndex, int count) {
  if (count <= 1) {
    return 0;
  }
  if (rawIndex == 0) {
    return count - 1;
  }
  if (rawIndex == count + 1) {
    return 0;
  }
  return rawIndex - 1;
}

bool _sameCategories(
  List<TemplateDiscoverySection> left,
  List<TemplateDiscoverySection> right,
) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index].category != right[index].category) {
      return false;
    }
  }
  return true;
}
