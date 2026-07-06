using System.Security.Claims;

using Microsoft.AspNetCore.Http;

using PetMagic.BuildingBlocks.Results;

namespace PetMagic.Modules.Templates.Api.Endpoints;

public static partial class AdminTemplateEndpoints
{
    private const string InvalidSubjectCode = "templates.invalid_subject";
    private const string InvalidSubjectMessage = InvalidSubjectCode;

    private static (Guid UserId, Error? Error) TryGetAdminUserId(HttpContext context)
    {
        var subject = context.User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? context.User.FindFirstValue("sub");

        return Guid.TryParse(subject, out var userId)
            ? (userId, null)
            : (Guid.Empty, new Error(InvalidSubjectCode, InvalidSubjectMessage));
    }
}
