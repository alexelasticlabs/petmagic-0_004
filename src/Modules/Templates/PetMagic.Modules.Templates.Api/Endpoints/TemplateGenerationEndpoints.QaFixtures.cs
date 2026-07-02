using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

using PetMagic.Modules.Templates.Application.Abstractions;
using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class TemplateGenerationEndpoints
{
    private static async Task<Results<Ok<QaGenerationFixturesResponse>, ProblemHttpResult>> CreateQaGenerationFixturesAsync(
        HttpContext context,
        [FromBody] CreateQaGenerationFixturesRequest request,
        [FromServices] ITemplateGenerationQaFixtureService fixtureService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var result = await fixtureService.CreateAsync(
            userId!.Value,
            new CreateQaGenerationFixturesCommand(
                request.ImageTemplateId,
                request.VideoTemplateId,
                request.Scenarios),
            cancellationToken);

        return result.IsFailure
            ? ToClientGenerationProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private static async Task<Results<Ok<QaGenerationFixtureCleanupResponse>, ProblemHttpResult>> CleanupQaGenerationFixturesAsync(
        HttpContext context,
        [FromServices] ITemplateGenerationQaFixtureService fixtureService,
        CancellationToken cancellationToken)
    {
        var (userId, subjectError) = TryGetSubject(context);
        if (subjectError is not null)
        {
            return ToClientGenerationProblem(subjectError);
        }

        var result = await fixtureService.CleanupAsync(userId!.Value, cancellationToken);
        return result.IsFailure
            ? ToClientGenerationProblem(result.Error)
            : TypedResults.Ok(result.Value);
    }

    private sealed record CreateQaGenerationFixturesRequest(
        Guid? ImageTemplateId,
        Guid? VideoTemplateId,
        string[]? Scenarios);
}
