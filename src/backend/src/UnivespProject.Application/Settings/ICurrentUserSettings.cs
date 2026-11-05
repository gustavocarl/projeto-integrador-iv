using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Settings;

/// <summary>
/// The settings of the logged-in user, for services whose behavior depends on them
/// (product image, products created by the import).
/// </summary>
public interface ICurrentUserSettings
{
    /// <summary>The saved settings, or the defaults (every option off) when there are none or nobody is logged in.</summary>
    Task<UserSettings> GetAsync(CancellationToken cancellationToken = default);
}
