namespace PetMagic.Modules.SupportChat.Application.Abstractions;

public interface ISupportAttachmentReadUrlSigner
{
    string CreateReadUrl(string fileUrl);

    bool IsAuthorizedRequest(string requestPath, IReadOnlyDictionary<string, string?> query);
}
