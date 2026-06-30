using PetMagic.Modules.Identity.Domain.Enums;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed partial class IdentityServiceProfileTests
{
    [Fact]
    public async Task GetCurrentUserAsync_ShouldReturnSignedAvatarUrl()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());

        var user = CreateListUser("avatar-user@petmagic.app", DateTime.UtcNow);
        user.AvatarUrl = "http://localhost:5000/user-avatars/2026/06/avatar.jpg";
        user.AvatarFileName = "avatar.jpg";
        user.AvatarContentType = "image/jpeg";
        identityDb.Users.Add(user);
        await identityDb.SaveChangesAsync();

        var result = await service.GetCurrentUserAsync(user.Id, CancellationToken.None);

        Assert.True(result.IsSuccess);
        Assert.NotNull(result.Value.Avatar);
        AssertSignedAvatarUrl(result.Value.Avatar!.Url);
    }

    [Fact]
    public async Task ListUsersAsync_ShouldReturnSignedAvatarUrls()
    {
        await using var identityDb = CreateIdentityDbContext();
        await using var economyDb = CreateEconomyDbContext();
        await using var templatesDb = CreateTemplatesDbContext();
        var service = await CreateServiceAsync(identityDb, economyDb, templatesDb, new TrackingAvatarStorage());
        var user = CreateListUser("avatar-admin-list@petmagic.app", DateTime.UtcNow);
        user.AvatarUrl = "http://localhost:5000/user-avatars/2026/06/list-avatar.jpg";
        user.AvatarFileName = "list-avatar.jpg";
        user.AvatarContentType = "image/jpeg";
        identityDb.Users.Add(user);
        await identityDb.SaveChangesAsync();
        await AddUserRoleAsync(identityDb, user.Id, SystemRoles.User);

        var result = await service.ListUsersAsync(0, 10, null, null, null, null, CancellationToken.None);

        Assert.True(result.IsSuccess);
        var item = Assert.Single(result.Value.Items);
        Assert.NotNull(item.Avatar);
        AssertSignedAvatarUrl(item.Avatar!.Url);
    }

    private static void AssertSignedAvatarUrl(string avatarUrl)
    {
        var uri = new Uri(avatarUrl);
        Assert.Contains("/user-avatars/", uri.AbsolutePath, StringComparison.OrdinalIgnoreCase);
        var query = Microsoft.AspNetCore.WebUtilities.QueryHelpers.ParseQuery(uri.Query);
        Assert.True(query.TryGetValue("pmexp", out var expiresAt));
        Assert.True(query.TryGetValue("pmsig", out var signature));
        Assert.False(string.IsNullOrWhiteSpace(expiresAt.ToString()));
        Assert.False(string.IsNullOrWhiteSpace(signature.ToString()));
    }
}
