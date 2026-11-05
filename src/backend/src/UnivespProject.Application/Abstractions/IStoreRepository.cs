using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Abstractions;

/// <summary>Saved together with the users (same unit of work: <see cref="IUserRepository.SaveChangesAsync"/>).</summary>
public interface IStoreRepository
{
    /// <summary>The store whose <see cref="Store.NormalizedName"/> is <paramref name="normalizedName"/>.</summary>
    Task<Store?> GetByNormalizedNameAsync(string normalizedName, CancellationToken cancellationToken = default);

    /// <summary>True when another store (not <paramref name="exceptId"/>) already uses the name.</summary>
    Task<bool> NameExistsAsync(string normalizedName, Guid exceptId, CancellationToken cancellationToken = default);

    Task AddAsync(Store store, CancellationToken cancellationToken = default);
}
