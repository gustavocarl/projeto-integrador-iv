using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Notifications;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Notifications.Center;

internal sealed class UserNotificationService(
    INotifier notifier,
    IUserNotificationRepository notifications) : BaseService(notifier), IUserNotificationService
{
    public const int PageSize = 30;

    public async Task<NotificationListResponse> ListAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var items = await notifications.ListLatestAsync(userId, PageSize, cancellationToken);
        var unread = await notifications.CountUnreadAsync(userId, cancellationToken);
        return new NotificationListResponse(unread, items.Select(ToResponse).ToList());
    }

    public async Task<NotificationResponse?> MarkReadAsync(Guid userId, Guid notificationId, CancellationToken cancellationToken = default)
    {
        var notification = await notifications.GetByIdAsync(notificationId, cancellationToken);
        if (notification is null || notification.UserId != userId)
        {
            Notify("Notificação não encontrada.", NotificationType.NotFound);
            return null;
        }

        notification.MarkRead();
        await notifications.SaveChangesAsync(cancellationToken);
        return ToResponse(notification);
    }

    public async Task<int> MarkAllReadAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var unread = await notifications.ListUnreadAsync(userId, cancellationToken);
        foreach (var notification in unread)
            notification.MarkRead();

        await notifications.SaveChangesAsync(cancellationToken);
        return unread.Count;
    }

    private static NotificationResponse ToResponse(UserNotification n) =>
        new(n.Id, n.Kind.ToString(), n.Message, n.RelatedUserId, n.IsRead, n.CreatedAt);
}
