using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authentication.OAuth;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

public static class IdentityInfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddIdentityInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));
        services.Configure<BootstrapAdminOptions>(configuration.GetSection(BootstrapAdminOptions.SectionName));

        var externalAuth = configuration.GetSection(ExternalAuthOptions.SectionName).Get<ExternalAuthOptions>() ?? new ExternalAuthOptions();
        var jwtOptions = configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();

        services.AddDbContext<IdentityDbContext>(options =>
        {
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });

        services.AddIdentityCore<AppUser>(options =>
            {
                options.Password.RequiredLength = 10;
                options.Password.RequireDigit = true;
                options.Password.RequireUppercase = true;
                options.Password.RequireLowercase = true;
                options.User.RequireUniqueEmail = true;
                options.Lockout.MaxFailedAccessAttempts = 8;
                options.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
            })
            .AddRoles<IdentityRole<Guid>>()
            .AddSignInManager<SignInManager<AppUser>>()
            .AddEntityFrameworkStores<IdentityDbContext>()
            .AddDefaultTokenProviders();

        services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
            })
            .AddCookie(IdentityConstants.ExternalScheme)
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = jwtOptions.Issuer,
                    ValidAudience = jwtOptions.Audience,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtOptions.SigningKey))
                };
            });

        AddExternalProviders(services, externalAuth);

        services.AddAuthorizationBuilder()
            .AddPolicy("AdminOnly", policy => policy.RequireRole(SystemRoles.Admin))
            .AddPolicy("ModeratorOrAdmin", policy => policy.RequireRole(SystemRoles.Moderator, SystemRoles.Admin));

        services.AddScoped<IIdentityService, IdentityService>();

        return services;
    }

    public static async Task EnsureIdentitySeedDataAsync(this IServiceProvider serviceProvider)
    {
        using var scope = serviceProvider.CreateScope();

        var dbContext = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();
        await dbContext.Database.MigrateAsync();

        var roleManager = scope.ServiceProvider.GetRequiredService<RoleManager<IdentityRole<Guid>>>();
        foreach (var role in SystemRoles.All)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole<Guid>(role));
            }
        }

        var options = scope.ServiceProvider.GetRequiredService<Microsoft.Extensions.Options.IOptions<BootstrapAdminOptions>>().Value;
        if (string.IsNullOrWhiteSpace(options.Email) || string.IsNullOrWhiteSpace(options.Password))
        {
            return;
        }

        var userManager = scope.ServiceProvider.GetRequiredService<UserManager<AppUser>>();
        var existing = await userManager.FindByEmailAsync(options.Email);
        if (existing is not null)
        {
            return;
        }

        var admin = new AppUser
        {
            Id = Guid.NewGuid(),
            Email = options.Email,
            UserName = options.Email,
            DisplayName = options.DisplayName,
            IsActive = true,
            IsPremium = true,
            CreatedAtUtc = DateTime.UtcNow
        };

        var createResult = await userManager.CreateAsync(admin, options.Password);
        if (!createResult.Succeeded)
        {
            return;
        }

        await userManager.AddToRoleAsync(admin, SystemRoles.Admin);
    }

    private static void AddExternalProviders(IServiceCollection services, ExternalAuthOptions options)
    {
        if (!string.IsNullOrWhiteSpace(options.Google.ClientId) && !string.IsNullOrWhiteSpace(options.Google.ClientSecret))
        {
            services.AddAuthentication()
                .AddGoogle("Google", google =>
                {
                    google.ClientId = options.Google.ClientId;
                    google.ClientSecret = options.Google.ClientSecret;
                    google.SignInScheme = IdentityConstants.ExternalScheme;
                });
        }

        if (!string.IsNullOrWhiteSpace(options.Apple.ClientId) &&
            !string.IsNullOrWhiteSpace(options.Apple.ClientSecret) &&
            !string.IsNullOrWhiteSpace(options.Apple.AuthorizationEndpoint) &&
            !string.IsNullOrWhiteSpace(options.Apple.TokenEndpoint))
        {
            services.AddAuthentication()
                .AddOAuth("Apple", apple => ConfigureAppleOAuth(apple, options.Apple));
        }
    }

    private static void ConfigureAppleOAuth(OAuthOptions options, ExternalAuthOptions.OAuthProviderOptions apple)
    {
        options.ClientId = apple.ClientId;
        options.ClientSecret = apple.ClientSecret;
        options.AuthorizationEndpoint = apple.AuthorizationEndpoint;
        options.TokenEndpoint = apple.TokenEndpoint;
        options.CallbackPath = "/signin-apple";
        options.SignInScheme = IdentityConstants.ExternalScheme;
        options.Scope.Add("email");
        options.Scope.Add("name");
        options.ClaimActions.MapJsonKey("sub", "sub");
        options.ClaimActions.MapJsonKey("email", "email");
        options.ClaimActions.MapJsonKey("name", "name");
        options.SaveTokens = true;
    }
}
