namespace UnivespProject.Application.DTOs.Products;

/// <summary>Create or replace a product. <see cref="IsActive"/> defaults to true on create and is kept on update.</summary>
/// <param name="CostPrice">Optional; without it the product's sales have no profit.</param>
/// <param name="MinimumStock">Optional (0); at or below it the product is flagged as low stock.</param>
/// <param name="ImageUrl">Link (http/https) to the product photo; required only when the user's setting says so.</param>
public sealed record ProductRequest(
    string? Name,
    string? Sku,
    string? Category,
    decimal? SalePrice,
    decimal? CostPrice,
    int? StockQuantity,
    int? MinimumStock,
    bool? IsActive,
    string? ImageUrl = null);

/// <param name="Margin">(sale price - cost) / sale price, e.g. 0.35 = 35%; null without cost or price.</param>
public sealed record ProductResponse(
    Guid Id,
    string Name,
    string Sku,
    string? Category,
    decimal SalePrice,
    decimal? CostPrice,
    decimal? Margin,
    int StockQuantity,
    int MinimumStock,
    bool IsLowStock,
    bool IsActive,
    string? ImageUrl,
    DateTime CreatedAt,
    DateTime? UpdatedAt);
