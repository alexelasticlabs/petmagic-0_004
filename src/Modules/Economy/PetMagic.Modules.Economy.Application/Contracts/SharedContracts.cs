namespace PetMagic.Modules.Economy.Application.Contracts;

public sealed record OffsetPagedResponse<T>(
    IReadOnlyList<T> Items,
    int Skip,
    int Take,
    bool HasMore);
