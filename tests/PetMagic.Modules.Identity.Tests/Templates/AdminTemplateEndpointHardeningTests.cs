namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed class AdminTemplateEndpointHardeningTests
{
    [Fact]
    public void UserGenerationHistory_ShouldUseStablePaginationOrder()
    {
        var source = ReadAllPartialFiles(
            "TemplateGenerationService",
            "PetMagic.Modules.Templates.Infrastructure");

        Assert.Contains(".OrderByDescending(x => x.CreatedAtUtc)", source, StringComparison.Ordinal);
        Assert.Contains(".ThenByDescending(x => x.Id)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void RecentGenerationsEndpoint_ShouldUseBoundedDefaultTake()
    {
        var source = ReadAllEndpointPartialFiles("AdminTemplateEndpoints");

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
    public void AdminTemplatesCatalog_ShouldGuardLegacyNullSearchFields()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.AdminCatalog.cs"));

        Assert.Contains("(x.Title ?? string.Empty).ToLower().Contains(normalizedSearch)", source, StringComparison.Ordinal);
        Assert.Contains("(x.ShortDescription ?? string.Empty).ToLower().Contains(normalizedSearch)", source, StringComparison.Ordinal);
        Assert.Contains("(x.Category ?? string.Empty).ToLower().Contains(normalizedSearch)", source, StringComparison.Ordinal);
        Assert.Contains("(x.Tags ?? string.Empty).ToLower().Contains(normalizedSearch)", source, StringComparison.Ordinal);
        Assert.Contains("(x.Category ?? string.Empty).ToLower() == normalizedCategory", source, StringComparison.Ordinal);
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
        Assert.Contains("private static ProblemHttpResult ToPetProblem(Error error)", source, StringComparison.Ordinal);
        Assert.Contains("\"templates.invalid_subject\" => StatusCodes.Status401Unauthorized", source, StringComparison.Ordinal);
        Assert.Contains("\"Authentication failed.\"", source, StringComparison.Ordinal);
        Assert.Contains("? ToPetProblem(result.Error)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Invalid access token subject.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: result.Error.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: subjectError.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain("result.IsSuccess ? result.Value : []", source, StringComparison.Ordinal);
    }

    [Fact]
    public void PetGenerationFromPetEndpoint_ShouldUseSharedPetProblemForPremiumAccessFailures()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PetEndpoints.cs"));

        Assert.Contains("\"templates.premium_required\" => StatusCodes.Status403Forbidden", source, StringComparison.Ordinal);
        Assert.Contains("\"templates.premium_required\" => \"Premium subscription is required for this template.\"", source, StringComparison.Ordinal);
        Assert.Contains("return ToPetProblem(new Error(", source, StringComparison.Ordinal);
        Assert.DoesNotContain("title: \"templates.premium_required\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Premium subscription is required for this template.\"", source, StringComparison.Ordinal);
    }

    [Fact]
    public void TemplateFeedbackSummary_ShouldAggregateInDatabase()
    {
        var source = ReadAllPartialFiles(
            "FeedbackService",
            "PetMagic.Modules.Templates.Infrastructure");
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
        var source = ReadAllPartialFiles(
            "TemplateGenerationService",
            "PetMagic.Modules.Templates.Infrastructure");
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

    [Fact]
    public void PublicTemplateEndpoints_ShouldRegisterDocumentedCollectionRoute()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PublicTemplateEndpoints.cs"));

        Assert.Contains("group.MapGet(\"\", ListAsync)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("group.MapGet(\"/\", ListAsync)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void PublicTemplateDetail_ShouldUseReadOnlyFilteredPreviewProjection()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.Public.cs"));
        var method = ExtractMethodBody(source, "GetPublicAsync");

        Assert.Contains(".AsNoTracking()", method, StringComparison.Ordinal);
        Assert.Contains("_visibilityPolicy.ApplyPublic(", method, StringComparison.Ordinal);
        Assert.Contains(".Select(x => new", method, StringComparison.Ordinal);
        Assert.Contains("asset.AssetKind == TemplateAssetKind.Preview", method, StringComparison.Ordinal);
        Assert.DoesNotContain(".Include(x => x.Assets)", method, StringComparison.Ordinal);
        Assert.DoesNotContain("FindTemplateAsync(templateId", method, StringComparison.Ordinal);
    }

    [Fact]
    public void PublicTemplateVisibility_ShouldUseCentralPolicyWithoutCategoryArchiveRules()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplateVisibilityPolicy.cs"));

        Assert.Contains("template.DeletedAtUtc == null", source, StringComparison.Ordinal);
        Assert.Contains("template.Status == TemplateStatus.Active", source, StringComparison.Ordinal);
        Assert.Contains("context.IncludeQaOnly || !template.IsQaOnly", source, StringComparison.Ordinal);
        Assert.DoesNotContain("IsArchived", source, StringComparison.Ordinal);
        Assert.DoesNotContain("TemplateCategories", source, StringComparison.Ordinal);
    }

    [Fact]
    public void TemplateVisibilityPolicyDirectCheckAllowlist_ShouldStayDocumented()
    {
        var root = FindRepositoryRoot();
        var docs = File.ReadAllText(Path.Combine(root, "docs", "API_CONTRACTS.md"));
        var allowlistedFiles = new[]
        {
            Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "TemplateCategoryAdminService.cs"),
            Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "TemplateGenerationQaFixtureService.cs"),
            Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "TemplateContentHealthCheck.cs")
        };

        Assert.Contains("Template Visibility Policy Bypass Allowlist", docs, StringComparison.Ordinal);
        foreach (var relativePath in allowlistedFiles)
        {
            var source = File.ReadAllText(Path.Combine(root, relativePath));
            Assert.Contains("TemplateVisibilityPolicy direct-check allowlist", source, StringComparison.Ordinal);
            Assert.Contains(relativePath.Replace('\\', '/'), docs, StringComparison.Ordinal);
        }
    }

    [Fact]
    public void TemplateVisibilityPolicyDirectChecks_ShouldStayWithinAllowlist()
    {
        var root = FindRepositoryRoot();
        var templatesRoot = Path.Combine(root, "src", "Modules", "Templates");
        var allowed = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            NormalizeRepoPath(Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "TemplateCategoryAdminService.cs")),
            NormalizeRepoPath(Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "TemplateGenerationQaFixtureService.cs")),
            NormalizeRepoPath(Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "TemplateContentHealthCheck.cs")),
            NormalizeRepoPath(Path.Combine("src", "Modules", "Templates", "PetMagic.Modules.Templates.Infrastructure", "TemplateVisibilityPolicy.cs"))
        };

        var violations = new List<string>();
        foreach (var file in Directory.EnumerateFiles(templatesRoot, "*.cs", SearchOption.AllDirectories))
        {
            if (file.Contains($"{Path.DirectorySeparatorChar}Migrations{Path.DirectorySeparatorChar}", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var relativePath = NormalizeRepoPath(Path.GetRelativePath(root, file));
            var lines = File.ReadAllLines(file);
            for (var index = 0; index < lines.Length; index++)
            {
                if (!ContainsActiveStatusCheck(lines[index]))
                {
                    continue;
                }

                var windowStart = Math.Max(0, index - 4);
                var windowEnd = Math.Min(lines.Length - 1, index + 4);
                var hasDeletedCheckNearby = Enumerable
                    .Range(windowStart, windowEnd - windowStart + 1)
                    .Any(lineIndex => ContainsNotDeletedCheck(lines[lineIndex]));
                if (!hasDeletedCheckNearby)
                {
                    continue;
                }

                if (!allowed.Contains(relativePath))
                {
                    violations.Add($"{relativePath}:{index + 1}");
                    continue;
                }

                var source = string.Join('\n', lines);
                if (!relativePath.EndsWith("TemplateVisibilityPolicy.cs", StringComparison.OrdinalIgnoreCase)
                    && !source.Contains("TemplateVisibilityPolicy direct-check allowlist", StringComparison.Ordinal))
                {
                    violations.Add($"{relativePath}:{index + 1} missing allowlist marker");
                }
            }
        }

        Assert.Empty(violations);
    }

    [Fact]
    public void AdminTemplateBulkOperations_ShouldStayAbsentUntilSseBatchingExists()
    {
        var root = FindRepositoryRoot();
        var endpointSource = ReadAllEndpointPartialFiles("AdminTemplateEndpoints");
        var categoryEndpointSource = File.ReadAllText(Path.Combine(
            root,
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "AdminTemplateCategoryEndpoints.cs"));
        var adminWebClientSource = File.ReadAllText(Path.Combine(
            root,
            "apps",
            "admin-web",
            "src",
            "lib",
            "api-client.templates.ts"));
        var docs = File.ReadAllText(Path.Combine(root, "docs", "API_CONTRACTS.md"));

        Assert.DoesNotContain("/bulk", endpointSource, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("/bulk", categoryEndpointSource, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("/bulk", adminWebClientSource, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("Admin Template Bulk Operations", docs, StringComparison.Ordinal);
        Assert.Contains("There is no bulk template status/update endpoint", docs, StringComparison.Ordinal);
    }

    [Fact]
    public void PublicTemplateFeed_ShouldUseStablePublishedAtCursor()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.Public.cs"));
        var method = ExtractMethodBody(source, "ListPublicFeedAsync");

        Assert.Contains(".OrderByDescending(template => template.PublishedAtUtc ?? template.CreatedAtUtc)", method, StringComparison.Ordinal);
        Assert.DoesNotContain(".ThenByDescending(template => template.Version)", method, StringComparison.Ordinal);
        Assert.DoesNotContain("template.Version < cursor.Version.Value", method, StringComparison.Ordinal);
        Assert.Contains("template.Id.CompareTo(cursor.TemplateId) < 0", method, StringComparison.Ordinal);
        Assert.Contains("ResolvePublicFeedSortAtUtc(pageItems[^1].PublishedAtUtc, pageItems[^1].CreatedAtUtc)", method, StringComparison.Ordinal);
    }

    [Fact]
    public void PublicTemplateCatalog_ShouldGuardHugePageOffsetsBeforeSkip()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.Public.cs"));
        var method = ExtractMethodBody(source, "ListPublicCatalogAsync");

        Assert.Contains("baseQuery.LongCountAsync(cancellationToken)", method, StringComparison.Ordinal);
        Assert.Contains("memoryCache.TryGetValue", method, StringComparison.Ordinal);
        Assert.Contains("var offset = ((long)page - 1) * pageSize;", method, StringComparison.Ordinal);
        Assert.Contains("if (offset > int.MaxValue)", method, StringComparison.Ordinal);
        Assert.Contains(".Skip((int)offset)", method, StringComparison.Ordinal);
        Assert.DoesNotContain(".Skip((page - 1) * pageSize)", method, StringComparison.Ordinal);
    }

    [Fact]
    public void PublicTemplateCatalog_ShouldUseExtraRowForHasMore()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.Public.cs"));
        var method = ExtractMethodBody(source, "ListPublicCatalogAsync");

        Assert.Contains(".Take(pageSize + 1)", method, StringComparison.Ordinal);
        Assert.Contains("var pageItems = filtered.Take(pageSize).ToArray();", method, StringComparison.Ordinal);
        Assert.Contains("var hasMore = filtered.Length > pageSize;", method, StringComparison.Ordinal);
        Assert.DoesNotContain(".Take(pageSize)\n            .Select(template => new", method, StringComparison.Ordinal);
        Assert.DoesNotContain("var hasMore = totalCount > offset + pageItems.Length;", method, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateCategoryEndpoints_ShouldUseSanitizedProblemDetails()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "AdminTemplateCategoryEndpoints.cs"));

        Assert.Contains("private static ProblemHttpResult ToCategoryProblem(string errorCode)", source, StringComparison.Ordinal);
        Assert.Contains("detail: GetCategoryProblemDetail(errorCode)", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<AdminTemplateCategoryDiagnosticsResponse>, ProblemHttpResult>> DiagnosticsAsync(", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<IReadOnlyList<AdminTemplateCategoryListItemResponse>>, ProblemHttpResult>> ListAsync(", source, StringComparison.Ordinal);
        Assert.Equal(6, CountOccurrences(source, "if (result.IsFailure)"));
        Assert.DoesNotContain("detail: result.Error.Message", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateEndpoints_ShouldUseSanitizedProblemDetails()
    {
        var source = ReadAllEndpointPartialFiles("AdminTemplateEndpoints");

        Assert.Contains("private static ProblemHttpResult ToAdminTemplateProblem(Error error)", source, StringComparison.Ordinal);
        Assert.Contains("\"templates.invalid_subject\" => StatusCodes.Status401Unauthorized", source, StringComparison.Ordinal);
        Assert.Contains("\"templates.invalid_subject\" => \"Authentication failed.\"", source, StringComparison.Ordinal);
        Assert.Contains("detail: GetAdminTemplateProblemDetail(error.Code, statusCode)", source, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(result.Error);", source, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(storeResult.Error);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Invalid access token subject.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: result.Error.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: error.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: storeResult.Error.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: durationResult.Error.Message", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateCatalogFilters_ShouldUseCentralizedValidationProblems()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "AdminTemplateEndpoints.Catalog.cs"));

        Assert.Contains("return InvalidCatalogFilterProblem(\"templates.invalid_type\");", source, StringComparison.Ordinal);
        Assert.Contains("return InvalidCatalogFilterProblem(\"templates.invalid_status\");", source, StringComparison.Ordinal);
        Assert.Contains("return InvalidCatalogFilterProblem(\"templates.invalid_access\");", source, StringComparison.Ordinal);
        Assert.Contains("return InvalidCatalogFilterProblem(\"templates.invalid_sort\");", source, StringComparison.Ordinal);
        Assert.Contains("private static ProblemHttpResult InvalidCatalogFilterProblem(string errorCode)", source, StringComparison.Ordinal);
        Assert.Contains("private static string GetCatalogFilterProblemDetail(string errorCode)", source, StringComparison.Ordinal);
        Assert.Contains("private static ProblemHttpResult InvalidGenerationStatusFilterProblem()", source, StringComparison.Ordinal);
        Assert.DoesNotContain("title: \"templates.invalid_type\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("title: \"templates.invalid_access\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("title: \"templates.invalid_sort\"", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateCatalogEndpoints_ShouldGuardServiceFailures()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "AdminTemplateEndpoints.Catalog.cs"));

        Assert.Contains("Task<Results<Ok<AdminTemplateCatalogPageResponse>, ProblemHttpResult>> ListAsync(", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<AdminTemplatesAnalyticsOverviewResponse>, ProblemHttpResult>> GetAnalyticsOverviewAsync(", source, StringComparison.Ordinal);

        var listMethod = ExtractMethodBody(source, "ListAsync");
        var analyticsMethod = ExtractMethodBody(source, "GetAnalyticsOverviewAsync");

        Assert.Contains("if (result.IsFailure)", listMethod, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(result.Error);", listMethod, StringComparison.Ordinal);
        Assert.Contains("if (result.IsFailure)", analyticsMethod, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(result.Error);", analyticsMethod, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateActions_ShouldRejectInvalidAdminSubject()
    {
        var source = ReadAllEndpointPartialFiles("AdminTemplateEndpoints");

        Assert.Contains("private static (Guid UserId, Error? Error) TryGetAdminUserId(HttpContext context)", source, StringComparison.Ordinal);
        Assert.Contains("var (adminUserId, subjectError) = TryGetAdminUserId(httpContext);", source, StringComparison.Ordinal);
        Assert.Contains("var (adminUserId, subjectError) = TryGetAdminUserId(context);", source, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(subjectError);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ResolveAdminUserId(context) ?? Guid.Empty", source, StringComparison.Ordinal);
        Assert.DoesNotContain("private static Guid? ResolveAdminUserId(HttpContext httpContext)", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateOfTheDayEndpoints_ShouldGuardServiceFailures()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "AdminTemplateEndpoints.TemplateOfDay.cs"));

        Assert.Contains("Task<Results<Ok<AdminTemplateOfTheDayScheduleResponse>, ProblemHttpResult>> ListTemplateOfTheDayScheduleAsync(", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<AdminTemplateOfTheDayResponse?>, ProblemHttpResult>> GetCurrentTemplateOfTheDayAsync(", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<AdminTemplateOfTheDaySettingsResponse>, ProblemHttpResult>> GetTemplateOfTheDaySettingsAsync(", source, StringComparison.Ordinal);
        Assert.Equal(4, CountOccurrences(source, "if (result.IsFailure)"));
        Assert.DoesNotContain("ListAdminTemplateOfTheDayScheduleAsync(skip, take, cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("GetAdminCurrentTemplateOfTheDayAsync(date, cancellationToken);\r\n        AdminTemplateOfTheDayResponse? value = result.Value;", source, StringComparison.Ordinal);
        Assert.DoesNotContain("GetAdminTemplateOfTheDaySettingsAsync(cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateGenerationAdminEndpoints_ShouldGuardServiceFailures()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "AdminTemplateEndpoints.Generations.cs"));

        Assert.Contains("Task<Results<Ok<AdminTemplateGenerationDashboardMetricsResponse>, ProblemHttpResult>> GetGenerationDashboardMetricsAsync(", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<AdminModerationQueuePageResponse>, ProblemHttpResult>> GetModerationQueueAsync(", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<AdminWatermarkSettingsResponse>, ProblemHttpResult>> GetWatermarkSettingsAsync(", source, StringComparison.Ordinal);
        Assert.Contains("Task<Results<Ok<AdminWatermarkSettingsResponse>, ProblemHttpResult>> UpdateWatermarkSettingsAsync(", source, StringComparison.Ordinal);

        var dashboardMethod = ExtractMethodBody(source, "GetGenerationDashboardMetricsAsync");
        var queueMethod = ExtractMethodBody(source, "GetModerationQueueAsync");
        var listMethod = ExtractMethodBody(source, "ListGenerationsAsync");
        var watermarkMethod = ExtractMethodBody(source, "GetWatermarkSettingsAsync");
        var updateWatermarkMethod = ExtractMethodBody(source, "UpdateWatermarkSettingsAsync");

        Assert.Contains("if (result.IsFailure)", dashboardMethod, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(result.Error);", dashboardMethod, StringComparison.Ordinal);
        Assert.Contains("if (result.IsFailure)", queueMethod, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(result.Error);", queueMethod, StringComparison.Ordinal);
        Assert.Contains("if (result.IsFailure)", listMethod, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(result.Error);", listMethod, StringComparison.Ordinal);
        Assert.Contains("if (result.IsFailure)", watermarkMethod, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(result.Error);", watermarkMethod, StringComparison.Ordinal);
        Assert.Contains("if (result.IsFailure)", updateWatermarkMethod, StringComparison.Ordinal);
        Assert.Contains("return ToAdminTemplateProblem(result.Error);", updateWatermarkMethod, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateGenerationTestReadEndpoint_ShouldNotContainDuplicateFailureGuards()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "AdminTemplateEndpoints.Generations.cs"));
        var method = ExtractMethodBody(source, "GetAdminTestAsync");

        Assert.Equal(1, CountOccurrences(method, "if (result.IsFailure)"));
        Assert.Equal(1, CountOccurrences(method, "return ToAdminTemplateProblem(result.Error);"));
        Assert.Contains("return TypedResults.Ok(result.Value);", method, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminModerationQueue_ShouldGuardLegacyNullTemplateTitleSearch()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.AdminModeration.cs"));

        Assert.Contains("(analyticsEvent.Template.Title ?? string.Empty).ToLower().Contains(search)", source, StringComparison.Ordinal);
        Assert.Contains("analyticsEvent.Template.Title ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("analyticsEvent.EventType ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("analyticsEvent.ModerationStatus ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("analyticsEvent.Source ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("analyticsEvent.DeviceClass ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("analyticsEvent.CountryCode ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateFeedback_ShouldGuardLegacyNullSearchAndResponseFields()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplateAdminAnalyticsService.Events.cs"));

        Assert.Contains("(x.FeedbackMessage ?? string.Empty).ToLower().Contains(search)", source, StringComparison.Ordinal);
        Assert.Contains("x.EventType ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.Source ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.DeviceClass ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("x.CountryCode ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminTemplateGenerations_ShouldGuardLegacyNullProviderAndTemplateTitles()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.AdminDashboard.cs"));

        Assert.Contains("(job.UsedPreprocessingModel ?? string.Empty).ToLower().Contains(provider)", source, StringComparison.Ordinal);
        Assert.Contains("(job.UsedKlingModel ?? string.Empty).ToLower().Contains(provider)", source, StringComparison.Ordinal);
        Assert.Contains("job.Template.Title ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("parent.Template.Title ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void TemplateOfTheDayQueriesAndMappers_ShouldGuardLegacyNullPreviewAndTextFields()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplatesService.TemplateOfTheDay.cs"));

        Assert.Equal(3, CountOccurrences(source, "(asset.Url ?? string.Empty).Trim() != string.Empty"));
        Assert.Contains("assignment.Template.Title ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("assignment.Template.ShortDescription ?? string.Empty", source, StringComparison.Ordinal);
        Assert.Contains("assignment.Template.Category ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void TemplateCategoryMapper_ShouldGuardLegacyNullCategoryName()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Infrastructure",
            "TemplateCategoryAdminService.cs"));

        Assert.Contains("category.Name ?? string.Empty", source, StringComparison.Ordinal);
    }

    [Fact]
    public void PublicTemplateEvents_ShouldTreatClientDisconnectsAsNormalCompletion()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PublicTemplateEndpoints.cs"));
        var method = ExtractMethodBody(source, "private static async Task StreamEventsAsync");

        Assert.Contains("catch (OperationCanceledException) when", method, StringComparison.Ordinal);
        Assert.Contains("catch (System.IO.IOException) when", method, StringComparison.Ordinal);
        Assert.Contains("httpContext.RequestAborted.IsCancellationRequested", method, StringComparison.Ordinal);
    }

    [Fact]
    public void PublicTemplateEvents_ShouldFilterToCatalogInvalidationTopic()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Templates",
            "PetMagic.Modules.Templates.Api",
            "Endpoints",
            "PublicTemplateEndpoints.cs"));
        var method = ExtractMethodBody(source, "private static async Task StreamEventsAsync");

        Assert.Contains("AllowedPublicRealtimeTopics", source, StringComparison.Ordinal);
        Assert.Contains("TemplateFeedRealtimeTopics.TemplatesFeedInvalidated", source, StringComparison.Ordinal);
        Assert.Contains("if (!IsPublicRealtimeTopic(realtimeEvent.Topic))", method, StringComparison.Ordinal);
        Assert.DoesNotContain("GenerationStatusChanged", method, StringComparison.Ordinal);
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

    private static string ReadAllPartialFiles(string baseFileName, string namespacePath)
    {
        var root = FindRepositoryRoot();
        var dir = Path.Combine(root, "src", "Modules", "Templates", namespacePath);
        var files = Directory.GetFiles(dir, $"{baseFileName}*.cs");
        return string.Join("\n", files.Select(File.ReadAllText));
    }

    private static string ReadAllEndpointPartialFiles(string baseFileName)
    {
        return ReadAllPartialFiles(
            baseFileName,
            Path.Combine("PetMagic.Modules.Templates.Api", "Endpoints"));
    }

    private static string NormalizeRepoPath(string path)
    {
        return path.Replace('\\', '/');
    }

    private static bool ContainsActiveStatusCheck(string line)
    {
        return line.Contains("Status == TemplateStatus.Active", StringComparison.Ordinal)
            || line.Contains("TemplateStatus.Active == ", StringComparison.Ordinal);
    }

    private static bool ContainsNotDeletedCheck(string line)
    {
        return line.Contains("DeletedAtUtc == null", StringComparison.Ordinal)
            || line.Contains("DeletedAtUtc is null", StringComparison.Ordinal);
    }

    private static int CountOccurrences(string source, string value)
    {
        var count = 0;
        var index = 0;

        while ((index = source.IndexOf(value, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += value.Length;
        }

        return count;
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
