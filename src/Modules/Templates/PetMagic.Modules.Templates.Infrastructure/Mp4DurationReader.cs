using System.Buffers.Binary;

namespace PetMagic.Modules.Templates.Infrastructure;

internal static class Mp4DurationReader
{
    private static readonly HashSet<string> ContainerBoxTypes =
    [
        "moov",
        "trak",
        "mdia",
        "minf",
        "stbl",
        "edts",
        "udta",
        "dinf"
    ];

    public static bool TryReadDurationSeconds(Stream stream, out double seconds)
    {
        seconds = 0;

        if (!stream.CanRead || !stream.CanSeek)
        {
            return false;
        }

        stream.Position = 0;
        return TryReadBoxes(stream, stream.Length, out seconds);
    }

    private static bool TryReadBoxes(Stream stream, long endPosition, out double seconds)
    {
        seconds = 0;
        var header = new byte[8];
        var largeSizeBytes = new byte[8];

        while (stream.Position < endPosition)
        {
            var boxStart = stream.Position;
            if (endPosition - boxStart < 8)
            {
                return false;
            }

            if (!TryReadExact(stream, header))
            {
                return false;
            }

            var size = BinaryPrimitives.ReadUInt32BigEndian(header.AsSpan()[..4]);
            var type = GetBoxType(header[4..8]);
            long headerLength = 8;
            long boxSize = size;

            if (size == 1)
            {
                if (!TryReadExact(stream, largeSizeBytes))
                {
                    return false;
                }

                boxSize = checked((long)BinaryPrimitives.ReadUInt64BigEndian(largeSizeBytes));
                headerLength = 16;
            }
            else if (size == 0)
            {
                boxSize = endPosition - boxStart;
            }

            if (boxSize < headerLength)
            {
                return false;
            }

            var boxEnd = boxStart + boxSize;
            if (boxEnd > endPosition || boxEnd > stream.Length)
            {
                return false;
            }

            if (type == "mvhd")
            {
                var payloadLength = boxSize - headerLength;
                if (!TryReadMovieHeader(stream, payloadLength, out seconds))
                {
                    return false;
                }

                return true;
            }

            if (ContainerBoxTypes.Contains(type))
            {
                if (TryReadBoxes(stream, boxEnd, out seconds))
                {
                    return true;
                }
            }
            else if (type == "meta")
            {
                if (boxEnd - stream.Position < 4)
                {
                    return false;
                }

                stream.Position += 4;
                if (TryReadBoxes(stream, boxEnd, out seconds))
                {
                    return true;
                }
            }

            stream.Position = boxEnd;
        }

        return false;
    }

    private static bool TryReadMovieHeader(Stream stream, long payloadLength, out double seconds)
    {
        seconds = 0;
        if (payloadLength < 20)
        {
            return false;
        }

        var buffer = new byte[payloadLength];
        if (!TryReadExact(stream, buffer))
        {
            return false;
        }

        var version = buffer[0];
        if (version == 0)
        {
            if (buffer.Length < 20)
            {
                return false;
            }

            var timescale = BinaryPrimitives.ReadUInt32BigEndian(buffer.AsSpan(12, 4));
            var duration = BinaryPrimitives.ReadUInt32BigEndian(buffer.AsSpan(16, 4));

            return TryConvertToSeconds(timescale, duration, out seconds);
        }

        if (version == 1)
        {
            if (buffer.Length < 32)
            {
                return false;
            }

            var timescale = BinaryPrimitives.ReadUInt32BigEndian(buffer.AsSpan(20, 4));
            var duration = BinaryPrimitives.ReadUInt64BigEndian(buffer.AsSpan(24, 8));

            return TryConvertToSeconds(timescale, duration, out seconds);
        }

        return false;
    }

    private static bool TryConvertToSeconds(uint timescale, ulong duration, out double seconds)
    {
        seconds = 0;
        if (timescale == 0 || duration == 0)
        {
            return false;
        }

        seconds = duration / (double)timescale;
        return double.IsFinite(seconds) && seconds > 0;
    }

    private static string GetBoxType(ReadOnlySpan<byte> bytes)
    {
        Span<char> chars = stackalloc char[4];
        for (var index = 0; index < 4; index++)
        {
            chars[index] = (char)bytes[index];
        }

        return new string(chars);
    }

    private static bool TryReadExact(Stream stream, Span<byte> buffer)
    {
        var totalRead = 0;
        while (totalRead < buffer.Length)
        {
            var read = stream.Read(buffer[totalRead..]);
            if (read == 0)
            {
                return false;
            }

            totalRead += read;
        }

        return true;
    }

    private static bool TryReadExact(Stream stream, byte[] buffer)
    {
        return TryReadExact(stream, buffer.AsSpan());
    }
}
