namespace PetMagic.BuildingBlocks.BackgroundWorkers;

public sealed class AdaptiveIdlePollBackoff
{
    private static readonly TimeSpan DefaultInitialDelay = TimeSpan.FromSeconds(1);
    private static readonly TimeSpan DefaultMaximumDelay = TimeSpan.FromSeconds(5);

    private readonly long initialDelayTicks;
    private readonly long maximumDelayTicks;
    private long nextDelayTicks;

    public AdaptiveIdlePollBackoff()
        : this(DefaultInitialDelay, DefaultMaximumDelay)
    {
    }

    public AdaptiveIdlePollBackoff(TimeSpan initialDelay, TimeSpan maximumDelay)
    {
        if (initialDelay <= TimeSpan.Zero)
        {
            throw new ArgumentOutOfRangeException(nameof(initialDelay), "The initial idle delay must be positive.");
        }

        if (maximumDelay < initialDelay)
        {
            throw new ArgumentOutOfRangeException(
                nameof(maximumDelay),
                "The maximum idle delay must be greater than or equal to the initial delay.");
        }

        initialDelayTicks = initialDelay.Ticks;
        maximumDelayTicks = maximumDelay.Ticks;
        nextDelayTicks = initialDelayTicks;
    }

    public TimeSpan GetNextDelay()
    {
        while (true)
        {
            var observedDelayTicks = Volatile.Read(ref nextDelayTicks);
            var followingDelayTicks = observedDelayTicks >= maximumDelayTicks / 2
                ? maximumDelayTicks
                : observedDelayTicks * 2;

            if (Interlocked.CompareExchange(
                    ref nextDelayTicks,
                    followingDelayTicks,
                    observedDelayTicks) == observedDelayTicks)
            {
                return TimeSpan.FromTicks(observedDelayTicks);
            }
        }
    }

    public Task DelayAsync(CancellationToken cancellationToken) =>
        Task.Delay(GetNextDelay(), cancellationToken);

    public void Reset() => Volatile.Write(ref nextDelayTicks, initialDelayTicks);
}
