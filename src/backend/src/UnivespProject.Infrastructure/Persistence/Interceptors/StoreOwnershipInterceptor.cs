using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using UnivespProject.Application.Abstractions;
using UnivespProject.Domain.Common;

namespace UnivespProject.Infrastructure.Persistence.Interceptors;

/// <summary>Stamps new store data (<see cref="IStoreOwned"/>) with the request's store.</summary>
internal sealed class StoreOwnershipInterceptor(ICurrentStore currentStore) : SaveChangesInterceptor
{
    public override InterceptionResult<int> SavingChanges(DbContextEventData eventData, InterceptionResult<int> result)
    {
        AssignStore(eventData.Context);
        return base.SavingChanges(eventData, result);
    }

    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        AssignStore(eventData.Context);
        return base.SavingChangesAsync(eventData, result, cancellationToken);
    }

    private void AssignStore(DbContext? context)
    {
        if (context is null)
            return;

        foreach (var entry in context.ChangeTracker.Entries<IStoreOwned>())
        {
            if (entry.State != EntityState.Added || entry.Entity.StoreId != Guid.Empty)
                continue;

            // Endpoints with store data always check access first (RequireStoreAccess).
            var storeId = currentStore.Id
                          ?? throw new InvalidOperationException("Dados da loja salvos sem loja na requisição.");
            entry.Entity.AssignStore(storeId);
        }
    }
}
