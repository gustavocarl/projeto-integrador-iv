using UnivespProject.Api.Errors;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Stores;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Api.Extensions;

public static class StoreAccessExtensions
{
    /// <summary>
    /// The user must be approved in a store and allowed to use at least one of <paramref name="areas"/>
    /// (admins: everything); otherwise 403. Only then the store's data becomes visible to the request.
    /// </summary>
    public static TBuilder RequireStoreAccess<TBuilder>(this TBuilder builder, StoreArea areas)
        where TBuilder : IEndpointConventionBuilder
    {
        builder.AddEndpointFilter(async (context, next) =>
        {
            var services = context.HttpContext.RequestServices;
            var access = services.GetRequiredService<IStoreAccessService>();
            if (await access.EnterAsync(areas, context.HttpContext.RequestAborted))
                return await next(context);

            return services.GetRequiredService<INotifier>().ToResult<object>(null, Results.Ok);
        });

        return builder.ProducesProblem(StatusCodes.Status403Forbidden);
    }
}
