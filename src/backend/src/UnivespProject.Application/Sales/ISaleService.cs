using UnivespProject.Application.DTOs.Sales;

namespace UnivespProject.Application.Sales;

/// <summary>
/// Single sales: typed in by the user, listed and removed one by one.
/// Methods return null when they fail; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface ISaleService
{
    Task<ManualSaleResponse?> CreateAsync(ManualSaleRequest request, CancellationToken cancellationToken = default);

    Task<PagedResponse<SaleResponse>?> ListAsync(
        Guid importId, string? search, int page, int pageSize, CancellationToken cancellationToken = default);

    /// <summary>Removes the sale and recalculates the batch totals. The batch stays, even if empty.</summary>
    Task<bool?> DeleteAsync(Guid importId, Guid saleId, CancellationToken cancellationToken = default);

    /// <summary>Known marketplace names, to suggest while typing.</summary>
    Task<IReadOnlyList<string>> ListMarketplacesAsync(CancellationToken cancellationToken = default);
}
