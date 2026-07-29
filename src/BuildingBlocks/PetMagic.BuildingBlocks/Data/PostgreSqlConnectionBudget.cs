using Npgsql;

namespace PetMagic.BuildingBlocks.Data;

public sealed record PostgreSqlConnectionBudget(
    int HostMaxPoolSize,
    int PeerMaxPoolSize,
    int OperationalReserveConnections)
{
    public const int AcceptanceConnectionLimitExclusive = 70;
    public const int ApiDefaultMaxPoolSize = 28;
    public const int GenerationWorkerDefaultMaxPoolSize = 24;
    public const int DefaultOperationalReserveConnections = 16;

    public int PlannedAggregateConnections =>
        HostMaxPoolSize + PeerMaxPoolSize + OperationalReserveConnections;

    public void Validate(string componentName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(componentName);
        if (HostMaxPoolSize <= 0 || PeerMaxPoolSize <= 0 || OperationalReserveConnections <= 0)
        {
            throw new InvalidOperationException(
                $"{componentName} PostgreSQL pool sizes and operational reserve must be positive.");
        }

        if (PlannedAggregateConnections >= AcceptanceConnectionLimitExclusive)
        {
            throw new InvalidOperationException(
                $"{componentName} PostgreSQL connection budget must remain below "
                + $"{AcceptanceConnectionLimitExclusive}. Configured aggregate is "
                + $"{PlannedAggregateConnections} (host={HostMaxPoolSize}, peer={PeerMaxPoolSize}, "
                + $"reserve={OperationalReserveConnections}).");
        }
    }

    public NpgsqlDataSource CreateDataSource(string connectionString, string applicationName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(connectionString);
        ArgumentException.ThrowIfNullOrWhiteSpace(applicationName);
        Validate(applicationName);

        var builder = new NpgsqlConnectionStringBuilder(connectionString)
        {
            Pooling = true,
            MinPoolSize = 0,
            MaxPoolSize = HostMaxPoolSize,
            ApplicationName = applicationName
        };
        return NpgsqlDataSource.Create(builder.ConnectionString);
    }
}
