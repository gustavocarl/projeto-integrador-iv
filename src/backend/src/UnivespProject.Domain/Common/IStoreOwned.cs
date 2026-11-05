namespace UnivespProject.Domain.Common;

/// <summary>Data that belongs to one store: every query only sees the current store's rows.</summary>
public interface IStoreOwned
{
    Guid StoreId { get; }

    /// <summary>Sets the owner once (done on save); moving to another store is not allowed.</summary>
    void AssignStore(Guid storeId);
}
