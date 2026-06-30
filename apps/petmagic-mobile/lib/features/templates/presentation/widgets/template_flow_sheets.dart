import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';
import 'package:petmagic_mobile/features/premium/presentation/premium_page.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_controller.dart';
import 'package:petmagic_mobile/features/wallet/presentation/wallet_page.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_banner_style.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'template_flow_sheets_actions.part.dart';
part 'template_flow_sheets_blocked.part.dart';
part 'template_flow_sheets_chrome.part.dart';
part 'template_flow_sheets_content.part.dart';
part 'template_flow_sheets_generation.part.dart';
part 'template_flow_sheets_helpers.part.dart';
part 'template_flow_media_preview.part.dart';

enum TemplateDetailAction { upload }

enum TemplateBlockedAction { wallet, premium, chooseAnother }

const _kInsufficientBalanceMascotAsset =
    'assets/rewards/powspark-empty-cat.png';
const int _selectedPetPhotoPreviewCacheWidth = 288;
const int _selectedPetPhotoPreviewCacheHeight = 354;
