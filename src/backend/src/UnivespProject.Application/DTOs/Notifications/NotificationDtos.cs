namespace UnivespProject.Application.DTOs.Notifications;

/// <summary>A message of the notification center (the bell in the app).</summary>
/// <param name="Kind">"AccessRequested" (someone asked to join the store; see <c>RelatedUserId</c>) or "AccessApproved".</param>
/// <param name="RelatedUserId">Who the notification talks about (e.g. who asked for access).</param>
public sealed record NotificationResponse(
    Guid Id, string Kind, string Message, Guid? RelatedUserId, bool Read, DateTime CreatedAt);

/// <summary>The newest notifications and how many are unread (the bell's counter).</summary>
public sealed record NotificationListResponse(int Unread, IReadOnlyList<NotificationResponse> Items);
