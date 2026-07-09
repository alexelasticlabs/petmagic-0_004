using Npgsql;

namespace PetMagic.Host.Api.Startup;

internal static class PostgreSqlIndexIntegrityValidator
{
    public static async Task ValidateAsync(string? connectionString, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return;
        }

        await using var connection = new NpgsqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);
        await using var command = connection.CreateCommand();
        command.CommandText =
            """
            SELECT ns.nspname, idx.relname, i.indisvalid, i.indisready
            FROM pg_index AS i
            JOIN pg_class AS idx ON idx.oid = i.indexrelid
            JOIN pg_namespace AS ns ON ns.oid = idx.relnamespace
            WHERE (NOT i.indisvalid OR NOT i.indisready)
              AND ns.nspname NOT IN ('pg_catalog', 'information_schema')
              AND ns.nspname NOT LIKE 'pg_toast%'
            ORDER BY ns.nspname, idx.relname;
            """;

        var invalidIndexes = new List<(string Schema, string Name, bool IsValid, bool IsReady)>();
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            invalidIndexes.Add((
                reader.GetString(0),
                reader.GetString(1),
                reader.GetBoolean(2),
                reader.GetBoolean(3)));
        }

        if (invalidIndexes.Count == 0)
        {
            return;
        }

        var details = string.Join(
            ", ",
            invalidIndexes.Select(index =>
                $"{QuoteIdentifier(index.Schema)}.{QuoteIdentifier(index.Name)}(valid={index.IsValid},ready={index.IsReady})"));
        var remediation = string.Join(
            " ",
            invalidIndexes.Select(index =>
                $"DROP INDEX CONCURRENTLY IF EXISTS {QuoteIdentifier(index.Schema)}.{QuoteIdentifier(index.Name)};"));

        throw new InvalidOperationException(
            $"PostgreSQL contains invalid or unfinished indexes: {details}. "
            + $"Run outside a transaction, then restart so the owning migration recreates the index: {remediation}");
    }

    private static string QuoteIdentifier(string value) => $"\"{value.Replace("\"", "\"\"")}\"";
}
