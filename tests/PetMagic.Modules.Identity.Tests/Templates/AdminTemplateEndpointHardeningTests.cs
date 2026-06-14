namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class AdminTemplateEndpointHardeningTests
{
    [Fact]
    public void UserGenerationHistory_ShouldUseStablePaginationOrder()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplateGenerationService.cs"));

        Assert.Contains(".OrderByDescending(x => x.CreatedAtUtc)", source, StringComparison.Ordinal);
        Assert.Contains(".ThenByDescending(x => x.Id)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void RecentGenerationsEndpoint_ShouldUseBoundedDefaultTake()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "AdminTemplateEndpoints.cs"));

        Assert.Contains("private const int RecentGenerationsDefaultTake = 25;", source, StringComparison.Ordinal);
        Assert.Contains("private const int RecentGenerationsMaxTake = 250;", source, StringComparison.Ordinal);
        Assert.Contains(
            "take.HasValue ? Math.Clamp(take.Value, 1, RecentGenerationsMaxTake) : RecentGenerationsDefaultTake",
            source,
            StringComparison.Ordinal);
        Assert.DoesNotContain("take.HasValue ? Math.Clamp(take.Value, 1, 250) : int.MaxValue", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplatesCatalog_ShouldUseStablePaginationOrder()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.AdminCatalog.cs"));

        Assert.Contains(
            "\"title\" => itemsQuery.OrderBy(x => x.Title).ThenByDescending(x => x.UpdatedAtUtc).ThenByDescending(x => x.Id)",
            source,
            StringComparison.Ordinal);
        Assert.Contains(
            "\"tokens\" => itemsQuery.OrderByDescending(x => x.TokenCost).ThenByDescending(x => x.UpdatedAtUtc).ThenByDescending(x => x.Id)",
            source,
            StringComparison.Ordinal);
        Assert.Contains(
            "_ => itemsQuery.OrderByDescending(x => x.UpdatedAtUtc).ThenByDescending(x => x.CreatedAtUtc).ThenByDescending(x => x.Id)",
            source,
            StringComparison.Ordinal);
    }

    [Fact]
    public void AdminPetsEndpoint_ShouldNotMaskServiceFailuresAsEmptyLists()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PetEndpoints.cs"));

        Assert.Contains(
            "Task<Results<Ok<IReadOnlyList<AdminPetResponse>>, ProblemHttpResult>> ListAdminPetsAsync",
            source,
            StringComparison.Ordinal);
        Assert.Contains(
            "TypedResults.Problem(title: result.Error.Code, detail: result.Error.Message, statusCode: ResolveFailureStatusCode(result.Error))",
            source,
            StringComparison.Ordinal);
        Assert.DoesNotContain("result.IsSuccess ? result.Value : []", source, StringComparison.Ordinal);
    }

    [Fact]
    public void TemplateFeedbackSummary_ShouldAggregateInDatabase()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "FeedbackService.cs"));
        var method = ExtractMethodBody(source, "GetTemplateSummaryAsync");

        Assert.Contains(".GroupBy(_ => 1)", method, StringComparison.Ordinal);
        Assert.Contains(".Select(group => new", method, StringComparison.Ordinal);
        Assert.Contains(".GroupBy(x => x.Category)", method, StringComparison.Ordinal);
        Assert.DoesNotContain(".Where(x => x.TemplateId == templateId)\n            .ToListAsync(cancellationToken)", method, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminGenerationDashboardMetrics_ShouldAggregatePeriodCountsInDatabase()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.AdminDashboard.cs"));
        var method = ExtractMethodBody(source, "GetAdminGenerationDashboardMetricsAsync");

        Assert.Contains("var periodCounts = await dbContext.TemplateGenerationJobs", method, StringComparison.Ordinal);
        Assert.Contains(".GroupBy(_ => 1)", method, StringComparison.Ordinal);
        Assert.Contains("GenerationsToday = group.Count(job => job.CreatedAtUtc >= todayStart)", method, StringComparison.Ordinal);
        Assert.Contains("FailedGenerationsThisMonth = group.Count(job => job.Status == TemplateGenerationStatus.Failed)", method, StringComparison.Ordinal);
        Assert.DoesNotContain("var jobs = await", method, StringComparison.Ordinal);
        Assert.DoesNotContain("jobs.Count(", method, StringComparison.Ordinal);
    }

    [Fact]
    public void GenerationHistoryComparePreviews_ShouldUseBatchLookup()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplateGenerationService.cs"));
        var historyMapper = ExtractMethodBody(source, "private async Task<IReadOnlyList<TemplateGenerationResponse>> MapResponsesWithQueueMetricsAsync");
        var batchLookup = ExtractMethodBody(source, "private async Task<CompareAccessContext> BuildCompareAccessContextAsync");

        Assert.Contains("var compareAccessContext = await BuildCompareAccessContextAsync(jobs, cancellationToken);", historyMapper, StringComparison.Ordinal);
        Assert.Contains("ApplyCompareAccess(", historyMapper, StringComparison.Ordinal);
        Assert.DoesNotContain("ApplyCompareAccessAsync(", historyMapper, StringComparison.Ordinal);
        Assert.Contains("inputMediaAssetIds.Contains(x.Id)", batchLookup, StringComparison.Ordinal);
        Assert.Contains("resultMediaAssetIds.Contains(x.Id)", batchLookup, StringComparison.Ordinal);
        Assert.Contains("generationIds.Contains(x.GenerationId.Value)", batchLookup, StringComparison.Ordinal);
    }

    [Fact]
    public void PetEndpoints_ShouldNotRegisterDuplicateCollectionRoutes()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PetEndpoints.cs"));

        Assert.Contains("group.MapGet(\"\", ListPetsAsync)", source, StringComparison.Ordinal);
        Assert.Contains("group.MapPost(\"\", CreatePetAsync)", source, StringComparison.Ordinal);
        Assert.Contains("adminGroup.MapGet(\"\", ListAdminPetsAsync)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("group.MapGet(\"/\", ListPetsAsync)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("group.MapPost(\"/\", CreatePetAsync)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("adminGroup.MapGet(\"/\", ListAdminPetsAsync)", source, StringComparison.Ordinal);
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

    private static string ExtractMethodBody(string source, string methodName)
    {
        var methodIndex = source.IndexOf(methodName, StringComparison.Ordinal);
        if (methodIndex < 0)
        {
            throw new InvalidOperationException($"Could not locate method {methodName}.");
        }

        var bodyStart = source.IndexOf('{', methodIndex);
        if (bodyStart < 0)
        {
            throw new InvalidOperationException($"Could not locate method body for {methodName}.");
        }

        var depth = 0;
        for (var index = bodyStart; index < source.Length; index++)
        {
            if (source[index] == '{')
            {
                depth++;
            }
            else if (source[index] == '}')
            {
                depth--;
                if (depth == 0)
                {
                    return source[bodyStart..(index + 1)];
                }
            }
        }

        throw new InvalidOperationException($"Could not parse method body for {methodName}.");
    }
}
