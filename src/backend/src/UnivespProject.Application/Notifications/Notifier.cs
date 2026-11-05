using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Notifications;

internal sealed class Notifier : INotifier
{
    private readonly List<Notification> _notifications = [];

    public bool HasNotifications => _notifications.Count > 0;
    public IReadOnlyCollection<Notification> Notifications => _notifications;

    public void Add(Notification notification) => _notifications.Add(notification);

    public void AddRange(IEnumerable<Notification> notifications) => _notifications.AddRange(notifications);
}
