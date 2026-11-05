using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Notifications.Center;

internal sealed class AccessRequestNotices(
    IUserRepository users,
    IUserNotificationRepository notifications) : IAccessRequestNotices
{
    public async Task RequestedAsync(User requester, Store store, CancellationToken cancellationToken = default)
    {
        var message = $"{requester.Name} ({requester.Email}) pediu acesso à loja {store.Name}.";
        foreach (var admin in (await users.ListByStoreAsync(store.Id, cancellationToken)).Where(u => u.IsStoreAdmin))
        {
            await notifications.AddAsync(
                new UserNotification(admin.Id, NotificationKind.AccessRequested, message, requester.Id),
                cancellationToken);
        }
    }

    public async Task ResolveAsync(Guid requesterId, CancellationToken cancellationToken = default)
    {
        foreach (var notification in await notifications.ListUnreadAboutAsync(
                     NotificationKind.AccessRequested, requesterId, cancellationToken))
            notification.MarkRead();
    }

    public Task ApprovedAsync(User member, CancellationToken cancellationToken = default) =>
        notifications.AddAsync(
            new UserNotification(member.Id, NotificationKind.AccessApproved,
                $"Seu acesso à loja {member.Store?.Name} foi aprovado.", member.Id),
            cancellationToken);
}
