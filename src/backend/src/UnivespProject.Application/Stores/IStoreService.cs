using UnivespProject.Application.DTOs.Auth;
using UnivespProject.Application.DTOs.Stores;

namespace UnivespProject.Application.Stores;

/// <summary>
/// The user's store: open one or ask to join one by name, and (admins) manage its users.
/// Methods return null when they fail; the reasons are in <see cref="Notifications.INotifier"/>.
/// </summary>
public interface IStoreService
{
    /// <summary>
    /// Asks to join the store with this name or, when none has it, opens it as admin (see <see cref="IStoreEnrollment"/>).
    /// Only without access (none or pending: a pending request is replaced).
    /// </summary>
    Task<UserResponse?> EnterAsync(Guid userId, EnterStoreRequest request, CancellationToken cancellationToken = default);

    /// <summary>409 when another store already has the name.</summary>
    Task<UserResponse?> RenameAsync(Guid userId, RenameStoreRequest request, CancellationToken cancellationToken = default);

    /// <summary>Pending requests first, then by name.</summary>
    Task<IReadOnlyList<StoreMemberResponse>?> ListMembersAsync(Guid userId, CancellationToken cancellationToken = default);

    Task<StoreMemberResponse?> ApproveAsync(Guid userId, Guid memberId, ApproveMemberRequest request, CancellationToken cancellationToken = default);
    Task<StoreMemberResponse?> ChangeRoleAsync(Guid userId, Guid memberId, ChangeMemberRoleRequest request, CancellationToken cancellationToken = default);
    Task<StoreMemberResponse?> UpdateAreasAsync(Guid userId, Guid memberId, UpdateMemberAreasRequest request, CancellationToken cancellationToken = default);

    /// <summary>Removes a user (or refuses a request). The store never ends up without an admin.</summary>
    Task<bool?> RemoveAsync(Guid userId, Guid memberId, CancellationToken cancellationToken = default);
}
