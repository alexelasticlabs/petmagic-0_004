using FluentValidation;

using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Domain.Enums;

namespace PetMagic.Modules.Economy.Application.Validation;

public sealed class ClaimWeeklyGrantCommandValidator : AbstractValidator<ClaimWeeklyGrantCommand>
{
    public ClaimWeeklyGrantCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class ClaimAdRewardCommandValidator : AbstractValidator<ClaimAdRewardCommand>
{
    public ClaimAdRewardCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
    }
}

public sealed class CreditBalanceCommandValidator : AbstractValidator<CreditBalanceCommand>
{
    public CreditBalanceCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Amount).GreaterThan(0);
        RuleFor(x => x.Source).NotEmpty().MaximumLength(80);
        RuleFor(x => x.Reason).NotEmpty().MaximumLength(120);
    }
}

public sealed class CreatePackPurchaseCommandValidator : AbstractValidator<CreatePackPurchaseCommand>
{
    public CreatePackPurchaseCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PackId).NotEmpty();
        RuleFor(x => x.CurrencyCode).NotEmpty().Length(3);
        RuleFor(x => x.PaymentProvider)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PremiumSubscriptionValidationRules.IsSupportedCheckoutProvider)
            .WithMessage("economy.payment_provider_unsupported_checkout");
        RuleFor(x => x.Platform).NotEmpty().MaximumLength(24);
        RuleFor(x => x.AppVersion).NotEmpty().MaximumLength(32);
        RuleFor(x => x.Country).NotEmpty().MaximumLength(16);
        RuleFor(x => x.Locale).NotEmpty().MaximumLength(16);
        RuleFor(x => x.PaymentMethodId)
            .NotEmpty()
            .When(x => x.PaymentMethodId.HasValue);
        RuleFor(x => x.PaymentMethodId)
            .Null()
            .When(x => x.PaymentMethodId.HasValue && !PremiumSubscriptionValidationRules.IsStripeProvider(x.PaymentProvider))
            .WithMessage("economy.payment_method_stripe_only");
    }
}

public sealed class CreatePremiumCheckoutCommandValidator : AbstractValidator<CreatePremiumCheckoutCommand>
{
    public CreatePremiumCheckoutCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PlanCode)
            .NotEmpty()
            .MaximumLength(40);
        RuleFor(x => x.PaymentProvider)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PremiumSubscriptionValidationRules.IsSupportedCheckoutProvider)
            .WithMessage("economy.payment_provider_unsupported_checkout");
        RuleFor(x => x.Platform).NotEmpty().MaximumLength(24);
        RuleFor(x => x.AppVersion).NotEmpty().MaximumLength(32);
        RuleFor(x => x.Country).NotEmpty().MaximumLength(16);
        RuleFor(x => x.Locale).NotEmpty().MaximumLength(16);
    }
}

public sealed class CreatePremiumBillingPortalCommandValidator : AbstractValidator<CreatePremiumBillingPortalCommand>
{
    public CreatePremiumBillingPortalCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PaymentProvider)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PremiumSubscriptionValidationRules.IsStripeProvider)
            .WithMessage("economy.payment_provider_stripe_required");
    }
}

public sealed class CancelPremiumSubscriptionCommandValidator : AbstractValidator<CancelPremiumSubscriptionCommand>
{
    public CancelPremiumSubscriptionCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PaymentProvider)
            .NotEmpty()
            .MaximumLength(24)
            .Must(value => string.Equals(value.Trim(), "stripe", StringComparison.OrdinalIgnoreCase))
            .WithMessage("economy.payment_provider_stripe_required");
    }
}

public sealed class AdminRevokePremiumSubscriptionCommandValidator : AbstractValidator<AdminRevokePremiumSubscriptionCommand>
{
    public AdminRevokePremiumSubscriptionCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PaymentProvider)
            .NotEmpty()
            .MaximumLength(24)
            .Must(value => string.Equals(value.Trim(), "stripe", StringComparison.OrdinalIgnoreCase))
            .WithMessage("economy.payment_provider_stripe_required");
        RuleFor(x => x.Reason)
            .Must(value => !string.IsNullOrWhiteSpace(value))
            .WithMessage("economy.admin_premium_revoke_reason_required")
            .MaximumLength(500);
    }
}

