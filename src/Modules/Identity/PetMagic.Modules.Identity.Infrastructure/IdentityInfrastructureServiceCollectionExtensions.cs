using System.Text;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authentication.OAuth;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.IdentityModel.Tokens;
using PetMagic.Modules.Identity.Application.Abstractions;
using PetMagic.Modules.Identity.Domain.Enums;
using PetMagic.Modules.Identity.Infrastructure.Data;
using PetMagic.Modules.Identity.Infrastructure.Entities;
using PetMagic.Modules.Identity.Infrastructure.Options;

namespace PetMagic.Modules.Identity.Infrastructure;

public static class IdentityInfrastructureServiceCollectionExtensions
{
    public static IServiceCollection AddIdentityInfrastructure(this IServiceCollection services, IConfiguration configuration, IHostEnvironment? environment = null)
    {
        services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));
        services.Configure<BootstrapAdminOptions>(configuration.GetSection(BootstrapAdminOptions.SectionName));

        var externalAuth = BuildExternalAuthOptions(configuration.GetSection(ExternalAuthOptions.SectionName));
        var jwtOptions = configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();
        var emailOptions = BuildEmailOptions(configuration.GetSection(EmailOptions.SectionName));
        var avatarStorageOptions = BuildAvatarStorageOptions(configuration.GetSection(AvatarStorageOptions.SectionName));

        ValidateExternalAuthConfiguration(externalAuth);

        services.AddDbContext<IdentityDbContext>(options =>
        {
            options.UseNpgsql(configuration.GetConnectionString("DefaultConnection"));
        });

        services.AddIdentityCore<AppUser>(options =>
            {
                options.Password.RequiredLength = 6;
                options.Password.RequireDigit = false;
                options.Password.RequireUppercase = false;
                options.Password.RequireLowercase = false;
                options.Password.RequireNonAlphanumeric = false;
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

        ValidateProductionEmailConfiguration(emailOptions, environment);

        services.AddSingleton(externalAuth);
        services.AddSingleton(emailOptions);
        services.AddSingleton(avatarStorageOptions);
        services.AddSingleton<IIdentityEmailTemplateRenderer, IdentityEmailTemplateRenderer>();
        services.AddSingleton<IAvatarStorage, LocalAvatarStorage>();
        services.AddScoped<IGoogleIdentityTokenVerifier, GoogleIdentityTokenVerifier>();
        services.AddScoped<IEmailSender, SmtpEmailSender>();
        services.AddScoped<EmailDispatchProcessor>();
        services.AddHostedService<EmailDispatchWorker>();
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
            existing.UserName = options.Email;
            existing.DisplayName = options.DisplayName;
            existing.EmailConfirmed = true;
            existing.IsActive = true;
            existing.IsPremium = true;

            await userManager.UpdateAsync(existing);

            var passwordValid = await userManager.CheckPasswordAsync(existing, options.Password);
            if (!passwordValid)
            {
                var resetToken = await userManager.GeneratePasswordResetTokenAsync(existing);
                await userManager.ResetPasswordAsync(existing, resetToken, options.Password);
            }

            if (!await userManager.IsInRoleAsync(existing, SystemRoles.Admin))
            {
                await userManager.AddToRoleAsync(existing, SystemRoles.Admin);
            }

            return;
        }

        var admin = new AppUser
        {
            Id = Guid.NewGuid(),
            Email = options.Email,
            EmailConfirmed = true,
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
                    google.CallbackPath = "/signin-google";
                    google.SignInScheme = IdentityConstants.ExternalScheme;
                    google.SaveTokens = true;
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

    private static ExternalAuthOptions BuildExternalAuthOptions(IConfigurationSection section)
    {
        return new ExternalAuthOptions
        {
            Google = new ExternalAuthOptions.GoogleOAuthOptions
            {
                ClientId = ReadValue(section.GetSection("Google"), "ClientId", "GOOGLE_CLIENT_ID") ?? string.Empty,
                ClientSecret = ReadValue(section.GetSection("Google"), "ClientSecret", "GOOGLE_CLIENT_SECRET") ?? string.Empty
            },
            Apple = new ExternalAuthOptions.OAuthProviderOptions
            {
                ClientId = ReadValue(section.GetSection("Apple"), "ClientId", "APPLE_CLIENT_ID") ?? string.Empty,
                ClientSecret = ReadValue(section.GetSection("Apple"), "ClientSecret", "APPLE_CLIENT_SECRET") ?? string.Empty,
                AuthorizationEndpoint = ReadValue(section.GetSection("Apple"), "AuthorizationEndpoint", "APPLE_AUTHORIZATION_ENDPOINT") ?? string.Empty,
                TokenEndpoint = ReadValue(section.GetSection("Apple"), "TokenEndpoint", "APPLE_TOKEN_ENDPOINT") ?? string.Empty
            }
        };
    }

    private static EmailOptions BuildEmailOptions(IConfigurationSection section)
    {
        return new EmailOptions
        {
            Host = ReadValue(section, "Host", "EMAIL_HOST") ?? string.Empty,
            Port = ParseInt(ReadValue(section, "Port", "EMAIL_PORT"), 2525),
            Username = ReadValue(section, "Username", "EMAIL_USERNAME") ?? string.Empty,
            Password = ReadValue(section, "Password", "EMAIL_PASSWORD") ?? string.Empty,
            UseSsl = ParseBool(ReadValue(section, "UseSsl", "EMAIL_USE_SSL"), true),
            FromAddress = ReadValue(section, "FromAddress", "EMAIL_FROM_ADDRESS") ?? "no-reply@petmagic.local",
            FromName = ReadValue(section, "FromName", "EMAIL_FROM_NAME") ?? "PetMagic",
            VerificationCodeLength = ParseInt(section["VerificationCodeLength"], 6),
            VerificationCodeTtlMinutes = ParseInt(section["VerificationCodeTtlMinutes"], 15),
            PasswordResetCodeTtlMinutes = ParseInt(section["PasswordResetCodeTtlMinutes"], 15),
            ConfirmationResendCooldownSeconds = ParseInt(section["ConfirmationResendCooldownSeconds"], 60),
            DispatchWorkerEnabled = ParseBool(section["DispatchWorkerEnabled"], true),
            DispatchPollIntervalMilliseconds = ParseInt(section["DispatchPollIntervalMilliseconds"], 1_000),
            MaxDispatchAttempts = ParsePositiveInt(section["MaxDispatchAttempts"], 3),
            RetryDelaySeconds = ParseNonNegativeInt(section["RetryDelaySeconds"], 30),
            CompletedDispatchRetentionDays = ParseInt(section["CompletedDispatchRetentionDays"], 7)
        };
    }

    private static AvatarStorageOptions BuildAvatarStorageOptions(IConfigurationSection section)
    {
        return new AvatarStorageOptions
        {
            PublicBaseUrl = section["PublicBaseUrl"] ?? "http://localhost:5000",
            LocalMediaRootPath = section["LocalMediaRootPath"] ?? Path.Combine("wwwroot", "user-avatars"),
            MaxFileSizeBytes = ParsePositiveLong(section["MaxFileSizeBytes"], 5 * 1024 * 1024)
        };
    }

    private static string? ReadValue(IConfigurationSection section, string key, string environmentVariableName)
    {
        var configured = section[key];
        if (!string.IsNullOrWhiteSpace(configured))
        {
            return configured;
        }

        return Environment.GetEnvironmentVariable(environmentVariableName);
    }

    private static int ParseInt(string? rawValue, int fallback)
    {
        return int.TryParse(rawValue, out var parsed) ? parsed : fallback;
    }

    private static int ParsePositiveInt(string? rawValue, int fallback)
    {
        return int.TryParse(rawValue, out var parsed) && parsed > 0 ? parsed : fallback;
    }

    private static long ParsePositiveLong(string? rawValue, long fallback)
    {
        return long.TryParse(rawValue, out var parsed) && parsed > 0 ? parsed : fallback;
    }

    private static int ParseNonNegativeInt(string? rawValue, int fallback)
    {
        return int.TryParse(rawValue, out var parsed) && parsed >= 0 ? parsed : fallback;
    }

    private static bool ParseBool(string? rawValue, bool fallback)
    {
        return bool.TryParse(rawValue, out var parsed) ? parsed : fallback;
    }

    private static void ValidateExternalAuthConfiguration(ExternalAuthOptions options)
    {
        var googleClientIdConfigured = !string.IsNullOrWhiteSpace(options.Google.ClientId);
        var googleClientSecretConfigured = !string.IsNullOrWhiteSpace(options.Google.ClientSecret);
        if (googleClientIdConfigured != googleClientSecretConfigured)
        {
            throw new InvalidOperationException("Google external auth configuration is incomplete. Configure both ClientId and ClientSecret.");
        }

        var appleClientIdConfigured = !string.IsNullOrWhiteSpace(options.Apple.ClientId);
        var appleClientSecretConfigured = !string.IsNullOrWhiteSpace(options.Apple.ClientSecret);
        var appleAuthorizationConfigured = !string.IsNullOrWhiteSpace(options.Apple.AuthorizationEndpoint);
        var appleTokenConfigured = !string.IsNullOrWhiteSpace(options.Apple.TokenEndpoint);

        if (appleClientIdConfigured != appleClientSecretConfigured)
        {
            throw new InvalidOperationException("Apple external auth configuration is incomplete. Configure both ClientId and ClientSecret.");
        }

        var appleCredentialsConfigured = appleClientIdConfigured && appleClientSecretConfigured;
        var appleAllConfigured = appleCredentialsConfigured && appleAuthorizationConfigured && appleTokenConfigured;
        if (appleCredentialsConfigured && !appleAllConfigured)
        {
            throw new InvalidOperationException("Apple external auth configuration is incomplete. Configure ClientId, ClientSecret, AuthorizationEndpoint, and TokenEndpoint together.");
        }
    }

    private static void ValidateProductionEmailConfiguration(EmailOptions options, IHostEnvironment? environment)
    {
        if (environment is null || environment.IsDevelopment() || !options.DispatchWorkerEnabled)
        {
            return;
        }

        if (!options.IsConfigured)
        {
            throw new InvalidOperationException("Email dispatch worker is enabled but SMTP configuration is incomplete.");
        }
    }
}
