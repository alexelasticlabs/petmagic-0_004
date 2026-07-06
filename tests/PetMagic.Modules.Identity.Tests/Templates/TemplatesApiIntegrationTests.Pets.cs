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
        Assert.Contains("pets.type_invalid", body, StringComparison.Ordinal);
        Assert.DoesNotContain("Pet type must be dog, cat, or other.", body, StringComparison.Ordinal);
    }

    [Fact]
    public async Task StartFromPet_WithTooLongIdempotencyKey_ShouldReturnValidationProblem()
    {
        await using var application = await TestApplication.CreateAsync();

        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/templates/generations/from-pet")
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
        Assert.Contains("templates.idempotency_key_invalid", body, StringComparison.Ordinal);
        Assert.DoesNotContain("must be at most 256 characters", body, StringComparison.Ordinal);
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
        Assert.DoesNotContain("Pet request could not be completed.", body, StringComparison.Ordinal);
        Assert.DoesNotContain("\"detail\"", body, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task PetListEndpoints_ShouldReturnPrivateCacheHeaders()
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

        using var userListResponse = await application.Client.GetAsync("/api/pets");
        userListResponse.EnsureSuccessStatusCode();
        AssertPrivatePetResponseHeaders(userListResponse);

        using var adminListResponse = await application.Client.GetAsync($"/api/admin/users/{TestUserId}/pets");
        adminListResponse.EnsureSuccessStatusCode();
        AssertPrivatePetResponseHeaders(adminListResponse);

        var pets = await userListResponse.Content.ReadFromJsonAsync<IReadOnlyList<PetResponse>>(JsonOptions);
        Assert.Contains(pets ?? [], item => item.Id == pet.Id);
    }

    private static void AssertPrivatePetResponseHeaders(HttpResponseMessage response)
    {
        Assert.Equal("no-store", response.Headers.CacheControl?.ToString());
        Assert.Contains(response.Headers.Pragma, value => string.Equals(value.Name, "no-cache", StringComparison.OrdinalIgnoreCase));
        Assert.True(response.Headers.TryGetValues("X-Content-Type-Options", out var contentTypeOptions));
        Assert.Contains("nosniff", contentTypeOptions);
    }
}
