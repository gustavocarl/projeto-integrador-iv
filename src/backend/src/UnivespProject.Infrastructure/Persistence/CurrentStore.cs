using UnivespProject.Application.Abstractions;

namespace UnivespProject.Infrastructure.Persistence;

/// <summary>Per request: empty until the access check (then every query sees only this store).</summary>
internal sealed class CurrentStore : ICurrentStore
{
    public Guid? Id { get; private set; }

    public void Enter(Guid storeId)
    {
        if (Id is { } current && current != storeId)
            throw new InvalidOperationException("A requisição já está em outra loja.");
        Id = storeId;
    }
}
