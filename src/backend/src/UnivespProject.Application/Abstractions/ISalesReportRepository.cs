using UnivespProject.Domain.Common;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Abstractions;

public sealed record MonthTotals(int Year, int Month, int Sales, int Quantity, decimal Revenue);

/// <summary>Units and revenue of a product (name + SKU as written) in a month, with its catalog product when linked.</summary>
public sealed record ProductMonthTotals(
    int Year, int Month, string ProductName, string? Sku, Guid? ProductId, int Quantity, decimal Revenue)
{
    /// <summary>The product's identity: normalized SKU, or name when there is no SKU (same as <see cref="ProductTotals.Key"/>).</summary>
    public string Key => TextNormalizer.ToKey(string.IsNullOrWhiteSpace(Sku) ? ProductName : Sku);
}

/// <summary>How many different days of a month had at least one sale.</summary>
public sealed record MonthActivity(int Year, int Month, int DaysWithSales);

/// <summary>One sale with the names of its marketplace and batch (for the period spreadsheet).</summary>
/// <param name="Marketplace">Null for sales outside a marketplace.</param>
public sealed record SaleLine(
    DateOnly Date,
    string ProductName,
    string? Sku,
    int Quantity,
    decimal UnitPrice,
    decimal TotalPrice,
    SalesChannel Channel,
    string? Marketplace,
    string BatchName,
    ImportSource Source);

/// <summary>
/// Totals of every sale, whatever its batch, within a date range (both ends included).
/// Used to compare months.
/// </summary>
public interface ISalesReportRepository
{
    /// <summary>Months with at least one sale; months without sales are not returned.</summary>
    Task<IReadOnlyList<MonthTotals>> GetTotalsByMonthAsync(CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ChannelTotals>> GetTotalsByChannelAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default);

    /// <summary>Totals of the online sales, grouped by marketplace.</summary>
    Task<IReadOnlyList<MarketplaceTotals>> GetOnlineTotalsByMarketplaceAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default);

    /// <summary>Totals per sale date; days without sales are not returned.</summary>
    Task<IReadOnlyList<DayTotals>> GetTotalsByDayAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ProductTotals>> GetTotalsByProductAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default);

    Task<CostTotals> GetCostTotalsAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default);

    /// <summary>Totals per month and product, over every sale (the sales history of the analytics).</summary>
    Task<IReadOnlyList<ProductMonthTotals>> GetTotalsByProductAndMonthAsync(CancellationToken cancellationToken = default);

    /// <summary>Days with sales per month; months without sales are not returned.</summary>
    Task<IReadOnlyList<MonthActivity>> GetDaysWithSalesByMonthAsync(CancellationToken cancellationToken = default);

    /// <summary>Every sale in the range, by date, then batch, then spreadsheet row.</summary>
    Task<IReadOnlyList<SaleLine>> ListSalesAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default);
}
