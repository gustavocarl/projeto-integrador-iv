using UnivespProject.Domain.Common;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Domain.Entities;

/// <summary>
/// A message shown in a user's notification center (the bell in the app). Not to be confused with
/// <see cref="Notifications.Notification"/>, the validation messages of a request.
/// </summary>
public sealed class UserNotification : BaseEntity
{
    public const int MessageMaxLength = 500;

    /// <summary>Who receives it.</summary>
    public Guid UserId { get; private set; }

    public NotificationKind Kind { get; private set; }
    public string Message { get; private set; } = string.Empty;

    /// <summary>The user the notification talks about (e.g. who asked for access).</summary>
    public Guid? RelatedUserId { get; private set; }

    public DateTime? ReadAt { get; private set; }

    public bool IsRead => ReadAt is not null;

    // Required by Entity Framework.
    private UserNotification() { }

    public UserNotification(Guid userId, NotificationKind kind, string message, Guid? relatedUserId = null)
    {
        UserId = userId;
        Kind = kind;
        Message = message.Length > MessageMaxLength ? message[..MessageMaxLength] : message;
        RelatedUserId = relatedUserId;
    }

    public void MarkRead()
    {
        ReadAt ??= DateTime.UtcNow;
    }
}