public sealed class AdminRefundPurchaseCommandValidator : AbstractValidator<AdminRefundPurchaseCommand>
{
    public AdminRefundPurchaseCommandValidator()
    {
        RuleFor(x => x.OrderId).NotEmpty();
        RuleFor(x => x.Reason).MaximumLength(240);
    }
}

public sealed class AdminEconomyIncidentActionCommandValidator : AbstractValidator<AdminEconomyIncidentActionCommand>
{
    private static readonly HashSet<string> AllowedActions = new(StringComparer.OrdinalIgnoreCase)
    {
        "retry_webhook_processing",
        "retry_settlement",
        "manual_settle",
        "manual_revoke",
        "manual_refund_mark",
        "manual_bonus_grant",
        "manual_wallet_correction",
        "restore_generation_charge_marker",
        "refund_generation_spend",
        "resolve_incident",
        "reopen_incident"
    };

    public AdminEconomyIncidentActionCommandValidator()
    {
        RuleFor(x => x.IncidentId).NotEmpty();
        RuleFor(x => x.Action)
            .NotEmpty()
            .MaximumLength(80)
            .Must(value => AllowedActions.Contains(value.Trim()))
            .WithMessage("economy.incident_action_unsupported");
        RuleFor(x => x.Reason)
            .NotEmpty()
            .MaximumLength(1000);
        RuleFor(x => x.ExternalReferenceId).MaximumLength(160);

        When(
            x => string.Equals(x.Action, "manual_bonus_grant", StringComparison.OrdinalIgnoreCase),
            () => RuleFor(x => x.Amount).NotNull().GreaterThan(0));

        When(
            x => string.Equals(x.Action, "manual_wallet_correction", StringComparison.OrdinalIgnoreCase)
                || string.Equals(x.Action, "manual_revoke", StringComparison.OrdinalIgnoreCase),
            () => RuleFor(x => x.Amount).NotNull().NotEqual(0));

        When(
            x => string.Equals(x.Action, "manual_refund_mark", StringComparison.OrdinalIgnoreCase),
            () => RuleFor(x => x.ExternalReferenceId)
                .NotEmpty()
                .WithMessage("economy.incident_external_reference_required"));
    }
}

public sealed class VerifyPremiumStorePurchaseCommandValidator : AbstractValidator<VerifyPremiumStorePurchaseCommand>
{
    public VerifyPremiumStorePurchaseCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PlanCode)
            .NotEmpty()
            .MaximumLength(40);
        RuleFor(x => x.PaymentProvider)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PremiumSubscriptionValidationRules.IsSupportedStoreProvider)
            .WithMessage("economy.payment_provider_unsupported_store");
        RuleFor(x => x.ProductId).NotEmpty().MaximumLength(160);
        RuleFor(x => x.ServerVerificationData).NotEmpty().MaximumLength(8192);
        RuleFor(x => x.LocalVerificationData).MaximumLength(32768);
        RuleFor(x => x.PurchaseId).MaximumLength(160);
        RuleFor(x => x.TransactionDate).MaximumLength(64);
    }
}

public sealed class VerifyPremiumStripeSubscriptionCommandValidator : AbstractValidator<VerifyPremiumStripeSubscriptionCommand>
{
    public VerifyPremiumStripeSubscriptionCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PlanCode)
            .NotEmpty()
            .MaximumLength(40);
        RuleFor(x => x.ExternalSubscriptionId)
            .NotEmpty()
            .MaximumLength(160);
    }
}

public sealed class VerifyPackStorePurchaseCommandValidator : AbstractValidator<VerifyPackStorePurchaseCommand>
{
    public VerifyPackStorePurchaseCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.OrderId).NotEmpty();
        RuleFor(x => x.PaymentProvider)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PremiumSubscriptionValidationRules.IsSupportedStoreProvider)
            .WithMessage("economy.payment_provider_unsupported_store");
        RuleFor(x => x.ProductId).NotEmpty().MaximumLength(160);
        RuleFor(x => x.ServerVerificationData).NotEmpty().MaximumLength(8192);
        RuleFor(x => x.LocalVerificationData).MaximumLength(32768);
        RuleFor(x => x.PurchaseId).MaximumLength(160);
        RuleFor(x => x.TransactionDate).MaximumLength(64);
    }
}

