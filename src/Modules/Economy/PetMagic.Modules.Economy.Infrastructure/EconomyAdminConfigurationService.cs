using System.Text.Json;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

using Npgsql;

using PetMagic.BuildingBlocks.Observability;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Application.Contracts;
using PetMagic.Modules.Economy.Infrastructure.Data;
using PetMagic.Modules.Economy.Infrastructure.Entities;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Economy.Infrastructure;

internal sealed class EconomyAdminConfigurationService(
    EconomyDbContext dbContext,
    IOptions<EconomyOptions> options,
    EconomyAdminAuditOutbox? auditOutbox = null)
{
    private const string PaymentProviderConfigurationRouteUniqueIndexName =
        "IX_economy_payment_provider_configs_Provider_Platform_Region";

    private readonly EconomyAdminAuditOutbox _auditOutbox = auditOutbox ?? new EconomyAdminAuditOutbox(dbContext);

    public async Task<Result<IReadOnlyList<AdminCurrencyPackResponse>>> ListAdminCurrencyPacksAsync(CancellationToken cancellationToken)
    {
        var packs = await dbContext.CurrencyPacks
            .AsNoTracking()
            .OrderBy(x => x.CurrencyCode)
            .ThenBy(x => x.SortOrder)
            .ThenBy(x => x.Code)
            .Select(x => new AdminCurrencyPackResponse(
                x.Id,
                x.Code ?? string.Empty,
                x.DisplayName ?? string.Empty,
                x.CurrencyCode ?? string.Empty,
                x.PriceAmount,
                x.GrantedSpark,
                x.BonusSpark,
                x.GrantedSpark + x.BonusSpark,
                x.IsActive,
                x.SortOrder))
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminCurrencyPackResponse>>(packs);
    }

    public async Task<Result<IReadOnlyList<AdminSubscriptionPlanResponse>>> ListAdminSubscriptionPlansAsync(CancellationToken cancellationToken)
    {
        var plans = await dbContext.SubscriptionPlans
            .AsNoTracking()
            .OrderBy(x => x.DisplayOrder)
            .ThenBy(x => x.Id)
            .Select(x => new AdminSubscriptionPlanResponse(
                x.Id ?? string.Empty,
                x.Name ?? string.Empty,
                x.BillingPeriod ?? string.Empty,
                x.PriceAmount,
                x.CurrencyCode ?? string.Empty,
                x.MonthlyTokenLimit,
                x.IsRecommended,
                x.IsActive,
                x.AppleProductId,
                x.GoogleProductId,
                x.StripePriceId,
                x.DisplayOrder,
                x.UpdatedAtUtc))
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminSubscriptionPlanResponse>>(plans);
    }

    public async Task<Result<IReadOnlyList<AdminPaymentProviderConfigurationResponse>>> ListAdminPaymentProviderConfigurationsAsync(CancellationToken cancellationToken)
    {
        var configs = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .OrderBy(x => x.Platform)
            .ThenBy(x => x.Provider)
            .ThenBy(x => x.Region)
            .ToListAsync(cancellationToken);

        return Result.Success<IReadOnlyList<AdminPaymentProviderConfigurationResponse>>(
            [.. configs.Select(ToAdminPaymentProviderConfigurationResponse)]);
    }

    public async Task<Result<AdminPaymentProviderConfigurationResponse>> CreatePaymentProviderConfigurationAsync(
        CreatePaymentProviderConfigurationCommand command,
        CancellationToken cancellationToken)
    {
        var provider = command.Provider.Trim().ToLowerInvariant();
        var platform = EconomyPaymentProviderPolicy.NormalizePlatform(command.Platform);
        var region = EconomyPaymentProviderPolicy.NormalizeConfigRegion(command.Region);
        var warningTitle = NullIfWhiteSpace(command.WarningTitle);
        var warningMessage = NullIfWhiteSpace(command.WarningMessage);
        var notes = NullIfWhiteSpace(command.Notes);

        if (HasLegacyPaymentProviderDisclosureText(warningMessage, notes))
        {
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderDisclosureInvalid);
        }

        var exists = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .AnyAsync(
                x => x.Provider == provider
                    && x.Platform == platform
                    && x.Region == region,
                cancellationToken);

        if (exists)
        {
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderConfigurationAlreadyExists);
        }

        var now = DateTime.UtcNow;
        var configuration = new PaymentProviderConfiguration
        {
            Id = Guid.NewGuid(),
            Provider = provider,
            Platform = platform,
            Region = region,
            IsEnabled = command.IsEnabled,
            IsRecommended = command.IsRecommended,
            IsSelectedByDefault = command.IsSelectedByDefault,
            RequiresExternalWarning = command.RequiresExternalWarning,
            RequiresStoreDisclosure = command.RequiresStoreDisclosure,
            AllowedFromAppVersion = command.AllowedFromAppVersion.Trim(),
            ExternalCheckoutAllowed = command.ExternalCheckoutAllowed,
            BonusTokensPercent = command.BonusTokensPercent,
            DisplayLabel = NullIfWhiteSpace(command.DisplayLabel),
            DisplaySubtitle = NullIfWhiteSpace(command.DisplaySubtitle),
            WarningTitle = warningTitle,
            WarningMessage = warningMessage,
            Mode = EconomyPaymentProviderPolicy.NormalizeMode(command.Mode),
            Notes = notes,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.PaymentProviderConfigurations.Add(configuration);
        var pendingAudit = _auditOutbox.Enqueue(new AdminAuditEntry(
            "admin.economy.payment_provider_configuration.created",
            "payment_provider_configuration",
            configuration.Id.ToString("D"),
            null,
            DescribePaymentProviderConfiguration(configuration),
            "Payment provider configuration created."));
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (IsPaymentProviderConfigurationRouteUniqueViolation(exception))
        {
            // A concurrent create may pass the read pre-check before another request commits.
            // Map only this exact route index to the same conflict returned by the pre-check.
            dbContext.ChangeTracker.Clear();
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderConfigurationAlreadyExists);
        }

        await _auditOutbox.TryDeliverAsync(pendingAudit, cancellationToken);

        return Result.Success(ToAdminPaymentProviderConfigurationResponse(configuration));
    }

    public async Task<Result<AdminPaymentProviderConfigurationResponse>> ClonePaymentProviderConfigurationAsync(
        ClonePaymentProviderConfigurationCommand command,
        CancellationToken cancellationToken)
    {
        var source = await dbContext.PaymentProviderConfigurations
            .FirstOrDefaultAsync(x => x.Id == command.SourceConfigurationId, cancellationToken);

        if (source is null)
        {
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderConfigurationNotFound);
        }

        var region = EconomyPaymentProviderPolicy.NormalizeConfigRegion(command.Region);
        var exists = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .AnyAsync(
                x => x.Provider == source.Provider
                    && x.Platform == source.Platform
                    && x.Region == region,
                cancellationToken);

        if (exists)
        {
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderConfigurationAlreadyExists);
        }

        var now = DateTime.UtcNow;
        var clone = new PaymentProviderConfiguration
        {
            Id = Guid.NewGuid(),
            Provider = source.Provider,
            Platform = source.Platform,
            Region = region,
            IsEnabled = source.IsEnabled,
            IsRecommended = source.IsRecommended,
            IsSelectedByDefault = source.IsSelectedByDefault,
            RequiresExternalWarning = source.RequiresExternalWarning,
            RequiresStoreDisclosure = source.RequiresStoreDisclosure,
            AllowedFromAppVersion = source.AllowedFromAppVersion,
            ExternalCheckoutAllowed = source.ExternalCheckoutAllowed,
            BonusTokensPercent = source.BonusTokensPercent,
            DisplayLabel = source.DisplayLabel,
            DisplaySubtitle = source.DisplaySubtitle,
            WarningTitle = source.WarningTitle,
            WarningMessage = source.WarningMessage,
            Mode = source.Mode,
            Notes = source.Notes,
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.PaymentProviderConfigurations.Add(clone);
        var pendingAudit = _auditOutbox.Enqueue(new AdminAuditEntry(
            "admin.economy.payment_provider_configuration.cloned",
            "payment_provider_configuration",
            clone.Id.ToString("D"),
            DescribePaymentProviderConfiguration(source),
            DescribePaymentProviderConfiguration(clone),
            $"Cloned from payment provider configuration {source.Id:D}."));
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (IsPaymentProviderConfigurationRouteUniqueViolation(exception))
        {
            // A concurrent clone/create may pass the read pre-check before another request commits.
            // Map only this exact route index to the same conflict returned by the pre-check.
            dbContext.ChangeTracker.Clear();
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderConfigurationAlreadyExists);
        }

        await _auditOutbox.TryDeliverAsync(pendingAudit, cancellationToken);

        return Result.Success(ToAdminPaymentProviderConfigurationResponse(clone));
    }

    public async Task<Result> DeletePaymentProviderConfigurationAsync(
        DeletePaymentProviderConfigurationCommand command,
        CancellationToken cancellationToken)
    {
        var configuration = await dbContext.PaymentProviderConfigurations
            .FirstOrDefaultAsync(x => x.Id == command.ConfigurationId, cancellationToken);

        if (configuration is null)
        {
            return Result.Failure(EconomyErrors.PaymentProviderConfigurationNotFound);
        }

        var oldValue = DescribePaymentProviderConfiguration(configuration);
        dbContext.PaymentProviderConfigurations.Remove(configuration);
        var pendingAudit = _auditOutbox.Enqueue(new AdminAuditEntry(
            "admin.economy.payment_provider_configuration.deleted",
            "payment_provider_configuration",
            configuration.Id.ToString("D"),
            oldValue,
            null,
            "Payment provider configuration deleted."));
        await dbContext.SaveChangesAsync(cancellationToken);

        await _auditOutbox.TryDeliverAsync(pendingAudit, cancellationToken);

        return Result.Success();
    }

    public async Task<Result<AdminPaymentProviderConfigurationMatchResponse>> TestPaymentProviderConfigurationMatchAsync(
        TestPaymentProviderConfigurationMatchQuery query,
        CancellationToken cancellationToken)
    {
        var provider = query.Provider.Trim().ToLowerInvariant();
        var platform = EconomyPaymentProviderPolicy.NormalizePlatform(query.Platform);
        var normalizedRegion = EconomyPaymentProviderPolicy.NormalizeRegion(query.Country);
        var isEuRegion = EconomyPaymentProviderPolicy.IsEuRegion(normalizedRegion);
        var appVersion = query.AppVersion.Trim();

        var configs = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .Where(x => x.IsEnabled)
            .ToListAsync(cancellationToken);

        var matchedConfiguration = EconomyPaymentProviderPolicy.SelectProviderConfig(
            configs,
            provider,
            platform,
            normalizedRegion,
            isEuRegion,
            appVersion);

        if (matchedConfiguration is null)
        {
            return Result.Success(new AdminPaymentProviderConfigurationMatchResponse(
                provider,
                platform,
                query.Country,
                normalizedRegion,
                isEuRegion,
                appVersion,
                false,
                false,
                !string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase) || IsStripeModeConfigured("test") || IsStripeModeConfigured("live"),
                "config_not_found",
                "No enabled route matched provider/platform/region/appVersion.",
                null));
        }

        var allowedByPolicy = EconomyPaymentProviderPolicy.IsProviderAllowedForCheckout(provider, platform, matchedConfiguration);
        var stripeModeConfigured = !string.Equals(provider, "stripe", StringComparison.OrdinalIgnoreCase)
            || IsStripeModeConfigured(matchedConfiguration.Mode);

        var allowedForCheckout = allowedByPolicy && stripeModeConfigured;
        var decisionCode = allowedForCheckout
            ? "allowed"
            : allowedByPolicy
                ? "stripe_key_missing"
                : "policy_blocked";

        var decisionMessage = decisionCode switch
        {
            "allowed" => "Matched and allowed for checkout.",
            "stripe_key_missing" => "Matched route requires Stripe mode key that is not configured.",
            _ => "Matched route is blocked by checkout policy (for example mobile external checkout disabled)."
        };

        return Result.Success(new AdminPaymentProviderConfigurationMatchResponse(
            provider,
            platform,
            query.Country,
            normalizedRegion,
            isEuRegion,
            appVersion,
            true,
            allowedForCheckout,
            stripeModeConfigured,
            decisionCode,
            decisionMessage,
            ToAdminPaymentProviderConfigurationResponse(matchedConfiguration)));
    }

    public async Task<Result<AdminCurrencyPackResponse>> UpdateCurrencyPackAsync(
        UpdateCurrencyPackCommand command,
        CancellationToken cancellationToken)
    {
        var pack = await dbContext.CurrencyPacks
            .FirstOrDefaultAsync(x => x.Id == command.PackId, cancellationToken);

        if (pack is null)
        {
            return Result.Failure<AdminCurrencyPackResponse>(EconomyErrors.CurrencyPackNotFound);
        }

        var oldValue = DescribeCurrencyPack(pack);
        pack.DisplayName = command.DisplayName.Trim();
        pack.PriceAmount = decimal.Round(command.PriceAmount, 2, MidpointRounding.AwayFromZero);
        pack.GrantedSpark = command.GrantedSpark;
        pack.BonusSpark = command.BonusSpark;
        pack.IsActive = command.IsActive;
        pack.SortOrder = command.SortOrder;

        var pendingAudit = _auditOutbox.Enqueue(new AdminAuditEntry(
            "admin.economy.currency_pack.updated",
            "currency_pack",
            pack.Id.ToString("D"),
            oldValue,
            DescribeCurrencyPack(pack),
            "Currency pack updated."));
        await dbContext.SaveChangesAsync(cancellationToken);

        await _auditOutbox.TryDeliverAsync(pendingAudit, cancellationToken);

        return Result.Success(ToAdminCurrencyPackResponse(pack));
    }

    public async Task<Result<AdminSubscriptionPlanResponse>> UpdateSubscriptionPlanAsync(
        UpdateSubscriptionPlanCommand command,
        CancellationToken cancellationToken)
    {
        var plan = await dbContext.SubscriptionPlans
            .FirstOrDefaultAsync(x => x.Id == command.PlanId, cancellationToken);

        if (plan is null)
        {
            return Result.Failure<AdminSubscriptionPlanResponse>(EconomyErrors.PremiumPlanNotFound);
        }

        var oldValue = DescribeSubscriptionPlan(plan);
        plan.Name = command.Name.Trim();
        plan.PriceAmount = decimal.Round(command.PriceAmount, 2, MidpointRounding.AwayFromZero);
        plan.CurrencyCode = command.CurrencyCode.Trim().ToUpperInvariant();
        plan.MonthlyTokenLimit = command.MonthlyTokenLimit;
        plan.IsRecommended = command.IsRecommended;
        plan.IsActive = command.IsActive;
        plan.AppleProductId = NullIfWhiteSpace(command.AppleProductId);
        plan.GoogleProductId = NullIfWhiteSpace(command.GoogleProductId);
        plan.StripePriceId = NullIfWhiteSpace(command.StripePriceId);
        plan.DisplayOrder = command.DisplayOrder;
        plan.UpdatedAtUtc = DateTime.UtcNow;

        var pendingAudit = _auditOutbox.Enqueue(new AdminAuditEntry(
            "admin.economy.subscription_plan.updated",
            "subscription_plan",
            plan.Id ?? string.Empty,
            oldValue,
            DescribeSubscriptionPlan(plan),
            "Subscription plan updated."));
        await dbContext.SaveChangesAsync(cancellationToken);

        await _auditOutbox.TryDeliverAsync(pendingAudit, cancellationToken);

        return Result.Success(new AdminSubscriptionPlanResponse(
            plan.Id ?? string.Empty,
            plan.Name ?? string.Empty,
            plan.BillingPeriod ?? string.Empty,
            plan.PriceAmount,
            plan.CurrencyCode ?? string.Empty,
            plan.MonthlyTokenLimit,
            plan.IsRecommended,
            plan.IsActive,
            plan.AppleProductId,
            plan.GoogleProductId,
            plan.StripePriceId,
            plan.DisplayOrder,
            plan.UpdatedAtUtc));
    }

    public async Task<Result<AdminPaymentProviderConfigurationResponse>> UpdatePaymentProviderConfigurationAsync(
        UpdatePaymentProviderConfigurationCommand command,
        CancellationToken cancellationToken)
    {
        var configuration = await dbContext.PaymentProviderConfigurations
            .FirstOrDefaultAsync(x => x.Id == command.ConfigurationId, cancellationToken);

        if (configuration is null)
        {
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderConfigurationNotFound);
        }

        var warningTitle = NullIfWhiteSpace(command.WarningTitle);
        var warningMessage = NullIfWhiteSpace(command.WarningMessage);
        var notes = NullIfWhiteSpace(command.Notes);

        if (HasLegacyPaymentProviderDisclosureText(warningMessage, notes))
        {
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderDisclosureInvalid);
        }

        var region = EconomyPaymentProviderPolicy.NormalizeConfigRegion(command.Region);
        var conflictingConfigurationExists = await dbContext.PaymentProviderConfigurations
            .AsNoTracking()
            .AnyAsync(
                x => x.Id != configuration.Id
                    && x.Provider == configuration.Provider
                    && x.Platform == configuration.Platform
                    && x.Region == region,
                cancellationToken);
        if (conflictingConfigurationExists)
        {
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderConfigurationAlreadyExists);
        }

        var oldValue = DescribePaymentProviderConfiguration(configuration);
        configuration.Region = region;
        configuration.IsEnabled = command.IsEnabled;
        configuration.IsRecommended = command.IsRecommended;
        configuration.IsSelectedByDefault = command.IsSelectedByDefault;
        configuration.RequiresExternalWarning = command.RequiresExternalWarning;
        configuration.RequiresStoreDisclosure = command.RequiresStoreDisclosure;
        configuration.AllowedFromAppVersion = command.AllowedFromAppVersion.Trim();
        configuration.ExternalCheckoutAllowed = command.ExternalCheckoutAllowed;
        configuration.BonusTokensPercent = command.BonusTokensPercent;
        configuration.DisplayLabel = NullIfWhiteSpace(command.DisplayLabel);
        configuration.DisplaySubtitle = NullIfWhiteSpace(command.DisplaySubtitle);
        configuration.WarningTitle = warningTitle;
        configuration.WarningMessage = warningMessage;
        configuration.Mode = command.Mode.Trim().ToLowerInvariant();
        configuration.Notes = notes;
        configuration.UpdatedAtUtc = DateTime.UtcNow;

        var pendingAudit = _auditOutbox.Enqueue(new AdminAuditEntry(
            "admin.economy.payment_provider_configuration.updated",
            "payment_provider_configuration",
            configuration.Id.ToString("D"),
            oldValue,
            DescribePaymentProviderConfiguration(configuration),
            "Payment provider configuration updated."));
        try
        {
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException exception) when (IsPaymentProviderConfigurationRouteUniqueViolation(exception))
        {
            // Updating a region has the same race window as create/clone.
            dbContext.ChangeTracker.Clear();
            return Result.Failure<AdminPaymentProviderConfigurationResponse>(EconomyErrors.PaymentProviderConfigurationAlreadyExists);
        }

        await _auditOutbox.TryDeliverAsync(pendingAudit, cancellationToken);

        return Result.Success(ToAdminPaymentProviderConfigurationResponse(configuration));
    }

    private bool IsStripeModeConfigured(string? mode)
    {
        return !string.IsNullOrWhiteSpace(ResolveStripeApiKey(mode));
    }

    private string? ResolveStripeApiKey(string? mode = null)
    {
        var normalizedMode = mode is null ? null : EconomyPaymentProviderPolicy.NormalizeMode(mode);
        return normalizedMode switch
        {
            "live" => FirstNonEmpty(options.Value.StripeLiveSecretKey),
            "test" => FirstNonEmpty(options.Value.StripeTestSecretKey),
            _ => FirstNonEmpty(options.Value.StripeLiveSecretKey, options.Value.StripeTestSecretKey)
        };
    }

    private static AdminCurrencyPackResponse ToAdminCurrencyPackResponse(CurrencyPack pack)
    {
        return new AdminCurrencyPackResponse(
            pack.Id,
            pack.Code ?? string.Empty,
            pack.DisplayName ?? string.Empty,
            pack.CurrencyCode ?? string.Empty,
            pack.PriceAmount,
            pack.GrantedSpark,
            pack.BonusSpark,
            pack.GrantedSpark + pack.BonusSpark,
            pack.IsActive,
            pack.SortOrder);
    }

    private static AdminPaymentProviderConfigurationResponse ToAdminPaymentProviderConfigurationResponse(PaymentProviderConfiguration configuration)
    {
        return new AdminPaymentProviderConfigurationResponse(
            configuration.Id,
            configuration.Provider ?? string.Empty,
            configuration.Platform ?? string.Empty,
            configuration.Region ?? string.Empty,
            configuration.IsEnabled,
            configuration.IsRecommended,
            configuration.IsSelectedByDefault,
            configuration.RequiresExternalWarning,
            configuration.RequiresStoreDisclosure,
            configuration.AllowedFromAppVersion ?? string.Empty,
            configuration.ExternalCheckoutAllowed,
            configuration.BonusTokensPercent,
            configuration.DisplayLabel,
            configuration.DisplaySubtitle,
            configuration.WarningTitle,
            configuration.WarningMessage,
            configuration.Mode ?? string.Empty,
            configuration.Notes,
            configuration.UpdatedAtUtc);
    }

    private static string DescribeCurrencyPack(CurrencyPack pack)
    {
        return JsonSerializer.Serialize(new
        {
            pack.Code,
            pack.DisplayName,
            pack.CurrencyCode,
            pack.PriceAmount,
            pack.GrantedSpark,
            pack.BonusSpark,
            pack.IsActive,
            pack.SortOrder,
        });
    }

    private static string DescribeSubscriptionPlan(SubscriptionPlan plan)
    {
        return JsonSerializer.Serialize(new
        {
            plan.Id,
            plan.Name,
            plan.BillingPeriod,
            plan.PriceAmount,
            plan.CurrencyCode,
            plan.MonthlyTokenLimit,
            plan.IsRecommended,
            plan.IsActive,
            AppleProductIdConfigured = !string.IsNullOrWhiteSpace(plan.AppleProductId),
            GoogleProductIdConfigured = !string.IsNullOrWhiteSpace(plan.GoogleProductId),
            StripePriceIdConfigured = !string.IsNullOrWhiteSpace(plan.StripePriceId),
            plan.DisplayOrder,
        });
    }

    private static string DescribePaymentProviderConfiguration(PaymentProviderConfiguration configuration)
    {
        return $"provider={configuration.Provider}; platform={configuration.Platform}; region={configuration.Region}; "
            + $"enabled={configuration.IsEnabled}; recommended={configuration.IsRecommended}; "
            + $"selectedByDefault={configuration.IsSelectedByDefault}; mode={configuration.Mode}; "
            + $"externalCheckoutAllowed={configuration.ExternalCheckoutAllowed}";
    }

    private static string? NullIfWhiteSpace(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim();
    }

    private static bool HasLegacyPaymentProviderDisclosureText(string? warningMessage, string? notes)
    {
        var warningText = warningMessage ?? string.Empty;
        var noteText = notes ?? string.Empty;

        return warningText.Contains("stripe checkout", StringComparison.OrdinalIgnoreCase)
            || warningText.Contains("continue to stripe", StringComparison.OrdinalIgnoreCase)
            || warningText.Contains("native payment sheet", StringComparison.OrdinalIgnoreCase)
            || warningText.Contains("native payment sheets", StringComparison.OrdinalIgnoreCase)
            || noteText.Contains("external checkout", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsPaymentProviderConfigurationRouteUniqueViolation(DbUpdateException exception)
    {
        return exception.InnerException is PostgresException
        {
            SqlState: var sqlState,
            ConstraintName: var constraintName
        }
            && IsPaymentProviderConfigurationRouteUniqueViolation(sqlState, constraintName);
    }

    internal static bool IsPaymentProviderConfigurationRouteUniqueViolation(
        string? sqlState,
        string? constraintName)
    {
        return string.Equals(sqlState, PostgresErrorCodes.UniqueViolation, StringComparison.Ordinal)
            && string.Equals(
                constraintName,
                PaymentProviderConfigurationRouteUniqueIndexName,
                StringComparison.Ordinal);
    }

    private static string? FirstNonEmpty(params string?[] candidates)
    {
        return candidates.FirstOrDefault(candidate => !string.IsNullOrWhiteSpace(candidate));
    }
}
