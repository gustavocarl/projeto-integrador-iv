using UnivespProject.Application.DTOs.Settings;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Settings;
using UnivespProject.Domain.Notifications;
using UnivespProject.Tests.Application.Auth;

namespace UnivespProject.Tests.Application.Settings;

public class SettingsServiceTests
{
    private readonly InMemoryUserSettingsRepository _settings = new();
    private readonly FakeCurrentUser _maria = new(Guid.NewGuid(), "maria@exemplo.com");

    private SettingsService NewRequest(out Notifier notifier, FakeCurrentUser? user = null)
    {
        notifier = new Notifier();
        var currentUser = user ?? _maria;
        return new SettingsService(notifier, currentUser, new CurrentUserSettings(currentUser, _settings), _settings);
    }

    [Fact]
    public async Task WithoutARow_OnlyTheRestockWarningsAreOn_AndNothingIsSaved()
    {
        var settings = await NewRequest(out _).GetAsync();

        Assert.Equal(new UserSettingsResponse(false, false, "Dark"), settings);
        Assert.Empty(_settings.Items);
    }

    [Fact]
    public async Task FirstChange_CreatesTheUsersRow()
    {
        var response = await NewRequest(out var notifier).UpdateAsync(new UpdateSettingsRequest(CreateProductsOnImport: true));

        Assert.False(notifier.HasNotifications);
        Assert.Equal(new UserSettingsResponse(false, true, "Dark"), response);
        var row = Assert.Single(_settings.Items);
        Assert.Equal(_maria.Id, row.UserId);
        Assert.Equal(1, _settings.Saves);
        Assert.Equal(response, await NewRequest(out _).GetAsync());
    }

    [Fact]
    public async Task Update_ChangesOnlyTheFieldsSent()
    {
        await NewRequest(out _).UpdateAsync(new UpdateSettingsRequest(RequireProductImage: true, CreateProductsOnImport: true));

        var response = await NewRequest(out _).UpdateAsync(new UpdateSettingsRequest(CreateProductsOnImport: false));

        Assert.Equal(new UserSettingsResponse(true, false, "Dark"), response);
        Assert.Single(_settings.Items);
    }

    [Fact]
    public async Task EachUser_HasTheirOwnSettings()
    {
        await NewRequest(out _).UpdateAsync(new UpdateSettingsRequest(RequireProductImage: true));

        var joao = new FakeCurrentUser(Guid.NewGuid(), "joao@exemplo.com");

        Assert.Equal(new UserSettingsResponse(false, false, "Dark"), await NewRequest(out _, joao).GetAsync());
    }

    [Theory]
    [InlineData("Light", "Light")]
    [InlineData("light", "Light")]
    [InlineData(" DARK ", "Dark")]
    public async Task Theme_IsSavedByName_AndKeepsTheOtherSettings(string sent, string saved)
    {
        await NewRequest(out _).UpdateAsync(new UpdateSettingsRequest(RequireProductImage: true));

        var response = await NewRequest(out var notifier).UpdateAsync(new UpdateSettingsRequest(Theme: sent));

        Assert.False(notifier.HasNotifications);
        Assert.Equal(new UserSettingsResponse(true, false, saved), response);
        Assert.Equal(response, await NewRequest(out _).GetAsync());
    }

    [Theory]
    [InlineData("Blue")]
    [InlineData("2")]
    [InlineData("")]
    public async Task InvalidTheme_IsAFieldError_AndNothingIsSaved(string theme)
    {
        var response = await NewRequest(out var notifier)
            .UpdateAsync(new UpdateSettingsRequest(CreateProductsOnImport: true, Theme: theme));

        Assert.Null(response);
        var error = Assert.Single(notifier.Notifications);
        Assert.Equal(("theme", NotificationType.Validation), (error.Key, error.Type));
        Assert.Empty(_settings.Items);
        Assert.Equal(0, _settings.Saves);
    }

    [Fact]
    public async Task RestockWarnings_AreOnByDefault_AndCanBeTurnedOff()
    {
        Assert.True((await NewRequest(out _).GetAsync()).NotifyRestock);

        var off = await NewRequest(out var notifier).UpdateAsync(new UpdateSettingsRequest(NotifyRestock: false));

        Assert.False(notifier.HasNotifications);
        Assert.Equal(new UserSettingsResponse(false, false, "Dark", NotifyRestock: false), off);
        Assert.Equal(off, await NewRequest(out _).GetAsync());

        // Changing another option keeps it off; turning it back on keeps the others.
        await NewRequest(out _).UpdateAsync(new UpdateSettingsRequest(RequireProductImage: true));
        Assert.False((await NewRequest(out _).GetAsync()).NotifyRestock);
        var on = await NewRequest(out _).UpdateAsync(new UpdateSettingsRequest(NotifyRestock: true));
        Assert.Equal(new UserSettingsResponse(true, false, "Dark", NotifyRestock: true), on);
    }

    [Fact]
    public async Task Update_WithNothing_IsAnError()
    {
        Assert.Null(await NewRequest(out var notifier).UpdateAsync(new UpdateSettingsRequest()));

        var error = Assert.Single(notifier.Notifications);
        Assert.Equal(NotificationType.Validation, error.Type);
        Assert.Empty(_settings.Items);
    }
}
