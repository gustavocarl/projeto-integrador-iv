using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal sealed class MarketplaceRepository(AppDbContext context) : IMarketplaceRepository
{
    public async Task<IReadOnlyList<Marketplace>> GetByNormalizedNamesAsync(
        IReadOnlyCollection<string> normalizedNames, CancellationToken cancellationToken = default)
    {
        if (normalizedNames.Count == 0)
            return [];

        return await context.Marketplaces
            .Where(m => normalizedNames.Contains(m.NormalizedName))
            .ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyList<string>> ListNamesAsync(CancellationToken cancellationToken = default) =>
        await context.Marketplaces.AsNoTracking().OrderBy(m => m.Name).Select(m => m.Name).ToListAsync(cancellationToken);

    public Task AddRangeAsync(IEnumerable<Marketplace> marketplaces, CancellationToken cancellationToken = default) =>
        context.Marketplaces.AddRangeAsync(marketplaces, cancellationToken);
}
