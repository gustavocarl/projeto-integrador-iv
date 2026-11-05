using UnivespProject.Application.Notifications;
using UnivespProject.Application.Notifications.Center;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;
using UnivespProject.Tests.Application.Auth;

namespace UnivespProject.Tests.Application.Stores;

public class UserNotificationServiceTests
{
    private readonly InMemoryUserNotificationRepository _notifications = new();
    private readonly Guid _maria = Guid.NewGuid();
    private readonly Guid _joao = Guid.NewGuid();

    private UserNotificationService NewRequest(out INotifier notifier)
    {
        notifier = new Notifier();
        return new UserNotificationService(notifier, _notifications);
    }

    private UserNotification Add(Guid userId, string message, int minutesAgo)
    {
        var notification = new UserNotification(userId, NotificationKind.AccessRequested, message, _joao)
        {
            CreatedAt = DateTime.UtcNow.AddMinutes(-minutesAgo)
        };
        _notifications.Items.Add(notification);
        return notification;
    }

    [Fact]
    public async Task List_ShowsOnlyTheUsersNotifications_NewestFirst_WithTheUnreadCount()
    {
        Add(_maria, "antiga", 10).MarkRead();
        Add(_maria, "nova", 1);
        Add(_joao, "de outro usuário", 0);

        var list = await NewRequest(out _).ListAsync(_maria);

        Assert.Equal(1, list.Unread);
        Assert.Equal(["nova", "antiga"], list.Items.Select(n => n.Message));
        Assert.Equal(("AccessRequested", _joao, false), (list.Items[0].Kind, list.Items[0].RelatedUserId, list.Items[0].Read));
    }

    [Fact]
    public async Task MarkRead_OnlyForTheOwner()
    {
        var notification = Add(_maria, "pedido", 0);

        await NewRequest(out var notifier).MarkReadAsync(_joao, notification.Id);
        Assert.Equal(NotificationType.NotFound, Assert.Single(notifier.Notifications).Type);
        Assert.False(notification.IsRead);

        var read = await NewRequest(out _).MarkReadAsync(_maria, notification.Id);
        Assert.True(read!.Read);
    }

    [Fact]
    public async Task MarkAllRead_MarksOnlyTheUsersUnreadNotifications()
    {
        Add(_maria, "1", 2);
        Add(_maria, "2", 1);
        var other = Add(_joao, "3", 0);

        Assert.Equal(2, await NewRequest(out _).MarkAllReadAsync(_maria));
        Assert.Equal(0, (await NewRequest(out _).ListAsync(_maria)).Unread);
        Assert.False(other.IsRead);
    }
}
