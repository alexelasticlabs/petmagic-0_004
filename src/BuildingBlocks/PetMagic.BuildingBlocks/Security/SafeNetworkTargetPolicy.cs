using System.Net;

namespace PetMagic.BuildingBlocks.Security;

public static class SafeNetworkTargetPolicy
{
    public static bool IsPrivateNetworkTarget(Uri uri)
    {
        var host = uri.IdnHost;
        if (string.Equals(host, "localhost", StringComparison.OrdinalIgnoreCase)
            || host.EndsWith(".localhost", StringComparison.OrdinalIgnoreCase)
            || string.Equals(host, "0.0.0.0", StringComparison.OrdinalIgnoreCase)
            || string.Equals(host, "::", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        return IPAddress.TryParse(host.Trim('[', ']'), out var address) && IsPrivateNetworkAddress(address);
    }

    private static bool IsPrivateNetworkAddress(IPAddress address)
    {
        if (address.IsIPv4MappedToIPv6)
        {
            address = address.MapToIPv4();
        }

        if (IPAddress.IsLoopback(address)
            || IPAddress.Any.Equals(address)
            || IPAddress.None.Equals(address)
            || IPAddress.IPv6Any.Equals(address)
            || IPAddress.IPv6Loopback.Equals(address)
            || IPAddress.IPv6None.Equals(address)
            || address.IsIPv6LinkLocal
            || address.IsIPv6SiteLocal
            || address.IsIPv6Multicast
            || IsIPv6UniqueLocalAddress(address))
        {
            return true;
        }

        if (address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork)
        {
            return false;
        }

        var bytes = address.GetAddressBytes();
        return bytes[0] == 10
            || bytes[0] == 127
            || bytes[0] == 169 && bytes[1] == 254
            || bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31
            || bytes[0] == 192 && bytes[1] == 168
            || bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127
            || bytes[0] >= 224;
    }

    private static bool IsIPv6UniqueLocalAddress(IPAddress address)
    {
        if (address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetworkV6)
        {
            return false;
        }

        var bytes = address.GetAddressBytes();
        return (bytes[0] & 0xFE) == 0xFC;
    }
}
