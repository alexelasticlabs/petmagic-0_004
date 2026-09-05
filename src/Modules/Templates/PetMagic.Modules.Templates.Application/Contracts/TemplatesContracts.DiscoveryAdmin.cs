namespace PetMagic.Modules.Templates.Application.Contracts;

public sealed record DiscoveryCopy(string Title, string Subtitle);

public sealed record DiscoverySection(
    Guid Id,
    Guid CategoryId,
    bool IsEnabled,
    bool ShowInCarousel,
    bool ShowAsRail,
    Guid? HeroTemplateId,
    string SelectionMode,
    int ItemLimit,
    IReadOnlyList<Guid> TemplateIds,
    IReadOnlyDictionary<string, DiscoveryCopy> Copy);

/// <summary>A bounded, versioned editorial document; positions are array order.</summary>
public sealed record DiscoveryDocument(
    int SchemaVersion,
    IReadOnlyDictionary<string, DiscoveryCopy> Copy,
    bool SearchEnabled,
    bool CarouselEnabled,
    bool AutoplayEnabled,
    int AutoplayIntervalMs,
    IReadOnlyList<DiscoverySection> Sections);

public sealed record DiscoveryRevisionResponse(
    Guid Id, long Number, long EditVersion, string State,
    DiscoveryDocument Document, Guid? BasedOnRevisionId,
    DateTime CreatedAtUtc, DateTime UpdatedAtUtc, DateTime? PublishedAtUtc,
    Guid CreatedBy, Guid UpdatedBy, Guid? PublishedBy, string? Reason);

public sealed record DiscoveryAdminResponse(
    long PageVersion, DiscoveryRevisionResponse? Published, DiscoveryRevisionResponse? Draft);

public sealed record DiscoveryRevisionSummary(
    Guid Id, long Number, string State, DateTime UpdatedAtUtc,
    DateTime? PublishedAtUtc, Guid UpdatedBy, string? Reason);

public sealed record DiscoveryHistoryResponse(IReadOnlyList<DiscoveryRevisionSummary> Items, bool HasMore);
public sealed record DiscoveryValidationIssue(string Path, string Code, string Message);
public sealed record DiscoveryValidationResponse(IReadOnlyList<DiscoveryValidationIssue> Issues)
{
    public bool IsValid => Issues.Count == 0;
}

public sealed record CreateDiscoveryDraftRequest(long ExpectedPageVersion, Guid? SourceRevisionId = null);
public sealed record SaveDiscoveryDraftRequest(long ExpectedVersion, DiscoveryDocument Document);
public sealed record PublishDiscoveryRequest(long ExpectedVersion, long ExpectedPageVersion, string Reason);
public sealed record DiscardDiscoveryDraftRequest(long ExpectedVersion, long ExpectedPageVersion);

public sealed record PublicDiscoveryPageSettings(
    string Title, string Subtitle, bool SearchEnabled, bool CarouselEnabled,
    bool AutoplayEnabled, int AutoplayIntervalMs);
