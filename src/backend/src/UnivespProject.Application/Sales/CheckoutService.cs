using System.Globalization;
using UnivespProject.Application.Abstractions;
using UnivespProject.Application.DTOs.Sales;
using UnivespProject.Application.Notifications;
using UnivespProject.Domain.Entities;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Application.Sales;

internal sealed class CheckoutService(
    INotifier notifier,
    IProductRepository products,
    ISalesImportRepository imports,
    IMarketplaceRepository marketplaces,
    TimeProvider timeProvider) : SaleWriterService(notifier, marketplaces, timeProvider), ICheckoutService
{
    internal const int MaxItems = 100;
    internal const string ItemsField = "items";
    private static readonly CultureInfo PtBr = CultureInfo.GetCultureInfo("pt-BR");

    public async Task<CheckoutResponse?> CheckoutAsync(CheckoutRequest request, CancellationToken cancellationToken = default)
    {
        var items = request.Items ?? [];
        if (items.Count == 0)
            Notify(ItemsField, "Adicione ao menos um produto à venda.");
        else if (items.Count > MaxItems)
            Notify(ItemsField, $"Uma venda pode ter no máximo {MaxItems} itens.");

        // Errors of the fields shared by every item (date, channel, marketplace) are reported once.
        var reportedFields = new HashSet<string>();
        var today = Today;
        var date = request.Date ?? today;
        var channel = ParseChannel(request.Channel, reportedFields);
        var (marketplace, isNewMarketplace) = await ResolveMarketplaceAsync(request.Marketplace, reportedFields, cancellationToken);

        var ids = items.Where(i => i.ProductId is not null).Select(i => i.ProductId!.Value).Distinct().ToList();
        var productsById = (await products.GetByIdsAsync(ids, cancellationToken)).ToDictionary(p => p.Id);

        var sales = new List<(Sale Sale, Product Product)>();
        // The same product can be on several lines; the stock must cover all of them.
        var requested = new Dictionary<Guid, int>();

        for (var i = 0; i < items.Count && items.Count <= MaxItems; i++)
        {
            var item = items[i];
            if (BuildSale(i, item, productsById, date, channel, marketplace, today, reportedFields) is not { } sale)
                continue;

            var product = productsById[item.ProductId!.Value];
            var total = requested[product.Id] = requested.GetValueOrDefault(product.Id) + sale.Quantity;
            if (total > product.StockQuantity)
            {
                Notify(ItemField(i, Sale.Fields.Quantity), product.StockQuantity == 0
                    ? $"\"{product.Name}\" está sem estoque."
                    : $"Estoque insuficiente: há {product.StockQuantity} unidade(s) de \"{product.Name}\".");
                continue;
            }

            sales.Add((sale, product));
        }

        if (HasNotifications)
            return null;

        var batchName = SalesImport.StoreBatchName(date);
        var batch = await imports.GetByNameAsync(ImportSource.Store, batchName, cancellationToken);
        var isNewBatch = batch is null;
        batch ??= SalesImport.CreateStoreMonth(date);

        foreach (var (sale, product) in sales)
        {
            product.RemoveFromStock(sale.Quantity);
            sale.SellAtCheckout(product);
            batch.AddSale(sale);
            if (!isNewBatch)
                await imports.AddSaleAsync(sale, cancellationToken);
        }

        if (isNewMarketplace)
            await Marketplaces.AddRangeAsync([marketplace!], cancellationToken);
        if (isNewBatch)
            await imports.AddAsync(batch, cancellationToken);
        await imports.SaveChangesAsync(cancellationToken);

        var withCost = sales.Where(s => s.Sale.TotalCost is not null).Select(s => s.Sale).ToList();
        decimal? cost = withCost.Count == 0 ? null : withCost.Sum(s => s.TotalCost!.Value);
        decimal? profit = cost is null ? null : withCost.Sum(s => s.TotalPrice) - cost;

        return new CheckoutResponse(
            SalesMapper.ToResponse(batch),
            sales.Select(s => SalesMapper.ToResponse(s.Sale)).ToList(),
            sales.Sum(s => s.Sale.TotalPrice),
            cost,
            profit);
    }

    /// <summary>The item's sale, or null with its problems reported ("items[2].quantity", ...).</summary>
    private Sale? BuildSale(int index, CheckoutItemRequest item, Dictionary<Guid, Product> productsById, DateOnly date,
        SalesChannel? channel, Marketplace? marketplace, DateOnly today, HashSet<string> reportedFields)
    {
        if (item.ProductId is not { } productId)
        {
            Notify(ItemField(index, "productId"), "Escolha o produto.");
            return null;
        }

        if (!productsById.TryGetValue(productId, out var product))
        {
            Notify(ItemField(index, "productId"), "Produto não encontrado.");
            return null;
        }

        if (!product.IsActive)
        {
            Notify(ItemField(index, "productId"), $"\"{product.Name}\" está inativo e não pode ser vendido.");
            return null;
        }

        var sale = new Sale(null, date, product.Name, product.Sku, item.Quantity, item.UnitPrice ?? product.SalePrice,
            channel, marketplace, today);

        foreach (var n in sale.Notifications)
        {
            if (n.Key is Sale.Fields.Quantity or Sale.Fields.UnitPrice)
                Notify(ItemField(index, n.Key), n.Message);
            else if (reportedFields.Add(n.Key))
                Notify(n.Key, n.Message);
        }

        if (!sale.IsValid)
            return null;

        // Business rule: the checkout never sells below the cost (the price is editable).
        if (product.SellsAtLoss(sale.UnitPrice))
        {
            Notify(ItemField(index, Sale.Fields.UnitPrice), BelowCostMessage(product.CostPrice!.Value));
            return null;
        }

        // Business rule: at most 15% off the product's sale price.
        if (product.ExceedsMaxDiscount(sale.UnitPrice))
        {
            Notify(ItemField(index, Sale.Fields.UnitPrice), MaxDiscountMessage(product.MinimumCheckoutPrice));
            return null;
        }

        return sale;
    }

    internal static string MaxDiscountMessage(decimal minimum) =>
        $"O desconto não pode passar de {Product.MaxDiscount * 100:0}% do preço do produto: " +
        $"o mínimo é R$ {minimum.ToString("N2", PtBr)}.";

    internal static string BelowCostMessage(decimal cost) =>
        $"O preço não pode ser menor que o custo (R$ {cost.ToString("N2", PtBr)}): a venda daria prejuízo.";

    private static string ItemField(int index, string field) => $"{ItemsField}[{index}].{field}";
}
