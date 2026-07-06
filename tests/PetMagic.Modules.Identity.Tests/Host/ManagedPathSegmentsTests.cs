using PetMagic.BuildingBlocks.Storage;

namespace PetMagic.Modules.Identity.Tests.Host;

public sealed class ManagedPathSegmentsTests
{
    [Theory]
    [InlineData(".")]
    [InlineData("..")]
    [InlineData("%2e")]
    [InlineData("%2e%2e")]
    [InlineData("2026%2f..%2fprivate.png")]
    [InlineData("2026%5c..%5cprivate.png")]
    [InlineData("%zz-private.png")]
    [InlineData("private%")]
    public void IsUnsafe_ShouldRejectTraversalSeparatorsAndMalformedPercentEncoding(string segment)
    {
        Assert.True(ManagedPathSegments.IsUnsafe(segment));
    }

    [Theory]
    [InlineData("2026")]
    [InlineData("06")]
    [InlineData("result.png")]
    [InlineData("preview%20image.png")]
    public void IsUnsafe_ShouldAllowOrdinaryPathSegments(string segment)
    {
        Assert.False(ManagedPathSegments.IsUnsafe(segment));
    }
}
