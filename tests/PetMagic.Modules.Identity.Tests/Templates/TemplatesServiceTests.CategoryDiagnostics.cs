using Microsoft.EntityFrameworkCore;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesServiceTests
{
    [Fact]
    public async Task GetAdminCategoryDiagnosticsAsync_ShouldClassifyIssuesAndKeepDeterministicOrder()
    {
        await using var dbContext = CreateDbContext();
        var service = CreateService(dbContext);

        await CreateActiveImageTemplateAsync(service, "Canonical", "Canonical", ["diagnostics"]);
        var emptyCategoryTemplateId = await CreateActiveImageTemplateAsync(
            service,
            "Empty category",
            "Empty seed",
            ["diagnostics"]);
        var archivedCategoryTemplateId = await CreateActiveImageTemplateAsync(
            service,
            "Archived category",
            "Archived",
            ["diagnostics"]);
        var firstMissingTemplateId = await CreateActiveImageTemplateAsync(
            service,
            "Same missing title",
            "Missing",
            ["diagnostics"]);
        var secondMissingTemplateId = await CreateActiveImageTemplateAsync(
            service,
            "Second missing title",
            "Missing",
            ["diagnostics"]);

        var emptyCategoryTemplate = await dbContext.TemplateItems.SingleAsync(
            template => template.Id == emptyCategoryTemplateId);
        emptyCategoryTemplate.Category = " \t ";

        var archivedCategory = await dbContext.TemplateCategories.SingleAsync(
            category => category.Name == "Archived");
        archivedCategory.IsArchived = true;

        var missingCategory = await dbContext.TemplateCategories.SingleAsync(
            category => category.Name == "Missing");
        dbContext.TemplateCategories.Remove(missingCategory);

        var secondMissingTemplate = await dbContext.TemplateItems.SingleAsync(
            template => template.Id == secondMissingTemplateId);
        secondMissingTemplate.Title = "Same missing title";
        await dbContext.SaveChangesAsync();

        var result = await service.GetAdminCategoryDiagnosticsAsync(CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.Equal(5, result.Value.TotalActiveTemplates);
        Assert.Equal(4, result.Value.NoncanonicalTemplates);
        Assert.Equal(80d, result.Value.NoncanonicalPercent);
        Assert.Equal(
            "empty_category",
            Assert.Single(result.Value.Items, item => item.TemplateId == emptyCategoryTemplateId).IssueKind);
        Assert.Equal(
            "archived_category",
            Assert.Single(result.Value.Items, item => item.TemplateId == archivedCategoryTemplateId).IssueKind);
        Assert.All(
            result.Value.Items.Where(item =>
                item.TemplateId == firstMissingTemplateId || item.TemplateId == secondMissingTemplateId),
            item => Assert.Equal("missing_category", item.IssueKind));

        var expectedOrder = result.Value.Items
            .OrderBy(item => item.NormalizedCategory, StringComparer.Ordinal)
            .ThenBy(item => item.Title, StringComparer.Ordinal)
            .ThenBy(item => item.TemplateId)
            .Select(item => item.TemplateId)
            .ToArray();
        Assert.Equal(expectedOrder, result.Value.Items.Select(item => item.TemplateId));
    }
}
