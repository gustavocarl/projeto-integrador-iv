using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Notifications.Center;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Stores;

internal sealed class StoreEnrollment(
    INotifier notifier,
    IStoreRepository stores,
    IAccessRequestNotices notices) : BaseService(notifier), IStoreEnrollment
{
    public Store? Prepare(string? name, string key)
    {
        var store = new Store(name);
        foreach (var notification in store.Notifications)
            Notify(key, notification.Message);
        return store.IsValid ? store : null;
    }

    public async Task<StoreEnrollmentResult> EnrollAsync(User user, Store prepared, CancellationToken cancellationToken = default)
    {
        // A previous request (another store, or the same one asked again) is replaced.
        if (user.Role is not null)
            await notices.ResolveAsync(user.Id, cancellationToken);

        var existing = await stores.GetByNormalizedNameAsync(prepared.NormalizedName, cancellationToken);
        if (existing is null)
        {
            await stores.AddAsync(prepared, cancellationToken);
            user.OpenStore(prepared);
            return StoreEnrollmentResult.Opened;
        }

        user.RequestAccess(existing);
        await notices.RequestedAsync(user, existing, cancellationToken);
        return StoreEnrollmentResult.Requested;
    }
}
