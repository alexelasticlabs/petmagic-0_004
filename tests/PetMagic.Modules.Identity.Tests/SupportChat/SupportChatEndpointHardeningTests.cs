namespace PetMagic.Modules.Identity.Tests.SupportChat;

public sealed class SupportChatEndpointHardeningTests
{
    [Fact]
    public void SupportChatEndpoints_ShouldUseSanitizedProblemDetails()
    {
        var source = ReadEndpointSource("SupportChatEndpoints.AdminTicketActions.cs");
        var managementSource = ReadEndpointSource("SupportChatEndpoints.AdminConversationManagement.cs");
        var accessSource = ReadEndpointSource("SupportChatEndpoints.AdminConversationAccess.cs");

        Assert.Contains("extensions: BuildProblemExtensions(error.Code)", source, StringComparison.Ordinal);
        Assert.Contains("private static Dictionary<string, object?> BuildProblemExtensions(string errorCode)", source, StringComparison.Ordinal);
        Assert.Contains("[\"code\"] = errorCode", source, StringComparison.Ordinal);
        Assert.Contains("\"support.invalid_subject\" => StatusCodes.Status401Unauthorized", source, StringComparison.Ordinal);
        Assert.Contains("unauthorized = ToProblem(new Error(", source, StringComparison.Ordinal);
        Assert.Contains("return ToProblem(new Error(", managementSource, StringComparison.Ordinal);
        Assert.Contains("\"support.status_invalid\"", managementSource, StringComparison.Ordinal);
        Assert.Contains("\"support.priority_invalid\"", managementSource, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Support conversation status is not supported.\"", managementSource, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Support conversation priority is not supported.\"", managementSource, StringComparison.Ordinal);
        Assert.Contains("return ToProblem(new Error(", accessSource, StringComparison.Ordinal);
        Assert.Contains("\"support.assignment_invalid\"", accessSource, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Support inbox assignment filter is not supported.\"", accessSource, StringComparison.Ordinal);
        Assert.DoesNotContain("GetProblemDetail", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Support request could not be completed.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Support conversation was not found.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("Authentication failed.", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: error.Message", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Authentication failed.\"", source, StringComparison.Ordinal);
        Assert.DoesNotContain("detail: \"Invalid access token subject.\"", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SupportChatAdminAccessEndpoints_ShouldGuardServiceFailures()
    {
        var source = ReadEndpointSource("SupportChatEndpoints.AdminConversationAccess.cs");

        Assert.Contains("Task<Results<Ok<AdminSupportInboxMetricsResponse>, ProblemHttpResult>> GetAdminInboxMetricsAsync(", source, StringComparison.Ordinal);
        Assert.Contains("if (result.IsFailure)", source, StringComparison.Ordinal);
        Assert.Contains("return ToProblem(result.Error);", source, StringComparison.Ordinal);
        Assert.DoesNotContain("GetAdminInboxMetricsAsync(cancellationToken);\r\n        return TypedResults.Ok(result.Value);", source, StringComparison.Ordinal);
    }

    [Fact]
    public void SupportChatAttachmentEndpoints_ShouldValidateMetadataBeforeStorage()
    {
        var sharedSource = ReadEndpointSource("SupportChatEndpoints.SharedAttachmentUploads.cs");
        var userSource = ReadEndpointSource("SupportChatEndpoints.UserAttachments.cs");
        var adminSource = ReadEndpointSource("SupportChatEndpoints.AdminAttachments.cs");

        Assert.Contains("private const int AttachmentFileNameMaxLength = 256;", sharedSource, StringComparison.Ordinal);
        Assert.Contains("private const int AttachmentContentTypeMaxLength = 128;", sharedSource, StringComparison.Ordinal);
        Assert.Contains("var metadataValidationErrors = ValidateAttachmentFiles(files, attachmentStorage);", sharedSource, StringComparison.Ordinal);
        Assert.Contains("private static Dictionary<string, string[]> ValidateSingleAttachmentMetadata(", sharedSource, StringComparison.Ordinal);
        Assert.Contains("ISupportAttachmentStorage attachmentStorage", sharedSource, StringComparison.Ordinal);
        Assert.Contains("support.attachment_file_required", sharedSource, StringComparison.Ordinal);
        Assert.Contains("support.message_body_too_long", sharedSource, StringComparison.Ordinal);
        Assert.Contains("support.reply_target_invalid", sharedSource, StringComparison.Ordinal);
        Assert.Contains("support.attachment_file_name_required", sharedSource, StringComparison.Ordinal);
        Assert.Contains("support.attachment_file_name_too_long", sharedSource, StringComparison.Ordinal);
        Assert.Contains("support.attachment_content_type_too_long", sharedSource, StringComparison.Ordinal);
        Assert.Contains("support.attachment_file_too_large", sharedSource, StringComparison.Ordinal);
        Assert.Contains("attachmentStorage.ResolveMaxFileSizeBytes(contentType)", sharedSource, StringComparison.Ordinal);
        Assert.DoesNotContain("At least one support attachment file is required.", sharedSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Support message body must be at most", sharedSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Reply target message id must be a valid GUID.", sharedSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Support attachment file name is required.", sharedSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Support attachment file name must be at most", sharedSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Support attachment content type must be at most", sharedSource, StringComparison.Ordinal);
        Assert.Contains("RemoveAttachmentMetadataControlCharacters(Path.GetFileName(file.FileName)).Trim();", sharedSource, StringComparison.Ordinal);
        Assert.Contains("NormalizeAttachmentContentType(file)", sharedSource, StringComparison.Ordinal);
        Assert.Contains("private static string RemoveAttachmentMetadataControlCharacters(string value)", sharedSource, StringComparison.Ordinal);
        Assert.Contains("!value.Any(char.IsControl)", sharedSource, StringComparison.Ordinal);
        Assert.Contains("return string.IsNullOrWhiteSpace(contentType)", sharedSource, StringComparison.Ordinal);
        Assert.True(
            sharedSource.IndexOf("var metadataValidationErrors = ValidateAttachmentFiles(files, attachmentStorage);", StringComparison.Ordinal)
                < sharedSource.IndexOf("var storedAttachments = new List<StoredSupportAttachmentResponse>(files.Count);", StringComparison.Ordinal));
        Assert.Contains("var maxFileSizeBytes = attachmentStorage.ResolveMaxFileSizeBytes(contentType);", sharedSource, StringComparison.Ordinal);
        Assert.Contains("file.Length > maxFileSizeBytes.Value", sharedSource, StringComparison.Ordinal);

        Assert.Contains("var metadataValidationErrors = ValidateSingleAttachmentMetadata(file, attachmentStorage);", userSource, StringComparison.Ordinal);
        Assert.Contains("support.attachment_file_required", userSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Support attachment file is required.", userSource, StringComparison.Ordinal);
        Assert.Contains("var fileName = NormalizeAttachmentFileName(file);", userSource, StringComparison.Ordinal);
        Assert.Contains("AttachmentFileName: fileName", userSource, StringComparison.Ordinal);
        Assert.Contains("new SupportAttachmentUploadCommand(", userSource, StringComparison.Ordinal);
        Assert.Contains("fileName,", userSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Path.GetFileName(file.FileName)", userSource, StringComparison.Ordinal);
        Assert.True(
            userSource.IndexOf("var metadataValidationErrors = ValidateSingleAttachmentMetadata(file, attachmentStorage);", StringComparison.Ordinal)
                < userSource.IndexOf("var createMessageResult = await service.CreateAttachmentMessageAsync(", StringComparison.Ordinal));
        Assert.True(
            userSource.IndexOf("var metadataValidationErrors = ValidateSingleAttachmentMetadata(file, attachmentStorage);", StringComparison.Ordinal)
                < userSource.IndexOf("await using var stream = file.OpenReadStream();", StringComparison.Ordinal));

        Assert.Contains("var metadataValidationErrors = ValidateSingleAttachmentMetadata(file, attachmentStorage);", adminSource, StringComparison.Ordinal);
        Assert.Contains("support.attachment_file_required", adminSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Support attachment file is required.", adminSource, StringComparison.Ordinal);
        Assert.Contains("var fileName = NormalizeAttachmentFileName(file);", adminSource, StringComparison.Ordinal);
        Assert.Contains("AttachmentFileName: fileName", adminSource, StringComparison.Ordinal);
        Assert.Contains("new SupportAttachmentUploadCommand(", adminSource, StringComparison.Ordinal);
        Assert.Contains("fileName,", adminSource, StringComparison.Ordinal);
        Assert.DoesNotContain("Path.GetFileName(file.FileName)", adminSource, StringComparison.Ordinal);
        Assert.True(
            adminSource.IndexOf("var metadataValidationErrors = ValidateSingleAttachmentMetadata(file, attachmentStorage);", StringComparison.Ordinal)
                < adminSource.IndexOf("var createMessageResult = await service.CreateAttachmentMessageAsync(", StringComparison.Ordinal));
        Assert.True(
            adminSource.IndexOf("var metadataValidationErrors = ValidateSingleAttachmentMetadata(file, attachmentStorage);", StringComparison.Ordinal)
                < adminSource.IndexOf("await using var stream = file.OpenReadStream();", StringComparison.Ordinal));
    }

    [Fact]
    public void SupportChatAdminAttachmentEndpoints_ShouldReturnFallbackUpdateError()
    {
        var adminSource = ReadEndpointSource("SupportChatEndpoints.AdminAttachments.cs");

        Assert.Contains("return ToProblem(failedStatusResult.Error);", adminSource, StringComparison.Ordinal);
        Assert.DoesNotContain("return ToProblem(completeStatusResult.Error);", adminSource, StringComparison.Ordinal);
    }

    private static string ReadEndpointSource(string fileName)
    {
        return File.ReadAllText(Path.Combine(
            FindRepositoryRoot(),
            "src",
            "Modules",
            "SupportChat",
            "PetMagic.Modules.SupportChat.Api",
            "Endpoints",
            fileName));
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
}