public sealed class ValidateGooglePlayBillingCommandValidator : AbstractValidator<ValidateGooglePlayBillingCommand>
{
    public ValidateGooglePlayBillingCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PurchaseToken).NotEmpty().MaximumLength(8192);
        RuleFor(x => x.ProductId).NotEmpty().MaximumLength(160);
        RuleFor(x => x.PackageName).NotEmpty().MaximumLength(160);
    }
}

public sealed class ValidateAppleAppStoreBillingCommandValidator : AbstractValidator<ValidateAppleAppStoreBillingCommand>
{
    public ValidateAppleAppStoreBillingCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.SignedTransactionInfo).NotEmpty().MaximumLength(32768);
    }
}

public sealed class RegisterEconomyPushTokenCommandValidator : AbstractValidator<RegisterEconomyPushTokenCommand>
{
    public RegisterEconomyPushTokenCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Token).NotEmpty().MinimumLength(20).MaximumLength(512);
        RuleFor(x => x.Platform).NotEmpty().MaximumLength(32);
        RuleFor(x => x.DeviceId).MaximumLength(160);
        RuleFor(x => x.AppVersion).MaximumLength(64);
        RuleFor(x => x.Locale).MaximumLength(32);
    }
}

public sealed class UnregisterEconomyPushTokenCommandValidator : AbstractValidator<UnregisterEconomyPushTokenCommand>
{
    public UnregisterEconomyPushTokenCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Token).NotEmpty().MinimumLength(20).MaximumLength(512);
    }
}

public sealed class CreatePaymentMethodSetupCommandValidator : AbstractValidator<CreatePaymentMethodSetupCommand>
{
    public CreatePaymentMethodSetupCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PaymentProvider)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PremiumSubscriptionValidationRules.IsStripeProvider)
            .WithMessage("economy.payment_provider_stripe_required");
    }
}

public sealed class RemovePaymentMethodCommandValidator : AbstractValidator<RemovePaymentMethodCommand>
{
    public RemovePaymentMethodCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.PaymentMethodId).NotEmpty();
    }
}

public sealed class StripeWebhookCommandValidator : AbstractValidator<StripeWebhookCommand>
{
    private const int MaxWebhookPayloadLength = 256 * 1024;
    private const int MaxStripeSignatureLength = 4096;

    public StripeWebhookCommandValidator()
    {
        RuleFor(x => x.RawBody)
            .NotEmpty()
            .MaximumLength(MaxWebhookPayloadLength);
        RuleFor(x => x.StripeSignature)
            .NotEmpty()
            .MaximumLength(MaxStripeSignatureLength);
    }
}

public sealed class AppStoreServerNotificationCommandValidator : AbstractValidator<AppStoreServerNotificationCommand>
{
    private const int MaxWebhookPayloadLength = 256 * 1024;

    public AppStoreServerNotificationCommandValidator()
    {
        RuleFor(x => x.SignedPayload)
            .NotEmpty()
            .MaximumLength(MaxWebhookPayloadLength);
    }
}

public sealed class GooglePlayDeveloperNotificationCommandValidator : AbstractValidator<GooglePlayDeveloperNotificationCommand>
{
    private const int MaxWebhookPayloadLength = 256 * 1024;

    public GooglePlayDeveloperNotificationCommandValidator()
    {
        RuleFor(x => x.MessageData)
            .NotEmpty()
            .MaximumLength(MaxWebhookPayloadLength);
        RuleFor(x => x.MessageId).MaximumLength(160);
    }
}

public sealed class UpdateCurrencyPackCommandValidator : AbstractValidator<UpdateCurrencyPackCommand>
{
    public UpdateCurrencyPackCommandValidator()
    {
        RuleFor(x => x.PackId).NotEmpty();
        RuleFor(x => x.DisplayName).NotEmpty().MaximumLength(120);
        RuleFor(x => x.PriceAmount).GreaterThan(0);
        RuleFor(x => x.GrantedSpark).GreaterThan(0);
        RuleFor(x => x.BonusSpark).GreaterThanOrEqualTo(0);
        RuleFor(x => x.SortOrder).GreaterThanOrEqualTo(0);
    }
}

