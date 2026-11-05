using UnivespProject.Application.DTOs.Analytics;

namespace UnivespProject.Application.Analytics;

/// <summary>
/// Groups the products that sell alike (k-means over volume, price and regularity).
/// Returns null when it fails; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface IProductGroupsService
{
    /// <param name="groups">2 to 6; null = the number with the best silhouette.</param>
    Task<ProductGroupsResponse?> GroupAsync(int? groups, CancellationToken cancellationToken = default);
}
