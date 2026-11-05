using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Tests.Application.Auth;

internal sealed class InMemoryUserRepository : IUserRepository
{
    public List<User> Items { get; } = [];

    public Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.FirstOrDefault(u => u.Id == id));

    public Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.FirstOrDefault(u => u.Email == email));

    public Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.Any(u => u.Email == email));

    public Task<IReadOnlyList<User>> ListByStoreAsync(Guid storeId, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<User>>(Items.Where(u => u.StoreId == storeId).ToList());

    public Task<int> CountAdminsAsync(Guid storeId, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.Count(u => u.StoreId == storeId && u.Role == StoreRole.Admin));

    public Task AddAsync(User user, CancellationToken cancellationToken = default)
    {
        Items.Add(user);
        return Task.CompletedTask;
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken = default) => Task.CompletedTask;
}

/// <summary>The logged-in user of a test "request".</summary>
internal sealed class FakeCurrentUser(Guid? id = null, string? email = null) : ICurrentUser
{
    public Guid? Id { get; set; } = id;
    public string? Email { get; set; } = email;
}

internal sealed class InMemoryStoreRepository : IStoreRepository
{
    public List<Store> Items { get; } = [];

    public Task<Store?> GetByNormalizedNameAsync(string normalizedName, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.FirstOrDefault(s => s.NormalizedName == normalizedName));

    public Task<bool> NameExistsAsync(string normalizedName, Guid exceptId, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.Any(s => s.NormalizedName == normalizedName && s.Id != exceptId));

    public Task AddAsync(Store store, CancellationToken cancellationToken = default)
    {
        Items.Add(store);
        return Task.CompletedTask;
    }
}

/// <summary>The store of a test "request" (see StoreAccessService).</summary>
internal sealed class FakeCurrentStore : ICurrentStore
{
    public Guid? Id { get; private set; }

    public void Enter(Guid storeId) => Id = storeId;
}

internal sealed class InMemoryUserNotificationRepository : IUserNotificationRepository
{
    public List<UserNotification> Items { get; } = [];
    public int Saves { get; private set; }

    public IReadOnlyList<UserNotification> Of(Guid userId) => Items.Where(n => n.UserId == userId).ToList();

    public Task<IReadOnlyList<UserNotification>> ListLatestAsync(Guid userId, int take, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<UserNotification>>(
            Items.Where(n => n.UserId == userId).OrderByDescending(n => n.CreatedAt).Take(take).ToList());

    public Task<int> CountUnreadAsync(Guid userId, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.Count(n => n.UserId == userId && !n.IsRead));

    public Task<UserNotification?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.FirstOrDefault(n => n.Id == id));

    public Task<IReadOnlyList<UserNotification>> ListUnreadAsync(Guid userId, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<UserNotification>>(Items.Where(n => n.UserId == userId && !n.IsRead).ToList());

    public Task<IReadOnlyList<UserNotification>> ListUnreadAboutAsync(
        NotificationKind kind, Guid relatedUserId, CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<UserNotification>>(
            Items.Where(n => n.Kind == kind && n.RelatedUserId == relatedUserId && !n.IsRead).ToList());

    public Task AddAsync(UserNotification notification, CancellationToken cancellationToken = default)
    {
        Items.Add(notification);
        return Task.CompletedTask;
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        Saves++;
        return Task.CompletedTask;
    }
}
