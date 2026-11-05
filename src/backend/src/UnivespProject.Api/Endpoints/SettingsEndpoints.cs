using UnivespProject.Api.Errors;
using UnivespProject.Application.DTOs.Settings;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Settings;

namespace UnivespProject.Api.Endpoints;

/// <summary>The logged-in user's settings (table <c>user_settings</c>).</summary>
public static class SettingsEndpoints
{
    public static IEndpointRouteBuilder MapSettingsEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/settings").WithTags("Settings").RequireAuthorization();

        group.MapGet("/", async (ISettingsService settings, CancellationToken ct) =>
                Results.Ok(await settings.GetAsync(ct)))
            .WithName("GetSettings")
            .Produces<UserSettingsResponse>();

        group.MapPut("/", async (UpdateSettingsRequest request, ISettingsService settings, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await settings.UpdateAsync(request, ct), Results.Ok))
            .WithName("UpdateSettings")
            .Produces<UserSettingsResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest);

        return app;
    }
}
