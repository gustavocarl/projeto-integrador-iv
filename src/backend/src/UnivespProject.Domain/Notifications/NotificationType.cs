namespace UnivespProject.Domain.Notifications;

/// <summary>
/// Kind of problem being reported. The API uses it to choose the HTTP status code.
/// </summary>
public enum NotificationType
{
    Validation,
    Unauthorized,
    NotFound,
    Conflict,

    /// <summary>Logged in, but not allowed (no store access, area not given, not an admin).</summary>
    Forbidden
}
