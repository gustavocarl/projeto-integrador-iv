using UnivespProject.Application.Notifications;
using UnivespProject.Application.Stores;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;
using UnivespProject.Tests.Application.Auth;

namespace UnivespProject.Tests.Application.Stores;

public class StoreAccessServiceTests
{
    private readonly InMemoryUserRepository _users = new();
    private readonly FakeCurrentStore _currentStore = new();
    private readonly Store _store = new("Loja da Maria");

    private async Task<(bool Entered, INotifier Notifier)> EnterAsync(Action<User> setup, StoreArea areas)
    {
        var user = new User("Joao", "joao@exemplo.com");
        setup(user);
        _users.Items.Add(user);

        var notifier = new Notifier();
        var service = new StoreAccessService(notifier, new FakeCurrentUser(user.Id, user.Email), _users, _currentStore);
        return (await service.EnterAsync(areas), notifier);
    }

    [Fact]
    public async Task AnAllowedArea_EntersTheStore()
    {
        var (entered, notifier) = await EnterAsync(u => { u.RequestAccess(_store); u.Approve(StoreArea.Checkout); },
            StoreArea.Products | StoreArea.Checkout);

        Assert.True(entered);
        Assert.False(notifier.HasNotifications);
        Assert.Equal(_store.Id, _currentStore.Id);
    }

    [Fact]
    public async Task AnAreaNotGiven_IsForbiddenOnTheAreaKey()
    {
        var (entered, notifier) = await EnterAsync(u => { u.RequestAccess(_store); u.Approve(StoreArea.Checkout); },
            StoreArea.Imports);

        Assert.False(entered);
        var error = Assert.Single(notifier.Notifications);
        Assert.Equal((StoreAccessService.AreaKey, NotificationType.Forbidden), (error.Key, error.Type));
        Assert.Null(_currentStore.Id);
    }

    [Fact]
    public async Task APendingRequest_IsForbiddenOnTheStoreKey_NamingTheStore()
    {
        var (entered, notifier) = await EnterAsync(u => u.RequestAccess(_store), StoreArea.Products);

        Assert.False(entered);
        var error = Assert.Single(notifier.Notifications);
        Assert.Equal(StoreAccessService.StoreKey, error.Key);
        Assert.Contains("Loja da Maria", error.Message);
    }

    [Fact]
    public async Task AdminsUseEveryArea()
    {
        var (entered, _) = await EnterAsync(u => u.OpenStore(_store), StoreArea.Analytics);

        Assert.True(entered);
    }

    [Fact]
    public async Task WithoutAStore_IsForbidden()
    {
        var (entered, notifier) = await EnterAsync(_ => { }, StoreArea.Products);

        Assert.False(entered);
        Assert.Equal(NotificationType.Forbidden, Assert.Single(notifier.Notifications).Type);
    }
}
