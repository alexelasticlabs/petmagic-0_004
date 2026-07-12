import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:petmagic_mobile/core/startup/app_launch_controller.dart';
import 'package:petmagic_mobile/features/profile/application/profile_controller.dart';
import 'package:petmagic_mobile/features/wallet/application/wallet_controller.dart';

final templatePremiumAccessProvider = Provider<bool>((ref) {
  final isAuthenticated = ref.watch(
    appLaunchControllerProvider.select((state) => state.isAuthenticated),
  );
  if (!isAuthenticated) {
    return false;
  }

  final walletPremium = ref.watch(
    walletControllerProvider.select(
      (walletState) => walletState.wallet?.isPremium ?? false,
    ),
  );
  if (walletPremium) {
    return true;
  }

  return ref.watch(
    profileControllerProvider.select(
      (profileState) => profileState.profile?.isPremium ?? false,
    ),
  );
});
