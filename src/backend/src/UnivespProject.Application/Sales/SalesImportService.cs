using UnivespProject.Application.Abstractions;
using UnivespProject.Application.Common;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;
using UnivespProject.Application.Settings;
using UnivespProject.Domain.Common;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;
using UnivespProject.Domain.Notifications;

namespace UnivespProject.Application.Sales;

internal sealed class SalesImportService(
    INotifier notifier,
    ISalesSpreadsheet spreadsheet,
    ISalesImportRepository imports,
    IMarketplaceRepository marketplaces,
    IProductRepository products,
    ICurrentUserSettings settings,
    TimeProvider timeProvider) : BaseService(notifier), ISalesImportService
{
    /// <summary>Above this, the response would be unreadable; the user fixes these and uploads again.</summary>
    internal const int MaxReportedErrors = 100;

    private int _reportedErrors;
    private int _hiddenErrors;
    private HashSet<Guid> _persistedMarketplaces = [];

    public async Task<SalesImportResponse?> ImportAsync(SpreadsheetFile file, CancellationToken cancellationToken = default)
    {
        if (!ValidateFile(file))
            return null;

        var salesImport = new SalesImport(file.FileName);
        if (!Validate(salesImport))
            return null;

        var sheet = spreadsheet.Read(file.Content);
        foreach (var error in sheet.Errors)
            ReportError(error);
        if (HasNotifications)
            return null;

        if (sheet.Rows.Count == 0)
        {
            ReportError("A planilha não contém vendas. Preencha a aba \"Vendas\" do modelo.");
            return null;
        }

        if (sheet.Rows.Count > SalesSpreadsheetLayout.MaxRows)
        {
            ReportError($"A planilha tem {sheet.Rows.Count} linhas; o máximo é {SalesSpreadsheetLayout.MaxRows}. Divida o arquivo.");
            return null;
        }

        var marketplacesByKey = await LoadMarketplacesAsync(sheet.Rows, cancellationToken);
        var today = DateOnly.FromDateTime(timeProvider.GetLocalNow().DateTime);

        foreach (var row in sheet.Rows)
        {
            var sale = BuildSale(row, marketplacesByKey, today);
            if (sale is not null)
                salesImport.AddSale(sale);
        }

        if (_hiddenErrors > 0)
            ReportError($"... e mais {_hiddenErrors} erro(s). Corrija os anteriores e envie novamente.", force: true);

        if (HasNotifications)
            return null;

        var createProducts = (await settings.GetAsync(cancellationToken)).CreateProductsOnImport;
        var createdProducts = await LinkProductsAsync(salesImport.Sales, createProducts, cancellationToken);

        var newMarketplaces = marketplacesByKey.Values.Where(m => m.IsValid && !IsPersisted(m)).ToList();
        await marketplaces.AddRangeAsync(newMarketplaces, cancellationToken);
        foreach (var product in createdProducts)
            await products.AddAsync(product, cancellationToken);
        await imports.AddAsync(salesImport, cancellationToken);
        // One save: the sales, the new marketplaces and the new products go in together or not at all.
        await imports.SaveChangesAsync(cancellationToken);

        // Sales of earlier batches with the same SKU (typed in or imported before) now belong to the new products too.
        foreach (var product in createdProducts)
            await products.SyncSaleLinksAsync(product.Id, product.Sku, cancellationToken);

        return ToResponse(salesImport) with { CreatedProducts = createdProducts.Count };
    }

    public async Task<IReadOnlyList<SalesImportResponse>> ListAsync(CancellationToken cancellationToken = default) =>
        (await imports.ListAsync(cancellationToken)).Select(ToResponse).ToList();

    public async Task<SalesImportDetailResponse?> GetAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var salesImport = await FindAsync(id, cancellationToken);
        if (salesImport is null)
            return null;

        var byChannel = SalesBreakdown.ByChannel(await imports.GetTotalsByChannelAsync(id, cancellationToken));
        var byMarketplace = SalesBreakdown.ByMarketplace(await imports.GetOnlineTotalsByMarketplaceAsync(id, cancellationToken));
        var byDay = FillPeriod(salesImport, await imports.GetTotalsByDayAsync(id, cancellationToken));
        var productItems = BuildProducts(await imports.GetTotalsByProductAsync(id, cancellationToken));
        var profitSummary = SalesBreakdown.Profit(await imports.GetCostTotalsAsync(id, cancellationToken));

        return new SalesImportDetailResponse(ToResponse(salesImport), byChannel, byMarketplace, byDay, productItems, profitSummary);
    }

    /// <summary>One item per day from the first to the last sale, so gaps show up as zero.</summary>
    private static List<DailyItem> FillPeriod(SalesImport salesImport, IReadOnlyList<DayTotals> totals)
    {
        if (salesImport.PeriodStart is not { } start || salesImport.PeriodEnd is not { } end)
            return [];

        var byDate = totals.ToDictionary(t => t.Date);
        var days = new List<DailyItem>();
        for (var date = start; date <= end; date = date.AddDays(1))
        {
            days.Add(byDate.TryGetValue(date, out var t)
                ? new DailyItem(date, t.Sales, t.Quantity, t.Revenue)
                : new DailyItem(date, 0, 0, 0m));
        }

        return days;
    }

    /// <summary>
    /// Merges spelling variations of the same product (same SKU, or same name when there is no SKU)
    /// and classifies each one in the ABC curve, with a stock recommendation.
    /// </summary>
    private static List<ProductItem> BuildProducts(IReadOnlyList<ProductTotals> totals)
    {
        var merged = totals
            .GroupBy(t => t.Key)
            .Select(g =>
            {
                var main = g.MaxBy(t => t.Quantity)!;
                return new
                {
                    Key = g.Key,
                    main.ProductName,
                    main.Sku,
                    Sales = g.Sum(t => t.Sales),
                    Quantity = g.Sum(t => t.Quantity),
                    Revenue = g.Sum(t => t.Revenue),
                    LastSaleDate = g.Max(t => t.LastSaleDate),
                };
            })
            .OrderByDescending(p => p.Revenue)
            .ThenByDescending(p => p.Quantity)
            .ThenBy(p => p.ProductName, StringComparer.CurrentCulture)
            .ToList();

        var classes = AbcCurve.Classify(merged.Select(p => p.Revenue).ToList());
        var total = merged.Sum(p => p.Revenue);
        var medianQuantity = StockRecommendation.Median(merged.Select(p => p.Quantity).ToList());

        return merged
            .Select((p, i) => new ProductItem(
                p.Key, p.ProductName, p.Sku, p.Sales, p.Quantity, p.Revenue,
                total == 0 ? 0 : Math.Round(p.Revenue / total, 4),
                classes[i].ToString(),
                StockRecommendation.Recommend(classes[i], p.Quantity, medianQuantity).ToString(),
                p.LastSaleDate))
            .ToList();
    }

    public async Task<bool?> DeleteAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var salesImport = await imports.GetByIdWithSalesAsync(id, cancellationToken);
        if (salesImport is null)
        {
            Notify("Importação não encontrada.", NotificationType.NotFound);
            return null;
        }

        // Checkout sales go back to the shelf.
        var soldByProduct = salesImport.Sales
            .Where(s => s is { IsCheckout: true, ProductId: not null })
            .GroupBy(s => s.ProductId!.Value)
            .ToDictionary(g => g.Key, g => g.Sum(s => s.Quantity));
        foreach (var product in await products.GetByIdsAsync(soldByProduct.Keys, cancellationToken))
            product.ReturnToStock(soldByProduct[product.Id]);

        imports.Remove(salesImport);
        await imports.SaveChangesAsync(cancellationToken);
        return true;
    }

    public async Task<SalesImportDeletionImpactResponse?> GetDeletionImpactAsync(
        Guid id, CancellationToken cancellationToken = default)
    {
        var salesImport = await FindAsync(id, cancellationToken);
        if (salesImport is null)
            return null;

        var impact = await imports.GetDeletionImpactAsync(id, cancellationToken);
        return new SalesImportDeletionImpactResponse(salesImport.Id, salesImport.FileName,
            salesImport.SalesCount, salesImport.TotalRevenue, impact.LinkedProducts, impact.CheckoutQuantity);
    }

    public byte[]? CreateTemplate(string? platform = null)
    {
        if (SpreadsheetFont.TryFor(platform, out var font))
            return spreadsheet.CreateTemplate(font);

        Notify(SpreadsheetFont.Field, SpreadsheetFont.InvalidMessage);
        return null;
    }

    private bool ValidateFile(SpreadsheetFile? file)
    {
        if (file is null || file.Length == 0)
            ReportError("Selecione uma planilha para importar.");
        else if (!string.Equals(Path.GetExtension(file.FileName), ".xlsx", StringComparison.OrdinalIgnoreCase))
            ReportError("Formato não suportado. Envie um arquivo .xlsx (use o modelo de planilha).");
        else if (file.Length > SalesSpreadsheetLayout.MaxFileSizeBytes)
            ReportError($"O arquivo deve ter no máximo {SalesSpreadsheetLayout.MaxFileSizeBytes / (1024 * 1024)} MB.");

        return !HasNotifications;
    }

    /// <summary>
    /// Returns every marketplace named in the spreadsheet, keyed by normalized name:
    /// existing ones from the database, new ones created in memory (saved only if the import succeeds).
    /// </summary>
    private async Task<Dictionary<string, Marketplace>> LoadMarketplacesAsync(
        IReadOnlyList<SalesSheetRow> rows, CancellationToken cancellationToken)
    {
        var namesByKey = rows
            .Where(r => !string.IsNullOrWhiteSpace(r.Marketplace))
            .GroupBy(r => TextNormalizer.ToKey(r.Marketplace!))
            .ToDictionary(g => g.Key, g => g.First().Marketplace!);

        var existing = await marketplaces.GetByNormalizedNamesAsync(namesByKey.Keys, cancellationToken);
        _persistedMarketplaces = existing.Select(m => m.Id).ToHashSet();

        var result = existing.ToDictionary(m => m.NormalizedName);
        foreach (var (key, name) in namesByKey)
            result.TryAdd(key, new Marketplace(name));

        return result;
    }

    /// <summary>
    /// Links each sale to the registered product with the same SKU. With <paramref name="createProducts"/>
    /// (the user's setting "create products on import", off by default),
    /// SKUs not in the catalog first become new products (not saved yet), which are returned.
    /// Sales without SKU stay unlinked: a product needs a SKU and one is never made up.
    /// </summary>
    private async Task<List<Product>> LinkProductsAsync(
        IReadOnlyCollection<Sale> sales, bool createProducts, CancellationToken cancellationToken)
    {
        var skus = sales.Select(s => s.SkuKey).OfType<string>().Distinct().ToList();
        var productIds = new Dictionary<string, Guid>(await products.GetIdsBySkusAsync(skus, cancellationToken));

        var created = new List<Product>();
        if (createProducts)
        {
            var unknown = sales
                .Where(s => s.SkuKey is { } sku && !productIds.ContainsKey(sku))
                .GroupBy(s => s.SkuKey!);
            foreach (var group in unknown)
            {
                if (NewProduct(group.Key, group.ToList()) is not { } product)
                    continue;

                created.Add(product);
                productIds[group.Key] = product.Id;
            }
        }

        foreach (var sale in sales)
        {
            if (sale.SkuKey is { } sku && productIds.TryGetValue(sku, out var productId))
                sale.LinkToProduct(productId);
        }

        return created;
    }

    /// <summary>
    /// A catalog product made from the sales of one SKU: the name most often used for it (ties: the
    /// latest), the latest unit price, no category, cost or image, and no stock (past sales don't
    /// say how many units are left). The user fills in the rest when editing it.
    /// Null when the SKU can't be stored as it is (e.g. accents): the product would not match its sales.
    /// </summary>
    internal static Product? NewProduct(string sku, IReadOnlyList<Sale> sales)
    {
        if (TextNormalizer.ToKey(sku) != sku)
            return null;

        var latest = sales.MaxBy(s => (s.SaleDate, s.RowNumber ?? 0))!;
        var name = sales
            .GroupBy(s => s.ProductName)
            .OrderByDescending(g => g.Count())
            .ThenByDescending(g => g.Max(s => (s.SaleDate, s.RowNumber ?? 0)))
            .First().Key;

        // The user's "require image" setting is not applied here: like existing products,
        // a product without image only has to get one when it is edited.
        var product = new Product(name, sku, category: null, latest.UnitPrice, costPrice: null,
            stockQuantity: 0, minimumStock: 0);
        return product.IsValid ? product : null;
    }

    private bool IsPersisted(Marketplace marketplace) => _persistedMarketplaces.Contains(marketplace.Id);

    private Sale? BuildSale(SalesSheetRow row, Dictionary<string, Marketplace> marketplacesByKey, DateOnly today)
    {
        var errors = new List<string>(row.CellErrors.Values);
        // Fields whose problem is already reported; the domain would only add "is required" for them.
        var reportedFields = new HashSet<string>(row.CellErrors.Keys);

        SalesChannel? channel = null;
        if (SalesChannelParser.TryParse(row.Channel, out var parsed))
            channel = parsed;
        else if (!string.IsNullOrWhiteSpace(row.Channel))
        {
            errors.Add($"Canal \"{row.Channel}\" inválido. Use Presencial ou Online.");
            reportedFields.Add(Sale.Fields.Channel);
        }

        Marketplace? marketplace = null;
        if (!string.IsNullOrWhiteSpace(row.Marketplace))
        {
            marketplace = marketplacesByKey[TextNormalizer.ToKey(row.Marketplace)];
            errors.AddRange(marketplace.Notifications.Select(n => n.Message));
        }

        var sale = new Sale(row.RowNumber, row.Date, row.Product, row.Sku, row.Quantity, row.UnitPrice,
            channel, marketplace is { IsValid: true } ? marketplace : null, today);

        errors.AddRange(sale.Notifications.Where(n => !reportedFields.Contains(n.Key)).Select(n => n.Message));

        foreach (var error in errors)
            ReportError($"Linha {row.RowNumber}: {error}");

        return errors.Count == 0 ? sale : null;
    }

    private void ReportError(string message, bool force = false)
    {
        if (!force && _reportedErrors >= MaxReportedErrors)
        {
            _hiddenErrors++;
            return;
        }

        _reportedErrors++;
        Notify(message, NotificationType.Validation);
    }

    private async Task<SalesImport?> FindAsync(Guid id, CancellationToken cancellationToken)
    {
        var salesImport = await imports.GetByIdAsync(id, cancellationToken);
        if (salesImport is null)
            Notify("Importação não encontrada.", NotificationType.NotFound);

        return salesImport;
    }

    private static SalesImportResponse ToResponse(SalesImport i) => SalesMapper.ToResponse(i);
}
