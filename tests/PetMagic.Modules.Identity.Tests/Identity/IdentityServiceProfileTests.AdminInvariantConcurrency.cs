using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Identity.Application.Contracts;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed partial class IdentityServiceProfileTests
{
    [Theory]
    [InlineData("revoke")]
    [InlineData("block")]
    [InlineData("delete")]
    public async Task AdminInvariant_ShouldKeepOneActiveAdmin_WhenDestructiveActionsRunConcurrently(string action)
    {
        var databaseName = $"identity-admin-invariant-{Guid.NewGuid():N}";
        var databaseRoot = new InMemoryDatabaseRoot();
        var firstAdmin = CreateListUser("first-admin@petmagic.app", DateTime.UtcNow);
        var secondAdmin = CreateListUser("second-admin@petmagic.app", DateTime.UtcNow);

        await using (var setupIdentityDb = CreateIdentityDbContext(databaseName, databaseRoot))
        await using (var setupEconomyDb = CreateEconomyDbContext())
        await using (var setupTemplatesDb = CreateTemplatesDbContext())
        {
            _ = await CreateServiceAsync(
                setupIdentityDb,
                setupEconomyDb,
                setupTemplatesDb,
                new TrackingAvatarStorage());

            setupIdentityDb.Users.AddRange(firstAdmin, secondAdmin);
            await setupIdentityDb.SaveChangesAsync();
            await AddUserRoleAsync(setupIdentityDb, firstAdmin.Id, SystemRoles.Admin);
            await AddUserRoleAsync(setupIdentityDb, secondAdmin.Id, SystemRoles.Admin);
        }

        await using var firstIdentityDb = CreateIdentityDbContext(databaseName, databaseRoot);
        await using var firstEconomyDb = CreateEconomyDbContext();
        await using var firstTemplatesDb = CreateTemplatesDbContext();
        await using var secondIdentityDb = CreateIdentityDbContext(databaseName, databaseRoot);
        await using var secondEconomyDb = CreateEconomyDbContext();
        await using var secondTemplatesDb = CreateTemplatesDbContext();

        var firstService = await CreateServiceAsync(
            firstIdentityDb,
            firstEconomyDb,
            firstTemplatesDb,
            new TrackingAvatarStorage());
        var secondService = await CreateServiceAsync(
            secondIdentityDb,
            secondEconomyDb,
            secondTemplatesDb,
            new TrackingAvatarStorage());

        var start = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        var firstMutation = Task.Run(async () =>
        {
            await start.Task;
            return await ApplyDestructiveAdminActionAsync(firstService, firstAdmin.Id, action);
        });
        var secondMutation = Task.Run(async () =>
        {
            await start.Task;
            return await ApplyDestructiveAdminActionAsync(secondService, secondAdmin.Id, action);
        });

        start.SetResult(true);
        var results = await Task.WhenAll(firstMutation, secondMutation);

        _ = Assert.Single(results, result => result.IsSuccess);
        var rejectedResult = Assert.Single(results, result => result.IsFailure);
        Assert.Equal("users.cannot_remove_last_admin", rejectedResult.Error.Code);

        await using var verificationDb = CreateIdentityDbContext(databaseName, databaseRoot);
        var adminRoleId = await verificationDb.Roles
            .Where(role => role.Name == SystemRoles.Admin)
            .Select(role => role.Id)
            .SingleAsync();
        var activeAdminCount = await verificationDb.UserRoles
            .Where(userRole => userRole.RoleId == adminRoleId)
            .Join(
                verificationDb.Users.Where(user => user.IsActive),
                userRole => userRole.UserId,
                user => user.Id,
                (_, _) => 1)
            .CountAsync();

        Assert.Equal(1, activeAdminCount);
    }

    private static Task<Result> ApplyDestructiveAdminActionAsync(
        IdentityService service,
        Guid userId,
        string action)
    {
        return action switch
        {
            "revoke" => service.RevokeRoleAsync(
                new RevokeRoleCommand(userId, SystemRoles.Admin),
                CancellationToken.None),
            "block" => service.SetUserActiveStatusAsync(
                new SetUserActiveStatusCommand(userId, IsActive: false),
                CancellationToken.None),
            "delete" => service.DeleteAdminUserAsync(
                new DeleteAdminUserCommand(userId),
                CancellationToken.None),
            _ => throw new ArgumentOutOfRangeException(nameof(action), action, null)
        };
    }
}
