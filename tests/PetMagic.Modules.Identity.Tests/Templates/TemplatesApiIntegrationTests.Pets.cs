using System.Net;
using System.Net.Http.Json;

using PetMagic.Modules.Templates.Application.Contracts;

namespace PetMagic.Modules.Identity.Tests.Templates;

public sealed partial class TemplatesApiIntegrationTests
{
    [Fact]
    public async Task CreatePet_WithMissingType_ShouldReturnValidationProblem()
    {
        await using var application = await TestApplication.CreateAsync();

        using var response = await application.Client.PostAsJsonAsync(
            "/api/pets",
            new
            {
                name = "Milo"
            });

        var body = await response.Content.ReadAsStringAsync();
        Assert.True(
            response.StatusCode == HttpStatusCode.BadRequest,
            $"Expected 400 validation problem, got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
        Assert.Contains("Type", body, StringComparison.Ordinal);
        Assert.Contains("Pet type must be dog, cat, or other.", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task StartFromPet_WithTooLongIdempotencyKey_ShouldReturnValidationProblem()
    {
        await using var application = await TestApplication.CreateAsync();

        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/generations/from-pet")
        {
            Content = JsonContent.Create(new
            {
                petId = Guid.NewGuid(),
                templateId = Guid.NewGuid()
            })
        };
        request.Headers.TryAddWithoutValidation("Idempotency-Key", new string('x', 257));

        using var response = await application.Client.SendAsync(request);

        var body = await response.Content.ReadAsStringAsync();
        Assert.True(
            response.StatusCode == HttpStatusCode.BadRequest,
            $"Expected 400 validation problem, got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
        Assert.Contains("Idempotency-Key", body, StringComparison.Ordinal);
        Assert.Contains("must be at most 256 characters", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task AdminPetStatus_WithMissingStatus_ShouldReturnProblemDetailsInsteadOfServerError()
    {
        await using var application = await TestApplication.CreateAsync();

        var pet = await PostAsJsonAsync<PetResponse>(
            application.Client,
            "/api/pets",
            new
            {
                name = "Milo",
                type = "cat"
            });

        using var response = await application.Client.PostAsJsonAsync(
            $"/api/admin/users/{TestUserId}/pets/{pet.Id}/status",
            new { });

        var body = await response.Content.ReadAsStringAsync();
        Assert.True(
            response.StatusCode == HttpStatusCode.BadRequest,
            $"Expected 400 problem details, got {(int)response.StatusCode} {response.StatusCode}. Body: {body}");
        Assert.Contains("pets.invalid_status", body, StringComparison.Ordinal);
        Assert.Contains("Pet status is invalid.", body, StringComparison.Ordinal);
    }
}
