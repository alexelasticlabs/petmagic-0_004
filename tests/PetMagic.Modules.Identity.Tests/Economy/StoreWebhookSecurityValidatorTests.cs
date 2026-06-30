using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.Json;

using Microsoft.Extensions.Options;

using PetMagic.BuildingBlocks.Results;
using PetMagic.Modules.Economy.Infrastructure;
using PetMagic.Modules.Economy.Infrastructure.Options;
using PetMagic.Modules.Economy.Infrastructure.Payments;

namespace PetMagic.Modules.Identity.Tests.Economy;

public sealed class StoreWebhookSecurityValidatorTests
{
    private const string AppStoreBundleId = "com.petmagic.app";
    private const string AppStoreLeafCertificateOid = "1.2.840.113635.100.6.11.1";
    private const string AppStoreIntermediateCertificateOid = "1.2.840.113635.100.6.2.1";

    [Fact]
    public void ValidateAppStoreSignedPayload_ShouldFail_ForMalformedPayload()
    {
        var validator = CreateValidator();

        var result = validator.ValidateAppStoreSignedPayload("invalid-payload");

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
    }

    [Fact]
    public void ValidateAppStoreSignedPayload_ShouldSucceed_ForTrustedAppleStyleChain()
    {
        using var chain = TestAppleCertificateChain.Create();
        var validator = CreateValidator(trustedAppleRootThumbprints: [chain.Root.Thumbprint]);
        var signedPayload = CreateSignedPayload(chain, DateTimeOffset.UtcNow);

        var result = validator.ValidateAppStoreSignedPayload(signedPayload);

        Assert.True(result.IsSuccess);
    }

    [Fact]
    public void ValidateAppStoreSignedPayload_ShouldFail_WhenRootCertificateIsNotTrusted()
    {
        using var chain = TestAppleCertificateChain.Create();
        var validator = CreateValidator(trustedAppleRootThumbprints: ["0000000000000000000000000000000000000000"]);
        var signedPayload = CreateSignedPayload(chain, DateTimeOffset.UtcNow);

        var result = validator.ValidateAppStoreSignedPayload(signedPayload);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
    }

    [Fact]
    public void ValidateAppStoreSignedPayload_ShouldFail_WhenSignedDateFallsOutsideCertificateValidity()
    {
        var signedDate = DateTimeOffset.UtcNow;
        using var chain = TestAppleCertificateChain.Create(
            leafNotBefore: signedDate.AddDays(1).UtcDateTime,
            leafNotAfter: signedDate.AddDays(30).UtcDateTime);
        var validator = CreateValidator(trustedAppleRootThumbprints: [chain.Root.Thumbprint]);
        var signedPayload = CreateSignedPayload(chain, signedDate);

        var result = validator.ValidateAppStoreSignedPayload(signedPayload);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
    }

