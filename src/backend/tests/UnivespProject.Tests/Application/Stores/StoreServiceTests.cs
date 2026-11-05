using UnivespProject.Application.DTOs.Stores;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Notifications.Center;
using UnivespProject.Application.Stores;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;
using UnivespProject.Tests.Application.Auth;

namespace UnivespProject.Tests.Application.Stores;

public class StoreServiceTests
{
    private readonly InMemoryUserRepository _users = new();
    private readonly InMemoryStoreRepository _stores = new();
    private readonly InMemoryUserNotificationRepository _notifications = new();
    private readonly Store _store = new("Loja da Maria");
    private readonly User _admin;

    public StoreServiceTests()
    {
        _stores.Items.Add(_store);
        _admin = AddUser("Maria", u => u.OpenStore(_store));
    }

    private User AddUser(string name, Action<User> setup)
    {
        var user = new User(name, $"{name.ToLowerInvariant()}@exemplo.com");
        setup(user);
        _users.Items.Add(user);
        return user;
    }

    private StoreService NewRequest(out INotifier notifier)
    {
        notifier = new Notifier();
        var notices = new AccessRequestNotices(_users, _notifications);
        return new StoreService(notifier, _users, _stores, new StoreEnrollment(notifier, _stores, notices), notices);
    }

    [Fact]
    public async Task Enter_WithANewName_OpensAStore_AndMakesTheUserItsAdmin()
    {
        var user = AddUser("Joao", _ => { });

        var response = await NewRequest(out var notifier).EnterAsync(user.Id, new EnterStoreRequest("  Loja   do João "));

        Assert.False(notifier.HasNotifications);
        Assert.Equal("Loja do João", response!.Store!.Name);
        Assert.Equal("Admin", response.Store.Role);
        Assert.Equal(StoreAreas.ToNames(StoreArea.All), response.Store.Areas);
        Assert.Equal(2, _stores.Items.Count);
        Assert.Empty(_notifications.Items);
    }

    [Fact]
    public async Task Enter_WithoutName_IsAnErrorOnTheNameField()
    {
        var user = AddUser("Joao", _ => { });

        await NewRequest(out var notifier).EnterAsync(user.Id, new EnterStoreRequest(" "));

        Assert.Equal(Store.Fields.Name, Assert.Single(notifier.Notifications).Key);
        Assert.Null(user.StoreId);
    }

    [Fact]
    public async Task Enter_WithAnExistingName_WaitsForApproval_AndNotifiesEveryAdmin()
    {
        var otherAdmin = AddUser("Ana", u => { u.RequestAccess(_store); u.ChangeRole(StoreRole.Admin); });
        AddUser("Bia", u => { u.RequestAccess(_store); u.Approve(StoreArea.All); });
        var user = AddUser("Joao", _ => { });

        var response = await NewRequest(out var notifier).EnterAsync(user.Id, new EnterStoreRequest("loja da MARIA"));

        Assert.False(notifier.HasNotifications);
        Assert.Equal("Pending", response!.Store!.Role);
        Assert.Equal("Loja da Maria", response.Store.Name);
        Assert.Empty(response.Store.Areas);
        Assert.False(user.HasStoreAccess);
        Assert.Single(_stores.Items);

        Assert.Equal(new[] { _admin.Id, otherAdmin.Id }.Order(), _notifications.Items.Select(n => n.UserId).Order());
        Assert.All(_notifications.Items, n =>
            Assert.Equal((NotificationKind.AccessRequested, user.Id, false), (n.Kind, n.RelatedUserId, n.IsRead)));
    }

    [Fact]
    public async Task UsersWithAccess_CantEnterAnotherStore()
    {
        await NewRequest(out var notifier).EnterAsync(_admin.Id, new EnterStoreRequest("Outra"));

        Assert.Equal(NotificationType.Conflict, Assert.Single(notifier.Notifications).Type);
        Assert.Single(_stores.Items);
    }

    [Fact]
    public async Task APendingUser_CanGiveUpAndOpenTheirOwnStore_AndTheOldRequestIsResolved()
    {
        var user = AddUser("Joao", _ => { });
        await NewRequest(out _).EnterAsync(user.Id, new EnterStoreRequest("Loja da Maria"));

        var response = await NewRequest(out _).EnterAsync(user.Id, new EnterStoreRequest("Loja do João"));

        Assert.Equal("Admin", response!.Store!.Role);
        Assert.NotEqual(_store.Id, user.StoreId);
        Assert.True(Assert.Single(_notifications.Of(_admin.Id)).IsRead);
    }

