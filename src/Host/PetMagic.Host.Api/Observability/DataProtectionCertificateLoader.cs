using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

using Microsoft.Extensions.Logging;

namespace PetMagic.Host.Api.Observability;

public static class DataProtectionCertificateLoader
{
    public static X509Certificate2 LoadOrCreateDevelopmentCertificate(
        string certificatePath,
        string certificatePassword,
        string applicationName,
        ILogger? logger = null)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(certificatePath)!);

        if (File.Exists(certificatePath))
        {
            try
            {
                var existingCertificate = X509CertificateLoader.LoadPkcs12FromFile(
                    certificatePath,
                    certificatePassword,
                    X509KeyStorageFlags.Exportable | X509KeyStorageFlags.PersistKeySet);
                logger?.LogInformation(
                    "Development Data Protection certificate loaded. CertificatePath={CertificatePath} ApplicationName={ApplicationName}",
                    certificatePath,
                    applicationName);
                return existingCertificate;
            }
            catch (CryptographicException exception)
            {
                logger?.LogWarning(
                    exception,
                    "Development Data Protection certificate is unreadable and will be regenerated. CertificatePath={CertificatePath} ApplicationName={ApplicationName}",
                    certificatePath,
                    applicationName);
                File.Delete(certificatePath);
            }
        }

        using var rsa = RSA.Create(2048);
        var subject = $"CN={applicationName} Data Protection";
        var request = new CertificateRequest(
            new X500DistinguishedName(subject),
            rsa,
            HashAlgorithmName.SHA256,
            RSASignaturePadding.Pkcs1);

        request.CertificateExtensions.Add(
            new X509BasicConstraintsExtension(false, false, 0, false));
        request.CertificateExtensions.Add(
            new X509KeyUsageExtension(X509KeyUsageFlags.KeyEncipherment | X509KeyUsageFlags.DigitalSignature, false));
        request.CertificateExtensions.Add(
            new X509SubjectKeyIdentifierExtension(request.PublicKey, false));

        using var certificate = request.CreateSelfSigned(
            DateTimeOffset.UtcNow.AddDays(-1),
            DateTimeOffset.UtcNow.AddYears(5));

        File.WriteAllBytes(
            certificatePath,
            certificate.Export(X509ContentType.Pfx, certificatePassword));

        logger?.LogInformation(
            "Development Data Protection certificate generated. CertificatePath={CertificatePath} ApplicationName={ApplicationName}",
            certificatePath,
            applicationName);

        return X509CertificateLoader.LoadPkcs12FromFile(
            certificatePath,
            certificatePassword,
            X509KeyStorageFlags.Exportable | X509KeyStorageFlags.PersistKeySet);
    }
}
