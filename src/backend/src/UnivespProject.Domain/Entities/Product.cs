using UnivespProject.Domain.Common;

namespace UnivespProject.Domain.Entities;

/// <summary>
/// A catalog item the store sells. Sales made through the checkout come from here and take stock out;
/// inactive products stay in the catalog (and in old sales) but can't be sold.
/// </summary>
public sealed class Product : StoreOwnedEntity
{
    public const int NameMaxLength = Sale.ProductNameMaxLength;
    public const int SkuMaxLength = Sale.SkuMaxLength;
    public const int CategoryMaxLength = 60;
    public const int ImageUrlMaxLength = 2048;

    /// <summary>Largest discount the checkout may give on the sale price (business rule: 15%).</summary>
    public const decimal MaxDiscount = 0.15m;

    public string Name { get; private set; } = string.Empty;

    /// <summary>Unique code, stored as a comparison key (upper case, no accents): "nb-01" becomes "NB-01".</summary>
    public string Sku { get; private set; } = string.Empty;
    public string? Category { get; private set; }
    public decimal SalePrice { get; private set; }

    /// <summary>What the product costs the store; null when unknown (no profit is calculated).</summary>
    public decimal? CostPrice { get; private set; }
    public int StockQuantity { get; private set; }

    /// <summary>At or below this quantity the product is flagged to be restocked.</summary>
    public int MinimumStock { get; private set; }
    public bool IsActive { get; private set; } = true;

    /// <summary>
    /// The product photo: an external link (http/https) or the path of an image uploaded to the API
    /// ("/uploads/products/…"). Null when there is none.
    /// </summary>
    public string? ImageUrl { get; private set; }

    public bool IsLowStock => StockQuantity <= MinimumStock;

    /// <summary>
    /// Selling one unit for <paramref name="unitPrice"/> loses money: it is below the cost
    /// (compared in cents; equal to the cost is allowed). Never true without a cost.
    /// </summary>
    public bool SellsAtLoss(decimal unitPrice) =>
        CostPrice is { } cost && decimal.Round(unitPrice, 2) < decimal.Round(cost, 2);

    /// <summary>Lowest price the checkout accepts: the sale price minus <see cref="MaxDiscount"/>, in cents.</summary>
    public decimal MinimumCheckoutPrice =>
        decimal.Round(SalePrice * (1 - MaxDiscount), 2, MidpointRounding.AwayFromZero);

    /// <summary>
    /// Selling for <paramref name="unitPrice"/> gives more than <see cref="MaxDiscount"/> off the
    /// sale price. Prices above the sale price are not discounts.
    /// </summary>
    public bool ExceedsMaxDiscount(decimal unitPrice) => decimal.Round(unitPrice, 2) < MinimumCheckoutPrice;

    // Required by Entity Framework.
    private Product() { }

    /// <summary>
    /// Validates every field and reports all problems at once through notifications.
    /// Values are nullable so missing fields become notifications instead of exceptions.
    /// </summary>
    public Product(string? name, string? sku, string? category, decimal? salePrice, decimal? costPrice,
        int? stockQuantity, int? minimumStock, string? imageUrl = null, bool imageRequired = false)
    {
        Update(name, sku, category, salePrice, costPrice, stockQuantity, minimumStock, imageUrl, imageRequired);
    }