public sealed class UpdateSubscriptionPlanCommandValidator : AbstractValidator<UpdateSubscriptionPlanCommand>
{
    public UpdateSubscriptionPlanCommandValidator()
    {
        RuleFor(x => x.PlanId)
            .NotEmpty()
            .MaximumLength(40)
            .Must(PremiumSubscriptionValidationRules.IsSupportedPlanCode)
            .WithMessage("economy.plan_id_invalid");
        RuleFor(x => x.Name).NotEmpty().MaximumLength(120);
        RuleFor(x => x.PriceAmount).GreaterThan(0);
        RuleFor(x => x.CurrencyCode).NotEmpty().Length(3);
        RuleFor(x => x.MonthlyTokenLimit).GreaterThan(0);
        RuleFor(x => x.AppleProductId).MaximumLength(160);
        RuleFor(x => x.GoogleProductId).MaximumLength(160);
        RuleFor(x => x.StripePriceId).MaximumLength(160);
        RuleFor(x => x.DisplayOrder).GreaterThanOrEqualTo(0);

        When(
            x => x.IsActive,
            () =>
            {
                RuleFor(x => x.StripePriceId)
                    .NotEmpty()
                    .WithMessage("economy.stripe_price_required");
                RuleFor(x => x.AppleProductId)
                    .NotEmpty()
                    .WithMessage("economy.apple_product_required");
                RuleFor(x => x.GoogleProductId)
                    .NotEmpty()
                    .WithMessage("economy.google_product_required");
            });
    }
}

internal static class PremiumSubscriptionValidationRules
{
    public static bool IsSupportedPlanCode(string value)
    {
        var planCode = value.Trim().ToLowerInvariant();
        return planCode is "monthly" or "yearly";
    }

    public static bool IsSupportedCheckoutProvider(string value)
    {
        var provider = value.Trim().ToLowerInvariant();
        return provider is "stripe" or "app_store" or "google_play";
    }

    public static bool IsSupportedStoreProvider(string value)
    {
        var provider = value.Trim().ToLowerInvariant();
        return provider is "app_store" or "google_play";
    }

    public static bool IsStripeProvider(string value)
    {
        return string.Equals(value.Trim(), "stripe", StringComparison.OrdinalIgnoreCase);
    }
}

public sealed class UpdatePaymentProviderConfigurationCommandValidator : AbstractValidator<UpdatePaymentProviderConfigurationCommand>
{
    public UpdatePaymentProviderConfigurationCommandValidator()
    {
        RuleFor(x => x.ConfigurationId).NotEmpty();
        RuleFor(x => x.Region)
            .NotEmpty()
            .MaximumLength(16)
            .Must(PaymentProviderConfigurationValidationRules.IsValidRegion)
            .WithMessage("economy.region_invalid");
        RuleFor(x => x.AllowedFromAppVersion)
            .NotEmpty()
            .MaximumLength(32)
            .Must(PaymentProviderConfigurationValidationRules.IsValidVersion)
            .WithMessage("economy.app_version_invalid");
        RuleFor(x => x.BonusTokensPercent).InclusiveBetween(0, 100);
        RuleFor(x => x.DisplayLabel).MaximumLength(80);
        RuleFor(x => x.DisplaySubtitle).MaximumLength(160);
        RuleFor(x => x.WarningTitle).MaximumLength(120);
        RuleFor(x => x.WarningMessage).MaximumLength(800);
        RuleFor(x => x.Mode)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PaymentProviderConfigurationValidationRules.IsSupportedMode)
            .WithMessage("economy.mode_invalid");
        RuleFor(x => x.Notes).MaximumLength(240);
        RuleFor(x => x).Custom((command, context) =>
            PaymentProviderConfigurationValidationRules.AddLegacyDisclosureFailures(command.WarningMessage, command.Notes, context));
    }
}

public sealed class CreatePaymentProviderConfigurationCommandValidator : AbstractValidator<CreatePaymentProviderConfigurationCommand>
{
    public CreatePaymentProviderConfigurationCommandValidator()
    {
        RuleFor(x => x.Provider)
            .NotEmpty()
            .MaximumLength(32)
            .Must(PaymentProviderConfigurationValidationRules.IsSupportedProvider)
            .WithMessage("economy.provider_invalid");

        RuleFor(x => x.Platform)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PaymentProviderConfigurationValidationRules.IsSupportedPlatform)
            .WithMessage("economy.platform_invalid");

        RuleFor(x => x.Region)
            .NotEmpty()
            .MaximumLength(16)
            .Must(PaymentProviderConfigurationValidationRules.IsValidRegion)
            .WithMessage("economy.region_invalid");

