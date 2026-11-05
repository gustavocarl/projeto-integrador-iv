using UnivespProject.Application.DTOs.Notifications;

namespace UnivespProject.Application.Notifications.Center;

/// <summary>The logged-in user's notification center. Null = failed (reasons in <see cref="INotifier"/>).</summary>
public interface IUserNotificationService
{
    /// <summary>The newest <see cref="UserNotificationService.PageSize"/> notifications and the unread count.</summary>
    Task<NotificationListResponse> ListAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>404 for someone else's notification.</summary>
    Task<NotificationResponse?> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken cancellationToken = default);

    /// <summary>How many were marked.</summary>
    Task<int> MarkAllReadAsync(Guid userId, CancellationToken cancellationToken = default);
}
