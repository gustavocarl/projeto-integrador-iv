using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Stores;

/// <summary>
/// Puts a user in a store by its name: when a store with that name already exists (ignoring accents,
/// casing and extra spaces) the user asks its admins for access (pending, the admins are notified);
/// otherwise the store is opened and the user becomes its admin.
/// Shared by sign-up and by the store screen. Nothing is saved here: the caller saves the user.
/// </summary>
public interface IStoreEnrollment
{
    /// <summary>Validates the store name (no database access); errors go to <paramref name="key"/>. Null when invalid.</summary>
    Store? Prepare(string? name, string key);

    /// <summary>Joins the store named like <paramref name="prepared"/> or opens <paramref name="prepared"/>.</summary>
    Task<StoreEnrollmentResult> EnrollAsync(User user, Store prepared, CancellationToken cancellationToken = default);
}

public enum StoreEnrollmentResult
{
    /// <summary>New store: the user is its admin.</summary>
    Opened,

    /// <summary>Existing store: the user waits for an admin.</summary>
    Requested
}
