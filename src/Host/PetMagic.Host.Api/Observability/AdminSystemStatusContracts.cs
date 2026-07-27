namespace PetMagic.Host.Api.Observability;

public sealed record AdminSystemStatusResponse(
    string OverallStatus,
    DateTimeOffset GeneratedAtUtc,
    int StaleAfterSeconds,
    IReadOnlyList<AdminSystemStatusCheckResponse> Checks);

public sealed record AdminSystemStatusCheckResponse(
    string Key,
    string Status,
    string Summary,
    DateTimeOffset CheckedAtUtc);
