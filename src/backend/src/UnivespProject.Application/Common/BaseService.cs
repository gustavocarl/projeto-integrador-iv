using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Common;

/// <summary>
/// Base for every application service. Errors are reported through <see cref="INotifier"/>
/// instead of exceptions or ad-hoc return types.
/// </summary>
public abstract class BaseService(INotifier notifier)
{
    protected bool HasNotifications => notifier.HasNotifications;

    protected void Notify(string key, string message, NotificationType type = NotificationType.Validation) =>
        notifier.Add(new Notification(key, message, type));

    protected void Notify(string message, NotificationType type) => Notify(string.Empty, message, type);

    /// <summary>
    /// Copies the entity's notifications to the request notifier.
    /// </summary>
    /// <returns>True when the entity is valid.</returns>
    protected bool Validate(INotifiable notifiable)
    {
        notifier.AddRange(notifiable.Notifications);
        return notifiable.IsValid;
    }
}
