using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Tests.Application.Sales;

/// <summary>In-memory repositories shared by the sales service tests.</summary>
internal sealed class FakeSalesImportRepository : ISalesImportRepository
{
    public List<SalesImport> Items { get; } = [];
    public bool Saved { get; private set; }

    public Task AddAsync(SalesImport salesImport, CancellationToken cancellationToken = default)
    {
        Items.Add(salesImport);
        return Task.CompletedTask;
    }

    public Task<SalesImport?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.FirstOrDefault(i => i.Id == id));

    public Task<SalesImport?> GetByNameAsync(ImportSource source, string fileName, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.FirstOrDefault(i => i.Source == source && i.FileName == fileName));

    public Task<CostTotals> GetCostTotalsAsync(Guid importId, CancellationToken cancellationToken = default)
    {
        var withCost = SalesOf(importId).Where(s => s.TotalCost is not null).ToList();
        return Task.FromResult(new CostTotals(withCost.Count, withCost.Sum(s => s.TotalPrice), withCost.Sum(s => s.TotalCost!.Value)));
    }

    public Task<DeletionImpactTotals> GetDeletionImpactAsync(Guid importId, CancellationToken cancellationToken = default)
    {
        var sales = SalesOf(importId).ToList();
        return Task.FromResult(new DeletionImpactTotals(
            sales.Select(s => s.ProductId).OfType<Guid>().Distinct().Count(),
            sales.Where(s => s.IsCheckout).Sum(s => s.Quantity)));
    }

    public Task<IReadOnlyList<SalesImport>> ListAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<SalesImport>>(Items);

    public void Remove(SalesImport salesImport) => Items.Remove(salesImport);

    public Task<IReadOnlyList<ChannelTotals>> GetTotalsByChannelAsync(Guid importId, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<ChannelTotals>>([]);

    public Task<IReadOnlyList<MarketplaceTotals>> GetOnlineTotalsByMarketplaceAsync(Guid importId, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<MarketplaceTotals>>([]);

    public Task<IReadOnlyList<DayTotals>> GetTotalsByDayAsync(Guid importId, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<DayTotals>>(SalesOf(importId)
            .GroupBy(s => s.SaleDate)
            .Select(g => new DayTotals(g.Key, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToList());

    public Task<IReadOnlyList<ProductTotals>> GetTotalsByProductAsync(Guid importId, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<ProductTotals>>(SalesOf(importId)
            .GroupBy(s => (s.ProductName, s.Sku))
            .Select(g => new ProductTotals(g.Key.ProductName, g.Key.Sku, g.Count(), g.Sum(s => s.Quantity),
                g.Sum(s => s.TotalPrice), g.Max(s => s.SaleDate)))
            .ToList());

    private IEnumerable<Sale> SalesOf(Guid importId) => Items.Single(i => i.Id == importId).Sales;

    public Task<SalesImport?> GetByIdWithSalesAsync(Guid id, CancellationToken cancellationToken = default) =>
        GetByIdAsync(id, cancellationToken);

    public List<Sale> AddedSales { get; } = [];
    public List<Sale> RemovedSales { get; } = [];

    public Task AddSaleAsync(Sale sale, CancellationToken cancellationToken = default)
    {
        AddedSales.Add(sale);
        return Task.CompletedTask;
    }

    public void RemoveSale(Sale sale) => RemovedSales.Add(sale);

    public Task<(IReadOnlyList<Sale> Items, int TotalCount)> ListSalesAsync(
        Guid importId, string? search, int skip, int take, CancellationToken cancellationToken = default)
    {
        var matches = SalesOf(importId)
            .Where(s => search is null
                || s.ProductName.Contains(search, StringComparison.OrdinalIgnoreCase)
                || (s.Sku?.Contains(search, StringComparison.OrdinalIgnoreCase) ?? false))
            .OrderByDescending(s => s.SaleDate)
            .ToList();
        return Task.FromResult<(IReadOnlyList<Sale>, int)>((matches.Skip(skip).Take(take).ToList(), matches.Count));
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        Saved = true;
        return Task.CompletedTask;
    }
}

internal sealed class FakeMarketplaceRepository : IMarketplaceRepository
{
    public List<Marketplace> Items { get; } = [];

    public Task<IReadOnlyList<Marketplace>> GetByNormalizedNamesAsync(IReadOnlyCollection<string> normalizedNames, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<Marketplace>>(Items.Where(m => normalizedNames.Contains(m.NormalizedName)).ToList());

    public Task<IReadOnlyList<string>> ListNamesAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<string>>(Items.Select(m => m.Name).Order().ToList());

    public Task AddRangeAsync(IEnumerable<Marketplace> marketplaces, CancellationToken cancellationToken = default)
    {
        Items.AddRange(marketplaces);
        return Task.CompletedTask;
    }
}

internal sealed class FakeProductRepository : IProductRepository
{
    public List<Product> Items { get; } = [];

    /// <summary>Products a sale references (they can't be deleted).</summary>
    public HashSet<Guid> Sold { get; } = [];
    public bool Saved { get; private set; }

    public Task AddAsync(Product product, CancellationToken cancellationToken = default)
    {
        Items.Add(product);
        return Task.CompletedTask;
    }

    public Task<Product?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.FirstOrDefault(p => p.Id == id));

    public Task<IReadOnlyList<Product>> GetByIdsAsync(IReadOnlyCollection<Guid> ids, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<Product>>(Items.Where(p => ids.Contains(p.Id)).ToList());

    public Task<bool> SkuExistsAsync(string sku, Guid? exceptId, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.Any(p => p.Sku == sku && p.Id != exceptId));

    public Task<IReadOnlyList<Product>> ListAsync(
        string? search, string? category, bool includeInactive, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<Product>>(Items
            .Where(p => includeInactive || p.IsActive)
            .Where(p => category is null || string.Equals(p.Category, category, StringComparison.OrdinalIgnoreCase))
            .Where(p => search is null
                || p.Name.Contains(search, StringComparison.OrdinalIgnoreCase)
                || p.Sku.Contains(search, StringComparison.OrdinalIgnoreCase))
            .OrderBy(p => p.Name)
            .ToList());

    public Task<IReadOnlyList<string>> ListCategoriesAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<string>>(Items.Select(p => p.Category).OfType<string>().Distinct().Order().ToList());

    public Task<IReadOnlyDictionary<string, Guid>> GetIdsBySkusAsync(
        IReadOnlyCollection<string> skus, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyDictionary<string, Guid>>(Items.Where(p => skus.Contains(p.Sku)).ToDictionary(p => p.Sku, p => p.Id));

    /// <summary>Calls to <see cref="SyncSaleLinksAsync"/> (the SQL itself is checked against PostgreSQL).</summary>
    public List<(Guid ProductId, string Sku)> Synced { get; } = [];

    public Task SyncSaleLinksAsync(Guid productId, string sku, CancellationToken cancellationToken = default)
    {
        Synced.Add((productId, sku));
        return Task.CompletedTask;
    }

    public Task<bool> HasSalesAsync(Guid id, CancellationToken cancellationToken = default) =>
        Task.FromResult(Sold.Contains(id));

    public Task<bool> IsImageInUseAsync(string imageUrl, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.Any(p => p.ImageUrl == imageUrl));

    public void Remove(Product product) => Items.Remove(product);

    public Task SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        Saved = true;
        return Task.CompletedTask;
    }
}

/// <summary>Month totals computed in memory over a plain list of sales.</summary>
internal sealed class FakeSalesReportRepository : ISalesReportRepository
{
    public List<Sale> Sales { get; } = [];

    /// <summary>Batch of a sale for <see cref="ListSalesAsync"/>; sales not listed here are in "Lote de teste" (spreadsheet).</summary>
    public Dictionary<Sale, (string Name, ImportSource Source)> Batches { get; } = [];

    public Task<IReadOnlyList<SaleLine>> ListSalesAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<SaleLine>>(Between(start, end)
            .Select(s => (Sale: s, Batch: Batches.GetValueOrDefault(s, ("Lote de teste", ImportSource.Spreadsheet))))
            .OrderBy(x => x.Sale.SaleDate)
            .ThenBy(x => x.Batch.Item1)
            .Select(x => new SaleLine(x.Sale.SaleDate, x.Sale.ProductName, x.Sale.Sku, x.Sale.Quantity, x.Sale.UnitPrice,
                x.Sale.TotalPrice, x.Sale.Channel, x.Sale.Marketplace?.Name, x.Batch.Item1, x.Batch.Item2))
            .ToList());

    private IEnumerable<Sale> Between(DateOnly start, DateOnly end) =>
        Sales.Where(s => s.SaleDate >= start && s.SaleDate <= end);

    /// <summary>Monthly totals for the analytics, given directly (instead of computed from <see cref="Sales"/>).</summary>
    public List<ProductMonthTotals>? MonthlyTotals { get; set; }

    /// <summary>Days with sales per month, given directly (instead of computed from <see cref="Sales"/>).</summary>
    public List<MonthActivity>? Activity { get; set; }

    public Task<IReadOnlyList<ProductMonthTotals>> GetTotalsByProductAndMonthAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<ProductMonthTotals>>(MonthlyTotals ?? Sales
            .GroupBy(s => (s.SaleDate.Year, s.SaleDate.Month, s.ProductName, s.Sku, s.ProductId))
            .Select(g => new ProductMonthTotals(g.Key.Year, g.Key.Month, g.Key.ProductName, g.Key.Sku, g.Key.ProductId,
                g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToList());

    public Task<IReadOnlyList<MonthActivity>> GetDaysWithSalesByMonthAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<MonthActivity>>(Activity ?? Sales
            .GroupBy(s => (s.SaleDate.Year, s.SaleDate.Month))
            .Select(g => new MonthActivity(g.Key.Year, g.Key.Month, g.Select(s => s.SaleDate).Distinct().Count()))
            .ToList());

    public Task<IReadOnlyList<MonthTotals>> GetTotalsByMonthAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<MonthTotals>>(Sales
            .GroupBy(s => (s.SaleDate.Year, s.SaleDate.Month))
            .Select(g => new MonthTotals(g.Key.Year, g.Key.Month, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToList());

    public Task<IReadOnlyList<ChannelTotals>> GetTotalsByChannelAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<ChannelTotals>>(Between(start, end)
            .GroupBy(s => s.Channel)
            .Select(g => new ChannelTotals(g.Key, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToList());

    public Task<IReadOnlyList<MarketplaceTotals>> GetOnlineTotalsByMarketplaceAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<MarketplaceTotals>>(Between(start, end)
            .Where(s => s.Channel == SalesChannel.Online)
            .GroupBy(s => (s.MarketplaceId, s.Marketplace?.Name))
            .Select(g => new MarketplaceTotals(g.Key.MarketplaceId, g.Key.Name, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToList());

    public Task<IReadOnlyList<DayTotals>> GetTotalsByDayAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<DayTotals>>(Between(start, end)
            .GroupBy(s => s.SaleDate)
            .Select(g => new DayTotals(g.Key, g.Count(), g.Sum(s => s.Quantity), g.Sum(s => s.TotalPrice)))
            .ToList());

    public Task<IReadOnlyList<ProductTotals>> GetTotalsByProductAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<ProductTotals>>(Between(start, end)
            .GroupBy(s => (s.ProductName, s.Sku))
            .Select(g => new ProductTotals(g.Key.ProductName, g.Key.Sku, g.Count(), g.Sum(s => s.Quantity),
                g.Sum(s => s.TotalPrice), g.Max(s => s.SaleDate)))
            .ToList());

    public Task<CostTotals> GetCostTotalsAsync(DateOnly start, DateOnly end, CancellationToken cancellationToken = default)
    {
        var withCost = Between(start, end).Where(s => s.TotalCost is not null).ToList();
        return Task.FromResult(new CostTotals(withCost.Count, withCost.Sum(s => s.TotalPrice), withCost.Sum(s => s.TotalCost!.Value)));
    }
}
