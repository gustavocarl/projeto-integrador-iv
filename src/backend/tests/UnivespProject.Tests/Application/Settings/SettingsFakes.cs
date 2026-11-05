using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Settings;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Tests.Application.Settings;

internal sealed class InMemoryUserSettingsRepository : IUserSettingsRepository
{
    public List<UserSettings> Items { get; } = [];
    public int Saves { get; private set; }

    public Task<UserSettings?> GetByUserIdAsync(Guid userId, CancellationToken cancellationToken = default) =>
        Task.FromResult(Items.FirstOrDefault(s => s.UserId == userId));

    public Task AddAsync(UserSettings settings, CancellationToken cancellationToken = default)
    {
        Items.Add(settings);
        return Task.CompletedTask;
    }

    public Task SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        Saves++;
        return Task.CompletedTask;
    }
}

/// <summary>The logged-in user's settings in a test: the defaults until <see cref="Value"/> is changed.</summary>
internal sealed class FakeCurrentUserSettings : ICurrentUserSettings
{
    public UserSettings Value { get; } = new(Guid.NewGuid());

    public Task<UserSettings> GetAsync(CancellationToken cancellationToken = default) => Task.FromResult(Value);
}
