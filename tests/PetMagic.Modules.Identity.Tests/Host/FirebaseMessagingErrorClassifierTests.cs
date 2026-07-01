using System.Net;

using PetMagic.BuildingBlocks.Observability;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class FirebaseMessagingErrorClassifierTests
{
    [Fact]
    public void ShouldDisableToken_ShouldReturnTrue_WhenTokenIsUnregistered()
    {
        const string body = """
            {
              "error": {
                "code": 404,
                "message": "Requested entity was not found.",
                "status": "NOT_FOUND",
                "details": [
                  {
                    "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
                    "errorCode": "UNREGISTERED"
                  }
                ]
              }
            }
            """;

        Assert.True(FirebaseMessagingErrorClassifier.ShouldDisableToken(HttpStatusCode.NotFound, body));
        Assert.Equal("unregistered", FirebaseMessagingErrorClassifier.ResolveErrorReason(body));
    }

    [Fact]
    public void ShouldDisableToken_ShouldReturnFalse_ForGenericInvalidArgument()
    {
        const string body = """
            {
              "error": {
                "code": 400,
                "message": "Request contains an invalid argument.",
                "status": "INVALID_ARGUMENT",
                "details": [
                  {
                    "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
                    "errorCode": "INVALID_ARGUMENT"
                  }
                ]
              }
            }
            """;

        Assert.False(FirebaseMessagingErrorClassifier.ShouldDisableToken(HttpStatusCode.BadRequest, body));
        Assert.Equal("invalid_argument", FirebaseMessagingErrorClassifier.ResolveErrorReason(body));
    }

    [Fact]
    public void ShouldDisableToken_ShouldReturnTrue_ForInvalidRegistrationToken()
    {
        const string body = """
            {
              "error": {
                "code": 400,
                "message": "The registration token is not a valid FCM registration token",
                "status": "INVALID_ARGUMENT",
                "details": [
                  {
                    "@type": "type.googleapis.com/google.rpc.BadRequest",
                    "fieldViolations": [
                      {
                        "field": "message.token",
                        "description": "The registration token is not a valid FCM registration token"
                      }
                    ]
                  }
                ]
              }
            }
            """;

        Assert.True(FirebaseMessagingErrorClassifier.ShouldDisableToken(HttpStatusCode.BadRequest, body));
        Assert.Equal("invalid_registration_token", FirebaseMessagingErrorClassifier.ResolveErrorReason(body));
    }
}
