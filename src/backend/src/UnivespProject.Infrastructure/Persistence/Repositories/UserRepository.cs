using Microsoft.EntityFrameworkCore;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Infrastructure.Persistence.Repositories;

internal sealed class UserRepository(AppDbContext context) : IUserRepository
{
    private IQueryable<User> WithStore => context.Users.Include(u => u.Store);

    public Task<User?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        WithStore.FirstOrDefaultAsync(u => u.Id == id, cancellationToken);

    public Task<User?> GetByEmailAsync(string email, CancellationToken cancellationToken = default) =>
        WithStore.FirstOrDefaultAsync(u => u.Email == email, cancellationToken);

    public Task<bool> EmailExistsAsync(string email, CancellationToken cancellationToken = default) =>
        context.Users.AnyAsync(u => u.Email == email, cancellationToken);

    public async Task<IReadOnlyList<User>> ListByStoreAsync(Guid storeId, CancellationToken cancellationToken = default) =>
        await WithStore.AsNoTracking().Where(u => u.StoreId == storeId).ToListAsync(cancellationToken);

    public Task<int> CountAdminsAsync(Guid storeId, CancellationToken cancellationToken = default) =>
        context.Users.CountAsync(u => u.StoreId == storeId && u.Role == StoreRole.Admin, cancellationToken);

    public async Task AddAsync(User user, CancellationToken cancellationToken = default) =>
        await context.Users.AddAsync(user, cancellationToken);

    public Task SaveChangesAsync(CancellationToken cancellationToken = default) =>
        context.SaveChangesAsync(cancellationToken);
}
