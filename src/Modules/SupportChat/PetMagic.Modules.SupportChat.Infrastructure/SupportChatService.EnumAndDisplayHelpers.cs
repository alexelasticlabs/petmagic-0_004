using PetMagic.Modules.SupportChat.Domain.Enums;

namespace PetMagic.Modules.SupportChat.Infrastructure;

public sealed partial class SupportChatService
{
    private static bool TryParseNamedEnum<TEnum>(string? raw, out TEnum value)
        where TEnum : struct, Enum
    {
        value = default;

        if (string.IsNullOrWhiteSpace(raw))
        {
            return false;
        }

        var trimmed = raw.Trim();
        if (IsIntegerLiteral(trimmed))
        {
            return false;
        }

        return Enum.TryParse<TEnum>(trimmed, ignoreCase: true, out value)
            && Enum.IsDefined(value);
    }

    private static bool IsIntegerLiteral(string value)
    {
        return int.TryParse(value, out _);
    }

    private static string ResolveSenderDisplayType(
        SupportMessageSenderType senderType,
        bool isFromAdmin) =>
        senderType switch
        {
            SupportMessageSenderType.System => nameof(SupportMessageSenderType.System),
            SupportMessageSenderType.Bot => nameof(SupportMessageSenderType.Bot),
            SupportMessageSenderType.SupportAgent => nameof(SupportMessageSenderType.SupportAgent),
            _ when isFromAdmin => nameof(SupportMessageSenderType.SupportAgent),
            _ => nameof(SupportMessageSenderType.User)
        };

    private static string ResolveMessageSenderDisplayName(
        SupportMessageSenderType senderType,
        string? email,
        string? displayName,
        bool isFromAdmin)
    {
        return senderType switch
        {
            SupportMessageSenderType.System => "System",
            SupportMessageSenderType.Bot => "PetMagic Assistant",
            _ => ResolveDisplayName(email, displayName, isAdminSender: isFromAdmin)
        };
    }

    private static string ResolveDisplayName(
        string? email,
        string? displayName,
        bool isAdminSender = false)
    {
        if (!string.IsNullOrWhiteSpace(displayName))
        {
            return displayName.Trim();
        }

        if (!string.IsNullOrWhiteSpace(email))
        {
            return email.Trim();
        }

        return isAdminSender ? "Support Team" : "Unknown user";
    }

    private static string? Truncate(string? value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        var trimmed = value.Trim();
        if (trimmed.Length <= maxLength)
        {
            return trimmed;
        }

        return trimmed[..maxLength];
    }
}
