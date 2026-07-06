namespace PetMagic.Modules.Templates.Infrastructure;

internal static class ProcessOutputDrainer
{
    public static async Task<long> CountAsync(TextReader reader, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(reader);

        var buffer = new char[4096];
        long total = 0;
        while (true)
        {
            var read = await reader.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken);
            if (read == 0)
            {
                return total;
            }

            total += read;
        }
    }

    public static async Task DrainAsync(TextReader reader, CancellationToken cancellationToken)
    {
        _ = await CountAsync(reader, cancellationToken);
    }
}
