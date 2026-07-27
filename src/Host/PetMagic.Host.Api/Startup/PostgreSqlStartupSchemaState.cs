using Npgsql;

namespace PetMagic.Host.Api.Startup;

/// <summary>
/// Identifies a genuinely empty active PostgreSQL schema before migrations begin.
/// </summary>
internal static class PostgreSqlStartupSchemaState
{
    public static async Task<bool> IsEmptyAsync(
        string? connectionString,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return false;
        }

        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT NOT EXISTS (
                SELECT 1
                FROM pg_catalog.pg_class AS relation
                INNER JOIN pg_catalog.pg_namespace AS schema ON schema.oid = relation.relnamespace
                WHERE schema.nspname = ANY (current_schemas(false))
                  AND relation.relkind IN ('r', 'p', 'v', 'm', 'S', 'f'));
            """;

        var isEmptySchema = (bool?)await command.ExecuteScalarAsync(cancellationToken) == true;
        return isEmptySchema;
    }
}
