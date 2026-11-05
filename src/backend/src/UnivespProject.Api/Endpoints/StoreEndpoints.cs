using UnivespProject.Api.Errors;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Auth;
using UnivespProject.Application.DTOs.Stores;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Stores;

namespace UnivespProject.Api.Endpoints;

/// <summary>The logged-in user's store: open one or ask to join one by name and, for admins, manage its users.</summary>
public static class StoreEndpoints
{
    public static IEndpointRouteBuilder MapStoreEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/store").WithTags("Store").RequireAuthorization();

        // New name: opens the store (201, the user is its admin). Existing name: access request (200, pending).
        group.MapPost("/", (EnterStoreRequest request, ICurrentUser user, IStoreService stores, INotifier notifier, CancellationToken ct) =>
                Run(user, notifier, id => stores.EnterAsync(id, request, ct),
                    r => r.Store?.Role == "Admin" ? Results.Created("/api/auth/me", r) : Results.Ok(r)))
            .WithName("EnterStore")
            .Produces<UserResponse>(StatusCodes.Status201Created)
            .Produces<UserResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status409Conflict);

        group.MapPut("/", (RenameStoreRequest request, ICurrentUser user, IStoreService stores, INotifier notifier, CancellationToken ct) =>
                Run(user, notifier, id => stores.RenameAsync(id, request, ct), Results.Ok))
            .WithName("RenameStore")
            .Produces<UserResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status409Conflict);

        var members = group.MapGroup("/members");

        members.MapGet("/", (ICurrentUser user, IStoreService stores, INotifier notifier, CancellationToken ct) =>
                Run(user, notifier, id => stores.ListMembersAsync(id, ct), Results.Ok))
            .WithName("ListStoreMembers")
            .Produces<IReadOnlyList<StoreMemberResponse>>()
            .ProducesProblem(StatusCodes.Status403Forbidden);

        members.MapPost("/{memberId:guid}/approve", (Guid memberId, ApproveMemberRequest? request,
                    ICurrentUser user, IStoreService stores, INotifier notifier, CancellationToken ct) =>
                Run(user, notifier, id => stores.ApproveAsync(id, memberId, request ?? new ApproveMemberRequest(null), ct), Results.Ok))
            .WithName("ApproveStoreMember")
            .Produces<StoreMemberResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict);

        members.MapPut("/{memberId:guid}/role", (Guid memberId, ChangeMemberRoleRequest request,
                    ICurrentUser user, IStoreService stores, INotifier notifier, CancellationToken ct) =>
                Run(user, notifier, id => stores.ChangeRoleAsync(id, memberId, request, ct), Results.Ok))
            .WithName("ChangeStoreMemberRole")
            .Produces<StoreMemberResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict);

        members.MapPut("/{memberId:guid}/areas", (Guid memberId, UpdateMemberAreasRequest request,
                    ICurrentUser user, IStoreService stores, INotifier notifier, CancellationToken ct) =>
                Run(user, notifier, id => stores.UpdateAreasAsync(id, memberId, request, ct), Results.Ok))
            .WithName("UpdateStoreMemberAreas")
            .Produces<StoreMemberResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict);

        members.MapDelete("/{memberId:guid}", (Guid memberId, ICurrentUser user, IStoreService stores, INotifier notifier, CancellationToken ct) =>
                Run(user, notifier, id => stores.RemoveAsync(id, memberId, ct), _ => Results.NoContent()))
            .WithName("RemoveStoreMember")
            .Produces(StatusCodes.Status204NoContent)
            .ProducesProblem(StatusCodes.Status403Forbidden)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict);

        return app;
    }

    private static async Task<IResult> Run<T>(
        ICurrentUser user, INotifier notifier, Func<Guid, Task<T?>> action, Func<T, IResult> onSuccess)
    {
        if (user.Id is not { } id)
            return Results.Unauthorized();

        return notifier.ToResult(await action(id), onSuccess);
    }
}
