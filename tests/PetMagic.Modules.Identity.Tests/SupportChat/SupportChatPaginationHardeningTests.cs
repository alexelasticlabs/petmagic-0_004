namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatPaginationHardeningTests
{
    [Fact]
    public void AdminInbox_ShouldUseStablePaginationOrder()
    {
        var source = ReadSupportChatInfrastructureSource("SupportChatService.AdminInbox.cs");

        Assert.Contains("var orderedConversationsQuery = normalizedSort switch", source, StringComparison.Ordinal);
        Assert.Contains("\"priority\" => conversationsQuery", source, StringComparison.Ordinal);
        Assert.Contains("\"waiting\" => conversationsQuery", source, StringComparison.Ordinal);
        Assert.Contains(".ThenByDescending(x => x.Id)", source, StringComparison.Ordinal);
        Assert.Contains("var totalCount = await conversationsQuery.LongCountAsync(cancellationToken);", source, StringComparison.Ordinal);
        Assert.Contains("var boundedTotalCount = totalCount > int.MaxValue ? int.MaxValue : (int)totalCount;", source, StringComparison.Ordinal);
        Assert.Contains("var offset = ((long)page - 1L) * pageSize;", source, StringComparison.Ordinal);
        Assert.Contains("offset >= totalCount || offset > int.MaxValue", source, StringComparison.Ordinal);
        Assert.Contains("orderedConversationsQuery\n            .Skip((int)offset)", source, StringComparison.Ordinal);
        Assert.Contains("offset + summaries.Count < totalCount", source, StringComparison.Ordinal);
        Assert.DoesNotContain(".Skip((page - 1) * pageSize)", source, StringComparison.Ordinal);
        Assert.Contains(
            ".OrderByDescending(message => message.CreatedAtUtc)\n                    .ThenByDescending(message => message.Id)",
            source,
            StringComparison.Ordinal);
    }

    [Fact]
    public void AdminInbox_ShouldKeepMultiStatusAndFieldSpecificFilterErrors()
    {
        var source = ReadSupportChatInfrastructureSources(
            "SupportChatService.AdminInbox.cs",
            "SupportChatService.cs");

        Assert.Contains("query.Statuses is { Count: > 0 }", source, StringComparison.Ordinal);
        Assert.Contains("requestedStatuses.Add(ToCanonicalStatus(status));", source, StringComparison.Ordinal);
        Assert.Contains("support.source_invalid", source, StringComparison.Ordinal);
        Assert.Contains("support.priority_invalid", source, StringComparison.Ordinal);
        Assert.Contains("support.sort_invalid", source, StringComparison.Ordinal);
        Assert.Contains("support.queue_invalid", source, StringComparison.Ordinal);
        Assert.Contains("normalizedQueue == \"waiting_for_support\"", source, StringComparison.Ordinal);
        Assert.Contains("x.Status == SupportConversationStatus.New\n                || x.Status == SupportConversationStatus.InProgress", source, StringComparison.Ordinal);
    }

    [Fact]
    public void AdminInbox_ShouldRejectInvalidSortBeforeCountingRows()
    {
        var source = ReadSupportChatInfrastructureSource("SupportChatService.AdminInbox.cs");

        var sortValidationIndex = source.IndexOf(
            "if (normalizedSort is not (null or \"\" or \"default\" or \"priority\" or \"waiting\" or \"updated\" or \"created\"))",
            StringComparison.Ordinal);
        var countIndex = source.IndexOf(
            "var totalCount = await conversationsQuery.LongCountAsync(cancellationToken);",
            StringComparison.Ordinal);

        Assert.True(sortValidationIndex >= 0, "Support inbox sort validation was not found.");
        Assert.True(countIndex >= 0, "Support inbox count query was not found.");
        Assert.True(
            sortValidationIndex < countIndex,
            "Support inbox must reject invalid sort values before running the count query.");
    }

    [Fact]
    public void ConversationMessages_ShouldUseStablePaginationOrder()
    {
        var source = ReadSupportChatInfrastructureSource("SupportChatService.ConversationDetailBuilder.cs");

        Assert.Contains(
            ".OrderByDescending(x => x.CreatedAtUtc)\n            .ThenByDescending(x => x.Id)\n            .Take(normalizedTake + 1)",
            source,
            StringComparison.Ordinal);
        Assert.Contains("Guid? BeforeMessageId = null", File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Application",
            "Contracts",
            "SupportChatContracts.cs")), StringComparison.Ordinal);
        Assert.Contains(".Take(normalizedTake + 1)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("ConversationMessages.AnyAsync", source, StringComparison.Ordinal);
    }

    [Fact]
    public void ConversationEndpoints_ShouldClampUntrustedPaginationQueries()
    {
        var source = ReadSupportChatApiSources(
            "SupportChatEndpoints.AdminConversationAccess.cs",
            "SupportChatEndpoints.UserConversationAccess.cs");

        Assert.Contains("private const int MaxConversationMessagesTake = 120;", source, StringComparison.Ordinal);
        Assert.Contains("private const int MaxAdminInboxPageSize = 100;", source, StringComparison.Ordinal);
        Assert.Contains("var requestedPageSize = NormalizeAdminInboxPageSize(pageSize);", source, StringComparison.Ordinal);
        Assert.Equal(2, CountOccurrences(source, "Take: NormalizeConversationMessagesTake(take)"));
        Assert.Contains("Math.Clamp(take ?? DefaultConversationMessagesTake, 1, MaxConversationMessagesTake)", source, StringComparison.Ordinal);
        Assert.Contains("Math.Clamp(pageSize ?? DefaultAdminInboxPageSize, 1, MaxAdminInboxPageSize)", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Take: take ?? 60", source, StringComparison.Ordinal);
        Assert.DoesNotContain("pageSize is null or <= 0 ? 50 : pageSize.Value", source, StringComparison.Ordinal);
    }

    [Fact]
    public void MessageHotPaths_ShouldAvoidLoadingWholeConversationHistoryForHotActions()
    {
        var source = ReadSupportChatInfrastructureSources(
            "SupportChatService.MessageSending.cs",
            "SupportChatService.MessageReadTracking.cs",
            "SupportChatService.ConversationDetailBuilder.cs");

        Assert.DoesNotContain(".Include(x => x.Messages)", source, StringComparison.Ordinal);
        Assert.Contains("supportChatDbContext.ConversationMessages\n            .AsNoTracking()\n            .AnyAsync(", source, StringComparison.Ordinal);
        Assert.Contains("var unreadMessages = await supportChatDbContext.ConversationMessages", source, StringComparison.Ordinal);
        Assert.Contains("message.ReadAtUtc == null", source, StringComparison.Ordinal);
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

    private static string ReadSupportChatInfrastructureSource(string fileName)
    {
        return File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Infrastructure",
            fileName));
    }

    private static string ReadSupportChatInfrastructureSources(params string[] fileNames)
    {
        return string.Join(
            "\n",
            fileNames.Select(ReadSupportChatInfrastructureSource));
    }

    private static string ReadSupportChatApiSource(string fileName)
    {
        return File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Api",
            "Endpoints",
            fileName));
    }

    private static string ReadSupportChatApiSources(params string[] fileNames)
    {
        return string.Join(
            "\n",
            fileNames.Select(ReadSupportChatApiSource));
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
}
