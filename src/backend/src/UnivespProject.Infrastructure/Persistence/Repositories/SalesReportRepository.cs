using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal sealed class SalesReportRepository(AppDbContext context) : ISalesReportRepository
{
    public async Task<IReadOnlyList<MonthTotals>> GetTotalsByMonthAsync(CancellationToken cancellationToken = default) =>
        await context.Sales
            .GroupBy(s => new { s.SaleDate.Year, s.SaleDate.Month })
            .Select(g => new MonthTotals(g.Key.Year, g.Key.Month, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToListAsync(cancellationToken);

    public Task<IReadOnlyList<ChannelTotals>> GetTotalsByChannelAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Between(start, end).TotalsByChannelAsync(cancellationToken);

    public Task<IReadOnlyList<MarketplaceTotals>> GetOnlineTotalsByMarketplaceAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Between(start, end).OnlineTotalsByMarketplaceAsync(cancellationToken);

    public Task<IReadOnlyList<DayTotals>> GetTotalsByDayAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Between(start, end).TotalsByDayAsync(cancellationToken);

    public Task<IReadOnlyList<ProductTotals>> GetTotalsByProductAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Between(start, end).TotalsByProductAsync(cancellationToken);

    public Task<CostTotals> GetCostTotalsAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Between(start, end).CostTotalsAsync(cancellationToken);

    public async Task<IReadOnlyList<ProductMonthTotals>> GetTotalsByProductAndMonthAsync(CancellationToken cancellationToken = default) =>
        await context.Sales
            .GroupBy(s => new { s.SaleDate.Year, s.SaleDate.Month, s.ProductName, s.Sku, s.ProductId })
            .Select(g => new ProductMonthTotals(
                g.Key.Year, g.Key.Month, g.Key.ProductName, g.Key.Sku, g.Key.ProductId,
                g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<MonthActivity>> GetDaysWithSalesByMonthAsync(CancellationToken cancellationToken = default) =>
        await context.Sales
            .GroupBy(s => new { s.SaleDate.Year, s.SaleDate.Month })
            .Select(g => new MonthActivity(g.Key.Year, g.Key.Month, g.Select(s => s.SaleDate).Distinct().Count()))
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<SaleLine>> ListSalesAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        await Between(start, end)
            .AsNoTracking()
            .Join(context.SalesImports, s => s.SalesImportId, i => i.Id, (s, i) => new { Sale = s, Batch = i })
            .OrderBy(x => x.Sale.SaleDate)
            .ThenBy(x => x.Batch.FileName)
            .ThenBy(x => x.Sale.RowNumber)
            .ThenBy(x => x.Sale.CreatedAt)
            .Select(x => new SaleLine(
                x.Sale.SaleDate, x.Sale.ProductName, x.Sale.Sku, x.Sale.Quantity, x.Sale.UnitPrice, x.Sale.TotalPrice,
                x.Sale.Channel, x.Sale.Marketplace != null ? x.Sale.Marketplace.Name : null,
                x.Batch.FileName, x.Batch.Source))
            .ToListAsync(cancellationToken);

    private IQueryable<Sale> Between(DateOnly start, DateOnly end) =>
        context.Sales.Where(s => s.SaleDate >= start && s.SaleDate <= end);
}
