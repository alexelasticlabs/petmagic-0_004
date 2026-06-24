enum PremiumCheckoutVerificationState {
  idle,
  checking,
  activated,
  pending,
  error,
}

class PremiumCheckoutState {
  const PremiumCheckoutState({
    this.verificationState = PremiumCheckoutVerificationState.idle,
    this.isAwaitingVerification = false,
    this.wasPremiumBeforeCheckout = false,
    this.errorMessage,
    this.recentlyActivatedPremium = false,
  });

  final PremiumCheckoutVerificationState verificationState;
  final bool isAwaitingVerification;
  final bool wasPremiumBeforeCheckout;
  final String? errorMessage;
  final bool recentlyActivatedPremium;

  PremiumCheckoutState copyWith({
    PremiumCheckoutVerificationState? verificationState,
    bool? isAwaitingVerification,
    bool? wasPremiumBeforeCheckout,
    String? errorMessage,
    bool? recentlyActivatedPremium,
    bool clearError = false,
  }) {
    return PremiumCheckoutState(
      verificationState: verificationState ?? this.verificationState,
      isAwaitingVerification:
          isAwaitingVerification ?? this.isAwaitingVerification,
      wasPremiumBeforeCheckout:
          wasPremiumBeforeCheckout ?? this.wasPremiumBeforeCheckout,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      recentlyActivatedPremium:
          recentlyActivatedPremium ?? this.recentlyActivatedPremium,
    );
  }
}
