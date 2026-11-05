namespace UnivespProject.Domain.Notifications;

/// <summary>
/// Base for every class that needs to report errors. It can only be inherited:
/// derived classes call <see cref="AddNotification(string, string, NotificationType)"/> instead of throwing.
/// </summary>
public abstract class Notifiable : INotifiable
{
    private readonly List<Notification> _notifications = [];

    public IReadOnlyCollection<Notification> Notifications => _notifications;
    public bool IsValid => _notifications.Count == 0;

    protected void AddNotification(string key, string message, NotificationType type = NotificationType.Validation) =>
        _notifications.Add(new Notification(key, message, type));

    protected void AddNotifications(INotifiable other) => _notifications.AddRange(other.Notifications);

    protected void ClearNotifications() => _notifications.Clear();
}