    /// <summary>Replaces every field. On any error nothing is changed.</summary>
    /// <param name="imageRequired">The user's setting: when true a product without image is an error.</param>
    public void Update(string? name, string? sku, string? category, decimal? salePrice, decimal? costPrice,
        int? stockQuantity, int? minimumStock, string? imageUrl = null, bool imageRequired = false)
    {
        ClearNotifications();

        name = string.IsNullOrWhiteSpace(name) ? null : TextNormalizer.CollapseSpaces(name);
        if (name is null)
            AddNotification(Fields.Name, "O nome é obrigatório.");
        else if (name.Length > NameMaxLength)
            AddNotification(Fields.Name, $"O nome deve ter no máximo {NameMaxLength} caracteres.");

        sku = string.IsNullOrWhiteSpace(sku) ? null : TextNormalizer.ToKey(sku);
        if (sku is null)
            AddNotification(Fields.Sku, "O SKU é obrigatório.");
        else if (sku.Length > SkuMaxLength)
            AddNotification(Fields.Sku, $"O SKU deve ter no máximo {SkuMaxLength} caracteres.");

        category = string.IsNullOrWhiteSpace(category) ? null : TextNormalizer.CollapseSpaces(category);
        if (category?.Length > CategoryMaxLength)
            AddNotification(Fields.Category, $"A categoria deve ter no máximo {CategoryMaxLength} caracteres.");

        if (salePrice is null)
            AddNotification(Fields.SalePrice, "O preço de venda é obrigatório.");
        else if (salePrice < 0)
            AddNotification(Fields.SalePrice, "O preço de venda não pode ser negativo.");

        if (costPrice < 0)
            AddNotification(Fields.CostPrice, "O preço de custo não pode ser negativo.");
        // Business rule: a product is never sold at a loss (equal = no profit, allowed).
        else if (salePrice >= 0 && decimal.Round(costPrice ?? 0m, 2) > decimal.Round(salePrice.Value, 2))
            AddNotification(Fields.CostPrice,
                "O preço de custo não pode ser maior que o preço de venda: cada venda daria prejuízo.");

        if (stockQuantity is null)
            AddNotification(Fields.StockQuantity, "O estoque é obrigatório (use 0 se não houver).");
        else if (stockQuantity < 0)
            AddNotification(Fields.StockQuantity, "O estoque não pode ser negativo.");

        if (minimumStock < 0)
            AddNotification(Fields.MinimumStock, "O estoque mínimo não pode ser negativo.");

        imageUrl = string.IsNullOrWhiteSpace(imageUrl) ? null : imageUrl.Trim();
        if (imageUrl is null)
        {
            if (imageRequired)
                AddNotification(Fields.ImageUrl, "A imagem do produto é obrigatória (definido nas suas configurações).");
        }
        else if (imageUrl.Length > ImageUrlMaxLength)
            AddNotification(Fields.ImageUrl, $"O link da imagem deve ter no máximo {ImageUrlMaxLength} caracteres.");
        else if (!IsWebUrl(imageUrl) && !IsLocalPath(imageUrl))
            AddNotification(Fields.ImageUrl, "Informe um link de imagem válido, começando com http:// ou https://, ou envie um arquivo.");

        if (!IsValid)
            return;

        Name = name!;
        Sku = sku!;
        Category = category;
        SalePrice = decimal.Round(salePrice!.Value, 2);
        CostPrice = costPrice is null ? null : decimal.Round(costPrice.Value, 2);
        StockQuantity = stockQuantity!.Value;
        MinimumStock = minimumStock ?? 0;
        ImageUrl = imageUrl;
    }

    /// <summary>A path on the API itself, such as "/uploads/products/a1.png" (an uploaded image).</summary>
    private static bool IsLocalPath(string url) =>
        url.StartsWith('/') && !url.StartsWith("//") && !url.Contains("..") && !url.Contains('\\')
        && Uri.IsWellFormedUriString(url, UriKind.Relative);

    private static bool IsWebUrl(string url) =>
        Uri.TryCreate(url, UriKind.Absolute, out var uri)
        && (uri.Scheme == Uri.UriSchemeHttp || uri.Scheme == Uri.UriSchemeHttps)
        && !string.IsNullOrEmpty(uri.Host);

    public void SetActive(bool active) => IsActive = active;

    /// <summary>Takes sold units out of stock. Returns false, changing nothing, when there aren't enough.</summary>
    public bool RemoveFromStock(int quantity)
    {
        if (quantity <= 0 || quantity > StockQuantity)
            return false;

        StockQuantity -= quantity;
        return true;
    }

    /// <summary>Puts units back (a sale of this product was removed).</summary>
    public void ReturnToStock(int quantity)
    {
        if (quantity > 0)
            StockQuantity += quantity;
    }

    /// <summary>Notification keys: the field names of the API's product JSON.</summary>
    public static class Fields
    {
        public const string Name = "name";
        public const string Sku = "sku";
        public const string Category = "category";
        public const string SalePrice = "salePrice";
        public const string CostPrice = "costPrice";
        public const string StockQuantity = "stockQuantity";
        public const string MinimumStock = "minimumStock";
        public const string ImageUrl = "imageUrl";
    }
}
