using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Products;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Settings;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Products;

internal sealed class ProductService(
    INotifier notifier,
    IProductRepository products,
    ICurrentUserSettings settings,
    IProductImageStorage images)
    : BaseService(notifier), IProductService
{
    public async Task<IReadOnlyList<ProductResponse>> ListAsync(
        string? search, string? category, bool includeInactive, CancellationToken cancellationToken = default)
    {
        search = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
        category = string.IsNullOrWhiteSpace(category) ? null : category.Trim();
        return (await products.ListAsync(search, category, includeInactive, cancellationToken)).Select(ToResponse).ToList();
    }

    public async Task<ProductResponse?> GetAsync(Guid id, CancellationToken cancellationToken = default) =>
        await FindAsync(id, cancellationToken) is { } product ? ToResponse(product) : null;

    public async Task<ProductResponse?> CreateAsync(ProductRequest request, CancellationToken cancellationToken = default)
    {
        var product = new Product(request.Name, request.Sku, request.Category, request.SalePrice, request.CostPrice,
            request.StockQuantity, request.MinimumStock, request.ImageUrl, await IsImageRequiredAsync(cancellationToken));
        if (!Validate(product) || !IsImageAvailable(product) || await IsSkuTakenAsync(product.Sku, null, cancellationToken))
            return null;

        product.SetActive(request.IsActive ?? true);
        await products.AddAsync(product, cancellationToken);
        await products.SaveChangesAsync(cancellationToken);
        // Sales typed in or imported before the product existed now belong to it.
        await products.SyncSaleLinksAsync(product.Id, product.Sku, cancellationToken);
        return ToResponse(product);
    }

    public async Task<ProductResponse?> UpdateAsync(Guid id, ProductRequest request, CancellationToken cancellationToken = default)
    {
        var product = await FindAsync(id, cancellationToken);
        if (product is null)
            return null;

        var previousImage = product.ImageUrl;
        product.Update(request.Name, request.Sku, request.Category, request.SalePrice, request.CostPrice,
            request.StockQuantity, request.MinimumStock, request.ImageUrl, await IsImageRequiredAsync(cancellationToken));
        if (!Validate(product) || !IsImageAvailable(product) || await IsSkuTakenAsync(product.Sku, id, cancellationToken))
            return null;

        product.SetActive(request.IsActive ?? product.IsActive);
        await products.SaveChangesAsync(cancellationToken);
        if (previousImage != product.ImageUrl)
            await DeleteImageIfUnusedAsync(previousImage, cancellationToken);
        // A new SKU takes the sales with that SKU and leaves the old ones.
        await products.SyncSaleLinksAsync(product.Id, product.Sku, cancellationToken);
        return ToResponse(product);
    }

    public async Task<bool?> DeleteAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var product = await FindAsync(id, cancellationToken);
        if (product is null)
            return null;

        if (await products.HasSalesAsync(id, cancellationToken))
        {
            Notify("Este produto já tem vendas e não pode ser excluído. Desative-o para tirá-lo do catálogo.",
                NotificationType.Conflict);
            return null;
        }

        products.Remove(product);
        await products.SaveChangesAsync(cancellationToken);
        await DeleteImageIfUnusedAsync(product.ImageUrl, cancellationToken);
        return true;
    }

    public Task<IReadOnlyList<string>> ListCategoriesAsync(CancellationToken cancellationToken = default) =>
        products.ListCategoriesAsync(cancellationToken);

    /// <summary>A path on the API ("/uploads/…") must be an image uploaded here that still exists.</summary>
    private bool IsImageAvailable(Product product)
    {
        if (product.ImageUrl is not { } url || !url.StartsWith('/') || (images.IsStored(url) && images.Exists(url)))
            return true;

        Notify(Product.Fields.ImageUrl, "A imagem enviada não foi encontrada. Envie o arquivo novamente.");
        return false;
    }

    /// <summary>Removes an uploaded image no product uses anymore (external links are left alone).</summary>
    private async Task DeleteImageIfUnusedAsync(string? imageUrl, CancellationToken cancellationToken)
    {
        if (images.IsStored(imageUrl) && !await products.IsImageInUseAsync(imageUrl!, cancellationToken))
            await images.DeleteAsync(imageUrl, cancellationToken);
    }

    /// <summary>The logged-in user's setting "products need an image".</summary>
    private async Task<bool> IsImageRequiredAsync(CancellationToken cancellationToken) =>
        (await settings.GetAsync(cancellationToken)).RequireProductImage;

    private async Task<bool> IsSkuTakenAsync(string sku, Guid? exceptId, CancellationToken cancellationToken)
    {
        if (!await products.SkuExistsAsync(sku, exceptId, cancellationToken))
            return false;

        Notify(Product.Fields.Sku, $"Já existe um produto com o SKU {sku}.", NotificationType.Conflict);
        return true;
    }

    private async Task<Product?> FindAsync(Guid id, CancellationToken cancellationToken)
    {
        var product = await products.GetByIdAsync(id, cancellationToken);
        if (product is null)
            Notify("Produto não encontrado.", NotificationType.NotFound);

        return product;
    }

    internal static ProductResponse ToResponse(Product p) => new(
        p.Id, p.Name, p.Sku, p.Category, p.SalePrice, p.CostPrice,
        p.CostPrice is { } cost && p.SalePrice > 0 ? Math.Round((p.SalePrice - cost) / p.SalePrice, 4) : null,
        p.StockQuantity, p.MinimumStock, p.IsLowStock, p.IsActive, p.ImageUrl, p.CreatedAt, p.UpdatedAt);
}
