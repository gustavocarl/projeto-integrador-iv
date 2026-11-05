using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Abstractions;

/// <summary>Users come with their <see cref="User.Store"/> loaded.</summary>
public interface IUserRepository
{
    Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default);
    Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken = default);

    /// <summary>Everyone in the store, pending requests included.</summary>
    Task<IReadOnlyList<User>> ListByStoreAsync(Guid storeId, CancellationToken cancellationToken = default);

    Task<int> CountAdminsAsync(Guid storeId, CancellationToken cancellationToken = default);
    Task AddAsync(User user, CancellationToken cancellationToken = default);
    Task SaveChangesAsync(CancellationToken cancellationToken = default);
}
