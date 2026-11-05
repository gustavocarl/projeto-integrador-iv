using UnivespProject.Application.DTOs.Sales;

namespace UnivespProject.Application.Sales;

/// <summary>
/// Sells catalog products: validates every item, takes them out of stock and records the sales in the
/// month's batch, all or nothing. Returns null when it fails; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface ICheckoutService
{
    Task<CheckoutResponse?> CheckoutAsync(CheckoutRequest request, CancellationToken cancellationToken = default);
}
