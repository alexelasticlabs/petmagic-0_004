using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;

namespace PetMagic.Modules.Identity.Tests.Identity;

public sealed class IdentityUserLookupServiceTests
{
    [Fact]
    public async Task GetActiveUserIdsInRolesAsync_ShouldExcludeInactiveAndUnrelatedUsers()
    {
        var options = new DbContextOptionsBuilder<IdentityDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString("N"))
            .Options;
        await using var dbContext = new IdentityDbContext(options);

        var adminRole = CreateRole(SystemRoles.Admin);
        var moderatorRole = CreateRole(SystemRoles.Moderator);
        var userRole = CreateRole(SystemRoles.User);
        var activeAdmin = CreateUser("active-admin@petmagic.app", isActive: true);
        var activeModerator = CreateUser("active-moderator@petmagic.app", isActive: true);
        var inactiveAdmin = CreateUser("inactive-admin@petmagic.app", isActive: false);
        var activeUser = CreateUser("active-user@petmagic.app", isActive: true);

        dbContext.Roles.AddRange(adminRole, moderatorRole, userRole);
        dbContext.Users.AddRange(activeAdmin, activeModerator, inactiveAdmin, activeUser);
        await dbContext.SaveChangesAsync();
        dbContext.UserRoles.AddRange(
            new IdentityUserRole<Guid> { UserId = activeAdmin.Id, RoleId = adminRole.Id },
            new IdentityUserRole<Guid> { UserId = activeModerator.Id, RoleId = moderatorRole.Id },
            new IdentityUserRole<Guid> { UserId = inactiveAdmin.Id, RoleId = adminRole.Id },
            new IdentityUserRole<Guid> { UserId = activeUser.Id, RoleId = userRole.Id });
        await dbContext.SaveChangesAsync();

        var service = new IdentityUserLookupService(dbContext);

        var result = await service.GetActiveUserIdsInRolesAsync(
            [SystemRoles.Admin, SystemRoles.Moderator],
            CancellationToken.None);

        var expected = new[] { activeAdmin.Id, activeModerator.Id };
        Assert.Equal(expected.OrderBy(id => id), result.OrderBy(id => id));
    }

    private static IdentityRole<Guid> CreateRole(string name)
    {
        return new IdentityRole<Guid>(name)
        {
            Id = Guid.NewGuid(),
            NormalizedName = name.ToUpperInvariant()
        };
    }

    private static AppUser CreateUser(string email, bool isActive)
    {
        return new AppUser
        {
            Id = Guid.NewGuid(),
            Email = email,
            UserName = email,
            NormalizedEmail = email.ToUpperInvariant(),
            NormalizedUserName = email.ToUpperInvariant(),
            IsActive = isActive,
            CreatedAtUtc = DateTime.UtcNow
        };
    }
}