        RuleFor(x => x.AllowedFromAppVersion)
            .NotEmpty()
            .MaximumLength(32)
            .Must(PaymentProviderConfigurationValidationRules.IsValidVersion)
            .WithMessage("economy.app_version_invalid");

        RuleFor(x => x.BonusTokensPercent).InclusiveBetween(0, 100);
        RuleFor(x => x.DisplayLabel).MaximumLength(80);
        RuleFor(x => x.DisplaySubtitle).MaximumLength(160);
        RuleFor(x => x.WarningTitle).MaximumLength(120);
        RuleFor(x => x.WarningMessage).MaximumLength(800);

        RuleFor(x => x.Mode)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PaymentProviderConfigurationValidationRules.IsSupportedMode)
            .WithMessage("economy.mode_invalid");

        RuleFor(x => x.Notes).MaximumLength(240);
        RuleFor(x => x).Custom((command, context) =>
            PaymentProviderConfigurationValidationRules.AddLegacyDisclosureFailures(command.WarningMessage, command.Notes, context));
    }
}

public sealed class ClonePaymentProviderConfigurationCommandValidator : AbstractValidator<ClonePaymentProviderConfigurationCommand>
{
    public ClonePaymentProviderConfigurationCommandValidator()
    {
        RuleFor(x => x.SourceConfigurationId).NotEmpty();
        RuleFor(x => x.Region)
            .NotEmpty()
            .MaximumLength(16)
            .Must(PaymentProviderConfigurationValidationRules.IsValidRegion)
            .WithMessage("economy.region_invalid");
    }
}

public sealed class DeletePaymentProviderConfigurationCommandValidator : AbstractValidator<DeletePaymentProviderConfigurationCommand>
{
    public DeletePaymentProviderConfigurationCommandValidator()
    {
        RuleFor(x => x.ConfigurationId).NotEmpty();
    }
}

public sealed class TestPaymentProviderConfigurationMatchQueryValidator : AbstractValidator<TestPaymentProviderConfigurationMatchQuery>
{
    public TestPaymentProviderConfigurationMatchQueryValidator()
    {
        RuleFor(x => x.Provider)
            .NotEmpty()
            .MaximumLength(32)
            .Must(PaymentProviderConfigurationValidationRules.IsSupportedProvider)
            .WithMessage("economy.provider_invalid");

        RuleFor(x => x.Platform)
            .NotEmpty()
            .MaximumLength(24)
            .Must(PaymentProviderConfigurationValidationRules.IsSupportedPlatform)
            .WithMessage("economy.platform_invalid");

        RuleFor(x => x.Country)
            .NotEmpty()
            .MaximumLength(16)
            .Must(PaymentProviderConfigurationValidationRules.IsValidRegion)
            .WithMessage("economy.country_invalid");

        RuleFor(x => x.AppVersion)
            .NotEmpty()
            .MaximumLength(32)
            .Must(PaymentProviderConfigurationValidationRules.IsValidVersion)
            .WithMessage("economy.app_version_invalid");
    }
}

internal static class PaymentProviderConfigurationValidationRules
{
    private const string LegacyDisclosureValidationMessage = "economy.provider_disclosure_legacy";

