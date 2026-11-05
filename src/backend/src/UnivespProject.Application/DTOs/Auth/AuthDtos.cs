using UnivespProject.Application.DTOs.Stores;

namespace UnivespProject.Application.DTOs.Auth;

/// <summary>
/// Sign-up. <c>StoreName</c>: when a store with this name exists (ignoring accents, casing and extra
/// spaces) the user asks its admins for access; otherwise the store is opened and the user is its admin.
/// Error keys: <c>name</c>, <c>email</c>, <c>password</c>, <c>storeName</c>.
/// </summary>
public sealed record RegisterRequest(string Name, string Email, string Password, string? StoreName = null)
{
    public static class Fields
    {
        public const string StoreName = "storeName";
    }
}

public sealed record LoginRequest(string Email, string Password);

/// <summary>Error keys: <c>currentPassword</c> and <c>newPassword</c> (the JSON field names).</summary>
public sealed record ChangePasswordRequest(string? CurrentPassword, string? NewPassword)
{
    public static class Fields
    {
        public const string CurrentPassword = "currentPassword";
        public const string NewPassword = "newPassword";
    }
}

/// <summary>
/// Sets a new password for the account of <c>Email</c> without any check (simple recovery chosen by
/// the user for the prototype: whoever knows the e-mail can change the password).
/// Error keys: <c>email</c> and <c>newPassword</c>.
/// </summary>
public sealed record ResetPasswordRequest(string? Email, string? NewPassword)
{
    public static class Fields
    {
        public const string Email = "email";
        public const string NewPassword = "newPassword";
    }
}

/// <summary>
/// The user's settings are in <c>GET /api/settings</c> (table <c>user_settings</c>).
/// <c>Store</c> is null when the user has no store (removed by an admin).
/// </summary>
public sealed record UserResponse(Guid Id, string Name, string Email, DateTime CreatedAt, StoreMembershipResponse? Store = null);

public sealed record AuthResponse(string AccessToken, DateTime ExpiresAt, UserResponse User);
