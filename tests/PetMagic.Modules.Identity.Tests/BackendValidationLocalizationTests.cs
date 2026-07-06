using System.Text.RegularExpressions;

namespace PetMagic.Modules.Identity.Tests;

public sealed partial class BackendValidationLocalizationTests
{
    [Fact]
    public void ApplicationValidators_ShouldExposeValidationCodesInsteadOfUserFacingSentences()
    {
        var repositoryRoot = FindRepositoryRoot();
        var modulesRoot = Path.Combine(repositoryRoot, "src", "Modules");
        var validatorFiles = Directory.GetFiles(modulesRoot, "*Validators.cs", SearchOption.AllDirectories);

        Assert.NotEmpty(validatorFiles);

        var literalMessages = validatorFiles
            .SelectMany(file =>
            {
                var source = File.ReadAllText(file);

                return WithMessageLiteralRegex()
                    .Matches(source)
                    .Select(match => new
                    {
                        File = Path.GetRelativePath(repositoryRoot, file),
                        Message = match.Groups["message"].Value
                    });
            })
            .Where(item => !ValidationCodeRegex().IsMatch(item.Message))
            .Select(item => $"{item.File}: {item.Message}")
            .ToArray();

        Assert.Empty(literalMessages);

        var combinedValidationSource = string.Join(
            "\n",
            validatorFiles.Select(File.ReadAllText));

        Assert.DoesNotContain("PaymentProvider must be", combinedValidationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Support conversation priority is not supported.", combinedValidationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Template status is invalid.", combinedValidationSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Role is not supported.", combinedValidationSource, StringComparison.Ordinal);

        var endpointFiles = Directory.GetFiles(modulesRoot, "*Endpoints*.cs", SearchOption.AllDirectories);
        var combinedEndpointSource = string.Join(
            "\n",
            endpointFiles.Select(File.ReadAllText));

        Assert.DoesNotContain("validation.ToDictionary()", combinedEndpointSource, StringComparison.Ordinal);
        Assert.Contains("validation.ToValidationCodeDictionary()", combinedEndpointSource, StringComparison.Ordinal);
    }

    private static string FindRepositoryRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);

        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, ".gitignore")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new DirectoryNotFoundException("Could not locate repository root.");
    }

    [GeneratedRegex(@"WithMessage\(""(?<message>[^""]+)""\)", RegexOptions.Compiled)]
    private static partial Regex WithMessageLiteralRegex();

    [GeneratedRegex(@"^[a-z0-9_]+\.[a-z0-9_.]+$", RegexOptions.Compiled)]
    private static partial Regex ValidationCodeRegex();
}
