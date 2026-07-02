namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class AdminEconomyEndpointHardeningTests
{
    [Fact]
    public void AdminEconomyEndpoints_ShouldNotExposeRawErrorMessages()
    {
        var paymentProviderConfigs = ReadEndpointSource("AdminEconomyEndpoints.PaymentProviderConfigs.cs");
        var overviewAndSubscriptions = ReadEndpointSource("AdminEconomyEndpoints.OverviewAndSubscriptions.cs");
        var redeemCodes = ReadEndpointSource("AdminEconomyEndpoints.RedeemCodes.cs");
        var filters = ReadEndpointSource("AdminEconomyEndpoints.Filters.cs");

        Assert.DoesNotContain("detail: result.Error.Message", paymentProviderConfigs);
        Assert.DoesNotContain("detail: result.Error.Message", overviewAndSubscriptions);
        Assert.DoesNotContain("detail: result.Error.Message", redeemCodes);
        Assert.DoesNotContain("detail: result.Error.Message", filters);

        Assert.Contains("ToAdminEconomyProblem(result.Error", paymentProviderConfigs);
        Assert.Contains("ToAdminEconomyProblem(result.Error", overviewAndSubscriptions);
        Assert.Contains("ToAdminEconomyProblem(result.Error", redeemCodes);
        Assert.Contains("ToAdminEconomyFilterProblem(", filters);
        Assert.Contains("ToAdminEconomyProblem(\n                new Error(", redeemCodes, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminEconomyOverviewReadEndpoints_ShouldGuardServiceFailures()
    {
        var source = ReadEndpointSource("AdminEconomyEndpoints.OverviewAndSubscriptions.cs");

        Assert.Contains("Task<Results<Ok<AdminEconomyDashboardMetricsResponse>, ProblemHttpResult>> GetDashboardMetricsAsync(", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<IReadOnlyList<AdminCurrencyPackResponse>>, ProblemHttpResult>> ListPacksAsync(", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<IReadOnlyList<AdminSubscriptionPlanResponse>>, ProblemHttpResult>> ListSubscriptionPlansAsync(", source, StringComparison.Ordinal);
        Assert.DoesNotContain("GetAdminDashboardMetricsAsync(cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ListAdminCurrencyPacksAsync(cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ListAdminSubscriptionPlansAsync(cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminEconomyPaymentProviderReadEndpoints_ShouldGuardServiceFailures()
    {
        var source = ReadEndpointSource("AdminEconomyEndpoints.PaymentProviderConfigs.cs");

        Assert.Contains("Task<Results<Ok<IReadOnlyList<AdminPaymentProviderConfigurationResponse>>, ProblemHttpResult>> ListPaymentProviderConfigurationsAsync(", source, StringComparison.Ordinal);
        Assert.Contains("return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ListAdminPaymentProviderConfigurationsAsync(cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminEconomyRedeemCodeReadEndpoints_ShouldGuardServiceFailures()
    {
        var source = ReadEndpointSource("AdminEconomyEndpoints.RedeemCodes.cs");

        Assert.Contains("if (result.IsFailure)", source, StringComparison.Ordinal);
        Assert.Contains("return ToAdminEconomyProblem(result.Error, StatusCodes.Status400BadRequest);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ListAdminRedeemCodesAsync(query, cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("GetAdminRedeemCodeMetricsAsync(query, cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminEconomyProblemMapper_ShouldCoverStableAdminFailureStatuses()
    {
        var source = ReadEndpointSource("AdminEconomyEndpoints.ClientProblems.cs");

        Assert.Contains("\"economy.payment_provider_config_not_found\" => StatusCodes.Status404NotFound", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.payment_provider_config_exists\" => StatusCodes.Status409Conflict", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.redeem_code_not_found\" => StatusCodes.Status404NotFound", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.redeem_code_exists\" => StatusCodes.Status409Conflict", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.purchase_status_invalid\" => \"Query parameter status must be pending, succeeded, failed, refund_pending, refund_review, or refunded.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.subscription_status_invalid\" => \"Query parameter status is not supported for admin subscription filtering.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.subscription_event_status_invalid\" => \"Query parameter status is not supported for admin subscription event filtering.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.payment_provider_invalid\" => \"Query parameter provider must be stripe, app_store, or google_play.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.incident_category_invalid\" => \"Query parameter category is not supported for admin incident filtering.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.incident_action_invalid\" => StatusCodes.Status409Conflict", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.incident_action_reason_required\" => \"Incident action reason is required.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.redeem_code_status_invalid\" => \"Query parameter status must be all, draft, scheduled, active, paused, exhausted, expired, or archived.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.redeem_code_reward_kind_invalid\" => \"Query parameter rewardKind must be all or spark.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.redeem_code_sort_invalid\" => \"Query parameter sort must be updated, usage, reward, code, or expiry.\"", source, StringComparison.Ordinal);
        Assert.Contains("\"economy.payment_gateway_failed\" => StatusCodes.Status502BadGateway", source, StringComparison.Ordinal);
        Assert.Contains("\"Billing gateway is temporarily unavailable.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: error.Message", source);
    }

    [Fact]
    public void AdminEconomyIncidentActionEndpoints_ShouldRequireAdminReasonAndValidation()
    {
        var routesSource = ReadEndpointSource("AdminEconomyEndpoints.cs");
        var handlersSource = ReadEndpointSource("AdminEconomyEndpoints.OverviewAndSubscriptions.cs");

        Assert.Contains("group.MapGet(\"/incidents/{incidentId:guid}\", GetIncidentAsync);", routesSource, StringComparison.Ordinal);
        Assert.Contains("group.MapPost(\"/incidents/{incidentId:guid}/actions\", ApplyIncidentActionAsync)", routesSource, StringComparison.Ordinal);
        Assert.Contains(".WithMetadata(new RequestSizeLimitAttribute(MaxAdminEconomyMutationRequestBodyBytes))", routesSource, StringComparison.Ordinal);
        Assert.Contains(".RequireAuthorization(\"AdminOnly\")", routesSource, StringComparison.Ordinal);
        Assert.Contains("IValidator<AdminEconomyIncidentActionCommand> validator", handlersSource, StringComparison.Ordinal);
        Assert.Contains("request?.Reason ?? string.Empty", handlersSource, StringComparison.Ordinal);
        Assert.Contains("TypedResults.ValidationProblem(validation.ToDictionary())", handlersSource, StringComparison.Ordinal);
        Assert.Contains("Resolution note is required.", handlersSource, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminSubscriptionEventContract_ShouldNotExposeExternalSubscriptionIdentifiers()
    {
        var contractsSource = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Application",
            "Contracts",
            "AdminEconomyContracts.cs"));
        var adminServiceSource = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Admin.cs"));

        Assert.DoesNotContain("string? ExternalSubscriptionId", contractsSource, StringComparison.Ordinal);
        Assert.Contains("new AdminSubscriptionEventResponse(", adminServiceSource, StringComparison.Ordinal);
        Assert.DoesNotContain("x.ExternalEventId,\r\n                x.ExternalSubscriptionId,", adminServiceSource, StringComparison.Ordinal);
        Assert.Contains("string? ExternalEventId", contractsSource, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminDashboardMetrics_ShouldNotLoadProviderExternalIdentifiers()
    {
        var adminServiceSource = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Infrastructure",
            "EconomyService.Admin.cs"));
        var start = adminServiceSource.IndexOf("var subscriptionSnapshots = await dbContext.UserSubscriptions", StringComparison.Ordinal);
        Assert.True(start >= 0, "Admin dashboard subscription projection was not found.");
        var end = adminServiceSource.IndexOf("var activeSubscriptions = subscriptionSnapshots.Count", start, StringComparison.Ordinal);
        Assert.True(end > start, "Admin dashboard subscription projection end was not found.");
        var projection = adminServiceSource[start..end];

        Assert.Contains("Status = x.Status", projection, StringComparison.Ordinal);
        Assert.Contains("CurrentPeriodEndUtc = x.CurrentPeriodEndUtc", projection, StringComparison.Ordinal);
        Assert.Contains("CancelAtPeriodEnd = x.CancelAtPeriodEnd", projection, StringComparison.Ordinal);
        Assert.DoesNotContain("ExternalCustomerId", projection, StringComparison.Ordinal);
        Assert.DoesNotContain("ExternalSubscriptionId", projection, StringComparison.Ordinal);
        Assert.DoesNotContain("ExternalTransactionId", projection, StringComparison.Ordinal);
    }

    private static string ReadEndpointSource(string fileName)
    {
        return File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Economy",
            "PetMagic.Modules.Economy.Api",
            "Endpoints",
            fileName));
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }
}
