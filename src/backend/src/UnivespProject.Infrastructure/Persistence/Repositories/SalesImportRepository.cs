using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal sealed class SalesImportRepository(AppDbContext context) : ISalesImportRepository
{
    public async Task AddAsync(SalesImport salesImport, CancellationToken cancellationToken = default) =>
        await context.SalesImports.AddAsync(salesImport, cancellationToken);

    public Task<SalesImport?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        context.SalesImports.FirstOrDefaultAsync(i => i.Id == id, cancellationToken);

    public Task<SalesImport?> GetByNameAsync(ImportSource source, string fileName, CancellationToken cancellationToken = default) =>
        context.SalesImports
            .OrderBy(i => i.CreatedAt)
            .FirstOrDefaultAsync(i => i.Source == source && i.FileName == fileName, cancellationToken);

    public Task<SalesImport?> GetByIdWithSalesAsync(Guid id, CancellationToken cancellationToken = default) =>
        context.SalesImports.Include(i => i.Sales).FirstOrDefaultAsync(i => i.Id == id, cancellationToken);

    public async Task AddSaleAsync(Sale sale, CancellationToken cancellationToken = default) =>
        await context.Sales.AddAsync(sale, cancellationToken);

    public void RemoveSale(Sale sale) => context.Sales.Remove(sale);

    public async Task<(IReadOnlyList<Sale> Items, int TotalCount)> ListSalesAsync(
        Guid importId, string? search, int skip, int take, CancellationToken cancellationToken = default)
    {
        var query = context.Sales.AsNoTracking().Where(s => s.SalesImportId == importId);
        if (search is not null)
        {
            var pattern = $"%{LikePattern.Escape(search)}%";
            query = query.Where(s => EF.Functions.ILike(s.ProductName, pattern, @"\")
                || (s.Sku != null && EF.Functions.ILike(s.Sku, pattern, @"\")));
        }

        var total = await query.CountAsync(cancellationToken);
        var items = await query
            .Include(s => s.Marketplace)
            .OrderByDescending(s => s.SaleDate)
            .ThenByDescending(s => s.CreatedAt)
            .ThenBy(s => s.RowNumber)
            .Skip(skip)
            .Take(take)
            .ToListAsync(cancellationToken);
        return (items, total);
    }

    public async Task<IReadOnlyList<SalesImport>> ListAsync(CancellationToken cancellationToken = default) =>
        await context.SalesImports.AsNoTracking().OrderByDescending(i => i.CreatedAt).ToListAsync(cancellationToken);

    public void Remove(SalesImport salesImport) => context.SalesImports.Remove(salesImport);

    public Task<IReadOnlyList<ChannelTotals>> GetTotalsByChannelAsync(Guid importId, CancellationToken cancellationToken = default) =>
        SalesOf(importId).TotalsByChannelAsync(cancellationToken);

    public Task<IReadOnlyList<MarketplaceTotals>> GetOnlineTotalsByMarketplaceAsync(Guid importId, CancellationToken cancellationToken = default) =>
        SalesOf(importId).OnlineTotalsByMarketplaceAsync(cancellationToken);

    public Task<IReadOnlyList<DayTotals>> GetTotalsByDayAsync(Guid importId, CancellationToken cancellationToken = default) =>
        SalesOf(importId).TotalsByDayAsync(cancellationToken);

    public Task<IReadOnlyList<ProductTotals>> GetTotalsByProductAsync(Guid importId, CancellationToken cancellationToken = default) =>
        SalesOf(importId).TotalsByProductAsync(cancellationToken);

    public Task<CostTotals> GetCostTotalsAsync(Guid importId, CancellationToken cancellationToken = default) =>
        SalesOf(importId).CostTotalsAsync(cancellationToken);

    public async Task<DeletionImpactTotals> GetDeletionImpactAsync(Guid importId, CancellationToken cancellationToken = default)
    {
        var sales = SalesOf(importId);
        var linkedProducts = await sales
            .Where(s => s.ProductId != null)
            .Select(s => s.ProductId)
            .Distinct()
            .CountAsync(cancellationToken);
        var checkoutQuantity = await sales
            .Where(s => s.IsCheckout)
            .SumAsync(s => (int?)s.Quantity, cancellationToken) ?? 0;

        return new DeletionImpactTotals(linkedProducts, checkoutQuantity);
    }

    private IQueryable<Sale> SalesOf(Guid importId) => context.Sales.Where(s => s.SalesImportId == importId);

    public Task SaveChangesAsync(CancellationToken cancellationToken = default) =>
        context.SaveChangesAsync(cancellationToken);
}
