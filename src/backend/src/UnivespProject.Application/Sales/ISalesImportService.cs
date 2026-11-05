using UnivespProject.Application.DTOs.Sales;

namespace UnivespProject.Application.Sales;

/// <summary>
/// Methods return null when they fail; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface ISalesImportService
{
    /// <summary>
    /// Validates the whole spreadsheet; saves it only when every row is valid. With the logged-in
    /// user's setting <c>CreateProductsOnImport</c>, each SKU of the spreadsheet that is not in the
    /// catalog becomes a product (saved together with the sales).
    /// </summary>
    Task<SalesImportResponse?> ImportAsync(SpreadsheetFile file, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<SalesImportResponse>> ListAsync(CancellationToken cancellationToken = default);
    Task<SalesImportDetailResponse?> GetAsync(Guid id, CancellationToken cancellationToken = default);
    Task<bool?> DeleteAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>What <see cref="DeleteAsync"/> would take away, for the confirmation (nothing is changed).</summary>
    Task<SalesImportDeletionImpactResponse?> GetDeletionImpactAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>The template, in the default spreadsheet font of <paramref name="platform"/> (see <see cref="SpreadsheetFont"/>).</summary>
    byte[]? CreateTemplate(string? platform = null);
}
