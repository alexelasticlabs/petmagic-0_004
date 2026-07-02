using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal interface ITemplateVisibilityPolicy
{
    IQueryable<TemplateItem> ApplyPublic(
        IQueryable<TemplateItem> query,
        TemplateVisibilityContext context);

    IQueryable<TemplateOfTheDay> ApplyPublicTemplateOfTheDay(
        IQueryable<TemplateOfTheDay> query,
        TemplateVisibilityContext context);

    Task<TemplateVisibilityDecision> EvaluatePublicAsync(
        TemplateItem template,
        TemplateVisibilityContext context,
        CancellationToken cancellationToken);
}

internal sealed record TemplateVisibilityContext(
    bool IncludeQaOnly = false,
    bool RequireGenerationAccess = false,
    bool HasPremiumAccess = true,
    long? ExpectedVersion = null,
    string? Locale = null,
    string? Region = null);

internal sealed record TemplateVisibilityDecision(bool IsVisible, Error? Error)
{
    public static TemplateVisibilityDecision Visible { get; } = new(true, null);
}

internal sealed class TemplateVisibilityPolicy : ITemplateVisibilityPolicy
{
    public IQueryable<TemplateItem> ApplyPublic(
        IQueryable<TemplateItem> query,
        TemplateVisibilityContext context)
    {
        var filtered = query
            .Where(template => template.DeletedAtUtc == null)
            .Where(template => template.Status == TemplateStatus.Active)
            .Where(template => context.IncludeQaOnly || !template.IsQaOnly);

        if (context.RequireGenerationAccess && !context.HasPremiumAccess)
        {
            filtered = filtered.Where(template => !template.IsPremium);
        }

        return filtered;
    }

    public IQueryable<TemplateOfTheDay> ApplyPublicTemplateOfTheDay(
        IQueryable<TemplateOfTheDay> query,
        TemplateVisibilityContext context)
    {
        var filtered = query
            .Where(assignment => assignment.Template.DeletedAtUtc == null)
            .Where(assignment => assignment.Template.Status == TemplateStatus.Active)
            .Where(assignment => context.IncludeQaOnly || !assignment.Template.IsQaOnly);

        if (context.RequireGenerationAccess && !context.HasPremiumAccess)
        {
            filtered = filtered.Where(assignment => !assignment.Template.IsPremium);
        }

        return filtered;
    }

    public Task<TemplateVisibilityDecision> EvaluatePublicAsync(
        TemplateItem template,
        TemplateVisibilityContext context,
        CancellationToken cancellationToken)
    {
        var unavailable = EvaluatePublicFlags(template, context);
        if (unavailable is not null)
        {
            return Task.FromResult(new TemplateVisibilityDecision(false, unavailable));
        }

        if (context.ExpectedVersion.HasValue && template.Version != context.ExpectedVersion.Value)
        {
            return Task.FromResult(new TemplateVisibilityDecision(false, TemplatesErrors.TemplateChanged));
        }

        if (context.RequireGenerationAccess && template.IsPremium && !context.HasPremiumAccess)
        {
            return Task.FromResult(new TemplateVisibilityDecision(false, TemplatesErrors.PremiumRequired));
        }

        return Task.FromResult(TemplateVisibilityDecision.Visible);
    }

    private static Error? EvaluatePublicFlags(TemplateItem template, TemplateVisibilityContext context)
    {
        if (template.DeletedAtUtc is not null
            || (!context.IncludeQaOnly && template.IsQaOnly))
        {
            return TemplatesErrors.TemplateUnavailable;
        }

        if (template.Status != TemplateStatus.Active)
        {
            return TemplatesErrors.InvalidStatus;
        }

        return null;
    }
}
