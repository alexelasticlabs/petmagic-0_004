namespace PetMagic.Modules.Identity.Infrastructure.Options;

public sealed class EmailOptions
{
    public const string SectionName = "Email";

    public string Host { get; init; } = string.Empty;

    public int Port { get; init; } = 2525;

    public string Username { get; init; } = string.Empty;

    public string Password { get; init; } = string.Empty;

    public bool UseSsl { get; init; } = true;

    public string FromAddress { get; init; } = "no-reply@petmagic.local";

    public string FromName { get; init; } = "PetMagic";

    public int VerificationCodeLength { get; init; } = 6;

    public int VerificationCodeTtlMinutes { get; init; } = 10;

    public int PasswordResetCodeTtlMinutes { get; init; } = 10;

    public int ConfirmationResendCooldownSeconds { get; init; } = 60;

    public bool DispatchWorkerEnabled { get; init; } = true;

    public int DispatchPollIntervalMilliseconds { get; init; } = 1_000;

    public int MaxDispatchAttempts { get; init; } = 3;

    public int RetryDelaySeconds { get; init; } = 30;

    public int ProcessingLeaseSeconds { get; init; } = 120;

    public int CompletedDispatchRetentionDays { get; init; } = 7;

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(Host)
        && !string.IsNullOrWhiteSpace(FromAddress);

    public bool HasCredentials =>
        !string.IsNullOrWhiteSpace(Username)
        && !string.IsNullOrWhiteSpace(Password);

    public bool IsProductionConfigured => IsConfigured && HasCredentials;
}
