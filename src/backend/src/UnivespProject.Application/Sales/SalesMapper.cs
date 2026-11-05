using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Domain.Entities;

namespace UnivespProject.Application.Sales;

internal static class SalesMapper
{
    public static SalesImportResponse ToResponse(SalesImport i) => new(
        i.Id, i.FileName, i.Source.ToString(), i.CreatedAt, i.CreatedBy,
        i.SalesCount, i.TotalQuantity, i.TotalRevenue, i.PeriodStart, i.PeriodEnd);

    public static SaleResponse ToResponse(Sale s) => new(
        s.Id, s.SaleDate, s.ProductName, s.Sku, s.Quantity, s.UnitPrice, s.TotalPrice,
        s.Channel.ToString(), SalesChannelParser.Label(s.Channel), s.Marketplace?.Name,
        s.RowNumber, s.CreatedAt, s.CreatedBy, s.ProductId, s.TotalCost, s.IsCheckout);
}
