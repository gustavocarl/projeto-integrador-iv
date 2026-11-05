using UnivespProject.Domain.Notifications;

namespace UnivespProject.Domain.Common;

/// <summary>
/// Base for every entity: identity, audit fields and notifications.
/// Abstract, so it can only be inherited, never instantiated.
/// </summary>
public abstract class BaseEntity : Notifiable
{
    public Guid Id { get; protected set; } = Guid.NewGuid();

    public string CreatedBy { get; set; } = string.Empty;
    public string? UpdatedBy { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? UpdatedAt { get; set; }
}
