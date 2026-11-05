using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Auth;
using UnivespProject.Application.DTOs.Stores;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Notifications.Center;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Stores;

internal sealed class StoreService(
    INotifier notifier,
    IUserRepository users,
    IStoreRepository stores,
    IStoreEnrollment enrollment,
    IAccessRequestNotices notices) : BaseService(notifier), IStoreService
{
    public const string NameTaken = "Já existe outra loja com este nome.";
    private const string LastAdmin = "A loja precisa de pelo menos um admin. Torne outro usuário admin antes.";

    public async Task<UserResponse?> EnterAsync(Guid userId, EnterStoreRequest request, CancellationToken cancellationToken = default)
    {
        var user = await GetUserWithoutAccessAsync(userId, cancellationToken);
        if (user is null)
            return null;

        var store = enrollment.Prepare(request.Name, Store.Fields.Name);
        if (store is null)
            return null;

        await enrollment.EnrollAsync(user, store, cancellationToken);
        await users.SaveChangesAsync(cancellationToken);
        return UserMapper.ToResponse(user);
    }

    public async Task<UserResponse?> RenameAsync(Guid userId, RenameStoreRequest request, CancellationToken cancellationToken = default)
    {
        var admin = await GetAdminAsync(userId, cancellationToken);
        if (admin is null)
            return null;

        var store = admin.Store!;
        if (!store.Rename(request.Name))
        {
            Validate(store);
            return null;
        }

        if (await stores.NameExistsAsync(store.NormalizedName, store.Id, cancellationToken))
        {
            Notify(Store.Fields.Name, NameTaken, NotificationType.Conflict);
            return null;
        }

        await users.SaveChangesAsync(cancellationToken);
        return UserMapper.ToResponse(admin);
    }

    public async Task<IReadOnlyList<StoreMemberResponse>?> ListMembersAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var admin = await GetAdminAsync(userId, cancellationToken);
        if (admin is null)
            return null;

        var members = await users.ListByStoreAsync(admin.StoreId!.Value, cancellationToken);
        return members
            .OrderBy(u => u.Role == StoreRole.Pending ? 0 : 1)
            .ThenBy(u => u.Name, StringComparer.CurrentCultureIgnoreCase)
            .Select(UserMapper.ToMember)
            .ToList();
    }

    public async Task<StoreMemberResponse?> ApproveAsync(
        Guid userId, Guid memberId, ApproveMemberRequest request, CancellationToken cancellationToken = default)
    {
        var areas = request.Areas is null ? StoreArea.All : ParseAreas(request.Areas);
        if (areas is null)
            return null;

        var (admin, member) = await GetMemberAsync(userId, memberId, cancellationToken);
        if (admin is null || member is null)
            return null;

        if (member.Role != StoreRole.Pending)
        {
            Notify("Este usuário já tem acesso à loja.", NotificationType.Conflict);
            return null;
        }

        member.Approve(areas.Value);
        await notices.ResolveAsync(member.Id, cancellationToken);
        await notices.ApprovedAsync(member, cancellationToken);
        await users.SaveChangesAsync(cancellationToken);
        return UserMapper.ToMember(member);
    }

    public async Task<StoreMemberResponse?> ChangeRoleAsync(
        Guid userId, Guid memberId, ChangeMemberRoleRequest request, CancellationToken cancellationToken = default)
    {
        StoreRole? role = request.Role?.Trim().ToUpperInvariant() switch
        {
            "ADMIN" => StoreRole.Admin,
            "MEMBER" => StoreRole.Member,
            _ => null
        };
        if (role is null)
        {
            Notify(ChangeMemberRoleRequest.Fields.Role, "Papel inválido. Use Admin ou Member.");
            return null;
        }

        var (admin, member) = await GetMemberAsync(userId, memberId, cancellationToken);
        if (admin is null || member is null)
            return null;

        if (member.Role == StoreRole.Pending)
        {
            Notify("Aprove o acesso deste usuário antes de mudar o papel dele.", NotificationType.Conflict);
            return null;
        }

        if (member.Role == StoreRole.Admin && role == StoreRole.Member && !await HasAnotherAdminAsync(admin, cancellationToken))
        {
            Notify(LastAdmin, NotificationType.Conflict);
            return null;
        }

        member.ChangeRole(role.Value);
        await users.SaveChangesAsync(cancellationToken);
        return UserMapper.ToMember(member);
    }

    public async Task<StoreMemberResponse?> UpdateAreasAsync(
        Guid userId, Guid memberId, UpdateMemberAreasRequest request, CancellationToken cancellationToken = default)
    {
        if (request.Areas is null)
        {
            Notify(UpdateMemberAreasRequest.Fields.Areas, "Informe as partes do sistema liberadas (a lista pode ser vazia).");
            return null;
        }

        var areas = ParseAreas(request.Areas);
        if (areas is null)
            return null;

        var (admin, member) = await GetMemberAsync(userId, memberId, cancellationToken);
        if (admin is null || member is null)
            return null;

        if (member.Role != StoreRole.Member)
        {
            Notify(member.Role == StoreRole.Admin
                    ? "Admins usam todas as partes do sistema. Torne-o usuário comum para escolher."
                    : "Aprove o acesso deste usuário antes de escolher o que ele usa.",
                NotificationType.Conflict);
            return null;
        }

        member.SetAreas(areas.Value);
        await users.SaveChangesAsync(cancellationToken);
        return UserMapper.ToMember(member);
    }

    public async Task<bool?> RemoveAsync(Guid userId, Guid memberId, CancellationToken cancellationToken = default)
    {
        var (admin, member) = await GetMemberAsync(userId, memberId, cancellationToken);
        if (admin is null || member is null)
            return null;

        if (member.Role == StoreRole.Admin && !await HasAnotherAdminAsync(admin, cancellationToken))
        {
            Notify(LastAdmin, NotificationType.Conflict);
            return null;
        }

        if (member.Role == StoreRole.Pending)
            await notices.ResolveAsync(member.Id, cancellationToken);

        member.LeaveStore();
        await users.SaveChangesAsync(cancellationToken);
        return true;
    }

    private StoreArea? ParseAreas(IReadOnlyList<string> names)
    {
        var areas = StoreAreas.Parse(names, out var unknown);
        if (unknown.Count == 0)
            return areas;

        Notify(UpdateMemberAreasRequest.Fields.Areas,
            $"Parte do sistema desconhecida: {string.Join(", ", unknown)}. " +
            $"Use {string.Join(", ", StoreAreas.Each)}.");
        return null;
    }

    private async Task<bool> HasAnotherAdminAsync(User admin, CancellationToken cancellationToken) =>
        await users.CountAdminsAsync(admin.StoreId!.Value, cancellationToken) > 1;

    private async Task<User?> GetUserWithoutAccessAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await GetUserAsync(userId, cancellationToken);
        if (user is { HasStoreAccess: true })
        {
            Notify($"Você já faz parte da loja {user.Store?.Name}.", NotificationType.Conflict);
            return null;
        }

        return user;
    }

    private async Task<User?> GetAdminAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await GetUserAsync(userId, cancellationToken);
        if (user is { IsStoreAdmin: false })
        {
            Notify(StoreAccessService.AdminKey, "Só o admin da loja pode gerenciar a loja e os usuários.", NotificationType.Forbidden);
            return null;
        }

        return user;
    }

    /// <summary>The admin and a user of the same store (someone from another store is "not found").</summary>
    private async Task<(User? Admin, User? Member)> GetMemberAsync(Guid userId, Guid memberId, CancellationToken cancellationToken)
    {
        var admin = await GetAdminAsync(userId, cancellationToken);
        if (admin is null)
            return (null, null);

        var member = await users.GetByIdAsync(memberId, cancellationToken);
        if (member is null || member.StoreId != admin.StoreId)
        {
            Notify("Usuário não encontrado nesta loja.", NotificationType.NotFound);
            return (admin, null);
        }

        return (admin, member);
    }

    private async Task<User?> GetUserAsync(Guid userId, CancellationToken cancellationToken)
    {
        var user = await users.GetByIdAsync(userId, cancellationToken);
        if (user is null)
            Notify("Usuário não encontrado.", NotificationType.NotFound);
        return user;
    }
}