    [Fact]
    public async Task Approve_GivesOnlyTheChosenAreas()
    {
        var user = AddUser("Joao", u => u.RequestAccess(_store));

        var response = await NewRequest(out var notifier)
            .ApproveAsync(_admin.Id, user.Id, new ApproveMemberRequest(["checkout", "Products"]));

        Assert.False(notifier.HasNotifications);
        Assert.Equal("Member", response!.Role);
        Assert.Equal(["Products", "Checkout"], response.Areas);
        Assert.True(user.CanUseAny(StoreArea.Checkout));
        Assert.False(user.CanUseAny(StoreArea.Imports));
    }

    [Fact]
    public async Task Approve_ResolvesTheAdminsNotices_AndTellsTheUser()
    {
        var user = AddUser("Joao", _ => { });
        await NewRequest(out _).EnterAsync(user.Id, new EnterStoreRequest("Loja da Maria"));

        await NewRequest(out _).ApproveAsync(_admin.Id, user.Id, new ApproveMemberRequest(null));

        Assert.True(Assert.Single(_notifications.Of(_admin.Id)).IsRead);
        var approved = Assert.Single(_notifications.Of(user.Id));
        Assert.Equal(NotificationKind.AccessApproved, approved.Kind);
        Assert.Equal("Seu acesso à loja Loja da Maria foi aprovado.", approved.Message);
        Assert.False(approved.IsRead);
    }

    [Fact]
    public async Task RefusingARequest_ResolvesTheAdminsNotices()
    {
        var user = AddUser("Joao", _ => { });
        await NewRequest(out _).EnterAsync(user.Id, new EnterStoreRequest("Loja da Maria"));

        Assert.True(await NewRequest(out _).RemoveAsync(_admin.Id, user.Id));

        Assert.True(Assert.Single(_notifications.Of(_admin.Id)).IsRead);
        Assert.Empty(_notifications.Of(user.Id));
    }

    [Fact]
    public async Task Approve_WithoutAreas_GivesEverything()
    {
        var user = AddUser("Joao", u => u.RequestAccess(_store));

        var response = await NewRequest(out _).ApproveAsync(_admin.Id, user.Id, new ApproveMemberRequest(null));

        Assert.Equal(StoreAreas.ToNames(StoreArea.All), response!.Areas);
    }

    [Fact]
    public async Task UnknownArea_IsAnErrorOnTheAreasField_AndNothingChanges()
    {
        var user = AddUser("Joao", u => u.RequestAccess(_store));

        await NewRequest(out var notifier).ApproveAsync(_admin.Id, user.Id, new ApproveMemberRequest(["Products", "Caixa"]));

        var error = Assert.Single(notifier.Notifications);
        Assert.Equal(UpdateMemberAreasRequest.Fields.Areas, error.Key);
        Assert.Contains("Caixa", error.Message);
        Assert.Equal(StoreRole.Pending, user.Role);
    }

    [Fact]
    public async Task OnlyAdmins_ManageUsers()
    {
        var member = AddUser("Joao", u => { u.RequestAccess(_store); u.Approve(StoreArea.All); });

        var members = await NewRequest(out var notifier).ListMembersAsync(member.Id);

        Assert.Null(members);
        var error = Assert.Single(notifier.Notifications);
        Assert.Equal((StoreAccessService.AdminKey, NotificationType.Forbidden), (error.Key, error.Type));
    }

    [Fact]
    public async Task UsersOfAnotherStore_AreNotFound()
    {
        var other = new Store("Outra");
        var stranger = AddUser("Pedro", u => u.RequestAccess(other));

        await NewRequest(out var notifier).ApproveAsync(_admin.Id, stranger.Id, new ApproveMemberRequest(null));

        Assert.Equal(NotificationType.NotFound, Assert.Single(notifier.Notifications).Type);
        Assert.Equal(StoreRole.Pending, stranger.Role);
    }

    [Fact]
    public async Task ListMembers_ShowsPendingRequestsFirst()
    {
        AddUser("Ana", u => { u.RequestAccess(_store); u.Approve(StoreArea.Checkout); });
        AddUser("Zeca", u => u.RequestAccess(_store));
        AddUser("Pedro", u => u.RequestAccess(new Store("Outra")));

        var members = await NewRequest(out _).ListMembersAsync(_admin.Id);

        Assert.Equal(["Zeca", "Ana", "Maria"], members!.Select(m => m.Name));
    }

