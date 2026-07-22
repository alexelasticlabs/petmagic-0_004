import 'package:flutter/material.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_navigation_layout.dart';

typedef PetMagicModalSheetBuilder =
    Widget Function(BuildContext context, double bottomInset);

Future<T?> showPetMagicModalBottomSheet<T>({
  required BuildContext context,
  required PetMagicModalSheetBuilder builder,
  bool useRootNavigator = true,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  Color? backgroundColor,
  Color? barrierColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    barrierColor: barrierColor,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    builder: (sheetContext) {
      final bottomInset = petMagicBottomSheetOffset(sheetContext);
      return builder(sheetContext, bottomInset);
    },
  );
}
