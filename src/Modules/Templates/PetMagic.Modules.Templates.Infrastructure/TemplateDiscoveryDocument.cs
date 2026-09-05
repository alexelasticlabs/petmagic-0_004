using System.Text.Json;

using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class TemplateDiscoveryDocument
{
    internal static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);
    private static readonly HashSet<string> Locales = ["en", "ru", "de", "es", "fr", "it", "pl"];

    internal static string Serialize(DiscoveryDocument document) => JsonSerializer.Serialize(document, JsonOptions);

    internal static DiscoveryDocument? Read(string json)
    {
        try
        {
            var document = JsonSerializer.Deserialize<DiscoveryDocument>(json, JsonOptions);
            return ShapeIssues(document).Count == 0 ? document : null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    internal static DiscoveryCopy ResolveCopy(IReadOnlyDictionary<string, DiscoveryCopy> copy, string? locale)
    {
        var key = locale?.Trim().Replace('_', '-').Split('-')[0].ToLowerInvariant() ?? "en";
        copy.TryGetValue("en", out var fallback);
        copy.TryGetValue(key, out var localized);
        return new DiscoveryCopy(
            string.IsNullOrWhiteSpace(localized?.Title) ? fallback?.Title ?? "" : localized.Title.Trim(),
            string.IsNullOrWhiteSpace(localized?.Subtitle) ? fallback?.Subtitle ?? "" : localized.Subtitle.Trim());
    }

    internal static List<DiscoveryValidationIssue> ShapeIssues(DiscoveryDocument? document)
    {
        var issues = new List<DiscoveryValidationIssue>();
        void Add(string path, string message) => issues.Add(new(path, "invalid_document", message));
        if (document is null) { Add("document", "A discovery document is required."); return issues; }
        if (document.SchemaVersion != 1) Add("schemaVersion", "Unsupported editor schema version.");
        if (document.AutoplayIntervalMs is < 5000 or > 30000) Add("autoplayIntervalMs", "Use an interval between 5000 and 30000 ms.");
        ValidateCopy(document.Copy, "copy");
        if (document.Sections is null || document.Sections.Count > 24)
        {
            Add("sections", "Use at most 24 sections.");
            return issues;
        }
        var ids = new HashSet<Guid>();
        var categories = new HashSet<Guid>();
        for (var index = 0; index < document.Sections.Count; index++)
        {
            var section = document.Sections[index];
            var path = $"sections[{index}]";
            if (section is null) { Add(path, "A section is required."); continue; }
            if (section.Id == Guid.Empty || !ids.Add(section.Id)) Add(path + ".id", "Section identifiers must be unique and non-empty.");
            if (section.CategoryId == Guid.Empty || !categories.Add(section.CategoryId)) Add(path + ".categoryId", "Select a unique category for each section.");
            if (section.ItemLimit is < 1 or > 12) Add(path + ".itemLimit", "Use between 1 and 12 items.");
            if (section.SelectionMode is not ("Latest" or "Manual" or "Hybrid")) Add(path + ".selectionMode", "Select Latest, Manual or Hybrid.");
            if (section.HeroTemplateId == Guid.Empty) Add(path + ".heroTemplateId", "Invalid cover identifier.");
            if (section.TemplateIds is null || section.TemplateIds.Count > 12)
                Add(path + ".templateIds", "Use at most 12 pinned templates.");
            else if (section.TemplateIds.Any(id => id == Guid.Empty) || section.TemplateIds.Distinct().Count() != section.TemplateIds.Count)
                Add(path + ".templateIds", "Pinned template identifiers must be unique and non-empty.");
            ValidateCopy(section.Copy, path + ".copy");
        }
        return issues;

        void ValidateCopy(IReadOnlyDictionary<string, DiscoveryCopy>? copy, string path)
        {
            if (copy is null || copy.Count > 7) { Add(path, "Use only supported content locales."); return; }
            foreach (var pair in copy)
            {
                if (!Locales.Contains(pair.Key) || pair.Value is null || pair.Value.Title is null || pair.Value.Subtitle is null)
                    Add(path, "Each supported locale needs title and subtitle strings.");
                else if (pair.Value.Title.Length > 120 || pair.Value.Subtitle.Length > 240)
                    Add(path + "." + pair.Key, "Title is limited to 120 characters and subtitle to 240.");
            }
        }
    }
}
