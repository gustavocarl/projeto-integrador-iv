using UnivespProject.Application.DTOs.Settings;

namespace UnivespProject.Application.Settings;

/// <summary>
/// The logged-in user's settings. Methods return null when they fail; the reasons are in
/// <see cref="Notifications.INotifier"/>.
/// </summary>
public interface ISettingsService
{
    Task<UserSettingsResponse> GetAsync(CancellationToken cancellationToken = default);
    Task<UserSettingsResponse?> UpdateAsync(UpdateSettingsRequest request, CancellationToken cancellationToken = default);
}
