namespace UnivespProject.Application.DTOs.Stores;

/// <summary>The logged-in user's store.</summary>
/// <param name="Role">"Admin", "Member" or "Pending".</param>
/// <param name="Areas">What the user may use ("Products", "Checkout", "Imports", "Exports", "Comparison", "Analytics").</param>
public sealed record StoreMembershipResponse(Guid Id, string Name, string Role, IReadOnlyList<string> Areas);

/// <summary>
/// Enters a store by name: an existing store (ignoring accents, casing and extra spaces) gets an access
/// request (its admins are notified); a new name opens the store with the user as admin. Error key: <c>name</c>.
/// </summary>
public sealed record EnterStoreRequest(string? Name);

/// <summary>Admin renames the store (names are unique). Error key: <c>name</c>.</summary>
public sealed record RenameStoreRequest(string? Name);

/// <summary>A user of the admin's store (pending requests too).</summary>
public sealed record StoreMemberResponse(
    Guid Id, string Name, string Email, string Role, IReadOnlyList<string> Areas, DateTime CreatedAt);

/// <summary>Approves a request. <c>Areas</c> null = every area. Error key: <c>areas</c>.</summary>
public sealed record ApproveMemberRequest(IReadOnlyList<string>? Areas);

/// <summary>"Admin" or "Member". Error key: <c>role</c>.</summary>
public sealed record ChangeMemberRoleRequest(string? Role)
{
    public static class Fields
    {
        public const string Role = "role";
    }
}

/// <summary>Areas of a member (admins always have all). Error key: <c>areas</c>.</summary>
public sealed record UpdateMemberAreasRequest(IReadOnlyList<string>? Areas)
{
    public static class Fields
    {
        public const string Areas = "areas";
    }
}
