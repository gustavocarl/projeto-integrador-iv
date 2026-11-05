using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Abstractions;

public interface IMarketplaceRepository
{
    Task<IReadOnlyList<Marketplace>> GetByNormalizedNamesAsync(IReadOnlyCollection<string> normalizedNames, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<string>> ListNamesAsync(CancellationToken cancellationToken = default);
    Task AddRangeAsync(IEnumerable<Marketplace> marketplaces, CancellationToken cancellationToken = default);
}
