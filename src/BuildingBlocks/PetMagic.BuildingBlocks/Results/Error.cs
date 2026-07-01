namespace PetMagic.BuildingBlocks.Results;

public sealed record Error(string Code, string Message, IReadOnlyDictionary<string, object?>? Metadata = null)
{
    public static readonly Error None = new(string.Empty, string.Empty);
}
