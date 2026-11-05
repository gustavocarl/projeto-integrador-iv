using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Settings;

internal sealed class CurrentUserSettings(ICurrentUser currentUser, IUserSettingsRepository settings) : ICurrentUserSettings
{
    public async Task<UserSettings> GetAsync(CancellationToken cancellationToken = default)
    {
        if (currentUser.Id is not { } userId)
            return new UserSettings(Guid.Empty);

        return await settings.GetByUserIdAsync(userId, cancellationToken) ?? new UserSettings(userId);
    }
}
