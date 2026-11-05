using UnivespProject.Domain.Common;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Abstractions;

public sealed record ChannelTotals(SalesChannel Channel, int Sales, int Quantity, decimal Revenue);

/// <param name="MarketplaceId">Null for online sales outside a marketplace.</param>
public sealed record MarketplaceTotals(Guid? MarketplaceId, string? MarketplaceName, int Sales, int Quantity, decimal Revenue);

public sealed record DayTotals(DateOnly Date, int Sales, int Quantity, decimal Revenue);

/// <summary>Totals per product name + SKU as written in the spreadsheet (the service merges variations).</summary>
public sealed record ProductTotals(string ProductName, string? Sku, int Sales, int Quantity, decimal Revenue, DateOnly LastSaleDate)
{
    /// <summary>The product's identity: normalized SKU, or name when there is no SKU.</summary>
    public string Key => TextNormalizer.ToKey(string.IsNullOrWhiteSpace(Sku) ? ProductName : Sku);
}

/// <summary>Sales whose cost is known (TotalCost not null): how many, their revenue and their cost.</summary>
public sealed record CostTotals(int Sales, decimal Revenue, decimal Cost);

/// <summary>What removing a batch takes away.</summary>
/// <param name="LinkedProducts">Distinct catalog products its sales are linked to (checkout or same SKU).</param>
/// <param name="CheckoutQuantity">Units sold at the checkout: they go back to stock.</param>
public sealed record DeletionImpactTotals(int LinkedProducts, int CheckoutQuantity);

public interface ISalesImportRepository
{
    Task AddAsync(SalesImport salesImport, CancellationToken cancellationToken = default);
    Task<SalesImport?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>The batch of that source and exact name (finds the month's checkout batch).</summary>
    Task<SalesImport?> GetByNameAsync(ImportSource source, string fileName, CancellationToken cancellationToken = default);

    /// <summary>The batch with every sale loaded (to remove one and recalculate the totals).</summary>
    Task<SalesImport?> GetByIdWithSalesAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Registers a sale added to a batch that already exists in the database.</summary>
    Task AddSaleAsync(Sale sale, CancellationToken cancellationToken = default);

    void RemoveSale(Sale sale);

    /// <summary>
    /// A page of the batch's sales (with marketplace), most recent date first.
    /// <paramref name="search"/> matches product name or SKU, ignoring case.
    /// </summary>
    Task<(IReadOnlyList<Sale> Items, int TotalCount)> ListSalesAsync(
        Guid importId, string? search, int skip, int take, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<SalesImport>> ListAsync(CancellationToken cancellationToken = default);
    void Remove(SalesImport salesImport);

    Task<IReadOnlyList<ChannelTotals>> GetTotalsByChannelAsync(Guid importId, CancellationToken cancellationToken = default);

    /// <summary>Totals of the online sales of an import, grouped by marketplace.</summary>
    Task<IReadOnlyList<MarketplaceTotals>> GetOnlineTotalsByMarketplaceAsync(Guid importId, CancellationToken cancellationToken = default);

    /// <summary>Totals per sale date; days without sales are not returned.</summary>
    Task<IReadOnlyList<DayTotals>> GetTotalsByDayAsync(Guid importId, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<ProductTotals>> GetTotalsByProductAsync(Guid importId, CancellationToken cancellationToken = default);

    Task<CostTotals> GetCostTotalsAsync(Guid importId, CancellationToken cancellationToken = default);

    Task<DeletionImpactTotals> GetDeletionImpactAsync(Guid importId, CancellationToken cancellationToken = default);

    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}
