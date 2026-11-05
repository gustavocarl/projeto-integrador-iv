namespace UnivespProject.Application.ProductImages;

/// <summary>
/// Recognizes the image formats accepted for product photos by their first bytes ("magic numbers"),
/// so a renamed file (e.g. a .exe called foto.png) is refused whatever its name says.
/// </summary>
public static class ImageFormat
{
    /// <summary>Bytes needed to recognize every supported format.</summary>
    public const int HeaderLength = 12;

    /// <summary>The extension (with the dot) of the detected format, or null when it isn't a supported image.</summary>
    public static string? DetectExtension(ReadOnlySpan<byte> header)
    {
        if (header.StartsWith((ReadOnlySpan<byte>)[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
            return ".png";
        if (header.StartsWith((ReadOnlySpan<byte>)[0xFF, 0xD8, 0xFF]))
            return ".jpg";
        if (header.StartsWith("GIF87a"u8) || header.StartsWith("GIF89a"u8))
            return ".gif";
        if (header.Length >= 12 && header[..4].SequenceEqual("RIFF"u8) && header[8..12].SequenceEqual("WEBP"u8))
            return ".webp";
        return null;
    }
}
