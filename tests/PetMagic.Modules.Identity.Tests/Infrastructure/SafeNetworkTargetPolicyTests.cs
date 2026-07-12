using PetMagic.BuildingBlocks.Security;

namespace PetMagic.Modules.Identity.Tests.Infrastructure;

public sealed class SafeNetworkTargetPolicyTests
{
    [Theory]
    [InlineData("https://localhost/media.png")]
    [InlineData("https://media.localhost/media.png")]
    [InlineData("https://0.0.0.1/media.png")]
    [InlineData("https://10.0.0.5/media.png")]
    [InlineData("https://100.64.0.1/media.png")]
    [InlineData("https://169.254.169.254/latest/meta-data")]
    [InlineData("https://172.16.0.1/media.png")]
    [InlineData("https://192.168.1.1/media.png")]
    [InlineData("https://192.0.0.8/media.png")]
    [InlineData("https://192.0.2.8/media.png")]
    [InlineData("https://198.18.0.8/media.png")]
    [InlineData("https://198.51.100.8/media.png")]
    [InlineData("https://203.0.113.8/media.png")]
    [InlineData("https://224.0.0.1/media.png")]
    [InlineData("https://2130706433/media.png")]
    [InlineData("https://0x7f000001/media.png")]
    [InlineData("https://0177.0.0.1/media.png")]
    [InlineData("https://127.1/media.png")]
    [InlineData("https://127.0.1/media.png")]
    [InlineData("https://0300.0250.0001.0001/media.png")]
    [InlineData("https://[0:0:0:0:0:0:0:0]/media.png")]
    [InlineData("https://[0:0:0:0:0:0:0:1]/media.png")]
    [InlineData("https://[fe90::1]/media.png")]
    [InlineData("https://[fec0::1]/media.png")]
    [InlineData("https://[ff02::1]/media.png")]
    [InlineData("https://[::ffff:127.0.0.1]/media.png")]
    [InlineData("https://[::127.0.0.1]/media.png")]
    [InlineData("https://[::7f00:1]/media.png")]
    [InlineData("https://[2001:db8::1]/media.png")]
    [InlineData("https://[2002:7f00:1::1]/media.png")]
    [InlineData("https://[64:ff9b::a9fe:a9fe]/media.png")]
    [InlineData("https://[0:0:0:0:0:ffff:7f00:1]/media.png")]
    [InlineData("https://[0:0:0:0:0:ffff:127.0.0.1]/media.png")]
    [InlineData("https://[0:0:0:0:0:0:7f00:1]/media.png")]
    [InlineData("https://[0:0:0:0:0:0:127.0.0.1]/media.png")]
    public void IsPrivateNetworkTarget_ShouldRejectLocalPrivateAndReservedTargets(string rawUrl)
    {
        Assert.True(SafeNetworkTargetPolicy.IsPrivateNetworkTarget(new Uri(rawUrl)));
    }

    [Theory]
    [InlineData("https://cdn.petmagic.app/media.png")]
    [InlineData("https://8.8.8.8/media.png")]
    [InlineData("https://134744072/media.png")]
    [InlineData("https://0x08080808/media.png")]
    [InlineData("https://[::ffff:8.8.8.8]/media.png")]
    public void IsPrivateNetworkTarget_ShouldAllowPublicTargets(string rawUrl)
    {
        Assert.False(SafeNetworkTargetPolicy.IsPrivateNetworkTarget(new Uri(rawUrl)));
    }
}
