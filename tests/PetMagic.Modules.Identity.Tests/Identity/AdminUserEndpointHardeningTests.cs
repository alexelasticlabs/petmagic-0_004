namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class AdminUserEndpointHardeningTests
{
    [Fact]
    public void AdminUserMutations_ShouldMapStableFailureCodesToClientUsefulStatuses()
    {
        var source = File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "Identity",
            "PetMagic.Modules.Identity.Api",
            "Endpoints",
            "AdminUserEndpoints.cs"));

        Assert.Contains(
            "\"users.not_found\" => StatusCodes.Status404NotFound",
            source,
            StringComparison.Ordinal);
        Assert.Contains(
            "\"users.cannot_remove_last_admin\" => StatusCodes.Status409Conflict",
            source,
            StringComparison.Ordinal);
        Assert.Equal(
            5,
            CountOccurrences(source, "ResolveAdminUserMutationFailureStatusCode(result.Error.Code)"));
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);

        while (current is not null)
        {
            if (File.Exists(Path.Combine(current.FullName, ".gitignore")))
            {
                return current.FullName;
            }

            current = current.Parent;
        }

        throw new InvalidOperationException("Could not locate repository root.");
    }

    private static int CountOccurrences(string source, string value)
    {
        var count = 0;
        var index = 0;
        while ((index = source.IndexOf(value, index, StringComparison.Ordinal)) >= 0)
        {
            count++;
            index += value.Length;
        }

        return count;
    }
}
