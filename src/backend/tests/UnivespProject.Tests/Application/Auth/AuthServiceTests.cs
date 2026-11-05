using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Auth;
using UnivespProject.Application.DTOs.Auth;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Notifications.Center;
using UnivespProject.Application.Stores;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Tests.Application.Auth;

public class AuthServiceTests
{
    private readonly InMemoryUserRepository _users = new();
    private readonly InMemoryStoreRepository _stores = new();
    private readonly InMemoryUserNotificationRepository _notifications = new();

    // A fresh service + notifier per call, like one HTTP request each.
    private AuthService NewRequest(out INotifier notifier)
    {
        notifier = new Notifier();
        return new AuthService(notifier, _users, new FakePasswordHasher(), new FakeTokenService(),
            new StoreEnrollment(notifier, _stores, new AccessRequestNotices(_users, _notifications)));
    }

    [Fact]
    public async Task Register_CreatesUser_WithHashedPassword_AndReturnsToken()
    {
        var response = await NewRequest(out var notifier)
            .RegisterAsync(new RegisterRequest("Maria", "maria@exemplo.com", "Senha123", "Loja da Maria"));

        Assert.False(notifier.HasNotifications);
        Assert.Equal("token", response!.AccessToken);
        var stored = Assert.Single(_users.Items);
        Assert.NotEqual("Senha123", stored.PasswordHash);
    }

    [Fact]
    public async Task Register_WithANewStoreName_OpensTheStore_AsItsAdmin()
    {
        var response = await NewRequest(out _)
            .RegisterAsync(new RegisterRequest("Maria", "maria@exemplo.com", "Senha123", StoreName: "Loja da Maria"));

        var store = Assert.Single(_stores.Items);
        Assert.Equal(store.Id, response!.User.Store!.Id);
        Assert.Equal("Admin", response.User.Store.Role);
        Assert.Empty(_notifications.Items);
    }

    [Fact]
    public async Task Register_WithAnExistingStoreName_AsksItsAdminForAccess()
    {
        await NewRequest(out _).RegisterAsync(new RegisterRequest("Maria", "maria@exemplo.com", "Senha123", "Loja da Maria"));
        var admin = _users.Items[0];

        // Same store: accents, casing and spaces don't matter.
        var response = await NewRequest(out var notifier)
            .RegisterAsync(new RegisterRequest("Joao", "joao@exemplo.com", "Senha123", "  LOJA  DA MARÍA "));

        Assert.False(notifier.HasNotifications);
        Assert.Equal("Pending", response!.User.Store!.Role);
        Assert.Equal("Loja da Maria", response.User.Store.Name);
        Assert.Single(_stores.Items);

        var notice = Assert.Single(_notifications.Items);
        Assert.Equal((admin.Id, NotificationKind.AccessRequested, response.User.Id),
            (notice.UserId, notice.Kind, notice.RelatedUserId));
        Assert.Contains("Joao (joao@exemplo.com) pediu acesso à loja Loja da Maria", notice.Message);
    }

    [Fact]
    public async Task Register_NeedsAStoreName()
    {
        await NewRequest(out var notifier).RegisterAsync(new RegisterRequest("Maria", "maria@exemplo.com", "Senha123"));

        var error = Assert.Single(notifier.Notifications);
        Assert.Equal((RegisterRequest.Fields.StoreName, "Informe o nome da loja."), (error.Key, error.Message));
        Assert.Empty(_users.Items);
    }

    [Fact]
    public async Task Register_NotifiesDuplicateEmail_IgnoringCase()
    {
        await NewRequest(out _).RegisterAsync(new RegisterRequest("Maria", "maria@exemplo.com", "Senha123", "Loja da Maria"));

        var response = await NewRequest(out var notifier)
            .RegisterAsync(new RegisterRequest("Outra", "MARIA@exemplo.com", "Senha123", "Loja da Maria"));

        Assert.Null(response);
        var notification = Assert.Single(notifier.Notifications);
        Assert.Equal(NotificationType.Conflict, notification.Type);
        Assert.Equal(User.Fields.Email, notification.Key);
    }

    [Fact]
    public async Task Register_ReturnsAllValidationErrorsAtOnce()
    {
        var response = await NewRequest(out var notifier)
            .RegisterAsync(new RegisterRequest("", "invalido", "abc"));

        Assert.Null(response);
        Assert.Empty(_users.Items);
        Assert.All(notifier.Notifications, n => Assert.Equal(NotificationType.Validation, n.Type));
        Assert.Contains(notifier.Notifications, n => n.Key == User.Fields.Name);
        Assert.Contains(notifier.Notifications, n => n.Key == User.Fields.Email);
        Assert.Contains(notifier.Notifications, n => n.Key == User.Fields.Password);
    }

    [Fact]
    public async Task Login_Succeeds_WithCorrectPassword_AndRecordsLogin()
    {
        await NewRequest(out _).RegisterAsync(new RegisterRequest("Maria", "maria@exemplo.com", "Senha123", "Loja da Maria"));

        var response = await NewRequest(out var notifier)
            .LoginAsync(new LoginRequest("Maria@Exemplo.com", "Senha123"));

        Assert.NotNull(response);
        Assert.False(notifier.HasNotifications);
        Assert.NotNull(_users.Items[0].LastLoginAt);
    }

