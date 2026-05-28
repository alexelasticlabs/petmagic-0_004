// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get navTemplates => 'Modelli';

  @override
  String get navCreations => 'Galleria';

  @override
  String get navRewards => 'Rewards';

  @override
  String get navProfile => 'Profilo';

  @override
  String get comingSoonMessage =>
      'Questa sezione e pronta per la prossima fase del prodotto.';

  @override
  String get createMagicTitle => 'Crea magia';

  @override
  String get pickTemplateSubtitle => 'Scegli un modello per il tuo animale';

  @override
  String get searchTemplates => 'Cerca modelli';

  @override
  String get allFilter => 'Tutti';

  @override
  String get videosFilter => 'Video';

  @override
  String get imagesFilter => 'Immagini';

  @override
  String get trendingFilter => '🔥 Tendenze';

  @override
  String get funnyFilter => '😂 Divertenti';

  @override
  String get danceFilter => '🕺 Danza';

  @override
  String get magicFilter => '✣ Magia';

  @override
  String get adventureFilter => '🌄 Avventura';

  @override
  String get filtersTooltip => 'Filtri';

  @override
  String get giftTooltip => 'Ricompense';

  @override
  String get addTokensTooltip => 'Aggiungi PawSpark';

  @override
  String get premiumLabel => 'Premio';

  @override
  String get freeLabel => 'Gratuito';

  @override
  String get profileTitle => 'Il tuo profilo';

  @override
  String get profileSubtitle => 'Gestisci l\'accesso e il tuo avatar pubblico.';

  @override
  String get profileDashboardSubtitle =>
      'Gestisci il tuo account e personalizza la tua esperienza con PetMagic.';

  @override
  String get profileSignInTitle => 'Accedi per continuare';

  @override
  String get profileSignInHint =>
      'Usa il tuo account PetMagic per caricare il tuo profilo e gestire l\'avatar visibile nell\'amministratore.';

  @override
  String get profileEmailLabel => 'E-mail';

  @override
  String get profilePasswordLabel => 'Password';

  @override
  String get profileSignInAction => 'Registrazione';

  @override
  String get profileSignOutAction => 'disconnessione';

  @override
  String get profileLoadingAction => 'Lavorando...';

  @override
  String get profileAvatarUpload => 'Carica l\'avatar';

  @override
  String get profileAvatarRemove => 'Rimuovi l\'avatar';

  @override
  String get profileEmailConfirmed => 'E-mail confermata';

  @override
  String get profileEmailPending => 'E-mail non confermata';

  @override
  String get profileEmailVerifiedShort => 'Email verified';

  @override
  String get profileEmailPendingShort => 'Verify email';

  @override
  String get profileSignedOut => 'Disconnesso su questo dispositivo.';

  @override
  String get profileAccountCenterTitle => 'Centro conti';

  @override
  String get profileAccountCenterSubtitle =>
      'Controlla le tue preferenze, la privacy e la configurazione dell\'app.';

  @override
  String get profileTermsStat => 'Termini accettati';

  @override
  String get profileMarketingStat => 'Offerte e aggiornamenti';

  @override
  String get profileEmailStat => 'Stato dell\'e-mail';

  @override
  String get profileStatOn => 'SU';

  @override
  String get profileStatOff => 'Spento';

  @override
  String get profileStatReady => 'Pronto';

  @override
  String get profileStatPending => 'In attesa di';

  @override
  String get profilePetsTitle => 'I miei animali domestici';

  @override
  String get profilePetsSubtitle =>
      'I tuoi compagni preferiti e i profili degli animali domestici.';

  @override
  String get profilePremiumTitle => 'Passa a Premium';

  @override
  String get profilePremiumSubtitle =>
      'Sblocca tutti i modelli e i flussi di modifica premium.';

  @override
  String get profilePremiumPlanLabel => 'Premium Plan';

  @override
  String get profileFreePlanLabel => 'Free Plan';

  @override
  String get profilePremiumBannerTitle => 'Upgrade to Premium';

  @override
  String get profilePremiumBannerActiveTitle => 'Premium active';

  @override
  String get profilePremiumBenefitUnlimitedTemplates => 'Unlimited templates';

  @override
  String get profilePremiumBenefitPriorityGeneration => 'Priority generation';

  @override
  String get profilePremiumBenefitNoWatermark => 'No watermark';

  @override
  String get profilePremiumOpenAction => 'Upgrade';

  @override
  String get profileSubscriptionTitle => 'My subscription';

  @override
  String get profileSubscriptionStatusLabel => 'Status';

  @override
  String get profileSubscriptionProviderLabel => 'Provider';

  @override
  String get profileSubscriptionNextBillingLabel => 'Next billing date';

  @override
  String get profileSubscriptionTokensLabel => 'Tokens available';

  @override
  String get profileWalletTitle => 'Wallet';

  @override
  String get profileWalletHistoryHint => 'Open balance, purchases and history.';

  @override
  String get walletPageTitle => 'PawSpark wallet';

  @override
  String get walletPageSubtitle =>
      'Balance, promo codes, ad bonus, and PawSpark top-ups.';

  @override
  String get profileWalletPreviewEyebrow => 'PawSpark';

  @override
  String get profileWalletPreviewSubtitle =>
      'In-app currency for generations and bonus rewards.';

  @override
  String get profileWalletPreviewAction => 'Open';

  @override
  String get profileWalletPreviewLoadingStatus => 'Refreshing status';

  @override
  String get profileWalletPreviewWeeklyReady => 'Weekly reward ready';

  @override
  String profileWalletPreviewAdCount(Object count) {
    return 'Ads today: $count';
  }

  @override
  String get profileWalletLoadingHint => 'Loading balance...';

  @override
  String get profileWalletEmptyHint => 'Open balance and history';

  @override
  String get walletDataUnavailableFallback =>
      'Wallet data is not available right now.';

  @override
  String get walletRefreshTooltip => 'Refresh wallet';

  @override
  String get walletBalanceTitle =>
      'Available for photos, videos and premium templates.';

  @override
  String get walletBalanceEyebrow => 'Your balance';

  @override
  String get walletBalanceUnit => 'PawSpark';

  @override
  String get walletBalanceExplanation =>
      'PawSpark — internal currency of PetMagic. Use it for creating photos, videos and accessing premium templates.';

  @override
  String get walletPremiumStatus => 'Premium wallet';

  @override
  String get walletFreeStatus => 'Free wallet';

  @override
  String walletAdRewardsCount(Object count) {
    return '$count ad rewards';
  }

  @override
  String get walletQuickActionsTitle => 'Promo codes';

  @override
  String get walletRedeemAction => 'Activate';

  @override
  String get walletRewardsTitle => 'Ad bonus';

  @override
  String get walletAdRewardAction => 'Ad reward';

  @override
  String get walletAdRewardCompactTitle => 'Get PawSpark for free';

  @override
  String get walletAdRewardCompactDescription =>
      'Watch a short ad and get +15 PawSpark.';

  @override
  String walletAdRewardRemaining(Object count) {
    return 'Left today: $count';
  }

  @override
  String get walletWatchAdAction => 'Watch ad +15';

  @override
  String get walletAdDailyLimitReached =>
      'Ads are temporarily unavailable. Please try again later.';

  @override
  String get walletPromoTitle => 'Have a promo code?';

  @override
  String get walletPromoSubtitle =>
      'Enter a code from PetMagic and add PawSpark to your balance.';

  @override
  String get walletPromoInputPlaceholder => 'Enter promo code';

  @override
  String get walletPromoSuccessMessage => 'Promo code activated successfully!';

  @override
  String get walletBestValueBadge => 'Best value';

  @override
  String get walletPremiumUpsellTitle => 'Create often?';

  @override
  String get walletPremiumUpsellMessage =>
      'Premium membership gives you cheaper generations, monthly PawSparks and exclusive premium templates.';

  @override
  String get walletViewPremiumAction => 'View Premium';

  @override
  String get walletWhatYouCanCreateTitle => 'Enough for approximately:';

  @override
  String walletApproxPhotos(int count) {
    return '$count photos';
  }

  @override
  String walletApproxVideos(int count) {
    return '$count videos';
  }

  @override
  String get walletSpendPhotoSubtitle => 'Photos\nfrom 10 Spark';

  @override
  String get walletSpendVideoSubtitle => 'Videos\nfrom 50 Spark';

  @override
  String get walletSpendPremiumSubtitle => 'Premium\nfrom 80 Spark';

  @override
  String get walletContactSupportAction => 'Contact support';

  @override
  String get walletRetryAction => 'Retry';

  @override
  String get rewardsPageTitle => 'Rewards';

  @override
  String get rewardsPageSubtitle =>
      'Earn PawSpark with promo codes and invitations';

  @override
  String rewardsLastUpdatedLabel(Object value) {
    return 'Updated: $value';
  }

  @override
  String get rewardsLastUpdatedNow => 'just now';

  @override
  String rewardsLastUpdatedMinutes(int count) {
    return '$count min ago';
  }

  @override
  String rewardsLastUpdatedHours(int count) {
    return '$count h ago';
  }

  @override
  String get rewardsPromoTitle => 'Promo code';

  @override
  String get rewardsPromoSubtitle => 'Enter a promo code and receive a bonus';

  @override
  String get rewardsPromoEmptyError => 'Enter promo code.';

  @override
  String get rewardsPromoCheckingStatus => 'Checking code...';

  @override
  String get rewardsReferralTitle => 'Invite a friend';

  @override
  String get rewardsReferralSubtitle =>
      'Share your code with a friend. Referral bonus is not paid for signup and is credited only after their first successful paid purchase.';

  @override
  String get rewardsReferralInvitePrefix =>
      'Your friend gets a bonus before their first purchase, and you get';

  @override
  String get rewardsReferralInviteSuffix =>
      'after their first successful payment.';

  @override
  String get rewardsYourReferralCode => 'Your code';

  @override
  String get rewardsCopyReferralCodeAction => 'Copy';

  @override
  String get rewardsReferralCopiedMessage => 'Code copied.';

  @override
  String get rewardsReferralShareCodeAction => 'Share code';

  @override
  String get rewardsReferralUseFriendCodeAction => 'Enter friend code';

  @override
  String get rewardsReferralFriendCodePrompt => 'Have a friend\'s code?';

  @override
  String get rewardsReferralFriendCodeHint =>
      'Enter a friend\'s code before your first purchase and get a bonus.';

  @override
  String get rewardsReferralInputLabel => 'Friend code';

  @override
  String get rewardsReferralInputHint => 'PMABC12345';

  @override
  String get rewardsReferralActivateAction => 'Activate code';

  @override
  String get rewardsReferralEmptyError => 'Enter friend code.';

  @override
  String get rewardsReferralCheckingStatus => 'Checking referral code...';

  @override
  String get rewardsReferralActivatedMessage =>
      'Referral code activated. Bonus is credited after your first successful paid purchase.';

  @override
  String get rewardsReferralStatusLoading => 'Loading referral status...';

  @override
  String get rewardsReferralStatusNone =>
      'Enter a friend\'s code before your first purchase. Bonus is credited only after a successful payment.';

  @override
  String get rewardsReferralStatusPending =>
      'Referral connected. Bonus will be paid after your first successful paid purchase.';

  @override
  String get rewardsReferralStatusRewarded =>
      'Referral bonus paid. Thanks for growing PetMagic.';

  @override
  String get rewardsReferralEarnedLabel => 'Earned';

  @override
  String get rewardsReferralFriendsLabel => 'Friends';

  @override
  String get rewardsReferralBonusLabel => 'Friend purchases';

  @override
  String rewardsReferralBonusPerFriend(int count) {
    return '+$count PawSpark per invited friend';
  }

  @override
  String get rewardsReferralRulesNote =>
      'Bonus is credited after your friend\'s first successful purchase.';

  @override
  String get rewardsReferralHowItWorksAction => 'How does it work?';

  @override
  String rewardsReferralShareMessage(Object code, int bonus) {
    return 'Join me in PetMagic! Use my referral code $code. Bonus is credited after your first successful paid purchase. After your first purchase I\'ll receive +$bonus PawSpark.';
  }

  @override
  String get rewardsHistoryTitle => 'History';

  @override
  String get rewardsHistorySubtitle =>
      'Recent promo, referral, ad and weekly rewards.';

  @override
  String get rewardsHistoryEmpty =>
      'No bonuses yet. Promo and referral rewards will appear here.';

  @override
  String get rewardsSourcePromo => 'Promo code';

  @override
  String get rewardsSourceReferral => 'Referral bonus';

  @override
  String get rewardsSourceAd => 'Ad reward';

  @override
  String get rewardsSourceWeekly => 'Weekly reward';

  @override
  String get rewardsSourcePremium => 'Premium grant';

  @override
  String get rewardsSourceBonus => 'Bonus';

  @override
  String get rewardsReferralCodeNotFoundError => 'Referral code was not found.';

  @override
  String get rewardsReferralSelfError =>
      'You cannot activate your own referral code.';

  @override
  String get rewardsReferralAlreadyLinkedError =>
      'A referral code is already activated for this account.';

  @override
  String get rewardsReferralPaidUserError =>
      'Referral code must be activated before your first successful paid purchase.';

  @override
  String get walletBuySparkTitle => 'Top up PawSpark';

  @override
  String walletPackTotalSpark(Object count) {
    return '$count PawSpark';
  }

  @override
  String get walletPopularBadge => 'Popular';

  @override
  String get walletBestValueLabel => 'Best value';

  @override
  String walletPackBonus(Object count) {
    return '+$count bonus';
  }

  @override
  String walletPackBonusPill(Object count) {
    return 'Bonus +$count';
  }

  @override
  String walletPackBaseSpark(Object count) {
    return '$count base';
  }

  @override
  String walletBuyForPrice(Object price) {
    return 'Buy for $price';
  }

  @override
  String get walletPackDetailsAction => 'Details';

  @override
  String get walletPackDetailSubtitle =>
      'Check what is included before opening checkout.';

  @override
  String get walletCheckoutHint =>
      'Payment opens in secure Stripe Checkout. PetMagic does not store your card details.';

  @override
  String walletCheckoutSucceeded(int spark) {
    return 'Payment confirmed. +$spark PawSpark is already in your wallet.';
  }

  @override
  String walletPackBreakdown(Object base, Object bonus) {
    return '$base base + $bonus bonus';
  }

  @override
  String get walletRecentTransactionsTitle => 'Recent transactions';

  @override
  String get walletViewAllTransactions => 'All transactions';

  @override
  String get walletNoActivity => 'No wallet activity yet.';

  @override
  String walletBalanceAfter(Object count) {
    return 'Bal. $count';
  }

  @override
  String get walletPurchaseHistoryTitle => 'Purchase history';

  @override
  String walletPurchaseSummary(Object count, Object date) {
    return '$count PawSpark • $date';
  }

  @override
  String get walletPurchaseJustConfirmed => 'Just confirmed';

  @override
  String get walletUnavailableTitle => 'Wallet is temporarily unavailable';

  @override
  String get walletTryAgainAction => 'Try again';

  @override
  String get walletPending => 'Pending';

  @override
  String get walletSourcePackPurchase => 'Added funds';

  @override
  String get walletSourceGenerationSpend => 'Generation';

  @override
  String get walletSourceGenerationRefund => 'Generation refund';

  @override
  String get walletSourceWeeklyGrant => 'Weekly bonus';

  @override
  String get walletSourceAdReward => 'Ad bonus';

  @override
  String get walletSourcePromoCode => 'Promo code';

  @override
  String get walletSourceAdminGrant => 'Support credit';

  @override
  String get walletSourceAdminDebit => 'Support adjustment';

  @override
  String get walletPurchaseCompleted => 'Completed';

  @override
  String get walletPurchaseFailed => 'Failed';

  @override
  String get walletQueryFilterAll => 'All';

  @override
  String get walletQueryFilterCredits => 'Credits';

  @override
  String get walletQueryFilterDebits => 'Debits';

  @override
  String get walletPartialActivityUnavailable =>
      'Your balance is already available. History and some wallet actions will refresh a bit later.';

  @override
  String get walletPaymentGatewayUnavailableError =>
      'Payments are temporarily unavailable. Please try again later or update the app.';

  @override
  String get walletPaymentUnavailableError =>
      'Top-up is temporarily unavailable. Please try again later.';

  @override
  String get walletPackUnavailableError =>
      'This PawSpark pack is no longer available.';

  @override
  String get walletRedeemCodeNotFoundError => 'Redeem code was not found.';

  @override
  String get walletRedeemCodeAlreadyUsedError =>
      'This redeem code was already used.';

  @override
  String get walletRedeemCodeExpiredError => 'Redeem code has expired.';

  @override
  String get walletRedeemCodeInactiveError =>
      'This redeem code is not available right now.';

  @override
  String get walletRedeemCodeExhaustedError =>
      'This redeem code has reached its usage limit.';

  @override
  String get walletRedeemCodeUserLimitError =>
      'This user has already reached the redeem limit for this code.';

  @override
  String get walletRedeemOfflineError =>
      'No internet connection. Check your network and try again.';

  @override
  String get walletRedeemServerError =>
      'The promo code could not be applied because of a server error. Please try again later.';

  @override
  String get walletInsufficientBalanceError =>
      'Not enough PawSpark for this operation.';

  @override
  String get walletUnavailableError =>
      'Wallet data is temporarily unavailable. Please try again in a moment.';

  @override
  String get walletRedeemSheetTitle => 'Redeem code';

  @override
  String get walletRedeemSheetSubtitle =>
      'A code can be used once while it is active and not expired.';

  @override
  String get walletRedeemInputLabel => 'Promo code';

  @override
  String get walletRedeemHint => 'Enter promo code';

  @override
  String get walletRedeemCancelAction => 'Cancel';

  @override
  String get walletApplyCode => 'Apply code';

  @override
  String get walletRedeemSuccessMessage =>
      'Promo code applied successfully. Your balance is already updated.';

  @override
  String get walletRedeemSuccessAction => 'Done';

  @override
  String get profileStatsSectionTitle => 'Account stats';

  @override
  String get profileStatBalanceLabel => 'Balance';

  @override
  String get profileStatPlanLabel => 'Plan';

  @override
  String get profileStatLegalLabel => 'Legal';

  @override
  String get profileMagicMomentTitle => 'Your next pet star moment';

  @override
  String get profileMagicMomentSubtitle =>
      'Create something playful for your pets in just a few taps.';

  @override
  String get premiumPageTitle => 'PetMagic Premium';

  @override
  String get premiumPageSubtitle =>
      'Magia illimitata per animali, generazione più veloce e modelli premium in un unico piano.';

  @override
  String get premiumHeroEyebrow => 'Magia Premium';

  @override
  String get premiumHeroTitle => 'Passa a Premium e crea più contenuti.';

  @override
  String get premiumHeroSubtitle =>
      'Sblocca modelli premium, generazione più veloce e più spazio per foto e video in un unico piano.';

  @override
  String get premiumAlreadyActive => 'Premium attivo';

  @override
  String get premiumBenefitUnlimitedTemplates => 'Modelli illimitati';

  @override
  String get premiumBenefitFastGeneration => 'Generazione più veloce';

  @override
  String get premiumBenefitHighQuality => 'Output ad alta qualità';

  @override
  String get premiumBenefitExclusive => 'Modelli esclusivi';

  @override
  String get premiumChoosePlanTitle => 'Scegli un piano';

  @override
  String get premiumWeeklyPlan => 'Settimanale';

  @override
  String get premiumMonthlyPlan => 'Mensile';

  @override
  String get premiumYearlyPlan => 'Annuale';

  @override
  String get premiumWeeklyPeriod => '/ settimana';

  @override
  String get premiumMonthlyPeriod => '/ mese';

  @override
  String get premiumYearlyPeriod => '/ anno';

  @override
  String get premiumPopularBadge => 'Più popolare';

  @override
  String premiumTokensPerWeek(Object count) {
    return '$count token / settimana';
  }

  @override
  String premiumTokensPerMonth(Object count) {
    return '$count token / mese';
  }

  @override
  String premiumDiscountLabel(Object percent) {
    return 'Risparmia $percent%';
  }

  @override
  String get premiumCancelAnytime => 'Annulla in qualsiasi momento';

  @override
  String get premiumIncludesTitle => 'Cosa include Premium';

  @override
  String premiumTokenEstimate(Object videos, Object photos) {
    return '$videos video o $photos foto al mese, in base alla complessità del modello.';
  }

  @override
  String get premiumSocialProof =>
      'Il piano più scelto dai creator abituali di PetMagic.';

  @override
  String get premiumPaymentTitle => 'Metodo di pagamento';

  @override
  String get premiumPaymentStripe => 'Card via Stripe';

  @override
  String get premiumPaymentGooglePlay => 'Google Play';

  @override
  String get premiumPaymentApple => 'Apple Pay / App Store';

  @override
  String get premiumPaymentRecommendedBadge => 'Recommended';

  @override
  String get premiumPaymentDefaultBadge => 'Default';

  @override
  String paymentBonusPercentBadge(Object percent) {
    return '+$percent% bonus';
  }

  @override
  String get premiumComparisonTitle => 'Cosa cambia con Premium';

  @override
  String get premiumFreeColumn => 'Gratis';

  @override
  String get premiumPremiumColumn => 'Premium';

  @override
  String get premiumComparisonFreeTemplates => 'Modelli gratuiti';

  @override
  String get premiumComparisonPremiumTemplates => 'Modelli premium';

  @override
  String get premiumComparisonTokens => 'Token al mese';

  @override
  String premiumComparisonPremiumTokens(Object count) {
    return 'Fino a $count';
  }

  @override
  String get premiumComparisonPremiumTokensFallback => 'Fino a 1000';

  @override
  String get premiumComparisonFast => 'Generazione rapida';

  @override
  String get premiumComparisonHighQuality => 'Esportazione ad alta qualità';

  @override
  String get premiumComparisonNoWatermark => 'Senza filigrana';

  @override
  String get premiumComparisonPrioritySupport => 'Supporto prioritario';

  @override
  String get premiumFreeSummaryTokens => '20 tokens per month';

  @override
  String get premiumFreeSummaryWatermark => 'Watermark on content';

  @override
  String get premiumFreeSummaryTemplates => 'Basic templates';

  @override
  String get premiumFreeSummaryQuality => 'Standard quality';

  @override
  String get premiumSecurePaymentTitle => 'Pagamento sicuro';

  @override
  String get premiumSecurePaymentSubtitle =>
      'Gestisci o annulla l\'abbonamento in qualsiasi momento dalle impostazioni di fatturazione.';

  @override
  String get premiumContinueAction => 'Continua';

  @override
  String get externalCheckoutStripeTitle => 'Payment via Stripe';

  @override
  String get externalCheckoutStripeMessage =>
      'Stripe Checkout opens in a secure in-app browser. After you return to PetMagic, we automatically check the payment status before updating your access.';

  @override
  String get externalCheckoutContinueAction => 'Continue';

  @override
  String get externalCheckoutCheckingTitle => 'Checking payment';

  @override
  String get externalCheckoutCheckingMessage =>
      'We are waiting for Stripe confirmation. This usually takes a few seconds.';

  @override
  String get externalCheckoutPendingVerificationMessage =>
      'Payment is not confirmed yet. We will update Premium or your wallet as soon as Stripe webhook arrives.';

  @override
  String premiumContinueWithPlan(Object plan, Object price, Object period) {
    return 'Continua con $plan — $price $period';
  }

  @override
  String get premiumManageAction => 'Gestisci abbonamento';

  @override
  String get premiumRestoreAction => 'Ripristina acquisti';

  @override
  String get premiumTermsNotice =>
      'Continuando, accetti i Termini di utilizzo e l\'Informativa sulla privacy.';

  @override
  String get premiumStoreUnavailable =>
      'Gli abbonamenti store sono in attesa della configurazione prodotti su App Store / Google Play. Per ora usa Stripe Checkout.';

  @override
  String get premiumStoreProductUnavailable =>
      'Questo prodotto in abbonamento non è disponibile nello store su questo dispositivo.';

  @override
  String get premiumStoreVerificationUnavailable =>
      'La verifica store lato server non è ancora configurata.';

  @override
  String get premiumStorePurchaseInvalid =>
      'Non è stato possibile verificare l\'acquisto.';

  @override
  String get premiumStorePurchaseInactive =>
      'Questo abbonamento non è più attivo.';

  @override
  String get premiumPurchaseActivated => 'Premium è ora attivo.';

  @override
  String get premiumRecentlyActivatedBadge => 'Just activated';

  @override
  String get premiumRecentlyActivatedTitle => 'Premium confirmed';

  @override
  String get premiumRecentlyActivatedMessage =>
      'Your Premium access is active on this device and ready to use.';

  @override
  String get premiumPurchaseCancelled => 'L\'acquisto è stato annullato.';

  @override
  String get premiumCheckoutFailed =>
      'Premium checkout è temporaneamente non disponibile.';

  @override
  String get premiumManageFailed =>
      'La gestione della fatturazione non è ancora disponibile per questo account.';

  @override
  String get premiumRestoreStarted =>
      'Lo stato Premium è stato aggiornato su questo dispositivo.';

  @override
  String get profileCommunicationsTitle => 'Aggiornamenti di PetMagic';

  @override
  String get profileCommunicationsEnabled =>
      'Sei iscritto agli aggiornamenti e alle offerte dei prodotti.';

  @override
  String get profileCommunicationsDisabled =>
      'Gli aggiornamenti di marketing sono attualmente disattivati.';

  @override
  String get profilePrivacyTitle => 'Privacy e consenso';

  @override
  String get profileTermsAccepted =>
      'Il tuo account ha accettato i Termini di utilizzo e l\'Informativa sulla privacy.';

  @override
  String get profileTermsPending =>
      'Completa la revisione del consenso nelle impostazioni dell\'account.';

  @override
  String get profileLegalShortcutTitle => 'Privacy & Legal';

  @override
  String get profileLegalShortcutAccepted =>
      'Terms accepted • Privacy settings';

  @override
  String get profileLegalShortcutPending => 'Review permissions';

  @override
  String get profileSupportTitle => 'Contatta l\'assistenza';

  @override
  String get profileSupportSubtitle =>
      'Siamo qui quando hai bisogno di aiuto con il tuo account.';

  @override
  String get profileSupportCompactSubtitle =>
      'Get help with billing or account access.';

  @override
  String get profileSettingsShortcutTitle => 'Impostazioni';

  @override
  String get profileSettingsShortcutSubtitle =>
      'Gestisci le sezioni relative a lingua, tema e account.';

  @override
  String get profileSettingsCompactSubtitle =>
      'Language, theme and account settings.';

  @override
  String get profilePreferenceEnabled => 'Abilitato';

  @override
  String get profilePreferenceOff => 'Spento';

  @override
  String get profileSettingsTitle => 'Impostazioni';

  @override
  String get profileSettingsSubtitle => 'Gestisci l\'app e il tuo account.';

  @override
  String get profileSettingsAccountSection => 'Account';

  @override
  String get profileSettingsNotificationsSection => 'Notifiche';

  @override
  String get profileSettingsPreferencesSection => 'Preferenze';

  @override
  String get profileSettingsSupportSection => 'Supporto';

  @override
  String get profileSettingsAboutSection => 'Informazioni sull\'app';

  @override
  String get profileSettingsDangerSection => 'Zona pericolosa';

  @override
  String get profileSettingsAccountInfoTitle => 'Informazioni sull\'account';

  @override
  String get profileSettingsUnavailableSubtitle =>
      'Queste informazioni diventano disponibili dopo l\'accesso.';

  @override
  String get profileSettingsLinkedAccountsTitle => 'Account collegati';

  @override
  String get profileSettingsLinkedAccountsSubtitle =>
      'Google, Apple e altri fornitori appariranno qui.';

  @override
  String get profileSettingsPasswordTitle => 'Cambiare la password';

  @override
  String get profileSettingsPasswordSubtitle =>
      'Aggiorna la tua password per mantenere l\'account sicuro.';

  @override
  String get profileSettingsNotificationsTitle => 'Impostazioni di notifica';

  @override
  String get profileSettingsNotificationsSubtitle =>
      'Gestisci le preferenze push ed e-mail nell\'app.';

  @override
  String get profileSettingsLanguageTitle => 'Lingua dell\'app';

  @override
  String get profileSettingsLanguageSubtitle =>
      'Scegli la lingua utilizzata nell\'interfaccia.';

  @override
  String get profileSettingsThemeTitle => 'Tema dell\'app';

  @override
  String get profileSettingsThemeSubtitle =>
      'Passa dal sistema all\'aspetto chiaro e scuro.';

  @override
  String get profileSettingsHelpCenterTitle => 'Centro assistenza';

  @override
  String get profileSettingsHelpCenterSubtitle =>
      'Risposte rapide e guide per le domande più comuni.';

  @override
  String get profileSettingsSupportTitle => 'Contatta l\'assistenza';

  @override
  String get profileSettingsSupportSubtitle =>
      'Contattaci se hai bisogno di aiuto con la fatturazione o l\'accesso all\'account.';

  @override
  String get profileSettingsTermsTitle => 'Termini di utilizzo';

  @override
  String get profileSettingsTermsSubtitle =>
      'Rivedi le regole per l\'utilizzo di PetMagic.';

  @override
  String get profileSettingsPrivacyTitle => 'politica sulla riservatezza';

  @override
  String get profileSettingsPrivacySubtitle =>
      'Scopri come i tuoi dati vengono gestiti e protetti.';

  @override
  String get profileSettingsDeleteAccountTitle => 'Elimina account';

  @override
  String get profileSettingsDeleteAccountSubtitle =>
      'Questa azione non può essere annullata.';

  @override
  String get profileAccountDetailsSubtitle =>
      'Controlla i dati dell\'account attualmente disponibili su questo dispositivo.';

  @override
  String get profileAccountDetailsSection => 'Dettagli del conto';

  @override
  String get profileAccountUserIdLabel => 'ID utente';

  @override
  String get profileAccountDisplayNameLabel => 'Nome da visualizzare';

  @override
  String get profileAccountDisplayNameMissing => 'Non ancora impostato';

  @override
  String get profileAccountRolesLabel => 'Ruoli';

  @override
  String get profileAccountRolesMissing => 'Nessun ruolo assegnato';

  @override
  String get profileAccountMembershipLabel => 'Appartenenza';

  @override
  String get profileAccountConsentLabel => 'Accettazione dei termini';

  @override
  String get profileAccountMarketingLabel => 'Offerte e aggiornamenti';

  @override
  String get profileAccountAvatarLabel => 'Avatar';

  @override
  String get profileAccountAvatarMissing => 'Nessun avatar caricato';

  @override
  String get profileAccountAvatarUploaded => 'Avatar caricato';

  @override
  String get profileDetailsCurrentStatusSection => 'Stato attuale';

  @override
  String get profileDetailsNextStepSection => 'Cosa succede dopo';

  @override
  String get profileDetailsLinkedAccountsBody =>
      'I fornitori collegati verranno visualizzati qui non appena il collegamento sarà abilitato per il tuo account.';

  @override
  String get profileDetailsLinkedAccountsStatus =>
      'Nessun fornitore esterno è ancora collegato. L\'e-mail e la password rimangono il metodo di accesso attivo per questo profilo.';

  @override
  String get profileDetailsLinkedAccountsNext =>
      'Google, Apple e altri fornitori verranno visualizzati qui dopo l\'apertura del flusso di collegamento del backend nell\'app.';

  @override
  String get profileLinkedAccountsLoading =>
      'Caricamento dei provider di accesso collegati...';

  @override
  String get profileLinkedAccountsConnectedStatus =>
      'Collegato e pronto per l\'accesso.';

  @override
  String get profileLinkedAccountsNotConnectedStatus => 'Non ancora collegato.';

  @override
  String get profileLinkedAccountsConnectAction => 'Collega';

  @override
  String get profileLinkedAccountsDisconnectAction => 'Scollega';

  @override
  String get profileLinkedAccountsProtectedHint =>
      'Questo provider non può essere rimosso finché non rimane disponibile un altro metodo di accesso.';

  @override
  String get profileLinkedAccountsSignInRequired =>
      'Accedi di nuovo per gestire gli account collegati.';

  @override
  String get profileLinkedAccountsUnavailable =>
      'Gli account collegati non sono temporaneamente disponibili.';

  @override
  String get profileDetailsNotificationsBody =>
      'Questa sezione riflette le tue attuali preferenze di comunicazione nell\'app.';

  @override
  String get profileDetailsNotificationsStatusEnabled =>
      'Gli aggiornamenti e le offerte del prodotto sono abilitati per questo profilo. Ulteriori controlli push verranno visualizzati qui in seguito.';

  @override
  String get profileDetailsNotificationsStatusDisabled =>
      'Le email di marketing sono attualmente disabilitate per questo profilo. Ulteriori controlli push verranno visualizzati qui in seguito.';

  @override
  String get profileDetailsNotificationsNext =>
      'Puoi già rivedere l\'attuale preferenza email qui. Gli interruttori push dedicati verranno aggiunti in una sezione successiva del prodotto.';

  @override
  String get profileNotificationsLoading => 'Loading notification settings...';

  @override
  String get profileNotificationsPushSection => 'Push notifications';

  @override
  String get profileNotificationsPushPhotoReady => 'Photo is ready';

  @override
  String get profileNotificationsPushVideoReady => 'Video is ready';

  @override
  String get profileNotificationsPushGenerationErrors => 'Generation errors';

  @override
  String get profileNotificationsPushReminders => 'Reminders';

  @override
  String get profileNotificationsPushNewTemplates => 'New templates';

  @override
  String get profileNotificationsPushPurchasesAndSubscriptions =>
      'Purchases and subscriptions';

  @override
  String get profileNotificationsEmailSection => 'Email';

  @override
  String get profileNotificationsEmailOffers => 'Offers and discounts';

  @override
  String get profileNotificationsEmailNews => 'PetMagic news';

  @override
  String get profileNotificationsEmailAccountAlerts =>
      'Important account alerts';

  @override
  String get profileNotificationsDeviceSection => 'Device status';

  @override
  String get profileNotificationsPushPermissionLabel => 'Push permissions';

  @override
  String get profileNotificationsPushPermissionAllowed => 'Allowed';

  @override
  String get profileNotificationsPushPermissionDenied =>
      'Disabled in device settings';

  @override
  String get profileNotificationsPushPermissionNotDetermined =>
      'Not requested yet';

  @override
  String get profileNotificationsPushPermissionProvisional => 'Allowed quietly';

  @override
  String get profileNotificationsPushPermissionUnknown => 'Unknown';

  @override
  String get profileNotificationsRefreshStatus => 'Refresh status';

  @override
  String get profileNotificationsRequestPermission =>
      'Allow push notifications';

  @override
  String get profileDetailsHelpBody =>
      'Il Centro assistenza raccoglierà risposte rapide, suggerimenti per la configurazione e indicazioni sull\'account in un unico posto.';

  @override
  String get profileDetailsHelpStatus =>
      'La knowledge base in-app è ancora in fase di assemblaggio, quindi questa schermata mostra lo stato attuale del lancio.';

  @override
  String get profileDetailsHelpNext =>
      'I primi articoli della guida e le guide per la risoluzione dei problemi verranno visualizzati qui man mano che viene pubblicato il contenuto del supporto mobile.';

  @override
  String get profileDetailsSupportBody =>
      'Le richieste di supporto verranno gestite qui senza costringerti a uscire dall\'area del profilo.';

  @override
  String get profileDetailsSupportStatus =>
      'Il contatto diretto in-app non è ancora stato cablato. Per ora, mantieni questa schermata come punto di ingresso di supporto per la sezione successiva.';

  @override
  String get profileDetailsSupportNext =>
      'Il passaggio successivo è un vero e proprio modulo di supporto o un trasferimento di posta elettronica collegato al flusso di supporto back-end.';

  @override
  String get profileDetailsTermsBody =>
      'Controlla come PetMagic prevede che verranno utilizzati l\'app e l\'account.';

  @override
  String get profileDetailsTermsStatusAccepted =>
      'Questo account ha già accettato i Termini di utilizzo durante la registrazione.';

  @override
  String get profileDetailsTermsStatusPending =>
      'Questo account non ha ancora registrato l\'accettazione dei termini completata.';

  @override
  String get profileDetailsTermsNext =>
      'Una visione più completa del documento legale può essere allegata qui in seguito. Per ora, questa schermata conferma l\'attuale stato di accettazione.';

  @override
  String get profileDetailsPrivacyBody =>
      'Scopri come PetMagic archivia, protegge e utilizza i dati dell\'account.';

  @override
  String get profileDetailsPrivacyStatus =>
      'I dettagli sulla privacy sono attualmente rappresentati come una schermata di riepilogo in-app mentre viene preparato il flusso completo dei documenti legali.';

  @override
  String get profileDetailsPrivacyNext =>
      'La sezione successiva può allegare a questo percorso un documento politico completo o una pagina legale ospitata.';

  @override
  String get profileLegalAcceptanceCurrent =>
      'I documenti legali correnti sono accettati per questo account.';

  @override
  String get profileLegalAcceptanceRequired =>
      'Questo account deve accettare le versioni correnti dei documenti legali.';

  @override
  String get profileLegalVersionLabel => 'Versione corrente';

  @override
  String get profileLegalPublishedLabel => 'Pubblicato';

  @override
  String get profileLegalAcceptedVersionLabel => 'Versione accettata';

  @override
  String get profileLegalAcceptedAtLabel => 'Accettato il';

  @override
  String get profileLegalLoading =>
      'Caricamento del documento legale corrente dal backend...';

  @override
  String get profileLegalUnavailable =>
      'Al momento non è stato possibile caricare il documento legale corrente.';

  @override
  String get profileLegalAcceptAction => 'Accetta i documenti legali correnti';

  @override
  String get profileLegalAcceptanceGuestHint =>
      'Durante la registrazione accetterai la versione corrente dei Termini di utilizzo e della Privacy Policy.';

  @override
  String get profileLegalDocumentSection => 'Documento';

  @override
  String get profileLegalDocumentInfoSection => 'Document info';

  @override
  String get profileLegalOpenFullAction => 'Open full policy';

  @override
  String get profileLegalCompactHint =>
      'Il riepilogo resta visibile e ogni sezione si apre solo quando serve.';

  @override
  String get profileLegalCurrentAcceptedHint =>
      'Per questo account non è richiesta alcuna ulteriore conferma.';

  @override
  String get profileLegalCompactSectionLabel => 'Tocca per espandere';

  @override
  String get profilePrivacyQuickDataTitle => 'What we collect';

  @override
  String get profilePrivacyQuickDataBody =>
      '• Email\n• Profile name\n• Generation history\n• Uploaded pet photos\n• Purchase history\n• Support requests';

  @override
  String get profilePrivacyQuickUsageTitle => 'Why we use it';

  @override
  String get profilePrivacyQuickUsageBody =>
      '• Run app features\n• Generate content\n• Respond in support\n• Protect account and payments';

  @override
  String get profilePrivacyQuickSharingTitle => 'Do we share data?';

  @override
  String get profilePrivacyQuickSharingBody =>
      'We do not sell personal data. Data may be shared only with processors needed to operate the service (for example payments, cloud hosting, and analytics).';

  @override
  String get profilePrivacyQuickRightsTitle => 'Your rights';

  @override
  String get profilePrivacyQuickRightsBody =>
      '• Request a copy of your data\n• Request account and data deletion\n• Withdraw consent where applicable';

  @override
  String get profileDetailsDeleteBody =>
      'La cancellazione dell\'account è intenzionalmente protetta e non è ancora eseguita da questa schermata.';

  @override
  String get profileDetailsDeleteStatus =>
      'Al momento l\'eliminazione non è disponibile come azione con un tocco nell\'app mobile. Ciò evita comportamenti distruttivi prima che il flusso di conferma del backend sia pronto.';

  @override
  String get profileDetailsDeleteNext =>
      'Quando viene implementato il flusso di lavoro di eliminazione del backend, questa schermata può diventare la fase di conferma e verifica anziché un segnaposto.';

  @override
  String get supportChatTitle => 'Chatta di supporto';

  @override
  String get supportChatSubtitle =>
      'Invia un messaggio al team PetMagic direttamente dal tuo profilo.';

  @override
  String get supportChatSecureTitle =>
      'Your conversation is protected. We use it only for support.';

  @override
  String get supportChatSecureSubtitle =>
      'We protect your data and keep your information private.';

  @override
  String get supportChatTeamTitle => 'PetMagic Support';

  @override
  String get supportChatTeamStatus => 'We usually reply within 24 hours';

  @override
  String get supportChatTodayLabel => 'Today';

  @override
  String get supportChatInputHint =>
      'Descrivi il problema, la domanda o la richiesta...';

  @override
  String get supportChatSendAction => 'Inviare';

  @override
  String get supportChatEmptyTitle => 'Inizia la conversazione';

  @override
  String get supportChatEmptyMessage =>
      'La tua chat di supporto è pronta. Invia il primo messaggio e il team risponderà qui.';

  @override
  String get supportChatWelcomeTitle =>
      'Hello! Describe your issue and we will help.';

  @override
  String get supportChatWelcomeBody =>
      'You can also choose one of the common topics below.';

  @override
  String get supportChatQuickActionGeneration => 'Issue with image generation';

  @override
  String get supportChatQuickActionPayment => 'Payment problem';

  @override
  String get supportChatQuickActionRefund => 'Refund request';

  @override
  String get supportChatQuickActionHuman => 'Talk to an operator';

  @override
  String get supportChatQuickActionSubscription =>
      'Problema con l\'abbonamento';

  @override
  String get supportChatQuickActionVideo => 'Il video non viene creato';

  @override
  String get supportChatQuickActionTokens =>
      'I token non sono stati accreditati';

  @override
  String get supportChatFaqTitle => 'FAQ';

  @override
  String get supportChatFaqGenerationTitle => 'Why did my generation fail?';

  @override
  String get supportChatFaqGenerationBody =>
      'Send the template name, your pet type and a screenshot if possible. This usually gives support enough context on the first reply.';

  @override
  String get supportChatFaqResponseTitle => 'When will support reply?';

  @override
  String get supportChatFaqResponseBody =>
      'The support team will reply in this chat. We usually respond within 24 hours.';

  @override
  String get supportChatFaqRefundTitle => 'How do refunds work?';

  @override
  String get supportChatFaqRefundBody =>
      'Share the order date and the reason for the request. Billing cases are reviewed in the same chat without switching channels.';

  @override
  String get supportChatStatusOpen => 'Aprire';

  @override
  String get supportChatStatusInProgress => 'In corso';

  @override
  String get supportChatStatusResolved => 'Risolto';

  @override
  String get supportChatStatusClosed => 'Chiuso';

  @override
  String get supportChatWaitingForSupportStatus => 'Waiting for support';

  @override
  String get supportChatWaitingForSupportStatusHint =>
      'The request is open. Support will see the new message.';

  @override
  String get supportChatInProgressStatusHint =>
      'Support is reviewing your issue.';

  @override
  String get supportChatAwaitingYourReplyStatus => 'Awaiting your reply';

  @override
  String get supportChatSupportRepliedStatusHint =>
      'Support replied. Did this help?';

  @override
  String get supportChatResolvedStatusHint =>
      'This request was marked as resolved. You can reopen it for 7 days.';

  @override
  String get supportChatClosedStatusHint =>
      'Conversation is closed. Send a new message to reopen it.';

  @override
  String get supportChatMessageDelivered => 'Consegnato';

  @override
  String get supportChatMessageRead => 'Letto';

  @override
  String get supportChatUnavailableError =>
      'Impossibile contattare il supporto in questo momento. Riprova tra poco.';

  @override
  String get supportChatAttachmentUnavailableError =>
      'Impossibile inviare l\'allegato in questo momento. Riprova tra poco.';

  @override
  String get supportChatAttachmentTooLargeError =>
      'L\'allegato è troppo grande. La dimensione massima è 10 MB.';

  @override
  String get supportChatImageLabel => 'Immagine di supporto';

  @override
  String get supportChatSaveImageAction => 'Salva immagine';

  @override
  String get supportChatShareAction => 'Condividi';

  @override
  String get supportChatOpenOriginalAction => 'Apri originale';

  @override
  String get supportChatCloseAction => 'Chiudi';

  @override
  String get supportChatImageSavedMessage => 'Immagine salvata';

  @override
  String get supportChatSaveImageFailedError =>
      'Impossibile salvare l\'immagine';

  @override
  String get supportChatShareImageFailedError =>
      'Impossibile condividere l\'immagine';

  @override
  String get supportChatAttachmentStatusUploading => 'Caricamento';

  @override
  String get supportChatAttachmentStatusUploaded => 'Caricata';

  @override
  String get supportChatAttachmentStatusFailed => 'Non riuscito';

  @override
  String get supportChatAttachmentStatusRetry => 'Riprova';

  @override
  String supportChatAttachmentUploadingWithCount(Object current, Object total) {
    return 'Uploading photo $current of $total';
  }

  @override
  String get supportChatImageUploadFailedLabel =>
      'Caricamento immagine non riuscito';

  @override
  String get supportChatFileFallbackLabel => 'File';

  @override
  String get supportChatSystemNoticeTitle => 'Richiesta inviata';

  @override
  String get supportChatSystemNoticeBody =>
      'Abbiamo ricevuto il tuo messaggio e risponderemo presto. Il tempo medio di risposta è entro 24 ore.';

  @override
  String get supportChatComposerAttachmentChip =>
      '1 foto: JPG/PNG/WebP, fino a 10 MB';

  @override
  String get supportChatComposerResponseChip =>
      'Di solito rispondiamo entro poche ore';

  @override
  String get supportChatAddPhotoTitle => 'Add photo';

  @override
  String get supportChatAddAttachmentTitle => 'Add attachment';

  @override
  String get supportChatTakePhotoAction => 'Take photo';

  @override
  String get supportChatChooseGalleryAction => 'Choose from gallery';

  @override
  String get supportChatChoosePhotosAction => 'Choose photos';

  @override
  String get supportChatRecordVideoAction => 'Record video';

  @override
  String get supportChatChooseVideoAction => 'Choose video';

  @override
  String get supportChatAttachFileAction => 'Files';

  @override
  String get supportChatRecentMediaTitle => 'Recent media';

  @override
  String get supportChatAttachmentNoRecentMedia => 'No recent photos or videos';

  @override
  String get supportChatAttachmentLimitedAccessHint =>
      'Not all photos are available. Allow full gallery access in device settings.';

  @override
  String get supportChatOpenSettingsAction => 'Open settings';

  @override
  String get supportChatAttachmentNoGalleryAccessError =>
      'Gallery access is denied. Allow access in device settings.';

  @override
  String get supportChatAttachmentExpiredPlaceholder =>
      'Attachment was deleted after 30 days';

  @override
  String get supportChatReplyLabel => 'Reply';

  @override
  String get supportChatReplyToPrefix => 'Reply to message';

  @override
  String get supportChatReplyOriginalUnavailable =>
      'Original message is unavailable';

  @override
  String get supportChatPhotoAttachedLabel => 'Photo attached';

  @override
  String get supportChatVideoAttachedLabel => 'Video attached';

  @override
  String get supportChatVideoLabel => 'Support video';

  @override
  String get supportChatAssistantBadge => 'Assistant';

  @override
  String get supportChatTooManyAttachmentsError => 'You can add up to 5 files';

  @override
  String get supportChatAttachmentUnsupportedFormatError =>
      'This format is not supported';

  @override
  String get supportChatAttachmentVideoTooLongError =>
      'Video must be 60 seconds or shorter.';

  @override
  String get supportChatMarkResolvedAction => 'Yes, close request';

  @override
  String get supportChatKeepOpenAction => 'No, write more';

  @override
  String get supportChatReopenAction => 'Reopen';

  @override
  String get supportChatArchiveAction => 'Archive';

  @override
  String get supportChatRateTitle => 'Rate the support reply';

  @override
  String supportChatRatedLabel(Object rating) {
    return 'Your rating: $rating/5';
  }

  @override
  String get supportChatReadOnlyHint => 'This conversation is read-only';

  @override
  String get supportHomeTitle => 'Help & Support';

  @override
  String get supportHomeSubtitle => 'What can we help you with?';

  @override
  String get supportHomeTopicGenerationIssue => 'Issue with image generation';

  @override
  String get supportHomeTopicGenerationTooLong => 'Generation takes too long';

  @override
  String get supportHomeTopicTokensNotArrived => 'Tokens did not arrive';

  @override
  String get supportHomeTopicPremiumIssue => 'Premium issue';

  @override
  String get supportHomeTopicPaymentRefund => 'Payment / Refund';

  @override
  String get supportHomeTopicOther => 'Other';

  @override
  String get supportAssistantTitle => 'Support Assistant';

  @override
  String get supportAssistantThisHelpedAction => 'This helped';

  @override
  String get supportAssistantCreateTicketAction => 'Create support ticket';

  @override
  String get supportAssistantCheckLaterAction => 'Check later';

  @override
  String get supportAssistantRecommendationGeneration =>
      'For better results, please use a photo where the pet is clearly visible, not cropped, not blurry, and well lit.';

  @override
  String get supportAssistantRecommendationGenerationTooLong =>
      'Video generation may take several minutes. It usually takes around 2–10 minutes. If it has taken too long, we can send this issue to support.';

  @override
  String get supportAssistantRecommendationTokensNotArrived =>
      'Sometimes token delivery after payment may take a few minutes. If the tokens still do not appear, create a support ticket and we will check the purchase.';

  @override
  String get supportAssistantRecommendationPremiumIssue =>
      'If Premium has already been paid for but is not visible in the app, please try restarting the app. If the problem remains, we will check your subscription status.';

  @override
  String get supportAssistantRecommendationPaymentRefund =>
      'We can check your payment or forward your refund request to support. Create a support ticket and we will attach the relevant purchase information if available.';

  @override
  String get supportAssistantRecommendationOther =>
      'Please describe what happened. You can also attach a screenshot to help support understand the situation faster.';

  @override
  String get supportTicketFormTitle => 'Create support ticket';

  @override
  String get supportTicketFormTopicLabel => 'Topic';

  @override
  String get supportTicketFormDescriptionLabel => 'Problem description';

  @override
  String get supportTicketFormDescriptionHint => 'Describe what happened...';

  @override
  String get supportTicketFormRelatedGenerationLabel => 'Related generation';

  @override
  String get supportTicketFormRelatedPaymentLabel => 'Related payment';

  @override
  String get supportTicketFormRelatedSubscriptionLabel =>
      'Related subscription';

  @override
  String get supportTicketFormAttachmentsLabel => 'Attachments';

  @override
  String get supportTicketFormAddScreenshotAction => 'Add screenshot';

  @override
  String get supportTicketFormSubmitAction => 'Send to support';

  @override
  String get supportTicketFormSubmittingLabel => 'Creating ticket...';

  @override
  String get supportTicketFormSuccessMessage =>
      'Your ticket has been created. We will reply in this chat.';

  @override
  String get supportTicketFormErrorMessage =>
      'Failed to create ticket. Please try again.';

  @override
  String get profileSettingsThemeSystem => 'Sistema';

  @override
  String get profileSettingsThemeLight => 'Leggero';

  @override
  String get profileSettingsThemeDark => 'Buio';

  @override
  String get profileSettingsLanguageRussian => 'russo';

  @override
  String get profileSettingsLanguageEnglish => 'Inglese';

  @override
  String get profileSettingsLanguageGerman => 'Tedesco';

  @override
  String get profileSettingsLanguageSpanish => 'Spagnolo';

  @override
  String get profileSettingsLanguageFrench => 'Francese';

  @override
  String get profileSettingsLanguageItalian => 'Italiano';

  @override
  String get profileSettingsLanguagePolish => 'Polacco';

  @override
  String profileSettingsVersionLabel(Object version) {
    return 'Versione dell\'app $version';
  }

  @override
  String get magicLoadingPreparing => 'Prepariamo la magia...';

  @override
  String get magicLoadingCutestAngle => 'Cerchiamo l\'angolo piu tenero...';

  @override
  String get magicLoadingAiPaws => 'Scaldiamo le zampette AI...';

  @override
  String get magicLoadingCreatingAdorable => 'Creiamo qualcosa di adorabile...';

  @override
  String get magicLoadingAlmostReady => 'Quasi pronto...';

  @override
  String get videoLabel => 'Video';

  @override
  String get imageLabel => 'Immagine';

  @override
  String get templatesErrorTitle => 'I modelli non sono stati caricati';

  @override
  String get retryAction => 'Riprova';

  @override
  String get emptyTemplatesTitle => 'Ancora nessun modello';

  @override
  String get emptyTemplatesMessage =>
      'Prova un altro filtro o aggiorna il catalogo.';

  @override
  String get templatesFeedEmptyError =>
      'I modelli sono temporaneamente non disponibili.';

  @override
  String get templatesConnectionTimeoutError =>
      'Nessuna connessione. Controlla la rete e riprova.';

  @override
  String get templatesServerTimeoutError =>
      'Il server ha impiegato troppo tempo a rispondere. Riprova.';

  @override
  String get templatesRequestFailedError =>
      'Impossibile caricare i modelli in questo momento. Riprova.';

  @override
  String get startupOnboardingActionContinueGuest => 'Continua come ospite';

  @override
  String get startupOnboardingActionNext => 'Prossimo';

  @override
  String get startupOnboardingActionStart => 'Inizia';

  @override
  String get startupOnboardingPageOneTitle =>
      'Crea momenti magici con il tuo animale domestico';

  @override
  String get startupOnboardingPageOneSubtitle =>
      'Trasforma le clip di tutti i giorni in storie giocose pronte per essere virali con modelli luminosi che mettono al primo posto gli animali domestici.';

  @override
  String get startupOnboardingPageOneHighlightOne => 'Modelli alla moda';

  @override
  String get startupOnboardingPageOneHighlightTwo => 'Modifiche veloci';

  @override
  String get startupOnboardingPageOneHighlightThree =>
      'Atmosfera sicura per gli animali domestici';

  @override
  String get startupOnboardingPageTwoTitle =>
      'Sfoglia prima, sblocca quando sei pronto';

  @override
  String get startupOnboardingPageTwoSubtitle =>
      'Esplora il feed come ospite, quindi accedi quando desideri visualizzare, salvare o passare a Premium.';

  @override
  String get startupOnboardingPageTwoHighlightOne => 'Navigazione ospite';

  @override
  String get startupOnboardingPageTwoHighlightTwo => 'Accedi con un tocco';

  @override
  String get startupOnboardingPageTwoHighlightThree => 'Trasferimento fluido';

  @override
  String get startupOnboardingPageThreeTitle =>
      'Raccogli gettoni e vantaggi premium in un secondo momento';

  @override
  String get startupOnboardingPageThreeSubtitle =>
      'Mantieni la prima impressione divertente. Token, premi e azioni premium attendono dietro una fase di autenticazione pulita.';

  @override
  String get startupOnboardingPageThreeHighlightOne => 'Sblocchi premium';

  @override
  String get startupOnboardingPageThreeHighlightTwo => 'Saldo dei gettoni';

  @override
  String get startupOnboardingPageThreeHighlightThree =>
      'Vantaggi del creatore';

  @override
  String get startupMiniFeatureFastStart => 'Inizio veloce';

  @override
  String get startupMiniFeaturePetFirst =>
      'Prima di tutto gli animali domestici';

  @override
  String get startupMiniFeatureUpgradeLater => 'Aggiorna più tardi';

  @override
  String get startupWelcomeViewOnboarding => 'Visualizza l\'onboarding';

  @override
  String get startupWelcomeTitle => 'Bentornati a PetMagic';

  @override
  String get startupWelcomeSubtitle =>
      'Continua a esplorare come ospite o accedi prima di eseguire il rendering dei modelli, sbloccare premi e salvare le tue creazioni.';

  @override
  String get startupWelcomeContinueGuest => 'Continua come ospite';

  @override
  String get startupWelcomeTemplatesTitle => 'Modelli virali';

  @override
  String get startupWelcomeTemplatesSubtitle =>
      'Visualizza l\'anteprima del feed completo';

  @override
  String get startupWelcomeAiTitle => 'Magia dell\'IA';

  @override
  String get startupWelcomeAiSubtitle => 'Sblocca all\'accesso';

  @override
  String get startupWelcomeShareTitle => 'Condividi e divertiti';

  @override
  String get startupWelcomeShareSubtitle => 'Salva i tuoi preferiti più tardi';

  @override
  String get authEntryTitle => 'Bentornato!';

  @override
  String get authEntrySubtitle =>
      'Accedi per continuare la magia del tuo animale domestico.';

  @override
  String get authRegisterTitle => 'Crea il tuo account';

  @override
  String get authRegisterSubtitle =>
      'Unisciti a PetMagic e sblocca modelli, token e funzionalità premium.';

  @override
  String get authRegisterAction => 'Iscrizione';

  @override
  String get authDisplayNameLabel => 'Nome visualizzato (facoltativo)';

  @override
  String get authConfirmPasswordLabel => 'Conferma password';

  @override
  String get authPasswordRulesHint => 'Utilizza almeno 6 caratteri.';

  @override
  String get authPasswordTooShort =>
      'La password deve contenere almeno 6 caratteri.';

  @override
  String get authForgotPasswordAction => 'Ha dimenticato la password?';

  @override
  String get authForgotPasswordComingSoon =>
      'Il recupero della password sarà disponibile a breve.';

  @override
  String get authPasswordResetTitle => 'Reimposta la tua password';

  @override
  String get authPasswordResetSubtitle =>
      'Inserisci la tua email e ti invieremo un codice di ripristino.';

  @override
  String get authPasswordResetCodeTitle =>
      'Inserisci il codice dalla tua email';

  @override
  String get authPasswordResetCodeSubtitle =>
      'Utilizza il codice per impostare una nuova password per il tuo account.';

  @override
  String get authPasswordResetCodeLabel => 'Reimposta il codice';

  @override
  String get authPasswordResetRequestAction => 'Invia codice';

  @override
  String get authPasswordResetConfirmAction => 'Salva la nuova password';

  @override
  String get authPasswordResetResendAction => 'Invia nuovamente il codice';

  @override
  String get authPasswordResetCodeSent =>
      'Abbiamo inviato un codice di reimpostazione della password alla tua email.';

  @override
  String get authPasswordResetSuccess =>
      'Password aggiornata. Ora puoi accedere con la nuova password.';

  @override
  String get authPasswordResetCodeInvalid =>
      'Questo codice di ripristino non è valido o è scaduto.';

  @override
  String get authOrContinueWith => 'o continuare con';

  @override
  String get authAcceptTermsLabel =>
      'Accetto i Termini di utilizzo e l\'Informativa sulla privacy';

  @override
  String get authReceiveUpdatesLabel =>
      'Desidero ricevere aggiornamenti e offerte da PetMagic';

  @override
  String get authAcceptTermsRequired =>
      'È necessario accettare i Termini di utilizzo e l\'Informativa sulla privacy per creare un account.';

  @override
  String get authReviewTermsAction => 'Vedi termini';

  @override
  String get authReviewPrivacyAction => 'Vedi privacy';

  @override
  String get authLegalLoading =>
      'Caricamento dei documenti correnti di termini e privacy...';

  @override
  String get authLegalReady =>
      'I documenti legali correnti sono pronti per essere letti e accettati.';

  @override
  String get authLegalUnavailable =>
      'I documenti legali correnti sono temporaneamente non disponibili. Riprova tra poco.';

  @override
  String get authGoogleShortLabel => 'Google';

  @override
  String get authAppleShortLabel => 'Mela';

  @override
  String get authContinueWithGoogle => 'Continua con Google';

  @override
  String get authContinueWithApple => 'Continua con Apple';

  @override
  String get authNoAccountPrompt => 'Non hai un account?';

  @override
  String get authHaveAccountPrompt => 'Hai già un account?';

  @override
  String get authSignUpAction => 'Iscrizione';

  @override
  String get authSocialComingSoon =>
      'L\'accesso social sarà presto disponibile.';

  @override
  String get authPasswordMismatch => 'Le password non corrispondono.';

  @override
  String get authExternalCancelled => 'L\'accesso è stato annullato.';

  @override
  String get authExternalFailed =>
      'Accesso esterno non riuscito. Per favore riprova.';

  @override
  String get authExternalTimedOut =>
      'L\'accesso ha richiesto troppo tempo. Per favore riprova.';

  @override
  String get authExternalLaunchFailed =>
      'Impossibile aprire la pagina di accesso.';

  @override
  String get authExternalCallbackFailed =>
      'Non è stato possibile completare l\'accesso all\'app.';

  @override
  String get authExternalSessionExpired =>
      'Questa sessione di accesso è scaduta. Per favore riprova.';

  @override
  String get authSignInRequired => 'È richiesto l\'accesso.';

  @override
  String get authSessionExpired => 'Sessione scaduta.';

  @override
  String get authLoginFailed => 'Accesso non riuscito. Riprova.';

  @override
  String get authRegistrationFailed => 'Registrazione non riuscita. Riprova.';

  @override
  String get authPasswordResetRequestFailed =>
      'Richiesta di reimpostazione password non riuscita. Riprova.';

  @override
  String get authPasswordResetFailed =>
      'Reimpostazione password non riuscita. Riprova.';

  @override
  String get authRequestFailed => 'Richiesta non riuscita. Riprova.';

  @override
  String get profileActionFailed =>
      'We could not complete this action. Please try again.';

  @override
  String get authSecurePrivateTitle => 'Sicuro e privato';

  @override
  String get authSecurePrivateSubtitle => 'I tuoi dati rimangono protetti.';

  @override
  String get authFastEasyTitle => 'Veloce e facile';

  @override
  String get authFastEasySubtitle => 'Inizia a creare in pochi tocchi.';

  @override
  String get authLovedByPetsTitle => 'Amato dagli animali domestici';

  @override
  String get authLovedByPetsSubtitle =>
      'Costruito per genitori felici di animali domestici.';

  @override
  String get authPrivacyTitle => 'La tua privacy è importante';

  @override
  String get authPrivacySubtitle =>
      'Non vendiamo né condividiamo mai i tuoi dati con terze parti.';

  @override
  String get authRequiredTitle => 'Accedi per sbloccare questa azione';

  @override
  String get authRequiredMessage =>
      'Gli ospiti possono esplorare l\'app, ma le azioni dei modelli, i premi e le funzionalità dei token richiedono un account PetMagic.';

  @override
  String get authRequiredContinueBrowsing => 'Continua la navigazione';

  @override
  String get templateTryAction => 'Prova il modello';

  @override
  String get templateGuestPreview => 'Anteprima degli ospiti';

  @override
  String get templateActionComingSoon =>
      'Lo studio dei modelli sarà presto disponibile.';

  @override
  String get tokensActionComingSoon =>
      'Il portafoglio token sarà presto disponibile.';

  @override
  String get rewardsActionComingSoon =>
      'Il centro premi sarà presto disponibile.';

  @override
  String get templateFlowPhotoSourceGallery => 'Gallery';

  @override
  String get templateFlowPhotoSourceCamera => 'Camera';

  @override
  String get templateFlowReadyTitle => 'Ready to create!';

  @override
  String get templateFlowCheckDetailsSubtitle =>
      'Check the details before creating';

  @override
  String get templateFlowTemplateLabel => 'Modello';

  @override
  String get templateFlowCostLabel => 'Costo';

  @override
  String get templateFlowBalanceLabel => 'Your balance';

  @override
  String get templateFlowDurationHint =>
      'Creation can take from 10 seconds to 1 minute.';

  @override
  String get templateFlowCreateMagicAction => 'Create magic';

  @override
  String get templateFlowChangePhotoAction => 'Change photo';

  @override
  String get templateFlowPremiumTemplateTitle => 'Premium template';

  @override
  String get templateFlowPremiumTemplateMessage =>
      'This template is available with Premium.';

  @override
  String get templateFlowInsufficientBalanceTitle => 'Not enough PawSpark';

  @override
  String templateFlowInsufficientBalanceMessage(
    Object tokenCost,
    Object balance,
  ) {
    return 'This template costs $tokenCost PawSpark. Your balance: $balance PawSpark.';
  }

  @override
  String get templateFlowChooseAnotherTemplateAction =>
      'Choose another template';

  @override
  String get templateFlowCreateFailedTitle => 'Could not create magic';

  @override
  String get templateFlowCreateFailedBalanceHint =>
      'Top up your balance and try creating again.';

  @override
  String get templateFlowCreateFailedRetryHint =>
      'Try another photo or retry later.';

  @override
  String get templateFlowCreateHint => 'This may take a little time';

  @override
  String get templateFlowStepProcessPhoto => 'Elaborazione foto';

  @override
  String get templateFlowStepAnalyzePet => 'Analyzing pet';

  @override
  String get templateFlowStepCreateMagic => 'Creazione della magia';

  @override
  String get templateFlowStepFinalTouches => 'Ritocchi finali';

  @override
  String get templateFlowTopUpBalanceAction => 'Top up balance';

  @override
  String get templateFlowResultReadyTitle => 'Done!';

  @override
  String get templateFlowResultReadySubtitle => 'Your magic is ready';

  @override
  String get templateFlowResultUnavailable =>
      'Il risultato non e ancora disponibile';

  @override
  String get templateFlowLoadingResult => 'Loading result...';

  @override
  String get templateFlowResultLoadFailed =>
      'Impossibile caricare il risultato';

  @override
  String get templateFlowCreateMoreAction => 'Create more';

  @override
  String get templateFlowPreviewFallback => 'Preview';

  @override
  String get templateFlowLoadingPreview => 'Loading preview...';

  @override
  String get templateFlowPreviewUnavailable => 'Preview unavailable';

  @override
  String get templateFlowLoadingVideo => 'Loading video...';

  @override
  String get templateFlowBestPhotoTitle => 'Best photo for this template:';

  @override
  String get templateFlowUploadPetPhotoAction => 'Upload a pet photo';

  @override
  String get templateFlowPremiumRequiredError =>
      'This template is available only with Premium.';

  @override
  String get templateFlowInsufficientBalanceError =>
      'Not enough PawSpark to start generation.';

  @override
  String get templateFlowNetworkError =>
      'No connection. Check your network and try again.';

  @override
  String get templateFlowServerError =>
      'Service is temporarily unavailable. Please try again later.';

  @override
  String get templateFlowStartFailedError =>
      'Could not start generation. Please try again.';

  @override
  String get generationStatusTitle => 'Stato generazione';

  @override
  String get generationStatusCreatedLabel => 'Creato';

  @override
  String get generationStatusStartedLabel => 'Avviato';

  @override
  String get generationStatusTypeLabel => 'Tipo';

  @override
  String get generationStatusAttemptLabel => 'Tentativo';

  @override
  String get generationStatusUntitledFallback => 'Senza titolo';

  @override
  String get generationStatusDetailsTitle => 'Dettagli';

  @override
  String get generationStatusFeedbackTitle => 'Com\'e il risultato?';

  @override
  String get generationStatusFeedbackExcellent => 'Eccellente';

  @override
  String get generationStatusFeedbackOkay => 'Buono';

  @override
  String get generationStatusFeedbackBad => 'Non molto buono';

  @override
  String get generationStatusSaveAction => 'Salva';

  @override
  String get generationStatusDeleteAction => 'Elimina';

  @override
  String get generationStatusReportProblemAction => 'Segnala un problema';

  @override
  String get generationStatusPickAnotherPhotoAction => 'Scegli un\'altra foto';

  @override
  String get generationStatusRetryAction => 'Riprova';

  @override
  String get generationStatusContactSupportAction => 'Contatta supporto';

  @override
  String get generationStatusOpenGalleryAction => 'Apri galleria';

  @override
  String get generationStatusOpenStatusAction => 'Apri stato';

  @override
  String get generationStatusCancelGenerationAction => 'Annulla generazione';

  @override
  String get generationStatusResultUnavailableForSave =>
      'Il risultato non e ancora disponibile per il salvataggio.';

  @override
  String get generationStatusResultUnavailableForShare =>
      'Il risultato non e ancora disponibile per la condivisione.';

  @override
  String get generationStatusSaveFileDialogTitle => 'Salva file';

  @override
  String get generationStatusFileSavedMessage =>
      'File salvato sul dispositivo.';

  @override
  String get generationStatusFileSaveFailedMessage =>
      'Impossibile salvare il file. Riprova.';

  @override
  String get generationStatusSavedToGalleryMessage => 'Salvato nella galleria';

  @override
  String get generationStatusLinkCopiedMessage => 'Link copiato';

  @override
  String get generationStatusDeletedMessage => 'Eliminato';

  @override
  String get generationStatusFullscreenControlsHint =>
      'Tocca per mostrare/nascondere i controlli';

  @override
  String get generationStatusDeleteSoonMessage =>
      'L\'eliminazione sara disponibile presto.';

  @override
  String get generationStatusCancelSoonMessage =>
      'L\'annullamento della generazione sara disponibile presto.';

  @override
  String get generationStatusRetrySoonMessage =>
      'Scegli un\'altra foto e avvia di nuovo la generazione.';

  @override
  String get generationStatusFeedbackThanksMessage =>
      'Grazie! Il tuo feedback aiuta a migliorare PetMagic.';

  @override
  String get generationStatusResultTitle => 'Risultato PetMagic';

  @override
  String get generationStatusNonTerminalHint =>
      'Di solito richiede alcuni minuti. Puoi continuare a usare l\'app.';

  @override
  String get generationStatusStageQueued => 'In coda';

  @override
  String get generationStatusStageDone => 'Fatto';

  @override
  String get generationStatusVideoReady => 'Il video e pronto';

  @override
  String get generationStatusShareVideoAction => 'Condividi video';

  @override
  String get generationStatusFailedTitle => 'Impossibile creare il risultato';

  @override
  String get generationStatusTokensRefundedHint =>
      'I token sono stati restituiti al tuo saldo.';

  @override
  String get generationStatusTokensRefundedShort => 'Token rimborsati';

  @override
  String get generationStatusSupportHint =>
      'Se si ripete, contatta il supporto.';

  @override
  String get generationStatusBackgroundHint =>
      'La generazione continua sul server. Mostreremo il risultato nella Galleria quando sara pronto.';

  @override
  String get generationStatusDownloadAction => 'Scarica';

  @override
  String get generationStatusContinueInAppAction => 'Continua nell\'app';

  @override
  String get generationStatusFeedbackImproveTitle =>
      'Cosa possiamo migliorare?';

  @override
  String get generationStatusFeedbackCommentLabel => 'Commento';

  @override
  String get generationStatusFeedbackCommentHint =>
      'Descrivi brevemente cosa non e andato';

  @override
  String get generationStatusFeedbackSubmitAction => 'Invia feedback';

  @override
  String get generationStatusFeedbackReasonPetNotSimilar =>
      'L\'animale non sembra se stesso';

  @override
  String get generationStatusFeedbackReasonFaceDistorted =>
      'Viso o muso sono distorti';

  @override
  String get generationStatusFeedbackReasonStrangeMotion =>
      'Il movimento sembra strano';

  @override
  String get generationStatusFeedbackReasonPreviewMismatch =>
      'Il risultato differisce dall\'anteprima';

  @override
  String get generationStatusFeedbackReasonLowQuality =>
      'La qualita e troppo bassa';

  @override
  String get generationStatusFeedbackReasonStyleDisliked =>
      'Lo stile non mi e piaciuto';

  @override
  String get generationStatusFeedbackReasonOther => 'Altro';

  @override
  String generationStatusEtaEstimated(Object value) {
    return 'Mancano circa $value';
  }

  @override
  String get generationStatusEtaQueued => 'In attesa in coda';

  @override
  String get generationStatusEtaFinalizing => 'Quasi pronto';

  @override
  String get generationStatusEtaDefault => 'Mancano circa 1-2 min';

  @override
  String get generationStatusEtaStartsSoon => 'Iniziera tra pochi minuti';

  @override
  String get generationStatusEtaNotifyHint =>
      'Ti avviseremo quando il risultato sara pronto.';

  @override
  String get generationStatusFailurePhotoHint =>
      'La foto non e adatta a questo template. Prova una foto in cui l\'animale sia chiaramente visibile.';

  @override
  String get generationStatusFailureTechnicalHint =>
      'Impossibile creare il risultato a causa di un problema tecnico. I token sono stati restituiti al tuo saldo.';

  @override
  String get generationStatusStatusCompleted => 'Il tuo risultato e pronto';

  @override
  String get generationStatusStatusFailed => 'Impossibile creare il risultato';

  @override
  String get generationStatusStatusCreatingMagic => 'Creazione della magia...';

  @override
  String get generationStatusTerminalRefundedHint =>
      'I token sono stati rimborsati automaticamente.';

  @override
  String get generationStatusTerminalFailureHint =>
      'E stato registrato un problema tecnico.';

  @override
  String get generationStatusTerminalSuccessHint =>
      'Apri il risultato, condividilo o lascia un feedback.';

  @override
  String get generationStatusSectionActive => 'In corso';

  @override
  String get generationStatusSectionReady => 'Pronto';

  @override
  String get generationStatusSectionFailed => 'Fallito';

  @override
  String get generationStatusFilterActive => 'In corso';

  @override
  String get generationStatusFilterReady => 'Pronto';

  @override
  String get generationStatusFilterFailed => 'Fallito';

  @override
  String generationStatusShowMoreAction(int hiddenCount) {
    return 'Mostra altro ($hiddenCount) ▾';
  }

  @override
  String get generationStatusCollapseAction => 'Comprimi ▲';

  @override
  String get generationStatusActiveInfoHint =>
      'Puoi chiudere l\'app. Ti avviseremo quando il risultato sara pronto.';

  @override
  String generationStatusUnreadCount(int count) {
    return '$count nuovi';
  }

  @override
  String get generationStatusEmptyTitle => 'I tuoi risultati appariranno qui';

  @override
  String get generationStatusEmptyMessage =>
      'Scegli un template, carica la foto del tuo animale e crea la tua prima opera magica.';

  @override
  String get generationStatusSubtitleAll => 'Le tue creazioni magiche';

  @override
  String get generationStatusSubtitleActive => 'Generazioni attive';

  @override
  String get generationStatusSubtitleReady => 'I tuoi risultati pronti';

  @override
  String get generationStatusSubtitleFailed => 'Problemi di generazione';

  @override
  String generationStatusDateToday(Object time) {
    return 'Oggi, $time';
  }

  @override
  String generationStatusDateYesterday(Object time) {
    return 'Ieri, $time';
  }

  @override
  String shellActiveGenerationLabel(Object templateTitle) {
    return '✨ Creazione di $templateTitle';
  }

  @override
  String get shellActiveGenerationFallback => 'risultato';
}
