using PetMagic.Modules.SupportChat.Application.Abstractions;
using PetMagic.Modules.SupportChat.Application.Contracts;

namespace PetMagic.Modules.SupportChat.Api.Endpoints;

public static partial class SupportChatEndpoints
{
    private static SupportConversationDetailResponse SignAttachmentUrls(
        SupportConversationDetailResponse response,
        ISupportAttachmentReadUrlSigner signer)
    {
        return response with
        {
            Messages = response.Messages.Select(message => SignAttachmentUrls(message, signer)).ToList()
        };
    }

    private static SupportMessageResponse SignAttachmentUrls(
        SupportMessageResponse response,
        ISupportAttachmentReadUrlSigner signer)
    {
        return response with
        {
            Attachments = response.Attachments
                .Select(attachment => attachment with
                {
                    FileUrl = attachment.IsDeleted ? string.Empty : signer.CreateReadUrl(attachment.FileUrl)
                })
                .ToList()
        };
    }
}
