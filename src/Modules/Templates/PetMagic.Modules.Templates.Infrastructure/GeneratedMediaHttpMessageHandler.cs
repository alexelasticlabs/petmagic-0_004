using System.Net;
using System.Net.Sockets;

using PetMagic.BuildingBlocks.Security;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class GeneratedMediaHttpMessageHandler
{
    public static SocketsHttpHandler Create()
    {
        return new SocketsHttpHandler
        {
            AllowAutoRedirect = false,
            UseProxy = false,
            ConnectCallback = ConnectToValidatedAddressAsync
        };
    }

    internal static IReadOnlyList<IPEndPoint> BuildValidatedEndpoints(
        DnsEndPoint target,
        IReadOnlyCollection<IPAddress> resolvedAddresses)
    {
        if (resolvedAddresses.Count == 0)
        {
            throw new HttpRequestException("Generated media host did not resolve to an address.");
        }

        // Reject the whole DNS answer when it contains any non-public address. Picking only the
        // public member of a mixed answer would make policy enforcement depend on address order.
        if (resolvedAddresses.Any(SafeNetworkTargetPolicy.IsPrivateNetworkAddress))
        {
            throw new HttpRequestException("Generated media host resolved to a non-public address.");
        }

        return resolvedAddresses
            .Select(address => new IPEndPoint(address, target.Port))
            .ToArray();
    }

    private static async ValueTask<Stream> ConnectToValidatedAddressAsync(
        SocketsHttpConnectionContext context,
        CancellationToken cancellationToken)
    {
        var resolvedAddresses = await Dns.GetHostAddressesAsync(
            context.DnsEndPoint.Host,
            cancellationToken);
        var endpoints = BuildValidatedEndpoints(context.DnsEndPoint, resolvedAddresses);
        Exception? lastException = null;
        foreach (var endpoint in endpoints)
        {
            var socket = new Socket(endpoint.AddressFamily, SocketType.Stream, ProtocolType.Tcp)
            {
                NoDelay = true
            };

            try
            {
                await socket.ConnectAsync(endpoint, cancellationToken);
                return new NetworkStream(socket, ownsSocket: true);
            }
            catch (Exception exception)
            {
                socket.Dispose();
                cancellationToken.ThrowIfCancellationRequested();
                lastException = exception;
            }
        }

        throw new HttpRequestException(
            "Could not connect to any validated generated media address.",
            lastException);
    }
}
