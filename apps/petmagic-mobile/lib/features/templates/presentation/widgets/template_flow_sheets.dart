import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/app/localization/generated/app_localizations.dart';
import 'package:petmagic_mobile/app/theme/app_theme.dart';
import 'package:petmagic_mobile/core/errors/app_exception.dart';
import 'package:petmagic_mobile/core/errors/auth_feedback_mapper.dart';
import 'package:petmagic_mobile/core/logging/app_logger.dart';
import 'package:petmagic_mobile/core/navigation/app_navigator.dart';
import 'package:petmagic_mobile/core/performance/performance_guard.dart';
import 'package:petmagic_mobile/core/performance/media_lifecycle_policy.dart';
import 'package:petmagic_mobile/core/performance/template_media_cache.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_controller.dart';
import 'package:petmagic_mobile/core/performance/template_preview_video_source.dart';
import 'package:petmagic_mobile/features/templates/domain/template_generation_models.dart';
import 'package:petmagic_mobile/features/templates/domain/template_models.dart';
import 'package:petmagic_mobile/features/templates/application/template_error_key_mapper.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_entitlement_provider.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_generation_controller.dart';
import 'package:petmagic_mobile/features/templates/presentation/template_preview_media_selection.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/generation_completed_premium_gate.dart';
import 'package:petmagic_mobile/features/templates/presentation/widgets/template_preview_image.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';
import 'package:petmagic_mobile/shared/files/persistent_media_url.dart';
import 'package:petmagic_mobile/shared/navigation/external_url_policy.dart';
import 'package:petmagic_mobile/shared/navigation/app_navigation_context.dart';
import 'package:petmagic_mobile/shared/navigation/petmagic_modal_sheet.dart';
import 'package:petmagic_mobile/shared/widgets/pawspark_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_banner_style.dart';
import 'package:petmagic_mobile/shared/widgets/premium_crown_icon.dart';
import 'package:petmagic_mobile/shared/widgets/premium_shimmer_button.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/scheduler.dart';
import 'package:visibility_detector/visibility_detector.dart';

part 'template_flow_sheets_actions.part.dart';
part 'template_flow_sheets_blocked.part.dart';
part 'template_flow_sheets_chrome.part.dart';
part 'template_flow_sheets_placeholders.part.dart';
part 'template_flow_sheets_content.part.dart';
part 'template_flow_sheets_generation.part.dart';
part 'template_flow_sheets_helpers.part.dart';
part 'template_flow_media_preview.part.dart';
part 'template_flow_video_preview.part.dart';
part 'template_flow_video_preview_view.part.dart';
part 'template_flow_thumbnail.part.dart';
part 'template_flow_preview_playback.part.dart';
part 'template_flow_video_preview_lifecycle.part.dart';
part 'template_flow_video_preview_source.part.dart';
part 'template_flow_video_preview_initialize.part.dart';

enum TemplateDetailAction { upload, unlockPremium }

enum TemplateBlockedAction { wallet, premium, chooseAnother }

const _kInsufficientBalanceMascotAsset =
    'assets/rewards/powspark-empty-cat.png';
const int _selectedPetPhotoPreviewCacheWidth = 288;
const int _selectedPetPhotoPreviewCacheHeight = 354;
