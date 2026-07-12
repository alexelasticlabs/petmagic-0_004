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

    public static bool IsPrivateNetworkAddress(IPAddress address)
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

        if (TryMapIPv4CompatibleToIPv4(address, out var compatibleAddress))
        {
            return IsPrivateNetworkAddress(compatibleAddress);
        }

        if (address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork)
        {
            return IsRestrictedIpv6Address(address);
        }

        var bytes = address.GetAddressBytes();
        return IsRestrictedIpv4Address(bytes);
    }

    private static bool TryMapIPv4CompatibleToIPv4(IPAddress address, out IPAddress ipv4Address)
    {
        ipv4Address = IPAddress.None;
        if (address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetworkV6)
        {
            return false;
        }

        var bytes = address.GetAddressBytes();
        for (var index = 0; index < 12; index++)
        {
            if (bytes[index] != 0)
            {
                return false;
            }
        }

        ipv4Address = new IPAddress([bytes[12], bytes[13], bytes[14], bytes[15]]);
        return true;
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

    private static bool IsRestrictedIpv4Address(ReadOnlySpan<byte> bytes)
    {
        return bytes[0] == 0 // "This network".
            || bytes[0] == 10
            || bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127 // Shared address space.
            || bytes[0] == 127
            || bytes[0] == 169 && bytes[1] == 254
            || bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31
            || bytes[0] == 192 && bytes[1] == 0 && bytes[2] == 0 // IETF protocol assignments.
            || bytes[0] == 192 && bytes[1] == 0 && bytes[2] == 2 // TEST-NET-1.
            || bytes[0] == 192 && bytes[1] == 168
            || bytes[0] == 198 && (bytes[1] == 18 || bytes[1] == 19) // Benchmarking.
            || bytes[0] == 198 && bytes[1] == 51 && bytes[2] == 100 // TEST-NET-2.
            || bytes[0] == 203 && bytes[1] == 0 && bytes[2] == 113 // TEST-NET-3.
            || bytes[0] >= 224;
    }

    private static bool IsRestrictedIpv6Address(IPAddress address)
    {
        if (address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetworkV6)
        {
            return false;
        }

        var bytes = address.GetAddressBytes();
        if (HasPrefix(bytes, 0x20, 0x01, 0x0d, 0xb8)) // Documentation range 2001:db8::/32.
        {
            return true;
        }

        // 6to4 embeds an IPv4 destination in bytes 2..5. Do not let an IPv6 literal
        // bypass the same private-network policy applied to IPv4 literals.
        if (bytes[0] == 0x20
            && bytes[1] == 0x02
            && IsRestrictedIpv4Address(bytes.AsSpan(2, 4)))
        {
            return true;
        }

        // The well-known NAT64 prefix can also encode an IPv4 target. Reject it when
        // that target is non-public; public NAT64 targets remain valid.
        return HasPrefix(bytes, 0x00, 0x64, 0xff, 0x9b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
            && IsRestrictedIpv4Address(bytes.AsSpan(12, 4));
    }

    private static bool HasPrefix(ReadOnlySpan<byte> bytes, params byte[] prefix)
    {
        return bytes.Length >= prefix.Length && bytes[..prefix.Length].SequenceEqual(prefix);
    }
}
