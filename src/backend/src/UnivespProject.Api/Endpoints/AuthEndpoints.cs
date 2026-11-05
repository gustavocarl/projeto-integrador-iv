using UnivespProject.Api.Errors;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Auth;
using UnivespProject.Application.DTOs.Auth;
using UnivespProject.Application.Notifications;

namespace UnivespProject.Api.Endpoints;

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/auth").WithTags("Auth");

        group.MapPost("/register", async (RegisterRequest request, IAuthService auth, INotifier notifier, CancellationToken ct) =>
            {
                var response = await auth.RegisterAsync(request, ct);
                return notifier.ToResult(response, r => Results.Created("/api/auth/me", r));
            })
            .WithName("Register")
            .Produces<AuthResponse>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status409Conflict);

        group.MapPost("/login", async (LoginRequest request, IAuthService auth, INotifier notifier, CancellationToken ct) =>
            {
                var response = await auth.LoginAsync(request, ct);
                return notifier.ToResult(response, Results.Ok);
            })
            .WithName("Login")
            .Produces<AuthResponse>()
            .ProducesProblem(StatusCodes.Status401Unauthorized);

        group.MapGet("/me", async (ICurrentUser currentUser, IAuthService auth, INotifier notifier, CancellationToken ct) =>
            {
                if (currentUser.Id is not { } userId)
                    return Results.Unauthorized();

                var response = await auth.GetProfileAsync(userId, ct);
                return notifier.ToResult(response, Results.Ok);
            })
            .RequireAuthorization()
            .WithName("GetCurrentUser")
            .Produces<UserResponse>()
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapPost("/change-password", async (
                ChangePasswordRequest request, ICurrentUser currentUser, IAuthService auth, INotifier notifier, CancellationToken ct) =>
            {
                if (currentUser.Id is not { } userId)
                    return Results.Unauthorized();

                return notifier.ToResult(await auth.ChangePasswordAsync(userId, request, ct), _ => Results.NoContent());
            })
            .RequireAuthorization()
            .WithName("ChangePassword")
            .Produces(StatusCodes.Status204NoContent)
            .ProducesProblem(StatusCodes.Status400BadRequest);

        // Simple recovery for the prototype: no e-mail confirmation (see README).
        group.MapPost("/reset-password", async (ResetPasswordRequest request, IAuthService auth, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await auth.ResetPasswordAsync(request, ct), _ => Results.NoContent()))
            .WithName("ResetPassword")
            .Produces(StatusCodes.Status204NoContent)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status404NotFound);

        return app;
    }
}
