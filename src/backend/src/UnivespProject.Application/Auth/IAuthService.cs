using UnivespProject.Application.DTOs.Auth;

namespace UnivespProject.Application.Auth;

/// <summary>
/// Methods return null when they fail; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface IAuthService
{
    Task<AuthResponse?> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default);
    Task<AuthResponse?> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default);
    Task<UserResponse?> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Replaces the password after checking the current one. A wrong current password is a
    /// validation error (400), not 401: the user is logged in, only the field is wrong.
    /// </summary>
    Task<bool?> ChangePasswordAsync(Guid userId, ChangePasswordRequest request, CancellationToken cancellationToken = default);

    /// <summary>
    /// Password recovery without confirmation (prototype): replaces the password of the account
    /// with the given e-mail. Unknown e-mail → 404 on the <c>email</c> key.
    /// </summary>
    Task<bool?> ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken = default);
}
