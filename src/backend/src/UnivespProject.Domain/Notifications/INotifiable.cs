namespace UnivespProject.Domain.Notifications;

/// <summary>
/// An object that validates itself and keeps the errors it found instead of throwing exceptions.
/// </summary>
public interface INotifiable
{
    IReadOnlyCollection<Notification> Notifications { get; }
    bool IsValid { get; }
}
