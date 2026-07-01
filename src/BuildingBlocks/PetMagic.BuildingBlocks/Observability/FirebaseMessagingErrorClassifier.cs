using System.Net;
using System.Text.Json;

namespace PetMagic.BuildingBlocks.Observability;

public static class FirebaseMessagingErrorClassifier
{
    public static bool ShouldDisableToken(HttpStatusCode statusCode, string? body)
    {
        if (statusCode is not (HttpStatusCode.BadRequest or HttpStatusCode.NotFound))
        {
            return false;
        }

        return ContainsUnregisteredTokenSignal(body)
            || ContainsInvalidRegistrationTokenSignal(body);
    }

    public static string ResolveErrorReason(string? body)
    {
        if (ContainsUnregisteredTokenSignal(body))
        {
            return "unregistered";
        }

        if (ContainsInvalidRegistrationTokenSignal(body))
        {
            return "invalid_registration_token";
        }

        if (ContainsInvalidArgumentSignal(body))
        {
            return "invalid_argument";
        }

        return "fcm_send_failed";
    }

    private static bool ContainsUnregisteredTokenSignal(string? body)
    {
        return ContainsValue(body, "UNREGISTERED");
    }

    private static bool ContainsInvalidRegistrationTokenSignal(string? body)
    {
        if (!ContainsInvalidArgumentSignal(body))
        {
            return false;
        }

        if (ContainsValue(body, "registration token") || ContainsValue(body, "message.token"))
        {
            return true;
        }

        if (!TryParseBody(body, out var root))
        {
            return false;
        }

        return ErrorContainsInvalidTokenField(root)
            || DetailsContainInvalidTokenField(root);
    }

    private static bool ContainsInvalidArgumentSignal(string? body)
    {
        return ContainsValue(body, "INVALID_ARGUMENT");
    }

    private static bool ErrorContainsInvalidTokenField(JsonElement root)
    {
        if (!TryGetError(root, out var error))
        {
            return false;
        }

        if (error.TryGetProperty("message", out var message)
            && message.ValueKind == JsonValueKind.String)
        {
            var value = message.GetString();
            return ContainsValue(value, "registration token") || ContainsValue(value, "message.token");
        }

        return false;
    }

    private static bool DetailsContainInvalidTokenField(JsonElement root)
    {
        if (!TryGetError(root, out var error)
            || !error.TryGetProperty("details", out var details)
            || details.ValueKind != JsonValueKind.Array)
        {
            return false;
        }

        foreach (var detail in details.EnumerateArray())
        {
            if (detail.TryGetProperty("fieldViolations", out var fieldViolations)
                && fieldViolations.ValueKind == JsonValueKind.Array)
            {
                foreach (var violation in fieldViolations.EnumerateArray())
                {
                    if (violation.TryGetProperty("field", out var field)
                        && field.ValueKind == JsonValueKind.String
                        && ContainsValue(field.GetString(), "message.token"))
                    {
                        return true;
                    }

                    if (violation.TryGetProperty("description", out var description)
                        && description.ValueKind == JsonValueKind.String
                        && ContainsValue(description.GetString(), "registration token"))
                    {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    private static bool TryParseBody(string? body, out JsonElement root)
    {
        root = default;
        if (string.IsNullOrWhiteSpace(body))
        {
            return false;
        }

        try
        {
            using var document = JsonDocument.Parse(body);
            root = document.RootElement.Clone();
            return true;
        }
        catch (JsonException)
        {
            return false;
        }
    }

    private static bool TryGetError(JsonElement root, out JsonElement error)
    {
        if (root.ValueKind == JsonValueKind.Object
            && root.TryGetProperty("error", out error)
            && error.ValueKind == JsonValueKind.Object)
        {
            return true;
        }

        error = default;
        return false;
    }

    private static bool ContainsValue(string? value, string expected)
    {
        return !string.IsNullOrWhiteSpace(value)
            && value.Contains(expected, StringComparison.OrdinalIgnoreCase);
    }
}