    [Fact]
    public async Task ValidateGooglePlayPushAsync_ShouldFail_WhenAuthorizationHeaderMissing()
    {
        var validator = CreateValidator(audience: "https://petmagic.app/webhooks/google-play");

        var result = await validator.ValidateGooglePlayPushAsync(null, CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
    }

    [Fact]
    public async Task ValidateGooglePlayPushAsync_ShouldFail_WhenExpectedEmailDoesNotMatch()
    {
        var validator = CreateValidator(
            audience: "https://petmagic.app/webhooks/google-play",
            expectedEmail: "pubsub@petmagic.app",
            googleTokenVerifier: new FakeGoogleStoreWebhookTokenVerifier(
                Result.Success(new GoogleStoreWebhookTokenPayload(
                    "https://accounts.google.com",
                    "wrong@petmagic.app",
                    true,
                    "subject-1"))));

        var result = await validator.ValidateGooglePlayPushAsync("Bearer token-1", CancellationToken.None);

        Assert.True(result.IsFailure);
        Assert.Equal(EconomyErrors.InvalidStoreWebhookSignature.Code, result.Error.Code);
    }

    [Fact]
    public async Task ValidateGooglePlayPushAsync_ShouldSucceed_WhenTokenMatchesAudienceAndEmail()
    {
        var validator = CreateValidator(
            audience: "https://petmagic.app/webhooks/google-play",
            expectedEmail: "pubsub@petmagic.app",
            googleTokenVerifier: new FakeGoogleStoreWebhookTokenVerifier(
                Result.Success(new GoogleStoreWebhookTokenPayload(
                    "https://accounts.google.com",
                    "pubsub@petmagic.app",
                    true,
                    "subject-1"))));

        var result = await validator.ValidateGooglePlayPushAsync("Bearer token-1", CancellationToken.None);

        Assert.True(result.IsSuccess);
    }

    private static string CreateSignedPayload(
        TestAppleCertificateChain chain,
        DateTimeOffset signedDate)
    {
        var headerJson = JsonSerializer.Serialize(new Dictionary<string, object?>
        {
            ["alg"] = "ES256",
            ["x5c"] = new[]
            {
                Convert.ToBase64String(chain.Leaf.Export(X509ContentType.Cert)),
                Convert.ToBase64String(chain.Intermediate.Export(X509ContentType.Cert)),
                Convert.ToBase64String(chain.Root.Export(X509ContentType.Cert)),
            }
        });
        var payloadJson = JsonSerializer.Serialize(new Dictionary<string, object?>
        {
            ["bundleId"] = AppStoreBundleId,
            ["signedDate"] = signedDate.ToUnixTimeMilliseconds(),
        });

        var encodedHeader = Base64UrlEncode(Encoding.UTF8.GetBytes(headerJson));
        var encodedPayload = Base64UrlEncode(Encoding.UTF8.GetBytes(payloadJson));
        var bytesToSign = Encoding.ASCII.GetBytes($"{encodedHeader}.{encodedPayload}");
        var signature = chain.LeafKey.SignData(bytesToSign, HashAlgorithmName.SHA256);

        return $"{encodedHeader}.{encodedPayload}.{Base64UrlEncode(signature)}";
    }

    private static string Base64UrlEncode(byte[] bytes)
    {
        return Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static byte[] CreateSerialNumber()
    {
        var serial = RandomNumberGenerator.GetBytes(16);
        serial[0] |= 0x01;
        return serial;
    }

    private static X509Extension CreateMarkerExtension(string oid)
    {
        return new X509Extension(new Oid(oid), [0x05, 0x00], critical: false);
    }

    private static CertificateRequest CreateCertificateRequest(
        string subject,
        ECDsa key,
        bool isCertificateAuthority,
        X509Extension? markerExtension = null)
    {
        var request = new CertificateRequest(
            new X500DistinguishedName(subject),
            key,
            HashAlgorithmName.SHA256);

        request.CertificateExtensions.Add(new X509BasicConstraintsExtension(
            isCertificateAuthority,
            isCertificateAuthority,
            isCertificateAuthority ? 1 : 0,
            critical: true));
        request.CertificateExtensions.Add(new X509KeyUsageExtension(
            isCertificateAuthority
                ? X509KeyUsageFlags.KeyCertSign | X509KeyUsageFlags.CrlSign
                : X509KeyUsageFlags.DigitalSignature,
            critical: true));
        request.CertificateExtensions.Add(new X509SubjectKeyIdentifierExtension(request.PublicKey, false));

        if (markerExtension is not null)
        {
            request.CertificateExtensions.Add(markerExtension);
        }

        return request;
    }

    private static StoreWebhookSecurityValidator CreateValidator(
        string audience = "",
        string expectedEmail = "",
        IGoogleStoreWebhookTokenVerifier? googleTokenVerifier = null,
        IEnumerable<string>? trustedAppleRootThumbprints = null)
    {
        var options = Options.Create(new EconomyOptions
        {
            AppStoreBundleId = AppStoreBundleId,
            GooglePlayPubSubAudience = audience,
            GooglePlayPubSubExpectedEmail = expectedEmail,
        });
        var verifier = googleTokenVerifier ?? new FakeGoogleStoreWebhookTokenVerifier(
            Result.Success(new GoogleStoreWebhookTokenPayload(
                "https://accounts.google.com",
                "pubsub@petmagic.app",
                true,
                "subject-1")));

        return trustedAppleRootThumbprints is null
            ? new StoreWebhookSecurityValidator(options, verifier)
            : new StoreWebhookSecurityValidator(options, verifier, trustedAppleRootThumbprints);
    }

    private sealed class FakeGoogleStoreWebhookTokenVerifier(Result<GoogleStoreWebhookTokenPayload> result)
        : IGoogleStoreWebhookTokenVerifier
    {
        public Task<Result<GoogleStoreWebhookTokenPayload>> ValidateAsync(string idToken, string audience, CancellationToken cancellationToken)
        {
            return Task.FromResult(result);
        }
    }

    private sealed class TestAppleCertificateChain : IDisposable
    {
        private readonly ECDsa _rootKey;
        private readonly ECDsa _intermediateKey;

        private TestAppleCertificateChain(
            X509Certificate2 root,
            X509Certificate2 intermediate,
            X509Certificate2 leaf,
            ECDsa rootKey,
            ECDsa intermediateKey,
            ECDsa leafKey)
        {
            Root = root;
            Intermediate = intermediate;
            Leaf = leaf;
            _rootKey = rootKey;
            _intermediateKey = intermediateKey;
            LeafKey = leafKey;
        }

        public X509Certificate2 Root { get; }

        public X509Certificate2 Intermediate { get; }

        public X509Certificate2 Leaf { get; }

        public ECDsa LeafKey { get; }

        public static TestAppleCertificateChain Create(
            DateTime? leafNotBefore = null,
            DateTime? leafNotAfter = null)
        {
            var rootKey = ECDsa.Create(ECCurve.NamedCurves.nistP256);
            var intermediateKey = ECDsa.Create(ECCurve.NamedCurves.nistP256);
            var leafKey = ECDsa.Create(ECCurve.NamedCurves.nistP256);
            var now = DateTime.UtcNow;

            var rootRequest = CreateCertificateRequest(
                "CN=Apple Root CA - Test, O=Apple Inc., C=US",
                rootKey,
                isCertificateAuthority: true);
            var root = rootRequest.CreateSelfSigned(now.AddDays(-30), now.AddYears(10));

            var intermediateRequest = CreateCertificateRequest(
                "CN=Apple Worldwide Developer Relations Certification Authority - Test, O=Apple Inc., C=US",
                intermediateKey,
                isCertificateAuthority: true,
                markerExtension: CreateMarkerExtension(AppStoreIntermediateCertificateOid));
            var intermediate = intermediateRequest
                .Create(
                    root.SubjectName,
                    X509SignatureGenerator.CreateForECDsa(rootKey),
                    now.AddDays(-7),
                    now.AddYears(5),
                    CreateSerialNumber())
                .CopyWithPrivateKey(intermediateKey);

            var leafRequest = CreateCertificateRequest(
                "CN=App Store Server Notifications - Test, O=Apple Inc., C=US",
                leafKey,
                isCertificateAuthority: false,
                markerExtension: CreateMarkerExtension(AppStoreLeafCertificateOid));
            var leaf = leafRequest
                .Create(
                    intermediate.SubjectName,
                    X509SignatureGenerator.CreateForECDsa(intermediateKey),
                    leafNotBefore ?? now.AddDays(-1),
                    leafNotAfter ?? now.AddYears(1),
                    CreateSerialNumber())
                .CopyWithPrivateKey(leafKey);

            return new TestAppleCertificateChain(root, intermediate, leaf, rootKey, intermediateKey, leafKey);
        }

        public void Dispose()
        {
            Leaf.Dispose();
            Intermediate.Dispose();
            Root.Dispose();
            LeafKey.Dispose();
            _intermediateKey.Dispose();
            _rootKey.Dispose();
        }
    }
}
