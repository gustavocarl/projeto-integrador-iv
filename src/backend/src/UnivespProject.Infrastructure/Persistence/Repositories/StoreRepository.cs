using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal sealed class StoreRepository(AppDbContext context) : IStoreRepository
{
    public Task<Store?> GetByNormalizedNameAsync(string normalizedName, CancellationToken cancellationToken = default) =>
        context.Stores.FirstOrDefaultAsync(s => s.NormalizedName == normalizedName, cancellationToken);

    public Task<bool> NameExistsAsync(string normalizedName, Guid exceptId, CancellationToken cancellationToken = default) =>
        context.Stores.AnyAsync(s => s.NormalizedName == normalizedName && s.Id != exceptId, cancellationToken);

    public async Task AddAsync(Store store, CancellationToken cancellationToken = default) =>
        await context.Stores.AddAsync(store, cancellationToken);
}
