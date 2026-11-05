using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Abstractions;

public interface IProductRepository
{
    Task AddAsync(Product product, CancellationToken cancellationToken = default);
    Task<Product?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<Product>> GetByIdsAsync(IReadOnlyCollection<Guid> ids, CancellationToken cancellationToken = default);

    /// <summary>True when another product (not <paramref name="exceptId"/>) already uses the SKU.</summary>
    Task<bool> SkuExistsAsync(string sku, Guid? exceptId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Products sorted by name. <paramref name="search"/> matches name or SKU, ignoring case;
    /// <paramref name="category"/> must match exactly, ignoring case.
    /// </summary>
    Task<IReadOnlyList<Product>> ListAsync(
        string? search, string? category, bool includeInactive, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<string>> ListCategoriesAsync(CancellationToken cancellationToken = default);

    /// <summary>Ids of the products with these SKUs (already in upper case), keyed by SKU.</summary>
    Task<IReadOnlyDictionary<string, Guid>> GetIdsBySkusAsync(
        IReadOnlyCollection<string> skus, CancellationToken cancellationToken = default);

    /// <summary>
    /// Keeps the typed-in and spreadsheet sales linked to the product by SKU, right away (no SaveChanges):
    /// links unlinked sales whose SKU matches <paramref name="sku"/> and unlinks the product's
    /// non-checkout sales that no longer match (after a SKU change). Checkout sales are never touched.
    /// </summary>
    Task SyncSaleLinksAsync(Guid productId, string sku, CancellationToken cancellationToken = default);

    /// <summary>True when a sale references the product (it can then only be deactivated).</summary>
    Task<bool> HasSalesAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>True when a saved product uses this image (so its file must be kept).</summary>
    Task<bool> IsImageInUseAsync(string imageUrl, CancellationToken cancellationToken = default);

    void Remove(Product product);
    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}
