using Microsoft.EntityFrameworkCore;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Contracts;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Entities;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed partial class TemplatesService
{
    private const int TemplateOfTheDayDefaultTake = 30;
    private const int TemplateOfTheDayMaxTake = 100;
    private const int TemplateOfTheDayDefaultExcludeRecentDays = 7;
    private const int TemplateOfTheDayMaxExcludeRecentDays = 365;
    private const string TemplateOfTheDayDefaultBadge = "Template of the Day";
    private const string TemplateOfTheDayDefaultAllowedTypes = "both";

    public async Task<Result<PublicTemplateOfTheDayResponse>> GetPublicTemplateOfTheDayAsync(
        DateOnly? date,
        string? locale,
        CancellationToken cancellationToken)
    {
        var targetDate = ResolveTemplateOfTheDayBusinessDate(date);
        var assignment = await ResolveTemplateOfTheDayAsync(
            targetDate,
            createAutoFallback: true,
            createdByAdminId: null,
            cancellationToken);

        if (assignment is null)
        {
            return Result.Success(new PublicTemplateOfTheDayResponse(null));
        }

        return Result.Success(new PublicTemplateOfTheDayResponse(
            MapPublicTemplateOfTheDay(assignment, targetDate, locale)));
    }

    public async Task<Result<AdminTemplateOfTheDayScheduleResponse>> ListAdminTemplateOfTheDayScheduleAsync(
        int? skip,
        int? take,
        CancellationToken cancellationToken)
    {
        var normalizedSkip = Math.Max(skip ?? 0, 0);
        var normalizedTake = Math.Clamp(take ?? TemplateOfTheDayDefaultTake, 1, TemplateOfTheDayMaxTake);

        var query = dbContext.TemplateOfTheDay
            .AsNoTracking()
            .Include(assignment => assignment.Template)
            .ThenInclude(template => template.Assets)
            .OrderByDescending(assignment => assignment.StartDate)
            .ThenByDescending(assignment => assignment.Priority)
            .ThenByDescending(assignment => assignment.UpdatedAtUtc)
            .ThenByDescending(assignment => assignment.Id);

        var totalCount = await query.CountAsync(cancellationToken);
        var items = await query
            .Skip(normalizedSkip)
            .Take(normalizedTake)
            .ToArrayAsync(cancellationToken);

        return Result.Success(new AdminTemplateOfTheDayScheduleResponse(
            [.. items.Select(MapAdminTemplateOfTheDay)],
            normalizedSkip,
            normalizedTake,
            totalCount,
            totalCount > normalizedSkip + items.Length,
            DateTime.UtcNow));
    }

    public async Task<Result<AdminTemplateOfTheDayResponse?>> GetAdminCurrentTemplateOfTheDayAsync(
        DateOnly? date,
        CancellationToken cancellationToken)
    {
        var targetDate = ResolveTemplateOfTheDayBusinessDate(date);
        var assignment = await ResolveTemplateOfTheDayAsync(
            targetDate,
            createAutoFallback: false,
            createdByAdminId: null,
            cancellationToken);

        return Result.Success(assignment is null ? null : MapAdminTemplateOfTheDay(assignment));
    }

    public async Task<Result<AdminTemplateOfTheDaySettingsResponse>> GetAdminTemplateOfTheDaySettingsAsync(
        CancellationToken cancellationToken)
    {
        var settings = await GetTemplateOfTheDaySettingsEntityAsync(cancellationToken);
        return Result.Success(MapAdminTemplateOfTheDaySettings(settings));
    }

    public async Task<Result<AdminTemplateOfTheDaySettingsResponse>> UpdateAdminTemplateOfTheDaySettingsAsync(
        UpdateTemplateOfTheDaySettingsCommand command,
        CancellationToken cancellationToken)
    {
        var settings = await GetTemplateOfTheDaySettingsEntityAsync(cancellationToken);
        settings.AutoModeEnabled = command.AutoModeEnabled;
        settings.AllowedTypes = NormalizeTemplateOfTheDayAllowedTypes(command.AllowedTypes);
        settings.ExcludeRecentDays = NormalizeTemplateOfTheDayExcludeRecentDays(command.ExcludeRecentDays);
        settings.UpdatedAtUtc = DateTime.UtcNow;
        settings.UpdatedByAdminId = command.UpdatedByAdminId;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(MapAdminTemplateOfTheDaySettings(settings));
    }

    public async Task<Result<AdminTemplateOfTheDayResponse>> CreateTemplateOfTheDayAsync(
        CreateTemplateOfTheDayCommand command,
        CancellationToken cancellationToken)
    {
        var dateRangeValidation = ValidateTemplateOfTheDayDateRange(command.StartDate, command.EndDate);
        if (dateRangeValidation.IsFailure)
        {
            return Result.Failure<AdminTemplateOfTheDayResponse>(dateRangeValidation.Error);
        }

        var template = await FindAvailableTemplateOfTheDayTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateOfTheDayResponse>(TemplatesErrors.TemplateOfTheDayTemplateUnavailable);
        }

        if (command.IsManual && command.IsActive
            && await HasManualTemplateOfTheDayOverlapAsync(command.StartDate, command.EndDate, null, cancellationToken))
        {
            return Result.Failure<AdminTemplateOfTheDayResponse>(TemplatesErrors.TemplateOfTheDayDateOccupied);
        }

        var now = DateTime.UtcNow;
        var assignment = new TemplateOfTheDay
        {
            Id = Guid.NewGuid(),
            TemplateId = template.Id,
            Template = template,
            StartDate = command.StartDate,
            EndDate = command.EndDate,
            IsActive = command.IsActive,
            IsManual = command.IsManual,
            Priority = command.Priority,
            TitleOverride = NormalizeOptionalTemplateOfTheDayText(command.TitleOverride, 120),
            SubtitleOverride = NormalizeOptionalTemplateOfTheDayText(command.SubtitleOverride, 240),
            BadgeTextOverride = NormalizeOptionalTemplateOfTheDayText(command.BadgeTextOverride, 64),
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
            CreatedByAdminId = command.CreatedByAdminId
        };

        dbContext.TemplateOfTheDay.Add(assignment);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(MapAdminTemplateOfTheDay(assignment));
    }

    public async Task<Result<AdminTemplateOfTheDayResponse>> UpdateTemplateOfTheDayAsync(
        UpdateTemplateOfTheDayCommand command,
        CancellationToken cancellationToken)
    {
        var assignment = await dbContext.TemplateOfTheDay
            .Include(item => item.Template)
            .ThenInclude(template => template.Assets)
            .FirstOrDefaultAsync(item => item.Id == command.Id, cancellationToken);

        if (assignment is null)
        {
            return Result.Failure<AdminTemplateOfTheDayResponse>(TemplatesErrors.NotFound);
        }

        var dateRangeValidation = ValidateTemplateOfTheDayDateRange(command.StartDate, command.EndDate);
        if (dateRangeValidation.IsFailure)
        {
            return Result.Failure<AdminTemplateOfTheDayResponse>(dateRangeValidation.Error);
        }

        var template = await FindAvailableTemplateOfTheDayTemplateAsync(command.TemplateId, cancellationToken);
        if (template is null)
        {
            return Result.Failure<AdminTemplateOfTheDayResponse>(TemplatesErrors.TemplateOfTheDayTemplateUnavailable);
        }

        if (command.IsManual && command.IsActive
            && await HasManualTemplateOfTheDayOverlapAsync(command.StartDate, command.EndDate, command.Id, cancellationToken))
        {
            return Result.Failure<AdminTemplateOfTheDayResponse>(TemplatesErrors.TemplateOfTheDayDateOccupied);
        }

        assignment.TemplateId = template.Id;
        assignment.Template = template;
        assignment.StartDate = command.StartDate;
        assignment.EndDate = command.EndDate;
        assignment.IsActive = command.IsActive;
        assignment.IsManual = command.IsManual;
        assignment.Priority = command.Priority;
        assignment.TitleOverride = NormalizeOptionalTemplateOfTheDayText(command.TitleOverride, 120);
        assignment.SubtitleOverride = NormalizeOptionalTemplateOfTheDayText(command.SubtitleOverride, 240);
        assignment.BadgeTextOverride = NormalizeOptionalTemplateOfTheDayText(command.BadgeTextOverride, 64);
        assignment.UpdatedAtUtc = DateTime.UtcNow;

        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success(MapAdminTemplateOfTheDay(assignment));
    }

    public async Task<Result> DeleteTemplateOfTheDayAsync(Guid id, CancellationToken cancellationToken)
    {
        var assignment = await dbContext.TemplateOfTheDay
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);

        if (assignment is null)
        {
            return Result.Failure(TemplatesErrors.NotFound);
        }

        dbContext.TemplateOfTheDay.Remove(assignment);
        await dbContext.SaveChangesAsync(cancellationToken);
        return Result.Success();
    }

    public async Task<Result<AdminTemplateOfTheDayResponse>> AutoPickTemplateOfTheDayAsync(
        AutoPickTemplateOfTheDayCommand command,
        CancellationToken cancellationToken)
    {
        var settings = await GetTemplateOfTheDaySettingsEntityAsync(cancellationToken);
        if (!settings.AutoModeEnabled && !command.Force)
        {
            return Result.Failure<AdminTemplateOfTheDayResponse>(TemplatesErrors.TemplateOfTheDayAutoModeDisabled);
        }

        var allowedTypes = command.AllowedTypes ?? settings.AllowedTypes;
        var excludeRecentDays = command.ExcludeRecentDays ?? settings.ExcludeRecentDays;
        var assignment = await CreateAutoTemplateOfTheDayAsync(
            command.Date,
            command.CreatedByAdminId,
            ResolveTemplateOfTheDayAllowedType(allowedTypes),
            NormalizeTemplateOfTheDayExcludeRecentDays(excludeRecentDays),
            cancellationToken);

        return assignment is null
            ? Result.Failure<AdminTemplateOfTheDayResponse>(TemplatesErrors.TemplateOfTheDayTemplateUnavailable)
            : Result.Success(MapAdminTemplateOfTheDay(assignment));
    }

    private async Task<TemplateOfTheDay?> ResolveTemplateOfTheDayAsync(
        DateOnly date,
        bool createAutoFallback,
        Guid? createdByAdminId,
        CancellationToken cancellationToken)
    {
        var manual = await QueryAvailableTemplateOfTheDayAssignments(date)
            .Where(assignment => assignment.IsManual)
            .OrderByDescending(assignment => assignment.Priority)
            .ThenByDescending(assignment => assignment.UpdatedAtUtc)
            .ThenByDescending(assignment => assignment.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (manual is not null)
        {
            return manual;
        }

        var automatic = await QueryAvailableTemplateOfTheDayAssignments(date)
            .Where(assignment => !assignment.IsManual)
            .OrderByDescending(assignment => assignment.Priority)
            .ThenByDescending(assignment => assignment.UpdatedAtUtc)
            .ThenByDescending(assignment => assignment.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (automatic is not null || !createAutoFallback)
        {
            return automatic;
        }

        var settings = await GetTemplateOfTheDaySettingsEntityAsync(cancellationToken);
        if (!settings.AutoModeEnabled)
        {
            return null;
        }

        return await CreateAutoTemplateOfTheDayAsync(
            date,
            createdByAdminId,
            ResolveTemplateOfTheDayAllowedType(settings.AllowedTypes),
            settings.ExcludeRecentDays,
            cancellationToken);
    }

    private IQueryable<TemplateOfTheDay> QueryAvailableTemplateOfTheDayAssignments(DateOnly date)
    {
        return dbContext.TemplateOfTheDay
            .Include(assignment => assignment.Template)
            .ThenInclude(template => template.Assets)
            .Where(assignment => assignment.IsActive)
            .Where(assignment => assignment.StartDate <= date)
            .Where(assignment => assignment.EndDate == null || assignment.EndDate >= date)
            .Where(assignment => assignment.Template.DeletedAtUtc == null)
            .Where(assignment => assignment.Template.Status == TemplateStatus.Active)
            .Where(assignment => assignment.Template.Assets.Any(asset =>
                asset.AssetKind == TemplateAssetKind.Preview
                && asset.Url.Trim() != string.Empty));
    }

    private async Task<TemplateOfTheDay?> CreateAutoTemplateOfTheDayAsync(
        DateOnly date,
        Guid? createdByAdminId,
        TemplateType? allowedType,
        int excludeRecentDays,
        CancellationToken cancellationToken)
    {
        var manual = await QueryAvailableTemplateOfTheDayAssignments(date)
            .Where(assignment => assignment.IsManual)
            .OrderByDescending(assignment => assignment.Priority)
            .ThenByDescending(assignment => assignment.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (manual is not null)
        {
            return manual;
        }

        var existing = await QueryAvailableTemplateOfTheDayAssignments(date)
            .Where(assignment => !assignment.IsManual)
            .OrderByDescending(assignment => assignment.UpdatedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (existing is not null)
        {
            return existing;
        }

        var baseCandidates = dbContext.TemplateItems
            .Include(template => template.Assets)
            .Where(template => template.DeletedAtUtc == null)
            .Where(template => template.Status == TemplateStatus.Active)
            .Where(template => !allowedType.HasValue || template.TemplateType == allowedType.Value)
            .Where(template => template.Assets.Any(asset =>
                asset.AssetKind == TemplateAssetKind.Preview
                && asset.Url.Trim() != string.Empty));

        var recentCutoff = date.AddDays(-excludeRecentDays);
        var recentTemplateIds = excludeRecentDays <= 0
            ? Array.Empty<Guid>()
            : await dbContext.TemplateOfTheDay
                .AsNoTracking()
                .Where(assignment => assignment.IsActive)
                .Where(assignment => assignment.StartDate >= recentCutoff && assignment.StartDate < date)
                .Select(assignment => assignment.TemplateId)
                .Distinct()
                .ToArrayAsync(cancellationToken);

        var candidates = await baseCandidates
            .Where(template => recentTemplateIds.Length == 0 || !recentTemplateIds.Contains(template.Id))
            .OrderByDescending(template => template.UpdatedAtUtc)
            .ThenByDescending(template => template.Id)
            .ToArrayAsync(cancellationToken);

        if (candidates.Length == 0 && recentTemplateIds.Length > 0)
        {
            candidates = await baseCandidates
                .OrderByDescending(template => template.UpdatedAtUtc)
                .ThenByDescending(template => template.Id)
                .ToArrayAsync(cancellationToken);
        }

        if (candidates.Length == 0)
        {
            return null;
        }

        var selected = candidates[new Random(HashCode.Combine(date.DayNumber, candidates.Length)).Next(candidates.Length)];
        var now = DateTime.UtcNow;
        var assignment = new TemplateOfTheDay
        {
            Id = Guid.NewGuid(),
            TemplateId = selected.Id,
            Template = selected,
            StartDate = date,
            EndDate = date,
            IsActive = true,
            IsManual = false,
            Priority = 0,
            CreatedAtUtc = now,
            UpdatedAtUtc = now,
            CreatedByAdminId = createdByAdminId
        };

        dbContext.TemplateOfTheDay.Add(assignment);
        await dbContext.SaveChangesAsync(cancellationToken);
        return assignment;
    }

    private async Task<TemplateItem?> FindAvailableTemplateOfTheDayTemplateAsync(
        Guid templateId,
        CancellationToken cancellationToken)
    {
        return await dbContext.TemplateItems
            .Include(template => template.Assets)
            .Where(template => template.Id == templateId)
            .Where(template => template.DeletedAtUtc == null)
            .Where(template => template.Status == TemplateStatus.Active)
            .Where(template => template.Assets.Any(asset =>
                asset.AssetKind == TemplateAssetKind.Preview
                && asset.Url.Trim() != string.Empty))
            .FirstOrDefaultAsync(cancellationToken);
    }

    private async Task<bool> HasManualTemplateOfTheDayOverlapAsync(
        DateOnly startDate,
        DateOnly? endDate,
        Guid? excludeId,
        CancellationToken cancellationToken)
    {
        var requestedEnd = endDate ?? DateOnly.MaxValue;
        return await dbContext.TemplateOfTheDay
            .AnyAsync(assignment =>
                assignment.IsActive
                && assignment.IsManual
                && (!excludeId.HasValue || assignment.Id != excludeId.Value)
                && assignment.StartDate <= requestedEnd
                && (assignment.EndDate == null || assignment.EndDate >= startDate),
                cancellationToken);
    }

    private static Result ValidateTemplateOfTheDayDateRange(DateOnly startDate, DateOnly? endDate)
    {
        return endDate.HasValue && endDate.Value < startDate
            ? Result.Failure(TemplatesErrors.InvalidTemplateOfTheDayDateRange)
            : Result.Success();
    }

    private static TemplateType? ResolveTemplateOfTheDayAllowedType(string? rawAllowedTypes)
    {
        return rawAllowedTypes?.Trim().ToLowerInvariant() switch
        {
            "image" or "images" => TemplateType.Image,
            "video" or "videos" => TemplateType.Video,
            _ => null
        };
    }

    private async Task<TemplateOfTheDaySettings> GetTemplateOfTheDaySettingsEntityAsync(
        CancellationToken cancellationToken)
    {
        var settings = await dbContext.TemplateOfTheDaySettings
            .OrderBy(item => item.CreatedAtUtc)
            .ThenBy(item => item.Id)
            .FirstOrDefaultAsync(cancellationToken);

        if (settings is not null)
        {
            return settings;
        }

        var now = DateTime.UtcNow;
        settings = new TemplateOfTheDaySettings
        {
            Id = Guid.NewGuid(),
            AutoModeEnabled = true,
            AllowedTypes = NormalizeTemplateOfTheDayAllowedTypes(options.TemplateOfTheDayAutoPickAllowedTypes),
            ExcludeRecentDays = NormalizeTemplateOfTheDayExcludeRecentDays(options.TemplateOfTheDayAutoPickExcludeRecentDays),
            CreatedAtUtc = now,
            UpdatedAtUtc = now
        };

        dbContext.TemplateOfTheDaySettings.Add(settings);
        await dbContext.SaveChangesAsync(cancellationToken);
        return settings;
    }

    private static string NormalizeTemplateOfTheDayAllowedTypes(string? rawAllowedTypes)
    {
        return rawAllowedTypes?.Trim().ToLowerInvariant() switch
        {
            "image" or "images" => "image",
            "video" or "videos" => "video",
            _ => TemplateOfTheDayDefaultAllowedTypes
        };
    }

    private static int NormalizeTemplateOfTheDayExcludeRecentDays(int? excludeRecentDays)
    {
        return Math.Clamp(
            excludeRecentDays ?? TemplateOfTheDayDefaultExcludeRecentDays,
            0,
            TemplateOfTheDayMaxExcludeRecentDays);
    }

    private DateOnly ResolveTemplateOfTheDayBusinessDate(DateOnly? explicitDate)
    {
        if (explicitDate.HasValue)
        {
            return explicitDate.Value;
        }

        var businessNow = TimeZoneInfo.ConvertTimeFromUtc(
            DateTime.UtcNow,
            ResolveTemplateOfTheDayBusinessTimeZone());
        return DateOnly.FromDateTime(businessNow);
    }

    private TimeZoneInfo ResolveTemplateOfTheDayBusinessTimeZone()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById(options.TemplateOfTheDayBusinessTimeZone);
        }
        catch (TimeZoneNotFoundException)
        {
            return TimeZoneInfo.Utc;
        }
        catch (InvalidTimeZoneException)
        {
            return TimeZoneInfo.Utc;
        }
    }

    private static string? NormalizeOptionalTemplateOfTheDayText(string? value, int maxLength)
    {
        var normalized = value?.Trim();
        if (string.IsNullOrEmpty(normalized))
        {
            return null;
        }

        return normalized.Length <= maxLength ? normalized : normalized[..maxLength];
    }

    private static AdminTemplateOfTheDayResponse MapAdminTemplateOfTheDay(TemplateOfTheDay assignment)
    {
        return new AdminTemplateOfTheDayResponse(
            assignment.Id,
            assignment.TemplateId,
            assignment.Template.Title,
            assignment.Template.TemplateType.ToString(),
            assignment.Template.Category,
            assignment.Template.Status.ToString(),
            assignment.Template.IsPremium,
            GetAsset(assignment.Template, TemplateAssetKind.Preview),
            assignment.StartDate,
            assignment.EndDate,
            assignment.IsActive,
            assignment.IsManual,
            assignment.Priority,
            assignment.TitleOverride,
            assignment.SubtitleOverride,
            assignment.BadgeTextOverride,
            assignment.CreatedAtUtc,
            assignment.UpdatedAtUtc,
            assignment.CreatedByAdminId);
    }

    private static AdminTemplateOfTheDaySettingsResponse MapAdminTemplateOfTheDaySettings(
        TemplateOfTheDaySettings settings)
    {
        return new AdminTemplateOfTheDaySettingsResponse(
            settings.AutoModeEnabled,
            settings.AllowedTypes,
            settings.ExcludeRecentDays,
            settings.UpdatedAtUtc,
            settings.UpdatedByAdminId);
    }

    private static PublicTemplateOfTheDayItemResponse MapPublicTemplateOfTheDay(
        TemplateOfTheDay assignment,
        DateOnly date,
        string? locale)
    {
        var localized = TemplateLocalizationTranslator.Resolve(
            assignment.Template.Title,
            assignment.Template.ShortDescription,
            assignment.Template.LocalizedTextsJson,
            locale);
        var previewAsset = GetAsset(assignment.Template, TemplateAssetKind.Preview);
        var previewUrl = previewAsset?.Url;
        var previewContentType = previewAsset?.ContentType.Trim().ToLowerInvariant() ?? string.Empty;
        var previewIsVideo = previewContentType.StartsWith("video/", StringComparison.Ordinal)
            || IsVideoAssetUrl(previewUrl);

        return new PublicTemplateOfTheDayItemResponse(
            assignment.TemplateId,
            assignment.TitleOverride ?? localized.Title,
            assignment.SubtitleOverride ?? localized.ShortDescription,
            assignment.BadgeTextOverride ?? TemplateOfTheDayDefaultBadge,
            assignment.Template.TemplateType.ToString(),
            previewIsVideo ? null : previewUrl,
            previewUrl,
            assignment.Template.IsPremium,
            assignment.Template.IsPremium ? "premium" : "free",
            date,
            assignment.IsManual ? "manual" : "auto");
    }
}
