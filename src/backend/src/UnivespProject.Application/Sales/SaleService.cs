using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Sales;

internal sealed class SaleService(
    INotifier notifier,
    ISalesImportRepository imports,
    IMarketplaceRepository marketplaces,
    IProductRepository products,
    TimeProvider timeProvider) : SaleWriterService(notifier, marketplaces, timeProvider), ISaleService
{
    internal const int MaxPageSize = 100;
    internal const string ImportIdField = "importId";

    public async Task<ManualSaleResponse?> CreateAsync(ManualSaleRequest request, CancellationToken cancellationToken = default)
    {
        var (batch, isNewBatch) = await ResolveBatchAsync(request, cancellationToken);

        // Fields already reported here; the sale would only add "is required" for them.
        var reportedFields = new HashSet<string>();

        var channel = ParseChannel(request.Channel, reportedFields);
        var (marketplace, isNewMarketplace) = await ResolveMarketplaceAsync(request.Marketplace, reportedFields, cancellationToken);

        var sale = new Sale(null, request.Date, request.ProductName, request.Sku, request.Quantity,
            request.UnitPrice, channel, marketplace, Today);

        foreach (var n in sale.Notifications.Where(n => !reportedFields.Contains(n.Key)))
            Notify(n.Key, n.Message);

        if (HasNotifications || batch is null)
            return null;

        if (sale.SkuKey is { } sku
            && (await products.GetIdsBySkusAsync([sku], cancellationToken)).TryGetValue(sku, out var productId))
            sale.LinkToProduct(productId);

        batch.AddSale(sale);
        if (isNewMarketplace)
            await Marketplaces.AddRangeAsync([marketplace!], cancellationToken);
        if (isNewBatch)
            await imports.AddAsync(batch, cancellationToken);
        else
            await imports.AddSaleAsync(sale, cancellationToken);

        await imports.SaveChangesAsync(cancellationToken);
        return new ManualSaleResponse(SalesMapper.ToResponse(batch), SalesMapper.ToResponse(sale));
    }

    public async Task<PagedResponse<SaleResponse>?> ListAsync(
        Guid importId, string? search, int page, int pageSize, CancellationToken cancellationToken = default)
    {
        if (await FindAsync(importId, withSales: false, cancellationToken) is null)
            return null;

        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, MaxPageSize);
        search = string.IsNullOrWhiteSpace(search) ? null : search.Trim();

        var (items, total) = await imports.ListSalesAsync(importId, search, (page - 1) * pageSize, pageSize, cancellationToken);
        return new PagedResponse<SaleResponse>(items.Select(SalesMapper.ToResponse).ToList(), page, pageSize, total);
    }

    public async Task<bool?> DeleteAsync(Guid importId, Guid saleId, CancellationToken cancellationToken = default)
    {
        var batch = await FindAsync(importId, withSales: true, cancellationToken);
        if (batch is null)
            return null;

        var sale = batch.RemoveSale(saleId);
        if (sale is null)
        {
            Notify("Venda não encontrada neste lote.", NotificationType.NotFound);
            return null;
        }

        imports.RemoveSale(sale);
        // A checkout sale goes back to the shelf (typed-in sales linked by SKU never left it).
        if (sale is { IsCheckout: true, ProductId: { } productId }
            && await products.GetByIdAsync(productId, cancellationToken) is { } product)
            product.ReturnToStock(sale.Quantity);

        await imports.SaveChangesAsync(cancellationToken);
        return true;
    }

    public Task<IReadOnlyList<string>> ListMarketplacesAsync(CancellationToken cancellationToken = default) =>
        Marketplaces.ListNamesAsync(cancellationToken);

    /// <summary>The existing batch (by id) or a new manual one (by name); exactly one must be given.</summary>
    private async Task<(SalesImport? Batch, bool IsNew)> ResolveBatchAsync(ManualSaleRequest request, CancellationToken cancellationToken)
    {
        var hasName = !string.IsNullOrWhiteSpace(request.ImportName);
        if (request.ImportId is { } id)
        {
            if (hasName)
            {
                Notify(ImportIdField, "Escolha um lote existente ou informe o nome de um novo lote, não os dois.");
                return (null, false);
            }

            var existing = await imports.GetByIdAsync(id, cancellationToken);
            if (existing is null)
                Notify(ImportIdField, "Lote não encontrado.", NotificationType.NotFound);
            return (existing, false);
        }

        if (!hasName)
        {
            Notify(ImportIdField, "Escolha o lote da venda ou crie um novo.");
            return (null, false);
        }

        var batch = SalesImport.CreateManual(request.ImportName);
        return Validate(batch) ? (batch, true) : (null, false);
    }

    private async Task<SalesImport?> FindAsync(Guid id, bool withSales, CancellationToken cancellationToken)
    {
        var batch = withSales
            ? await imports.GetByIdWithSalesAsync(id, cancellationToken)
            : await imports.GetByIdAsync(id, cancellationToken);
        if (batch is null)
            Notify("Lote não encontrado.", NotificationType.NotFound);

        return batch;
    }
}
