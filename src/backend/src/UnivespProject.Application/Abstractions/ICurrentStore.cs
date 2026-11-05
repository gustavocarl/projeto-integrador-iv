namespace UnivespProject.Application.Abstractions;

/// <summary>
/// The store of the current request. Set once the user's access is checked
/// (<see cref="Stores.IStoreAccessService"/>); the store's data is only visible after that.
/// </summary>
public interface ICurrentStore
{
    Guid? Id { get; }

    void Enter(Guid storeId);
}
