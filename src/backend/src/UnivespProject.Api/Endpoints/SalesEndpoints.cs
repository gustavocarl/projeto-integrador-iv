using UnivespProject.Api.Extensions;
using UnivespProject.Domain.Enums;
using Microsoft.AspNetCore.Mvc;
using UnivespProject.Api.Errors;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Sales;

namespace UnivespProject.Api.Endpoints;

public static class SalesEndpoints
{
    private const string XlsxContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    public static IEndpointRouteBuilder MapSalesEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/sales").WithTags("Sales").RequireAuthorization();

        // ?platform=windows|macos|linux|android|ios: the file uses that system's default spreadsheet font.
        group.MapGet("/template", (string? platform, ISalesImportService sales, INotifier notifier) =>
                notifier.ToResult(sales.CreateTemplate(platform),
                    bytes => Results.File(bytes, XlsxContentType, "modelo-vendas.xlsx")))
            .WithName("DownloadSalesTemplate")
            .RequireStoreAccess(StoreArea.Imports)
            .Produces(StatusCodes.Status200OK, contentType: XlsxContentType)
            .ProducesProblem(StatusCodes.Status400BadRequest);

        group.MapPost("/imports", async (IFormFile? file, ISalesImportService sales, INotifier notifier, CancellationToken ct) =>
            {
                SalesImportResponse? response;
                if (file is null)
                {
                    response = await sales.ImportAsync(new SpreadsheetFile(string.Empty, 0, Stream.Null), ct);
                }
                else
                {
                    await using var content = file.OpenReadStream();
                    response = await sales.ImportAsync(new SpreadsheetFile(file.FileName, file.Length, content), ct);
                }

                return notifier.ToResult(response, r => Results.Created($"/api/sales/imports/{r.Id}", r));
            })
            // JWT in the Authorization header (not cookies), so there is no CSRF risk for this upload.
            .DisableAntiforgery()
            .Accepts<IFormFile>("multipart/form-data")
            .WithName("ImportSales")
            .RequireStoreAccess(StoreArea.Imports)
            .Produces<SalesImportResponse>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest);

        group.MapGet("/imports", async (ISalesImportService sales, CancellationToken ct) =>
                Results.Ok(await sales.ListAsync(ct)))
            .WithName("ListSalesImports")
            .RequireStoreAccess(StoreArea.Imports)
            .Produces<IReadOnlyList<SalesImportResponse>>();

        group.MapGet("/imports/{id:guid}", async (Guid id, ISalesImportService sales, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await sales.GetAsync(id, ct), Results.Ok))
            .WithName("GetSalesImport")
            .RequireStoreAccess(StoreArea.Imports)
            .Produces<SalesImportDetailResponse>()
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapGet("/imports/{id:guid}/deletion-impact", async (Guid id, ISalesImportService sales, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await sales.GetDeletionImpactAsync(id, ct), Results.Ok))
            .WithName("GetSalesImportDeletionImpact")
            .RequireStoreAccess(StoreArea.Imports)
            .Produces<SalesImportDeletionImpactResponse>()
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapDelete("/imports/{id:guid}", async (Guid id, ISalesImportService sales, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await sales.DeleteAsync(id, ct), _ => Results.NoContent()))
            .WithName("DeleteSalesImport")
            .RequireStoreAccess(StoreArea.Imports)
            .Produces(StatusCodes.Status204NoContent)
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapPost("/manual", async (ManualSaleRequest request, ISaleService sales, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await sales.CreateAsync(request, ct),
                    r => Results.Created($"/api/sales/imports/{r.Import.Id}/sales/{r.Sale.Id}", r)))
            .WithName("CreateManualSale")
            .RequireStoreAccess(StoreArea.Imports)
            .Produces<ManualSaleResponse>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapPost("/checkout", async (CheckoutRequest request, ICheckoutService checkout, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await checkout.CheckoutAsync(request, ct),
                    r => Results.Created($"/api/sales/imports/{r.Import.Id}", r)))
            .WithName("Checkout")
            .RequireStoreAccess(StoreArea.Checkout)
            .Produces<CheckoutResponse>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest);

        group.MapGet("/imports/{id:guid}/sales", async (
                    Guid id, string? search, int? page, int? pageSize,
                    ISaleService sales, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await sales.ListAsync(id, search, page ?? 1, pageSize ?? 50, ct), Results.Ok))
            .WithName("ListSales")
            .RequireStoreAccess(StoreArea.Imports)
            .Produces<PagedResponse<SaleResponse>>()
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapDelete("/imports/{id:guid}/sales/{saleId:guid}", async (
                    Guid id, Guid saleId, ISaleService sales, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await sales.DeleteAsync(id, saleId, ct), _ => Results.NoContent()))
            .WithName("DeleteSale")
            .RequireStoreAccess(StoreArea.Imports)
            .Produces(StatusCodes.Status204NoContent)
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapGet("/marketplaces", async (ISaleService sales, CancellationToken ct) =>
                Results.Ok(await sales.ListMarketplacesAsync(ct)))
            .WithName("ListMarketplaces")
            .RequireStoreAccess(StoreArea.Imports | StoreArea.Checkout)
            .Produces<IReadOnlyList<string>>();

        group.MapGet("/months", async (ISalesComparisonService comparison, CancellationToken ct) =>
                Results.Ok(await comparison.ListMonthsAsync(ct)))
            .WithName("ListSalesMonths")
            .RequireStoreAccess(StoreArea.Comparison)
            .Produces<IReadOnlyList<SalesMonthItem>>();

        // Sales spreadsheets of a period (all batches), kept to be downloaded again.
        group.MapPost("/exports", async (CreateSalesExportRequest request, ISalesExportService exports, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await exports.CreateAsync(request, ct),
                    r => Results.Created($"/api/sales/exports/{r.Id}/file", r)))
            .WithName("CreateSalesExport")
            .RequireStoreAccess(StoreArea.Exports)
            .Produces<SalesExportResponse>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapGet("/exports", async (ISalesExportService exports, CancellationToken ct) =>
                Results.Ok(await exports.ListAsync(ct)))
            .WithName("ListSalesExports")
            .RequireStoreAccess(StoreArea.Exports)
            .Produces<IReadOnlyList<SalesExportResponse>>();

        group.MapGet("/exports/{id:guid}/file", async (Guid id, ISalesExportService exports, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await exports.DownloadAsync(id, ct),
                    file => Results.File(file.Content, XlsxContentType, file.FileName)))
            .WithName("DownloadSalesExport")
            .RequireStoreAccess(StoreArea.Exports)
            .Produces(StatusCodes.Status200OK, contentType: XlsxContentType)
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapDelete("/exports/{id:guid}", async (Guid id, ISalesExportService exports, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await exports.DeleteAsync(id, ct), _ => Results.NoContent()))
            .WithName("DeleteSalesExport")
            .RequireStoreAccess(StoreArea.Exports)
            .Produces(StatusCodes.Status204NoContent)
            .ProducesProblem(StatusCodes.Status404NotFound);

        // GET /api/sales/comparison?base=2026-01&target=2027-01
        group.MapGet("/comparison", async (
                    [FromQuery(Name = "base")] string? baseMonth, [FromQuery(Name = "target")] string? targetMonth,
                    ISalesComparisonService comparison, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await comparison.CompareAsync(baseMonth, targetMonth, ct), Results.Ok))
            .WithName("CompareMonths")
            .RequireStoreAccess(StoreArea.Comparison)
            .Produces<MonthComparisonResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest);

        return app;
    }
}
