using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal sealed class ProductRepository(AppDbContext context) : IProductRepository
{
    public async Task AddAsync(Product product, CancellationToken cancellationToken = default) =>
        await context.Products.AddAsync(product, cancellationToken);

    public Task<Product?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        context.Products.FirstOrDefaultAsync(p => p.Id == id, cancellationToken);

    public async Task<IReadOnlyList<Product>> GetByIdsAsync(IReadOnlyCollection<Guid> ids, CancellationToken cancellationToken = default)
    {
        if (ids.Count == 0)
            return [];

        return await context.Products.Where(p => ids.Contains(p.Id)).ToListAsync(cancellationToken);
    }

    public Task<bool> SkuExistsAsync(string sku, Guid? exceptId, CancellationToken cancellationToken = default) =>
        context.Products.AnyAsync(p => p.Sku == sku && p.Id != exceptId, cancellationToken);

    public async Task<IReadOnlyList<Product>> ListAsync(
        string? search, string? category, bool includeInactive, CancellationToken cancellationToken = default)
    {
        var query = context.Products.AsNoTracking();
        if (!includeInactive)
            query = query.Where(p => p.IsActive);
        if (category is not null)
            query = query.Where(p => p.Category != null && EF.Functions.ILike(p.Category, LikePattern.Escape(category), @"\"));
        if (search is not null)
        {
            var pattern = $"%{LikePattern.Escape(search)}%";
            query = query.Where(p => EF.Functions.ILike(p.Name, pattern, @"\") || EF.Functions.ILike(p.Sku, pattern, @"\"));
        }

        return await query.OrderBy(p => p.Name).ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<string>> ListCategoriesAsync(CancellationToken cancellationToken = default) =>
        await context.Products.AsNoTracking()
            .Where(p => p.Category != null)
            .Select(p => p.Category!)
            .Distinct()
            .OrderBy(c => c)
            .ToListAsync(cancellationToken);

    public async Task<IReadOnlyDictionary<string, Guid>> GetIdsBySkusAsync(
        IReadOnlyCollection<string> skus, CancellationToken cancellationToken = default) =>
        skus.Count == 0
            ? new Dictionary<string, Guid>()
            : await context.Products
                .Where(p => skus.Contains(p.Sku))
                .ToDictionaryAsync(p => p.Sku, p => p.Id, cancellationToken);

    public async Task SyncSaleLinksAsync(Guid productId, string sku, CancellationToken cancellationToken = default)
    {
        // Same rule as Sale.SkuKey: the sale's SKU in upper case.
        await context.Sales
            .Where(s => s.ProductId == productId && !s.IsCheckout && (s.Sku == null || s.Sku.ToUpper() != sku))
            .ExecuteUpdateAsync(u => u.SetProperty(s => s.ProductId, (Guid?)null), cancellationToken);

        await context.Sales
            .Where(s => s.ProductId == null && s.Sku != null && s.Sku.ToUpper() == sku)
            .ExecuteUpdateAsync(u => u.SetProperty(s => s.ProductId, productId), cancellationToken);
    }

    public Task<bool> HasSalesAsync(Guid id, CancellationToken cancellationToken = default) =>
        context.Sales.AnyAsync(s => s.ProductId == id, cancellationToken);

    // Every store: the uploads folder is shared, so a file can't go while another store still shows it.
    public Task<bool> IsImageInUseAsync(string imageUrl, CancellationToken cancellationToken = default) =>
        context.Products.IgnoreQueryFilters().AnyAsync(p => p.ImageUrl == imageUrl, cancellationToken);

    public void Remove(Product product) => context.Products.Remove(product);

    public Task SaveChangesAsync(CancellationToken cancellationToken = default) =>
        context.SaveChangesAsync(cancellationToken);
}
