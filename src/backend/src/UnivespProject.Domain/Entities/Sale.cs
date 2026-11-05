using UnivespProject.Domain.Common;
using UnivespProject.Domain.Enums;

namespace UnivespProject.Domain.Entities;

/// <summary>
/// A product sold on a date, through a channel and, when online, possibly a marketplace.
/// Comes from a spreadsheet row, is typed in, or is made at the checkout (then linked to a catalog product).
/// </summary>
public sealed class Sale : StoreOwnedEntity
{
    public const int ProductNameMaxLength = 200;
    public const int SkuMaxLength = 60;

    public Guid SalesImportId { get; private set; }

    /// <summary>Row of the spreadsheet the sale came from, to trace it back; null when typed in by the user.</summary>
    public int? RowNumber { get; private set; }

    public DateOnly SaleDate { get; private set; }
    public string ProductName { get; private set; } = string.Empty;
    public string? Sku { get; private set; }
    public int Quantity { get; private set; }
    public decimal UnitPrice { get; private set; }
    public decimal TotalPrice { get; private set; }
    public SalesChannel Channel { get; private set; }

    /// <summary>Null when the sale happened outside a marketplace (physical store or own online store).</summary>
    public Guid? MarketplaceId { get; private set; }
    public Marketplace? Marketplace { get; private set; }

    /// <summary>
    /// Catalog product of the sale: the product sold at the checkout, or the product whose SKU a
    /// typed-in or spreadsheet sale has. Null when no registered product matches.
    /// A product with sales cannot be deleted (foreign key).
    /// </summary>
    public Guid? ProductId { get; private set; }

    /// <summary>Sold at the checkout: the units left the stock and go back when the sale is removed.</summary>
    public bool IsCheckout { get; private set; }

    /// <summary>Product cost at the time of the sale (it may change later); null when unknown.</summary>
    public decimal? UnitCost { get; private set; }
    public decimal? TotalCost { get; private set; }

    // Required by Entity Framework.
    private Sale() { }

    /// <summary>
    /// Validates every field and reports all problems at once through notifications.
    /// Required values are nullable so missing cells become notifications instead of exceptions.
    /// </summary>
    public Sale(
        int? rowNumber,
        DateOnly? saleDate,
        string? productName,
        string? sku,
        int? quantity,
        decimal? unitPrice,
        SalesChannel? channel,
        Marketplace? marketplace,
        DateOnly today)
    {
        RowNumber = rowNumber;

        if (saleDate is null)
            AddNotification(Fields.SaleDate, "A data é obrigatória.");
        else if (saleDate > today)
            AddNotification(Fields.SaleDate, "A data não pode estar no futuro.");
        else
            SaleDate = saleDate.Value;

        productName = string.IsNullOrWhiteSpace(productName) ? null : TextNormalizer.CollapseSpaces(productName);
        if (productName is null)
            AddNotification(Fields.ProductName, "O produto é obrigatório.");
        else if (productName.Length > ProductNameMaxLength)
            AddNotification(Fields.ProductName, $"O produto deve ter no máximo {ProductNameMaxLength} caracteres.");
        else
            ProductName = productName;

        sku = string.IsNullOrWhiteSpace(sku) ? null : sku.Trim();
        if (sku?.Length > SkuMaxLength)
            AddNotification(Fields.Sku, $"O SKU deve ter no máximo {SkuMaxLength} caracteres.");
        else
            Sku = sku;

        if (quantity is null)
            AddNotification(Fields.Quantity, "A quantidade é obrigatória.");
        else if (quantity <= 0)
            AddNotification(Fields.Quantity, "A quantidade deve ser maior que zero.");
        else
            Quantity = quantity.Value;

        if (unitPrice is null)
            AddNotification(Fields.UnitPrice, "O preço unitário é obrigatório.");
        else if (unitPrice < 0)
            AddNotification(Fields.UnitPrice, "O preço unitário não pode ser negativo.");
        else
            UnitPrice = decimal.Round(unitPrice.Value, 2);

        if (channel is null)
            AddNotification(Fields.Channel, "O canal é obrigatório (Presencial ou Online).");
        else
            Channel = channel.Value;

        if (marketplace is not null)
        {
            if (channel == SalesChannel.InPerson)
                AddNotification(Fields.Marketplace, "Venda presencial não pode ter marketplace.");
            else
            {
                Marketplace = marketplace;
                MarketplaceId = marketplace.Id;
            }
        }

        TotalPrice = decimal.Round(Quantity * UnitPrice, 2);
    }

    /// <summary>
    /// Key that matches a catalog product's SKU (stored in upper case): the SKU in upper case.
    /// The same rule is used in SQL (<c>upper("Sku")</c>), so links made now and later agree.
    /// </summary>
    public string? SkuKey => Sku?.ToUpperInvariant();

    /// <summary>Sale made at the checkout: links the product and keeps a copy of its current cost.</summary>
    public void SellAtCheckout(Product product)
    {
        ProductId = product.Id;
        IsCheckout = true;
        UnitCost = product.CostPrice;
        TotalCost = product.CostPrice is { } cost ? decimal.Round(Quantity * cost, 2) : null;
    }

    /// <summary>
    /// Links a typed-in or spreadsheet sale to the registered product with the same SKU.
    /// Stock and cost are not touched: the sale did not go through the checkout.
    /// </summary>
    public void LinkToProduct(Guid productId) => ProductId = productId;

    /// <summary>Notification keys: the field names of the API's sale JSON.</summary>
    public static class Fields
    {
        public const string SaleDate = "date";
        public const string ProductName = "productName";
        public const string Sku = "sku";
        public const string Quantity = "quantity";
        public const string UnitPrice = "unitPrice";
        public const string Channel = "channel";
        public const string Marketplace = "marketplace";
    }
}
