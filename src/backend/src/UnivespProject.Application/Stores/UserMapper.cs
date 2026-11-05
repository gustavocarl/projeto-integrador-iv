using UnivespProject.Application.DTOs.Auth;
using UnivespProject.Application.DTOs.Stores;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Stores;

/// <summary>User → API responses (shared by auth and store services).</summary>
public static class UserMapper
{
    public static UserResponse ToResponse(User user) =>
        new(user.Id, user.Name, user.Email, user.CreatedAt, ToMembership(user));

    public static StoreMemberResponse ToMember(User user) =>
        new(user.Id, user.Name, user.Email, user.Role?.ToString() ?? string.Empty,
            StoreAreas.ToNames(user.EffectiveAreas), user.CreatedAt);

    private static StoreMembershipResponse? ToMembership(User user) =>
        user is { Store: { } store, Role: { } role }
            ? new StoreMembershipResponse(
                store.Id, store.Name, role.ToString(), StoreAreas.ToNames(user.EffectiveAreas))
            : null;
}
