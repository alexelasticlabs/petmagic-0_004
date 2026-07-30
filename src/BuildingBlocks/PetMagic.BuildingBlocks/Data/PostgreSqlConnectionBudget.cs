using Npgsql;

namespace PetMagic.BuildingBlocks.Data;

public sealed record PostgreSqlConnectionBudget(
    int HostMaxPoolSize,
    int PeerMaxPoolSize,
    int OperationalReserveConnections)
{
    private const int DefaultPostgreSqlPort = 5432;

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

        var builder = CreateConnectionStringBuilder(connectionString);
        builder.Pooling = true;
        builder.MinPoolSize = 0;
        builder.MaxPoolSize = HostMaxPoolSize;
        builder.ApplicationName = applicationName;
        return NpgsqlDataSource.Create(builder.ConnectionString);
    }

    private static NpgsqlConnectionStringBuilder CreateConnectionStringBuilder(string connectionString)
    {
        if (!connectionString.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase)
            && !connectionString.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
        {
            return new NpgsqlConnectionStringBuilder(connectionString);
        }

        if (!Uri.TryCreate(connectionString, UriKind.Absolute, out var uri)
            || (uri.Scheme != "postgres" && uri.Scheme != "postgresql")
            || string.IsNullOrWhiteSpace(uri.Host)
            || !string.IsNullOrEmpty(uri.Fragment))
        {
            throw new ArgumentException("PostgreSQL connection URI is invalid.", nameof(connectionString));
        }

        var escapedUserInfo = uri.GetComponents(UriComponents.UserInfo, UriFormat.UriEscaped);
        var passwordSeparator = escapedUserInfo.IndexOf(':');
        var escapedUsername = passwordSeparator >= 0
            ? escapedUserInfo[..passwordSeparator]
            : escapedUserInfo;
        if (string.IsNullOrWhiteSpace(escapedUsername))
        {
            throw new ArgumentException(
                "PostgreSQL connection URI must include a username.",
                nameof(connectionString));
        }

        var escapedDatabase = uri.GetComponents(UriComponents.Path, UriFormat.UriEscaped);
        if (string.IsNullOrWhiteSpace(escapedDatabase))
        {
            throw new ArgumentException(
                "PostgreSQL connection URI must include a database name.",
                nameof(connectionString));
        }

        var builder = new NpgsqlConnectionStringBuilder
        {
            Host = uri.Host,
            Port = uri.Port > 0 ? uri.Port : DefaultPostgreSqlPort,
            Database = Uri.UnescapeDataString(escapedDatabase),
            Username = Uri.UnescapeDataString(escapedUsername),
            Password = passwordSeparator >= 0
                ? Uri.UnescapeDataString(escapedUserInfo[(passwordSeparator + 1)..])
                : string.Empty
        };

        ApplyUriQueryParameters(uri.Query, builder);
        return builder;
    }

    private static void ApplyUriQueryParameters(
        string query,
        NpgsqlConnectionStringBuilder builder)
    {
        if (string.IsNullOrEmpty(query))
        {
            return;
        }

        foreach (var pair in query[1..].Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var separator = pair.IndexOf('=');
            var key = DecodeQueryComponent(separator >= 0 ? pair[..separator] : pair);
            var value = DecodeQueryComponent(separator >= 0 ? pair[(separator + 1)..] : string.Empty);
            var builderKey = key.ToLowerInvariant() switch
            {
                "application_name" => "Application Name",
                "command_timeout" => "Command Timeout",
                "connect_timeout" => "Timeout",
                "keepalives" => "Keepalive",
                "options" => "Options",
                "search_path" => "Search Path",
                "sslmode" => "SSL Mode",
                "target_session_attrs" => "Target Session Attributes",
                _ => throw new ArgumentException(
                    $"PostgreSQL connection URI query parameter '{key}' is not supported.",
                    nameof(query))
            };

            try
            {
                builder[builderKey] = value;
            }
            catch (Exception exception) when (
                exception is ArgumentException or FormatException or InvalidCastException or OverflowException)
            {
                throw new ArgumentException(
                    $"PostgreSQL connection URI query parameter '{key}' has an invalid value.",
                    nameof(query));
            }
        }
    }

    private static string DecodeQueryComponent(string value) =>
        Uri.UnescapeDataString(value.Replace('+', ' '));
}
