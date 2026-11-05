using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Common;

namespace UnivespProject.Infrastructure.Persistence.Interceptors;

/// <summary>
/// Fills the audit fields of <see cref="BaseEntity"/> on every save.
/// </summary>
internal sealed class AuditInterceptor(ICurrentUser currentUser) : SaveChangesInterceptor
{
    private const string SystemUser = "system";

    public override InterceptionResult<int> SavingChanges(DbContextEventData eventData, InterceptionResult<int> result)
    {
        ApplyAudit(eventData.Context);
        return base.SavingChanges(eventData, result);
    }

    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        ApplyAudit(eventData.Context);
        return base.SavingChangesAsync(eventData, result, cancellationToken);
    }

    private void ApplyAudit(DbContext? context)
    {
        if (context is null)
            return;

        var now = DateTime.UtcNow;
        var user = currentUser.Email;

        foreach (var entry in context.ChangeTracker.Entries<BaseEntity>())
        {
            switch (entry.State)
            {
                case EntityState.Added:
                    entry.Entity.CreatedAt = now;
                    if (string.IsNullOrEmpty(entry.Entity.CreatedBy))
                        entry.Entity.CreatedBy = user ?? SystemUser;
                    break;

                case EntityState.Modified:
                    entry.Entity.UpdatedAt = now;
                    // Without an authenticated user, keep an author the entity set itself (e.g. on login).
                    if (user is not null || !entry.Property(e => e.UpdatedBy).IsModified)
                        entry.Entity.UpdatedBy = user ?? SystemUser;
                    // Creation data must never change after insert.
                    entry.Property(e => e.CreatedAt).IsModified = false;
                    entry.Property(e => e.CreatedBy).IsModified = false;
                    break;
            }
        }
    }
}
