namespace UnivespProject.Domain.Common;

/// <summary>
/// Base for the store's data (products, sales, batches...). The store is filled on save from the
/// request's store, so services never pass it around.
/// </summary>
public abstract class StoreOwnedEntity : BaseEntity, IStoreOwned
{
    public Guid StoreId { get; private set; }

    public void AssignStore(Guid storeId)
    {
        if (storeId == Guid.Empty)
            throw new ArgumentException("A loja é obrigatória.", nameof(storeId));
        if (StoreId != Guid.Empty && StoreId != storeId)
            throw new InvalidOperationException("Um registro não pode mudar de loja.");

        StoreId = storeId;
    }
}
