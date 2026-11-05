using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Notifications.Center;

/// <summary>
/// Notification-center messages about access requests. Nothing is saved here: the caller saves
/// (same unit of work as the users).
/// </summary>
public interface IAccessRequestNotices
{
    /// <summary>Tells every admin of <paramref name="store"/> that <paramref name="requester"/> asked to join.</summary>
    Task RequestedAsync(User requester, Store store, CancellationToken cancellationToken = default);

    /// <summary>
    /// The request of <paramref name="requesterId"/> was answered (approved, refused or replaced):
    /// the admins' notifications about it are marked as read.
    /// </summary>
    Task ResolveAsync(Guid requesterId, CancellationToken cancellationToken = default);

    /// <summary>Tells the member that the access was approved.</summary>
    Task ApprovedAsync(User member, CancellationToken cancellationToken = default);
}
