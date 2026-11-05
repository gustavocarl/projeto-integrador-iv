using UnivespProject.Domain.Common;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Sales;

public static class SalesChannelParser
{
    public const string InPersonLabel = "Presencial";
    public const string OnlineLabel = "Online";

    private static readonly Dictionary<string, SalesChannel> Aliases = new()
    {
        ["PRESENCIAL"] = SalesChannel.InPerson,
        ["INPERSON"] = SalesChannel.InPerson,
        ["LOJA FISICA"] = SalesChannel.InPerson,
        ["FISICA"] = SalesChannel.InPerson,
        ["ONLINE"] = SalesChannel.Online,
        ["LOJA VIRTUAL"] = SalesChannel.Online,
        ["VIRTUAL"] = SalesChannel.Online
    };

    /// <summary>
    /// Accepts "Presencial"/"Loja física" and "Online"/"Loja virtual", ignoring case and accents,
    /// plus the API keys "InPerson"/"Online".
    /// </summary>
    public static bool TryParse(string? value, out SalesChannel channel)
    {
        channel = default;
        return !string.IsNullOrWhiteSpace(value) && Aliases.TryGetValue(TextNormalizer.ToKey(value), out channel);
    }

    public static string Label(SalesChannel channel) => channel switch
    {
        SalesChannel.InPerson => InPersonLabel,
        SalesChannel.Online => OnlineLabel,
        _ => channel.ToString()
    };
}
