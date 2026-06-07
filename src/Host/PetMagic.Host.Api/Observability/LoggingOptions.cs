namespace PetMagic.Host.Api.Observability;

public sealed class LoggingOptions
{
    public const string SectionName = "LoggingOptions";

    public int SlowRequestThresholdMs { get; set; } = 1_000;
}
