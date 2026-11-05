using UnivespProject.Api.Extensions;
using UnivespProject.Domain.Enums;
using UnivespProject.Api.Errors;
using UnivespProject.Application.Analytics;
using UnivespProject.Application.DTOs.Analytics;
using UnivespProject.Application.Notifications;

namespace UnivespProject.Api.Endpoints;

/// <summary>Machine learning over the sales history (ML.NET): forecast and product groups.</summary>
public static class AnalyticsEndpoints
{
    public static IEndpointRouteBuilder MapAnalyticsEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/analytics").WithTags("Analytics").RequireAuthorization()
            .RequireStoreAccess(StoreArea.Analytics);

        // GET /api/analytics/forecast?months=3
        group.MapGet("/forecast", async (int? months, ISalesForecastService forecast, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await forecast.ForecastAsync(months, ct), Results.Ok))
            .WithName("ForecastSales")
            .Produces<SalesForecastResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status404NotFound);

        // GET /api/analytics/product-groups?groups=3 (without groups: chosen by the silhouette)
        group.MapGet("/product-groups", async (int? groups, IProductGroupsService service, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await service.GroupAsync(groups, ct), Results.Ok))
            .WithName("GroupProducts")
            .Produces<ProductGroupsResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status404NotFound);

        return app;
    }
}
