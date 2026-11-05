namespace UnivespProject.Domain.Enums;

/// <summary>What a user notification is about. Stored and sent as its name.</summary>
public enum NotificationKind
{
    /// <summary>To the store's admins: someone asked to join (<c>RelatedUserId</c> = who asked).</summary>
    AccessRequested = 1,

    /// <summary>To the person who asked: an admin approved the access.</summary>
    AccessApproved = 2
}
