using UnivespProject.Application.DTOs.Products;

namespace UnivespProject.Application.Products;

/// <summary>
/// The product catalog. Methods return null when they fail; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface IProductService
{
    Task<IReadOnlyList<ProductResponse>> ListAsync(
        string? search, string? category, bool includeInactive, CancellationToken cancellationToken = default);

    Task<ProductResponse?> GetAsync(Guid id, CancellationToken cancellationToken = default);
    Task<ProductResponse?> CreateAsync(ProductRequest request, CancellationToken cancellationToken = default);
    Task<ProductResponse?> UpdateAsync(Guid id, ProductRequest request, CancellationToken cancellationToken = default);

    /// <summary>Only products never sold can be deleted; the others are deactivated instead (409).</summary>
    Task<bool?> DeleteAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Categories in use, to suggest while typing and to filter.</summary>
    Task<IReadOnlyList<string>> ListCategoriesAsync(CancellationToken cancellationToken = default);
}
