using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Abstractions;

/// <summary>
/// The notification center. Not filtered by store (each notification belongs to a user).
/// Saved together with the users (same unit of work: <see cref="IUserRepository.SaveChangesAsync"/>).
/// </summary>
public interface IUserNotificationRepository
{
    /// <summary>The user's newest notifications (read or not), newest first.</summary>
    Task<IReadOnlyList<UserNotification>> ListLatestAsync(Guid userId, int take, CancellationToken cancellationToken = default);

    Task<int> CountUnreadAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Tracked, so <see cref="UserNotification.MarkRead"/> is saved.</summary>
    Task<UserNotification?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    /// <summary>Unread notifications of a user (tracked).</summary>
    Task<IReadOnlyList<UserNotification>> ListUnreadAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>Unread notifications of any user, of <paramref name="kind"/>, about <paramref name="relatedUserId"/> (tracked).</summary>
    Task<IReadOnlyList<UserNotification>> ListUnreadAboutAsync(
        NotificationKind kind, Guid relatedUserId, CancellationToken cancellationToken = default);

    Task AddAsync(UserNotification notification, CancellationToken cancellationToken = default);

    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}
