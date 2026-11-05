using UnivespProject.Application.DTOs.Sales;

namespace UnivespProject.Application.Sales;

/// <summary>
/// Compares months over every sale, whatever its batch.
/// Methods return null when they fail; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface ISalesComparisonService
{
    /// <summary>Months with sales, most recent first.</summary>
    Task<IReadOnlyList<SalesMonthItem>> ListMonthsAsync(CancellationToken cancellationToken = default);

    /// <param name="baseMonth">The reference month, "2026-01".</param>
    /// <param name="targetMonth">The month measured against it, "2026-02".</param>
    Task<MonthComparisonResponse?> CompareAsync(string? baseMonth, string? targetMonth, CancellationToken cancellationToken = default);
}