    public static bool IsValidRegion(string value)
    {
        var region = value.Trim();
        if (region == "*")
        {
            return true;
        }

        if (string.Equals(region, "EU", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return region.Length == 2 && region.All(char.IsLetter);
    }

    public static bool IsSupportedMode(string value)
    {
        return string.Equals(value.Trim(), "test", StringComparison.OrdinalIgnoreCase)
            || string.Equals(value.Trim(), "live", StringComparison.OrdinalIgnoreCase);
    }

    public static bool IsSupportedProvider(string value)
    {
        var provider = value.Trim().ToLowerInvariant();
        return provider is "stripe" or "app_store" or "google_play";
    }

    public static bool IsSupportedPlatform(string value)
    {
        var platform = value.Trim().ToLowerInvariant();
        return platform is "ios" or "android" or "web" or "iphone" or "ipad";
    }

    public static bool IsValidVersion(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        var normalized = value.Trim();
        var metadataSeparator = normalized.IndexOfAny(['-', '+']);
        if (metadataSeparator >= 0)
        {
            normalized = normalized[..metadataSeparator];
        }

        return Version.TryParse(normalized, out _);
    }

    public static void AddLegacyDisclosureFailures<T>(
        string? warningMessage,
        string? notes,
        ValidationContext<T> context)
    {
        if (ContainsLegacyWarningMessage(warningMessage))
        {
            context.AddFailure("WarningMessage", LegacyDisclosureValidationMessage);
        }

        if (ContainsLegacyNotes(notes))
        {
            context.AddFailure("Notes", LegacyDisclosureValidationMessage);
        }
    }

    private static bool ContainsLegacyWarningMessage(string? warningMessage)
    {
        var warningText = warningMessage ?? string.Empty;
        return warningText.Contains("stripe checkout", StringComparison.OrdinalIgnoreCase)
            || warningText.Contains("continue to stripe", StringComparison.OrdinalIgnoreCase)
            || warningText.Contains("native payment sheet", StringComparison.OrdinalIgnoreCase)
            || warningText.Contains("native payment sheets", StringComparison.OrdinalIgnoreCase);
    }

    private static bool ContainsLegacyNotes(string? notes)
    {
        var noteText = notes ?? string.Empty;
        return noteText.Contains("external checkout", StringComparison.OrdinalIgnoreCase);
    }
}

public sealed class ApplyRedeemCodeCommandValidator : AbstractValidator<ApplyRedeemCodeCommand>
{
    public ApplyRedeemCodeCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Code).NotEmpty().MinimumLength(4).MaximumLength(48);
    }
}

public sealed class ApplyReferralCodeCommandValidator : AbstractValidator<ApplyReferralCodeCommand>
{
    public ApplyReferralCodeCommandValidator()
    {
        RuleFor(x => x.UserId).NotEmpty();
        RuleFor(x => x.Code).NotEmpty().MinimumLength(4).MaximumLength(32);
    }
}

public sealed class CreateRedeemCodeCommandValidator : AbstractValidator<CreateRedeemCodeCommand>
{
    public CreateRedeemCodeCommandValidator()
    {
        RuleFor(x => x.Code).NotEmpty().MinimumLength(4).MaximumLength(48);
        RuleFor(x => x.Description).MaximumLength(160);
        RuleFor(x => x.RewardKind)
            .NotEmpty()
            .Must(raw => RedeemCodeRewardKind.All.Contains(raw.Trim().ToLowerInvariant()));
        RuleFor(x => x.RewardValue).GreaterThan(0);
        RuleFor(x => x.MaxRedemptions).GreaterThan(0);
        RuleFor(x => x.MaxRedemptionsPerUser).GreaterThan(0);
        RuleFor(x => x.CampaignName).MaximumLength(120);
        RuleFor(x => x.CampaignChannel).MaximumLength(64);
        RuleFor(x => x.MinimumSuccessfulPurchases).GreaterThanOrEqualTo(0);
        RuleFor(x => x.CreatedBy).MaximumLength(120);
        RuleFor(x => x.ExpiresAtUtc)
            .GreaterThan(x => x.StartsAtUtc)
            .When(x => x.StartsAtUtc.HasValue && x.ExpiresAtUtc.HasValue);
    }
}

public sealed class UpdateRedeemCodeCommandValidator : AbstractValidator<UpdateRedeemCodeCommand>
{
    public UpdateRedeemCodeCommandValidator()
    {
        RuleFor(x => x.RedeemCodeId).NotEmpty();
        RuleFor(x => x.Description).MaximumLength(160);
        RuleFor(x => x.RewardKind)
            .NotEmpty()
            .Must(raw => RedeemCodeRewardKind.All.Contains(raw.Trim().ToLowerInvariant()));
        RuleFor(x => x.RewardValue).GreaterThan(0);
        RuleFor(x => x.MaxRedemptions).GreaterThan(0);
        RuleFor(x => x.MaxRedemptionsPerUser).GreaterThan(0);
        RuleFor(x => x.CampaignName).MaximumLength(120);
        RuleFor(x => x.CampaignChannel).MaximumLength(64);
        RuleFor(x => x.MinimumSuccessfulPurchases).GreaterThanOrEqualTo(0);
        RuleFor(x => x.CreatedBy).MaximumLength(120);
        RuleFor(x => x.ExpiresAtUtc)
            .GreaterThan(x => x.StartsAtUtc)
            .When(x => x.StartsAtUtc.HasValue && x.ExpiresAtUtc.HasValue);
    }
}