    [Fact]
    public async Task Promote_GivesEveryArea_AndTheLastAdminCantBeDemoted()
    {
        var member = AddUser("Joao", u => { u.RequestAccess(_store); u.Approve(StoreArea.Checkout); });

        var promoted = await NewRequest(out _).ChangeRoleAsync(_admin.Id, member.Id, new ChangeMemberRoleRequest("admin"));
        Assert.Equal("Admin", promoted!.Role);
        Assert.Equal(StoreAreas.ToNames(StoreArea.All), promoted.Areas);

        // Two admins: Maria can step down; then João is the last one.
        await NewRequest(out _).ChangeRoleAsync(member.Id, _admin.Id, new ChangeMemberRoleRequest("Member"));
        await NewRequest(out var notifier).ChangeRoleAsync(member.Id, member.Id, new ChangeMemberRoleRequest("Member"));

        Assert.Equal(StoreRole.Member, _admin.Role);
        Assert.Equal(NotificationType.Conflict, Assert.Single(notifier.Notifications).Type);
        Assert.Equal(StoreRole.Admin, member.Role);
    }

    [Fact]
    public async Task InvalidRole_IsAnErrorOnTheRoleField()
    {
        var member = AddUser("Joao", u => { u.RequestAccess(_store); u.Approve(StoreArea.All); });

        await NewRequest(out var notifier).ChangeRoleAsync(_admin.Id, member.Id, new ChangeMemberRoleRequest("Pending"));

        Assert.Equal(ChangeMemberRoleRequest.Fields.Role, Assert.Single(notifier.Notifications).Key);
    }

    [Fact]
    public async Task UpdateAreas_ChangesWhatAMemberUses_ButNotAdmins()
    {
        var member = AddUser("Joao", u => { u.RequestAccess(_store); u.Approve(StoreArea.All); });

        var response = await NewRequest(out _).UpdateAreasAsync(_admin.Id, member.Id, new UpdateMemberAreasRequest([]));
        Assert.Empty(response!.Areas);
        Assert.False(member.CanUseAny(StoreArea.All));

        await NewRequest(out var notifier).UpdateAreasAsync(_admin.Id, _admin.Id, new UpdateMemberAreasRequest(["Products"]));
        Assert.Equal(NotificationType.Conflict, Assert.Single(notifier.Notifications).Type);
        Assert.True(_admin.CanUseAny(StoreArea.Analytics));
    }

    [Fact]
    public async Task Remove_TakesTheUserOutOfTheStore_ButNeverTheLastAdmin()
    {
        var member = AddUser("Joao", u => { u.RequestAccess(_store); u.Approve(StoreArea.All); });

        Assert.True(await NewRequest(out _).RemoveAsync(_admin.Id, member.Id));
        Assert.Null(member.StoreId);
        Assert.Equal(StoreArea.None, member.EffectiveAreas);

        Assert.Null(await NewRequest(out var notifier).RemoveAsync(_admin.Id, _admin.Id));
        Assert.Equal(NotificationType.Conflict, Assert.Single(notifier.Notifications).Type);
        Assert.Equal(_store.Id, _admin.StoreId);
    }

    [Fact]
    public async Task Rename_IsOnlyForAdmins_AndValidatesTheName()
    {
        var renamed = await NewRequest(out _).RenameAsync(_admin.Id, new RenameStoreRequest("Marcelo Eletrônicos"));
        Assert.Equal("Marcelo Eletrônicos", renamed!.Store!.Name);

        await NewRequest(out var notifier).RenameAsync(_admin.Id, new RenameStoreRequest(""));
        Assert.Equal(Store.Fields.Name, Assert.Single(notifier.Notifications).Key);
        Assert.Equal("Marcelo Eletrônicos", _store.Name);
    }

    [Fact]
    public async Task Rename_ToTheNameOfAnotherStore_IsAConflict()
    {
        _stores.Items.Add(new Store("Loja do João"));

        Assert.NotNull(await NewRequest(out _).RenameAsync(_admin.Id, new RenameStoreRequest("LOJA DA MARIA")));
        await NewRequest(out var notifier).RenameAsync(_admin.Id, new RenameStoreRequest("loja do joão"));

        var error = Assert.Single(notifier.Notifications);
        Assert.Equal((Store.Fields.Name, NotificationType.Conflict, StoreService.NameTaken), (error.Key, error.Type, error.Message));
    }
}
