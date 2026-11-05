using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

/// <summary>
/// Totals over any set of sales (a batch, a month), computed in SQL.
/// Shared by the batch analysis and the month comparison so both count the same way.
/// </summary>
internal static class SaleAggregates
{
    public static async Task<IReadOnlyList<ChannelTotals>> TotalsByChannelAsync(
        this IQueryable<Sale> sales, CancellationToken cancellationToken) =>
        await sales
            .GroupBy(s => s.Channel)
            .Select(g => new ChannelTotals(g.Key, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToListAsync(cancellationToken);

    public static async Task<IReadOnlyList<MarketplaceTotals>> OnlineTotalsByMarketplaceAsync(
        this IQueryable<Sale> sales, CancellationToken cancellationToken) =>
        await sales
            .Where(s => s.Channel == SalesChannel.Online)
            .GroupBy(s => new { s.MarketplaceId, Name = s.Marketplace != null ? s.Marketplace.Name : null })
            .Select(g => new MarketplaceTotals(g.Key.MarketplaceId, g.Key.Name, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToListAsync(cancellationToken);

    public static async Task<IReadOnlyList<DayTotals>> TotalsByDayAsync(
        this IQueryable<Sale> sales, CancellationToken cancellationToken) =>
        await sales
            .GroupBy(s => s.SaleDate)
            .Select(g => new DayTotals(g.Key, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToListAsync(cancellationToken);

    public static async Task<IReadOnlyList<ProductTotals>> TotalsByProductAsync(
        this IQueryable<Sale> sales, CancellationToken cancellationToken) =>
        await sales
            .GroupBy(s => new { s.ProductName, s.Sku })
            .Select(g => new ProductTotals(
                g.Key.ProductName, g.Key.Sku, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice), g.Max(s => s.SaleDate)))
            .ToListAsync(cancellationToken);

    public static async Task<CostTotals> CostTotalsAsync(
        this IQueryable<Sale> sales, CancellationToken cancellationToken) =>
        await sales
            .Where(s => s.TotalCost != null)
            .GroupBy(_ => 1)
            .Select(g => new CostTotals(g.Count(), g.Sum(s => s.TotalPrice), g.Sum(s => s.TotalCost!.Value)))
            .FirstOrDefaultAsync(cancellationToken) ?? new CostTotals(0, 0m, 0m);
}
