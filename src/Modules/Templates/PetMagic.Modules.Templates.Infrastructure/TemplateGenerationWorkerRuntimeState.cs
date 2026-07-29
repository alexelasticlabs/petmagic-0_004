namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationWorkerRuntimeState
{
    private long lastProgressUtcTicks;

    public DateTime? LastProgressAtUtc
    {
        get
        {
            var ticks = Interlocked.Read(ref lastProgressUtcTicks);
            return ticks <= 0 ? null : new DateTime(ticks, DateTimeKind.Utc);
        }
    }

    public void MarkProgress()
    {
        Interlocked.Exchange(ref lastProgressUtcTicks, DateTime.UtcNow.Ticks);
    }
}
