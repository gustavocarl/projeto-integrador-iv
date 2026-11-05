using UnivespProject.Application.DTOs.Analytics;

namespace UnivespProject.Application.Analytics;

/// <summary>
/// Predicts the sales of the coming months per product, with a stock purchase suggestion.
/// Returns null when it fails; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface ISalesForecastService
{
    /// <param name="months">How many months after the current one, 1 to 6 (default 3).</param>
    Task<SalesForecastResponse?> ForecastAsync(int? months, CancellationToken cancellationToken = default);
}
