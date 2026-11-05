using UnivespProject.Api.Errors;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Notifications;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Notifications.Center;

namespace UnivespProject.Api.Endpoints;

/// <summary>
/// The logged-in user's notification center (the bell in the app). Any logged-in user, even without
/// store access: a pending user is told when the access is approved.
/// </summary>
public static class NotificationEndpoints
{
    public static IEndpointRouteBuilder MapNotificationEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/notifications").WithTags("Notifications").RequireAuthorization();

        group.MapGet("/", async (ICurrentUser user, IUserNotificationService notifications, CancellationToken ct) =>
                user.Id is { } id ? Results.Ok(await notifications.ListAsync(id, ct)) : Results.Unauthorized())
            .WithName("ListNotifications")
            .Produces<NotificationListResponse>();

        group.MapPost("/{notificationId:guid}/read", async (Guid notificationId, ICurrentUser user,
                    IUserNotificationService notifications, INotifier notifier, CancellationToken ct) =>
                user.Id is { } id
                    ? notifier.ToResult(await notifications.MarkReadAsync(id, notificationId, ct), Results.Ok)
                    : Results.Unauthorized())
            .WithName("MarkNotificationRead")
            .Produces<NotificationResponse>()
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapPost("/read-all", async (ICurrentUser user, IUserNotificationService notifications, CancellationToken ct) =>
                user.Id is { } id
                    ? Results.Ok(new { marked = await notifications.MarkAllReadAsync(id, ct) })
                    : Results.Unauthorized())
            .WithName("MarkAllNotificationsRead")
            .Produces(StatusCodes.Status200OK);

        return app;
    }
}
