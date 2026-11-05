using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Abstractions;

public interface IUserSettingsRepository
{
    /// <summary>The user's saved settings; null when the user never changed them (defaults).</summary>
    Task<UserSettings?> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default);

    Task AddAsync(UserSettings settings, CancellationToken cancellationToken = default);
    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}
