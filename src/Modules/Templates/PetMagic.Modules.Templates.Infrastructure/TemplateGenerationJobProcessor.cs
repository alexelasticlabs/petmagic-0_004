using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Domain.Enums;
using PetMagic.Modules.Templates.Infrastructure.Data;
using PetMagic.Modules.Templates.Infrastructure.Entities;
using PetMagic.Modules.Templates.Infrastructure.Options;

namespace PetMagic.Modules.Templates.Infrastructure;

internal sealed class TemplateGenerationJobProcessor(
    TemplatesDbContext dbContext,
    IImagePreprocessor imagePreprocessor,
    IVideoMotionGenerator videoMotionGenerator,
    IGeneratedMediaImporter generatedMediaImporter,
    ITemplateGenerationBilling billing,
    TemplatesOptions options,
    ILogger<TemplateGenerationJobProcessor> logger)
{
    public async Task<bool> ProcessNextAsync(CancellationToken cancellationToken)
    {
        var job = await dbContext.TemplateGenerationJobs
            .Include(x => x.Template)
            .ThenInclude(x => x.Assets)
            .Where(x => x.Status == TemplateGenerationStatus.Queued && x.ChargedAtUtc != null)
            .OrderBy(x => x.QueuedAtUtc)
            .FirstOrDefaultAsync(cancellationToken);

        if (job is null)
        {
            return false;
        }

        await ProcessAsync(job, cancellationToken);
        return true;
    }

    private async Task ProcessAsync(TemplateGenerationJob job, CancellationToken cancellationToken)
    {
        var now = DateTime.UtcNow;
        job.Status = TemplateGenerationStatus.Processing;
        job.AttemptCount++;
        job.LastAttemptAtUtc = now;
        job.StartedAtUtc ??= now;
        job.UpdatedAtUtc = now;
        job.FailureCode = null;
        job.FailureMessage = null;
        await dbContext.SaveChangesAsync(cancellationToken);

        try
        {
            var readiness = TemplateGenerationService.ValidateTemplate(job.Template);
            if (readiness is not null)
            {
                await MarkFailedAsync(job, readiness, cancellationToken);
                return;
            }

            var referenceMotion = TemplateGenerationService.GetAsset(job.Template, TemplateAssetKind.ReferenceMotion)!;
            var normalized = await imagePreprocessor.NormalizeAsync(
                job.SourceImageUrl,
                job.Template.PreprocessingModel!,
                TemplateGenerationService.ResolvePrompt(job.Template.PreprocessingPrompt, options.DefaultPreprocessingPrompt),
                cancellationToken);

            if (normalized.IsFailure)
            {
                await MarkFailedAsync(job, normalized.Error, cancellationToken);
                return;
            }

            job.NormalizedImageUrl = normalized.Value;
            job.UpdatedAtUtc = DateTime.UtcNow;
            await dbContext.SaveChangesAsync(cancellationToken);

            var generated = await videoMotionGenerator.CreateAsync(
                normalized.Value,
                referenceMotion.Url,
                job.Template.CharacterOrientation!.Value.ToString(),
                job.Template.KeepOriginalSound ?? true,
                TemplateGenerationService.ResolvePrompt(job.Template.KlingPrompt, options.DefaultKlingPrompt),
                job.Template.KlingModel!,
                cancellationToken);

            if (generated.IsFailure)
            {
                await MarkFailedAsync(job, generated.Error, cancellationToken);
                return;
            }

            var storedOutput = await generatedMediaImporter.ImportVideoAsync(generated.Value, job.Id, cancellationToken);
            if (storedOutput.IsFailure)
            {
                await MarkFailedAsync(job, storedOutput.Error, cancellationToken);
                return;
            }

            job.OutputUrl = storedOutput.Value.Url;
            job.Status = TemplateGenerationStatus.Completed;
            job.UpdatedAtUtc = DateTime.UtcNow;
            job.CompletedAtUtc = job.UpdatedAtUtc;
            await dbContext.SaveChangesAsync(cancellationToken);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "Template generation job {GenerationId} failed.", job.Id);
            await MarkFailedAsync(job, TemplatesErrors.AiProviderFailed, CancellationToken.None);
        }
    }

    private async Task MarkFailedAsync(TemplateGenerationJob job, Error error, CancellationToken cancellationToken)
    {
        if (job.ChargedAtUtc is not null && job.RefundedAtUtc is null)
        {
            var refund = await billing.RefundAsync(job.UserId, job.Id, job.TokenCost, cancellationToken);
            if (refund.IsSuccess)
            {
                job.RefundedAtUtc = DateTime.UtcNow;
            }
            else
            {
                logger.LogWarning("Template generation refund failed for job {GenerationId}: {ErrorCode}", job.Id, refund.Error.Code);
            }
        }

        job.Status = TemplateGenerationStatus.Failed;
        job.FailureCode = error.Code;
        job.FailureMessage = error.Message;
        job.UpdatedAtUtc = DateTime.UtcNow;
        job.CompletedAtUtc = job.UpdatedAtUtc;
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
