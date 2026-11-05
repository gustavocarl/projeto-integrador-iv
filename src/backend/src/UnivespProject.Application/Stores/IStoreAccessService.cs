using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Stores;

/// <summary>Checks, at the start of a request, whether the logged-in user may use the store's data.</summary>
public interface IStoreAccessService
{
    /// <summary>
    /// True when the user is approved in a store and may use at least one of <paramref name="areas"/>;
    /// the request then sees that store's data (<see cref="Abstractions.ICurrentStore"/>).
    /// Otherwise a 403 on the <c>store</c> key (or <c>area</c> when only the area is missing).
    /// </summary>
    Task<bool> EnterAsync(StoreArea areas, CancellationToken cancellationToken = default);
}
