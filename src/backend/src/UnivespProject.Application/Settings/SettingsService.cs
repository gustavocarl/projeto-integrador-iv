using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Settings;
using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Settings;

internal sealed class SettingsService(
    INotifier notifier,
    ICurrentUser currentUser,
    ICurrentUserSettings current,
    IUserSettingsRepository settings) : BaseService(notifier), ISettingsService
{
    public async Task<UserSettingsResponse> GetAsync(CancellationToken cancellationToken = default) =>
        ToResponse(await current.GetAsync(cancellationToken));

    public async Task<UserSettingsResponse?> UpdateAsync(UpdateSettingsRequest request, CancellationToken cancellationToken = default)
    {
        if (request is { RequireProductImage: null, CreateProductsOnImport: null, Theme: null, NotifyRestock: null })
        {
            Notify("Informe ao menos uma configuração para alterar.", NotificationType.Validation);
            return null;
        }

        if (currentUser.Id is not { } userId)
        {
            Notify("Usuário não encontrado.", NotificationType.NotFound);
            return null;
        }

        // The row is created the first time the user changes something.
        var existing = await settings.GetByUserIdAsync(userId, cancellationToken);
        var saved = existing ?? new UserSettings(userId);

        saved.Update(request.RequireProductImage, request.CreateProductsOnImport, request.Theme, request.NotifyRestock);
        if (!Validate(saved))
            return null;

        if (existing is null)
            await settings.AddAsync(saved, cancellationToken);
        await settings.SaveChangesAsync(cancellationToken);
        return ToResponse(saved);
    }

    private static UserSettingsResponse ToResponse(UserSettings s) =>
        new(s.RequireProductImage, s.CreateProductsOnImport, s.Theme.ToString(), s.NotifyRestock);
}