    [Theory]
    [InlineData("maria@exemplo.com", "SenhaErrada1")]
    [InlineData("naoexiste@exemplo.com", "Senha123")]
    public async Task Login_NotifiesSameUnauthorizedError_ForWrongPasswordOrUnknownEmail(string email, string password)
    {
        await NewRequest(out _).RegisterAsync(new RegisterRequest("Maria", "maria@exemplo.com", "Senha123", "Loja da Maria"));

        var response = await NewRequest(out var notifier).LoginAsync(new LoginRequest(email, password));

        Assert.Null(response);
        var notification = Assert.Single(notifier.Notifications);
        Assert.Equal(NotificationType.Unauthorized, notification.Type);
        Assert.Equal("E-mail ou senha inválidos.", notification.Message);
    }

    private async Task<Guid> RegisterMariaAsync()
    {
        await NewRequest(out _).RegisterAsync(new RegisterRequest("Maria", "maria@exemplo.com", "Senha123", "Loja da Maria"));
        return Assert.Single(_users.Items).Id;
    }

    [Fact]
    public async Task ChangePassword_ReplacesTheHash_AndTheNewPasswordLogsIn()
    {
        var id = await RegisterMariaAsync();

        var changed = await NewRequest(out var notifier)
            .ChangePasswordAsync(id, new ChangePasswordRequest("Senha123", "NovaSenha456"));

        Assert.True(changed);
        Assert.False(notifier.HasNotifications);
        Assert.NotNull(await NewRequest(out _).LoginAsync(new LoginRequest("maria@exemplo.com", "NovaSenha456")));
        Assert.Null(await NewRequest(out _).LoginAsync(new LoginRequest("maria@exemplo.com", "Senha123")));
    }

    [Fact]
    public async Task ChangePassword_WrongCurrentPassword_IsAValidationErrorOnItsField()
    {
        var id = await RegisterMariaAsync();

        var changed = await NewRequest(out var notifier)
            .ChangePasswordAsync(id, new ChangePasswordRequest("Errada123", "NovaSenha456"));

        Assert.Null(changed);
        var notification = Assert.Single(notifier.Notifications);
        // 400, not 401: the app would end the session on a 401.
        Assert.Equal((NotificationType.Validation, "currentPassword", "A senha atual está incorreta."),
            (notification.Type, notification.Key, notification.Message));
        Assert.Equal("hashed:Senha123", _users.Items.Single().PasswordHash);
    }

    [Fact]
    public async Task ChangePassword_ReportsEveryProblemAtOnce()
    {
        var id = await RegisterMariaAsync();

        await NewRequest(out var notifier).ChangePasswordAsync(id, new ChangePasswordRequest("", "abc"));

        Assert.Contains(notifier.Notifications, n => n.Key == "currentPassword" && n.Message == "Informe a senha atual.");
        Assert.Equal(3, notifier.Notifications.Count(n => n.Key == "newPassword"));
    }

    [Fact]
    public async Task ChangePassword_NewPasswordMustDiffer()
    {
        var id = await RegisterMariaAsync();

        var changed = await NewRequest(out var notifier)
            .ChangePasswordAsync(id, new ChangePasswordRequest("Senha123", "Senha123"));

        Assert.Null(changed);
        Assert.Equal(("newPassword", "A nova senha deve ser diferente da atual."),
            (notifier.Notifications.Single().Key, notifier.Notifications.Single().Message));
    }

    [Fact]
    public async Task ChangePassword_UnknownUser_IsNotFound()
    {
        await NewRequest(out var notifier)
            .ChangePasswordAsync(Guid.NewGuid(), new ChangePasswordRequest("Senha123", "NovaSenha456"));

        Assert.Equal(NotificationType.NotFound, notifier.Notifications.Single().Type);
    }

    [Fact]
    public async Task ResetPassword_ReplacesTheHash_ByEmail_IgnoringCase()
    {
        await RegisterMariaAsync();

        var reset = await NewRequest(out var notifier)
            .ResetPasswordAsync(new ResetPasswordRequest("  MARIA@exemplo.com ", "NovaSenha456"));

        Assert.True(reset);
        Assert.False(notifier.HasNotifications);
        Assert.NotNull(await NewRequest(out _).LoginAsync(new LoginRequest("maria@exemplo.com", "NovaSenha456")));
        Assert.Null(await NewRequest(out _).LoginAsync(new LoginRequest("maria@exemplo.com", "Senha123")));
    }

    [Fact]
    public async Task ResetPassword_UnknownEmail_IsNotFoundOnTheEmailField()
    {
        await RegisterMariaAsync();

        Assert.Null(await NewRequest(out var notifier)
            .ResetPasswordAsync(new ResetPasswordRequest("joao@exemplo.com", "NovaSenha456")));

        var error = Assert.Single(notifier.Notifications);
        Assert.Equal((NotificationType.NotFound, "email", "Nenhum usuário cadastrado com este e-mail."),
            (error.Type, error.Key, error.Message));
        Assert.Equal("hashed:Senha123", _users.Items.Single().PasswordHash);
    }

    [Fact]
    public async Task ResetPassword_ReportsEveryProblemAtOnce_AndChangesNothing()
    {
        await RegisterMariaAsync();

        Assert.Null(await NewRequest(out var notifier).ResetPasswordAsync(new ResetPasswordRequest(" ", "abc")));

        Assert.Contains(notifier.Notifications, n => n.Key == "email" && n.Message == "Informe o e-mail.");
        Assert.Equal(3, notifier.Notifications.Count(n => n.Key == "newPassword"));
        Assert.Equal("hashed:Senha123", _users.Items.Single().PasswordHash);
    }

    private sealed class FakePasswordHasher : IPasswordHasher
    {
        public string Hash(string password) => $"hashed:{password}";
        public bool Verify(string passwordHash, string providedPassword) => passwordHash == $"hashed:{providedPassword}";
    }

    private sealed class FakeTokenService : ITokenService
    {
        public AccessToken Generate(User user) => new("token", DateTime.UtcNow.AddHours(1));
    }
}
