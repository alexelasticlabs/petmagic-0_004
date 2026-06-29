using System.Text.Json.Serialization;

namespace PetMagic.Modules.SupportChat.Domain.Enums;

[JsonConverter(typeof(SupportConversationSourceJsonConverter))]
public enum SupportConversationSource
{
    MobileAssistant = 1,
    MobileChat = 2,
    AdminCreated = 3,
    System = 4,
}
