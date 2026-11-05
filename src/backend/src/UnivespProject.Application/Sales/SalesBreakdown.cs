using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Sales;

namespace UnivespProject.Application.Sales;

/// <summary>Turns repository totals into labeled groups, the same way for a batch and for a month.</summary>
internal static class SalesBreakdown
{
    public const string OutsideMarketplaceKey = "none";
    public const string OutsideMarketplaceLabel = "Fora de marketplace";

    /// <summary>Presencial first, then Online.</summary>
    public static List<BreakdownItem> ByChannel(IEnumerable<ChannelTotals> totals) =>
        totals
            .OrderBy(t => t.Channel)
            .Select(t => new BreakdownItem(t.Channel.ToString(), SalesChannelParser.Label(t.Channel), t.Sales, t.Quantity, t.Revenue))
            .ToList();

    /// <summary>Highest revenue first; online sales outside a marketplace get the key "none".</summary>
    public static List<BreakdownItem> ByMarketplace(IEnumerable<MarketplaceTotals> totals) =>
        totals
            .OrderByDescending(t => t.Revenue)
            .Select(t => new BreakdownItem(
                t.MarketplaceId?.ToString() ?? OutsideMarketplaceKey,
                t.MarketplaceName ?? OutsideMarketplaceLabel,
                t.Sales, t.Quantity, t.Revenue))
            .ToList();

    public static ProfitSummary Profit(CostTotals cost)
    {
        var profit = cost.Revenue - cost.Cost;
        return new ProfitSummary(cost.Sales, cost.Revenue, cost.Cost, profit,
            cost.Revenue == 0 ? null : Math.Round(profit / cost.Revenue, 4));
    }
}
