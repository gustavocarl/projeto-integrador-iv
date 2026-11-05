using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Notifications;

/// <summary>
/// Collects the errors of the current request. Scoped: one instance per HTTP request,
/// shared by every service involved, and read by the API to build the response.
/// </summary>
public interface INotifier
{
    bool HasNotifications { get; }
    IReadOnlyCollection<Notification> Notifications { get; }

    void Add(Notification notification);
    void AddRange(IEnumerable<Notification> notifications);
}
