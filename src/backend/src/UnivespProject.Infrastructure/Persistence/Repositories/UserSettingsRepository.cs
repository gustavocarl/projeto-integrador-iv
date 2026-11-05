using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal sealed class UserSettingsRepository(AppDbContext context) : IUserSettingsRepository
{
    public Task<UserSettings?> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default) =>
        context.UserSettings.FirstOrDefaultAsync(s => s.UserId == userId, cancellationToken);

    public async Task AddAsync(UserSettings settings, CancellationToken cancellationToken = default) =>
        await context.UserSettings.AddAsync(settings, cancellationToken);

    public Task SaveChangesAsync(CancellationToken cancellationToken = default) =>
        context.SaveChangesAsync(cancellationToken);
}
