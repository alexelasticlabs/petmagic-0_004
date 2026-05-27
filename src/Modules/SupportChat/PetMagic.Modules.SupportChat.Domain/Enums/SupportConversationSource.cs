using System.Text.Json.Serialization;

namespace PetMagic.Modules.SupportChat.Domain.Enums;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum SupportConversationSource
{
    [Obsolete("Use MobileChat.")]
    Direct = 0,
    MobileAssistant = 1,
    MobileChat = 2,
    AdminCreated = 3,
    System = 4,
}
