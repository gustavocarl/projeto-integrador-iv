namespace UnivespProject.Domain.Notifications;

/// <summary>
/// A single error message.
/// </summary>
/// <param name="Key">Field the error refers to (e.g. "email"), or empty for a general error.</param>
/// <param name="Message">Message shown to the user.</param>
/// <param name="Type">Kind of problem.</param>
public sealed record Notification(string Key, string Message, NotificationType Type = NotificationType.Validation);
