using UnivespProject.Domain.Common;

namespace UnivespProject.Application.Sales;

/// <summary>
/// Font of the generated spreadsheets: the default of the spreadsheet app most used on the
/// operating system of whoever asked for the file.
/// </summary>
public sealed record SpreadsheetFont(string Name, double Size)
{
    /// <summary>Excel's default (Windows), also used when the system is not informed.</summary>
    public static readonly SpreadsheetFont Default = new("Calibri", 11);

    /// <summary>Apple Numbers.</summary>
    public static readonly SpreadsheetFont Apple = new("Helvetica Neue", 10);

    /// <summary>LibreOffice Calc.</summary>
    public static readonly SpreadsheetFont Linux = new("Liberation Sans", 10);

    /// <summary>Android's system font.</summary>
    public static readonly SpreadsheetFont Android = new("Roboto", 10);

    /// <summary>Error key: the request field / query parameter.</summary>
    public const string Field = "platform";

    public const string InvalidMessage = "Sistema operacional inválido. Use windows, macos, linux, android ou ios.";

    /// <summary>
    /// <paramref name="platform"/>: the app's operating system, as Flutter names it (windows,
    /// macOS, linux, android, iOS, fuchsia), any case. Empty = <see cref="Default"/>; false = unknown name.
    /// </summary>
    public static bool TryFor(string? platform, out SpreadsheetFont font)
    {
        SpreadsheetFont? found = string.IsNullOrWhiteSpace(platform)
            ? Default
            : TextNormalizer.ToKey(platform) switch
            {
                "WINDOWS" => Default,
                "MACOS" or "IOS" => Apple,
                "LINUX" => Linux,
                "ANDROID" or "FUCHSIA" => Android,
                _ => null
            };

        font = found ?? Default;
        return found is not null;
    }
}
