using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Auth;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Stores;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Auth;

internal sealed class AuthService(
    INotifier notifier,
    IUserRepository users,
    IPasswordHasher passwordHasher,
    ITokenService tokenService,
    IStoreEnrollment enrollment) : BaseService(notifier), IAuthService
{
    // Same message for unknown e-mail and wrong password, so the API does not reveal which accounts exist.
    private const string InvalidCredentials = "E-mail ou senha inválidos.";

    public async Task<AuthResponse?> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
    {
        var user = new User(request.Name, request.Email);
        Validate(user);

        foreach (var error in PasswordPolicy.Validate(request.Password))
            Notify(User.Fields.Password, error);

        // Every user opens a store or asks to join an existing one (same name).
        var store = enrollment.Prepare(request.StoreName, RegisterRequest.Fields.StoreName);

        if (HasNotifications)
            return null;

        if (await users.EmailExistsAsync(user.Email, cancellationToken))
        {
            Notify(User.Fields.Email, "Já existe um usuário cadastrado com este e-mail.", NotificationType.Conflict);
            return null;
        }

        await enrollment.EnrollAsync(user, store!, cancellationToken);

        user.SetPasswordHash(passwordHasher.Hash(request.Password));

        await users.AddAsync(user, cancellationToken);
        await users.SaveChangesAsync(cancellationToken);

        return CreateAuthResponse(user);
    }

    public async Task<AuthResponse?> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrEmpty(request.Password))
        {
            Notify(InvalidCredentials, NotificationType.Unauthorized);
            return null;
        }

        var user = await users.GetByEmailAsync(User.NormalizeEmail(request.Email), cancellationToken);
        if (user is null || !passwordHasher.Verify(user.PasswordHash, request.Password))
        {
            Notify(InvalidCredentials, NotificationType.Unauthorized);
            return null;
        }

        user.RegisterLogin();
        await users.SaveChangesAsync(cancellationToken);

        return CreateAuthResponse(user);
    }

    public async Task<UserResponse?> GetProfileAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var user = await users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            Notify("Usuário não encontrado.", NotificationType.NotFound);
            return null;
        }

        return UserMapper.ToResponse(user);
    }

    public async Task<bool?> ChangePasswordAsync(
        Guid userId, ChangePasswordRequest request, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrEmpty(request.CurrentPassword))
            Notify(ChangePasswordRequest.Fields.CurrentPassword, "Informe a senha atual.");

        foreach (var error in PasswordPolicy.Validate(request.NewPassword))
            Notify(ChangePasswordRequest.Fields.NewPassword, error);

        if (HasNotifications)
            return null;

        var user = await users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
        {
            Notify("Usuário não encontrado.", NotificationType.NotFound);
            return null;
        }

        if (!passwordHasher.Verify(user.PasswordHash, request.CurrentPassword!))
        {
            Notify(ChangePasswordRequest.Fields.CurrentPassword, "A senha atual está incorreta.");
            return null;
        }

        if (request.NewPassword == request.CurrentPassword)
        {
            Notify(ChangePasswordRequest.Fields.NewPassword, "A nova senha deve ser diferente da atual.");
            return null;
        }

        user.SetPasswordHash(passwordHasher.Hash(request.NewPassword!));
        await users.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<bool?> ResetPasswordAsync(ResetPasswordRequest request, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(request.Email))
            Notify(ResetPasswordRequest.Fields.Email, "Informe o e-mail.");

        foreach (var error in PasswordPolicy.Validate(request.NewPassword))
            Notify(ResetPasswordRequest.Fields.NewPassword, error);

        if (HasNotifications)
            return null;

        var user = await users.GetByEmailAsync(User.NormalizeEmail(request.Email!), cancellationToken);
        if (user is null)
        {
            Notify(ResetPasswordRequest.Fields.Email, "Nenhum usuário cadastrado com este e-mail.", NotificationType.NotFound);
            return null;
        }

        user.SetPasswordHash(passwordHasher.Hash(request.NewPassword!));
        await users.SaveChangesAsync(cancellationToken);
        return true;
    }

    private AuthResponse CreateAuthResponse(User user)
    {
        var token = tokenService.Generate(user);
        return new AuthResponse(token.Token, token.ExpiresAt, UserMapper.ToResponse(user));
    }
}
