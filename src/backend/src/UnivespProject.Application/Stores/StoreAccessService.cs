using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Stores;

internal sealed class StoreAccessService(
    INotifier notifier,
    ICurrentUser currentUser,
    IUserRepository users,
    ICurrentStore currentStore) : BaseService(notifier), IStoreAccessService
{
    public const string StoreKey = "store";
    public const string AreaKey = "area";

    /// <summary>Admin-only actions (managing the store and its users).</summary>
    public const string AdminKey = "admin";

    public async Task<bool> EnterAsync(StoreArea areas, CancellationToken cancellationToken = default)
    {
        var user = currentUser.Id is { } id ? await users.GetByIdAsync(id, cancellationToken) : null;
        if (user is null)
        {
            Notify("Sessão inválida. Entre novamente.", NotificationType.Unauthorized);
            return false;
        }

        if (!user.HasStoreAccess)
        {
            Notify(StoreKey, user.Role == StoreRole.Pending
                    ? $"Seu pedido de acesso à loja {user.Store?.Name} ainda não foi aprovado pelo admin."
                    : "Você não faz parte de nenhuma loja. Crie a sua ou peça acesso a uma.",
                NotificationType.Forbidden);
            return false;
        }

        if (!user.CanUseAny(areas))
        {
            Notify(AreaKey, "O admin da loja não liberou esta parte do sistema para você.", NotificationType.Forbidden);
            return false;
        }

        currentStore.Enter(user.StoreId!.Value);
        return true;
    }
}
