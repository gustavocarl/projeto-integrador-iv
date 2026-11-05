using UnivespProject.Api.Extensions;
using UnivespProject.Domain.Enums;
using UnivespProject.Api.Errors;
using UnivespProject.Application.DTOs.Products;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.ProductImages;
using UnivespProject.Application.Products;

namespace UnivespProject.Api.Endpoints;

public static class ProductEndpoints
{
    public static IEndpointRouteBuilder MapProductEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/products").WithTags("Products").RequireAuthorization();

        group.MapGet("/", async (string? search, string? category, bool? includeInactive,
                    IProductService products, CancellationToken ct) =>
                Results.Ok(await products.ListAsync(search, category, includeInactive ?? false, ct)))
            .WithName("ListProducts")
            .RequireStoreAccess(StoreArea.Products | StoreArea.Checkout)
            .Produces<IReadOnlyList<ProductResponse>>();

        group.MapGet("/categories", async (IProductService products, CancellationToken ct) =>
                Results.Ok(await products.ListCategoriesAsync(ct)))
            .WithName("ListProductCategories")
            .RequireStoreAccess(StoreArea.Products)
            .Produces<IReadOnlyList<string>>();

        group.MapPost("/images", async (IFormFile? file, IProductImageService images, INotifier notifier, CancellationToken ct) =>
            {
                ProductImageResponse? response;
                if (file is null)
                {
                    response = await images.UploadAsync(new ProductImageFile(string.Empty, 0, Stream.Null), ct);
                }
                else
                {
                    await using var content = file.OpenReadStream();
                    response = await images.UploadAsync(new ProductImageFile(file.FileName, file.Length, content), ct);
                }

                return notifier.ToResult(response, r => Results.Created(r.Url, r));
            })
            .DisableAntiforgery()
            .Accepts<IFormFile>("multipart/form-data")
            .WithName("UploadProductImage")
            .RequireStoreAccess(StoreArea.Products)
            .Produces<ProductImageResponse>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest);

        group.MapGet("/{id:guid}", async (Guid id, IProductService products, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await products.GetAsync(id, ct), Results.Ok))
            .WithName("GetProduct")
            .RequireStoreAccess(StoreArea.Products | StoreArea.Checkout)
            .Produces<ProductResponse>()
            .ProducesProblem(StatusCodes.Status404NotFound);

        group.MapPost("/", async (ProductRequest request, IProductService products, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await products.CreateAsync(request, ct), r => Results.Created($"/api/products/{r.Id}", r)))
            .WithName("CreateProduct")
            .RequireStoreAccess(StoreArea.Products)
            .Produces<ProductResponse>(StatusCodes.Status201Created)
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status409Conflict);

        group.MapPut("/{id:guid}", async (Guid id, ProductRequest request, IProductService products, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await products.UpdateAsync(id, request, ct), Results.Ok))
            .WithName("UpdateProduct")
            .RequireStoreAccess(StoreArea.Products)
            .Produces<ProductResponse>()
            .ProducesProblem(StatusCodes.Status400BadRequest)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict);

        group.MapDelete("/{id:guid}", async (Guid id, IProductService products, INotifier notifier, CancellationToken ct) =>
                notifier.ToResult(await products.DeleteAsync(id, ct), _ => Results.NoContent()))
            .WithName("DeleteProduct")
            .RequireStoreAccess(StoreArea.Products)
            .Produces(StatusCodes.Status204NoContent)
            .ProducesProblem(StatusCodes.Status404NotFound)
            .ProducesProblem(StatusCodes.Status409Conflict);

        return app;
    }
}
